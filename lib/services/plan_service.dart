import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/plan_models.dart';
import '../models/workout_models.dart';
import 'api_key_service.dart';
import 'gemini_service.dart' show GeminiException;
import 'youtube_service.dart';

/// Gemini-backed generator for weekly and single-day training plans. Uses the
/// active key/endpoint validated in the Keys page; without one a descriptive
/// [ApiKeyException] is thrown so the UI can prompt the user.
class PlanService {
  /// Generates a plan for [scope] from the collected [details].
  static Future<GeneratedPlan> generatePlan({
    required PlanDetails details,
    required PlanScope scope,
  }) async {
    final config = await ApiKeyStore.instance.requireActiveConfig();

    final isWeekly = scope == PlanScope.week;
    final dayLabel = details.dayLabel ?? 'Day 1';
    final exerciseTypes = details.exerciseTypes.isEmpty
        ? 'No specific preference - choose the most suitable split'
        : details.exerciseTypes.join(', ');
    final combination = details.exerciseCombination.trim().isEmpty
        ? 'None specified - choose freely'
        : details.exerciseCombination;
    // Neutral label used only if Gemini omits a category/target/focus field.
    final labelFallback = details.exerciseTypes.isEmpty
        ? 'General'
        : details.exerciseTypes.join(', ');

    final prompt =
        '''
You are an expert certified strength and conditioning coach.
Generate a detailed, safe and realistic training plan from the user's inputs.

TRAINEE PROFILE:
- Primary Goal: ${details.goal}
- Experience Level: ${details.experienceLevel}
- Equipment Available: ${details.equipment}
- Days Per Week Committed: ${details.daysPerWeek}
- Selected Day (single-day plan): $dayLabel
- Exercise Types to Include: $exerciseTypes
- Exercise Combination: $combination
- Plan Scope: ${isWeekly ? 'FULL WEEK' : 'SINGLE DAY'}

INSTRUCTIONS:
Return ONLY a valid JSON object (no markdown, no code fences, no explanation) with this exact structure:
{
  "title": "Short motivating plan title",
  "overview": "2-3 sentence overview explaining how the plan serves the goal",
  "days": [
    {
      "label": "Day 1 - Monday",
      "workoutName": "Full Body Strength A",
      "focus": "Full Body",
      "note": "Short coaching note for this day",
      "exercises": [
        {
          "name": "Exercise Name",
          "category": "Muscle Group",
          "sets": "3 sets",
          "reps": "8-10 reps",
          "rest": "90s",
          "cues": ["Form cue 1", "Safety cue 2", "Performance cue 3"]
        }
      ]
    }
  ]
}

RULES:
- Scope is ${isWeekly ? 'a full week' : 'a single day'}. For a full week, return exactly ${details.daysPerWeek} entries for training days plus any rest / light-cardio days needed to cover all 7 days, and use day labels such as "Day 1 - Monday". For a single day, return exactly ONE entry labeled "$dayLabel".
- Build each day primarily from the selected exercise types: $exerciseTypes. Include the "Rest/Light Cardio" option where recovery makes sense.
- Pair the muscle groups in the Exercise Combination ($combination) in the same sessions. For a single day, train all of those groups in that one workout. For a full week, spread the combination across the training days while keeping the listed groups together where sensible. If no combination was specified, choose an effective split yourself.
- Only prescribe movements possible with: ${details.equipment}.
- Respect the experience level (${details.experienceLevel}): beginners get simple technique-focused movements, intermediates get moderate loading, advanced get compound/higher-intensity variations.
- Align volume, rep ranges, rest periods and exercise selection with the goal: ${details.goal}.
- Give every exercise 2 or 3 short, actionable coaching cues.
- The JSON must be strictly valid - no trailing commas, no comments.
''';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 4096,
      },
    };

    final uri = Uri.parse(config.generateUrl);

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: geminiHeaders(config.key),
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));
    } on Exception catch (e) {
      throw GeminiException('Could not reach Gemini: $e');
    }

    if (response.statusCode != 200) {
      Object? errorBody;
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {
        errorBody = null;
      }
      final message = errorBody is Map<String, dynamic>
          ? (errorBody['error']?['message'] ?? 'Unknown error from Gemini API')
          : 'Unknown error from Gemini API';
      throw GeminiException('API Error ${response.statusCode}: $message');
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const GeminiException('No response generated by Gemini.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw const GeminiException('Empty content in Gemini response.');
    }

    var rawText = (parts[0]['text'] as String? ?? '').trim();
    if (rawText.startsWith('```')) {
      rawText = rawText.replaceFirst(RegExp(r'^```[a-z]*\n?'), '');
      rawText = rawText.replaceFirst(RegExp(r'\n?```$'), '');
      rawText = rawText.trim();
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(rawText) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiException(
        'Could not parse the plan from Gemini. Please try again.',
      );
    }

    final daysJson = parsed['days'] as List<dynamic>?;
    if (daysJson == null || daysJson.isEmpty) {
      throw const GeminiException(
        'Gemini returned an empty plan. Please try again.',
      );
    }

    final days = daysJson.map((entry) {
      final dayMap = entry as Map<String, dynamic>;
      final exercisesJson = dayMap['exercises'] as List<dynamic>? ?? [];
      final exercises = exercisesJson.map((e) {
        final ex = e as Map<String, dynamic>;
        final name = (ex['name'] as String?)?.trim() ?? '';
        final cues = (ex['cues'] as List<dynamic>? ?? [])
            .map((cue) => cue.toString())
            .toList();
        final videoUrl = ex['videoUrl'] as String?;
        return ExerciseModel(
          name: name.isEmpty ? 'Exercise' : name,
          category: (ex['category'] as String?)?.trim().isNotEmpty == true
              ? ex['category'] as String
              : labelFallback,
          difficulty: details.experienceLevel,
          target: (ex['target'] as String?) ?? labelFallback,
          equipment: details.equipment,
          sets: (ex['sets'] as String?) ?? '3 sets',
          reps: (ex['reps'] as String?) ?? '10 reps',
          rest: (ex['rest'] as String?) ?? '60s',
          pr: (ex['pr'] as String?) ?? 'Bodyweight',
          cues: cues,
          videoUrl: (videoUrl == null || videoUrl.isEmpty) ? null : videoUrl,
        );
      }).toList();

      return PlanDay(
        label: (dayMap['label'] as String?)?.trim().isNotEmpty == true
            ? dayMap['label'] as String
            : (isWeekly ? 'Training Day' : dayLabel),
        workoutName:
            (dayMap['workoutName'] as String?)?.trim().isNotEmpty == true
            ? dayMap['workoutName'] as String
            : 'Workout',
        focus: (dayMap['focus'] as String?)?.trim().isNotEmpty == true
            ? dayMap['focus'] as String
            : labelFallback,
        note: (dayMap['note'] as String?) ?? '',
        exercises: exercises,
      );
    }).toList();

    // Attach an accurate, playable YouTube demonstration to every generated
    // exercise. Resolve unique names in parallel so a full week does not pay
    // the lookup cost repeatedly. Curated matches are instant; unknown ones
    // are resolved by YouTubeService (with a safe search-URL fallback).
    final pendingNames = <String, String>{};
    for (final day in days) {
      for (final exercise in day.exercises) {
        final url = exercise.videoUrl;
        if (url == null || url.isEmpty || url.contains('search_query')) {
          pendingNames.putIfAbsent(
            exercise.name.toLowerCase(),
            () => exercise.name,
          );
        }
      }
    }

    if (pendingNames.isNotEmpty) {
      final uniqueNames = pendingNames.values.toList();
      final resolvedUrls = await Future.wait(
        uniqueNames.map((name) => YouTubeService.getExactVideoUrl(name)),
      );
      final resolvedByKey = <String, String>{};
      for (var i = 0; i < uniqueNames.length; i++) {
        resolvedByKey[uniqueNames[i].toLowerCase()] = resolvedUrls[i];
      }

      for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
        final day = days[dayIndex];
        final withVideos = day.exercises.map((exercise) {
          final resolved = resolvedByKey[exercise.name.toLowerCase()];
          if (resolved == null || resolved.isEmpty) return exercise;
          return exercise.copyWith(videoUrl: resolved);
        }).toList();
        days[dayIndex] = PlanDay(
          label: day.label,
          workoutName: day.workoutName,
          focus: day.focus,
          note: day.note,
          exercises: withVideos,
        );
      }
    }

    return GeneratedPlan(
      id: 'p-${DateTime.now().millisecondsSinceEpoch}',
      scope: scope,
      title: (parsed['title'] as String?)?.trim().isNotEmpty == true
          ? parsed['title'] as String
          : (isWeekly ? 'Your Weekly Plan' : 'Your Single-Day Plan'),
      overview: (parsed['overview'] as String?) ?? '',
      details: details,
      days: days,
      createdAt: DateTime.now(),
    );
  }
}
