import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calories_models.dart';
import 'api_key_service.dart';
import 'gemini_service.dart' show GeminiException;

/// Gemini-backed calorie / BMI estimator. The locally computed Mifflin-St Jeor
/// and BMI values are sent as reference numbers so the AI narrative stays
/// anchored to accurate maths. Uses the active key/endpoint from the Keys page.
class CaloriesService {
  static Future<WeeklyCalorieEstimate> generateWeeklyEstimate(
    CalorieProfile profile,
  ) async {
    final config = await ApiKeyStore.instance.requireActiveConfig();

    final bmr = CalorieMath.bmr(
      age: profile.age,
      gender: profile.gender,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
    );
    final tdee = CalorieMath.tdee(
      age: profile.age,
      gender: profile.gender,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      activity: profile.activity,
    );

    final prompt =
        '''
You are an expert registered dietitian and sports nutritionist.
Provide a 7-day maintenance-calorie estimate based on the profile below.

PROFILE:
- Age: ${profile.age} years
- Gender: ${profile.gender}
- Height: ${profile.heightCm} cm
- Weight: ${profile.weightKg} kg
- Activity Level: ${profile.activity}

VERIFIED REFERENCE VALUES (Mifflin-St Jeor, do not contradict these):
- BMR: ${bmr.round()} kcal/day
- Activity multiplier: ${CalorieMath.activityMultiplier(profile.activity)}
- TDEE (maintenance): ${tdee.round()} kcal/day

Return ONLY a valid JSON object (no markdown, no code fences, no explanation):
{
  "dailyTarget": 2200,
  "weeklyTarget": 15400,
  "summary": "2-3 sentence explanation of the estimate",
  "days": [
    {"day": "Monday", "calories": 2200, "note": "Short practical note"}
  ],
  "tips": ["Actionable nutrition tip 1", "Tip 2", "Tip 3"]
}

RULES:
- Return exactly 7 day entries, Monday through Sunday.
- dailyTarget must equal the reference TDEE (${tdee.round()} kcal) within a small margin, since no weight-goal was specified (maintenance).
- weeklyTarget must equal dailyTarget multiplied by 7.
- Day values should be realistic and consistent with dailyTarget; small variation across days is fine.
- Keep notes and tips short, practical and specific to this profile.
- Strictly valid JSON, no trailing commas.
''';

    final raw = await _askGemini(prompt, config);
    final parsed = _decode(raw);
    final daily = _asInt(parsed['dailyTarget'], fallback: tdee.round());
    final daysJson = parsed['days'] as List<dynamic>? ?? [];
    final days = daysJson.map((entry) {
      final map = entry as Map<String, dynamic>;
      return DayCalorieEstimate(
        day: (map['day'] as String?)?.trim().isNotEmpty == true
            ? map['day'] as String
            : 'Day',
        calories: _asInt(map['calories'], fallback: daily),
        note: (map['note'] as String?) ?? '',
      );
    }).toList();

    return WeeklyCalorieEstimate(
      id: 'c-${DateTime.now().millisecondsSinceEpoch}',
      profile: profile,
      bmr: bmr.round(),
      tdee: tdee.round(),
      dailyTarget: daily,
      weeklyTarget: _asInt(parsed['weeklyTarget'], fallback: daily * 7),
      summary: (parsed['summary'] as String?) ?? '',
      days: days,
      tips: (parsed['tips'] as List<dynamic>? ?? [])
          .map((tip) => tip.toString())
          .toList(),
      createdAt: DateTime.now(),
    );
  }

  static Future<BmiEstimate> generateBmiEstimate(CalorieProfile profile) async {
    final config = await ApiKeyStore.instance.requireActiveConfig();

    final bmi = CalorieMath.bmi(
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
    );
    final category = CalorieMath.bmiCategory(bmi);
    final range = CalorieMath.healthyWeightRange(profile.heightCm);

    final prompt =
        '''
You are an expert registered dietitian.
Interpret this BMI profile for a client.

PROFILE:
- Age: ${profile.age} years
- Gender: ${profile.gender}
- Height: ${profile.heightCm} cm
- Weight: ${profile.weightKg} kg

VERIFIED REFERENCE VALUES (do not contradict these):
- BMI: ${bmi.toStringAsFixed(1)}
- WHO category: $category
- Healthy weight range for this height: $range

Return ONLY a valid JSON object (no markdown, no code fences, no explanation):
{
  "category": "$category",
  "healthyWeightRange": "$range",
  "interpretation": "2-3 sentence explanation of what this BMI means",
  "recommendations": ["Actionable recommendation 1", "Recommendation 2", "Recommendation 3"]
}

RULES:
- Keep the reference category and healthy weight range exactly as given.
- Be clear that BMI is a screening tool, not a diagnosis, and that muscle mass / body composition matter.
- Give short, practical, non-judgemental recommendations tailored to this profile.
- Strictly valid JSON, no trailing commas.
''';

    final raw = await _askGemini(prompt, config);
    final parsed = _decode(raw);
    return BmiEstimate(
      id: 'b-${DateTime.now().millisecondsSinceEpoch}',
      profile: profile,
      bmi: bmi,
      category: (parsed['category'] as String?)?.trim().isNotEmpty == true
          ? parsed['category'] as String
          : category,
      healthyWeightRange:
          (parsed['healthyWeightRange'] as String?)?.trim().isNotEmpty == true
          ? parsed['healthyWeightRange'] as String
          : range,
      interpretation: (parsed['interpretation'] as String?) ?? '',
      recommendations: (parsed['recommendations'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      createdAt: DateTime.now(),
    );
  }

  static Future<String> _askGemini(String prompt, ActiveAiConfig config) async {
    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.5,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
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

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const GeminiException('No response generated by Gemini.');
    }
    final parts =
        (candidates[0]['content'] as Map<String, dynamic>?)?['parts']
            as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw const GeminiException('Empty content in Gemini response.');
    }

    var text = (parts[0]['text'] as String? ?? '').trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-z]*\n?'), '');
      text = text.replaceFirst(RegExp(r'\n?```$'), '');
      text = text.trim();
    }
    return text;
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiException(
        'Could not parse the estimate from Gemini. Please try again.',
      );
    }
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
