import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/calories_models.dart';
import 'package:workout_app/models/diet_models.dart';
import 'package:workout_app/models/plan_models.dart';
import 'package:workout_app/models/pose_history_models.dart';
import 'package:workout_app/models/workout_models.dart';
import 'package:workout_app/services/live_tracking_history_service.dart';
import 'package:workout_app/services/local_store.dart';
import 'package:workout_app/services/plan_history_service.dart';
import 'package:workout_app/state/diet_state.dart';
import 'package:workout_app/state/workout_state.dart';
import 'package:workout_app/theme/theme_controller.dart';

void main() {
  setUp(() async {
    await LocalStore.instance.resetForTesting();
  });

  test('local store round-trips JSON values', () async {
    await LocalStore.instance.write('workout_app.test.map', {
      'count': 2,
      'items': ['a', 'b'],
    });
    await LocalStore.instance.write('workout_app.test.list', [1, 2, 3]);

    expect(LocalStore.instance.readMap('workout_app.test.map'), {
      'count': 2,
      'items': ['a', 'b'],
    });
    expect(LocalStore.instance.readList('workout_app.test.list'), [1, 2, 3]);
  });

  test(
    'workout state restores saved workouts, current workout and logs',
    () async {
      final exercise = ExerciseModel(
        name: 'Push Up',
        category: 'Chest',
        difficulty: 'Beginner',
        target: 'Chest',
        equipment: 'Bodyweight',
        sets: '3 sets',
        reps: '10 reps',
        rest: '60s',
        pr: '0 kg',
      );
      final workout = WorkoutModel(
        id: 'saved-1',
        name: 'Test Routine',
        focus: 'Chest',
        duration: '30m',
        difficulty: 'Beginner',
        date: 'Today',
        exercises: [exercise],
      );
      final log = WorkoutSessionLog(
        id: 'log-1',
        exerciseName: 'Push Up',
        category: 'Chest',
        timestamp: DateTime(2026, 11, 20, 10),
        totalDurationSeconds: 120,
        sets: [
          ExerciseSetLog(
            setNumber: 1,
            weight: 0,
            reps: 10,
            completedAt: DateTime(2026, 11, 20, 10),
          ),
        ],
      );

      await LocalStore.instance.write('workout_app.workout_state.v1', {
        'savedWorkouts': [workout.toJson()],
        'currentWorkout': workout.toJson(),
        'exerciseLogs': [log.toJson()],
        'selectedTabIndex': 4,
      });

      final restored = WorkoutState();
      await restored.ensureLoaded();

      expect(restored.savedWorkouts.single.id, 'saved-1');
      expect(restored.currentWorkout.name, 'Test Routine');
      expect(restored.exerciseLogs.single.sets.single.reps, 10);
      expect(restored.selectedTabIndex, 4);
    },
  );

  test('diet state restores goals and entries for a date', () async {
    final date = DateTime(2026, 11, 20);
    final day = DietDay(
      calorieGoal: 1800,
      waterGoalMl: 3000,
      entries: [
        DietEntry(
          id: 'water-1',
          slotHour: 9,
          type: DietActivityType.water,
          label: 'Water',
          detail: '1 glass',
          waterMl: 250,
          createdAt: DateTime(2026, 11, 20, 9),
        ),
      ],
    );

    await LocalStore.instance.write('workout_app.diet_state.v1', {
      '2026-11-20': day.toJson(),
    });

    final restored = DietState();
    await restored.ensureLoaded();
    final loaded = restored.day(date);

    expect(loaded.calorieGoal, 1800);
    expect(loaded.waterGoalMl, 3000);
    expect(loaded.entries.single.waterMl, 250);
  });

  test('theme settings restore mode and palette', () async {
    await LocalStore.instance.write('workout_app.theme.v1', {
      'mode': 'light',
      'seed': ThemeController.palettes[1].seed.toARGB32(),
      'paletteName': ThemeController.palettes[1].name,
    });

    await ThemeController.ensureLoaded();

    expect(ThemeController.isDark, isFalse);
    expect(ThemeController.seed.value, ThemeController.palettes[1].seed);
    expect(ThemeController.paletteName.value, ThemeController.palettes[1].name);

    ThemeController.mode.value = ThemeMode.dark;
    ThemeController.seed.value = ThemeController.palettes.first.seed;
    ThemeController.paletteName.value = ThemeController.palettes.first.name;
  });

  test('generated plans survive a local-store round trip', () async {
    final plan = GeneratedPlan(
      id: 'plan-1',
      scope: PlanScope.week,
      title: 'Test Plan',
      overview: 'Overview',
      details: const PlanDetails(
        goal: 'Build muscle',
        experienceLevel: 'Intermediate',
        equipment: 'Gym',
        daysPerWeek: 3,
        exerciseTypes: ['Strength'],
        exerciseCombination: 'Chest+Tricep',
      ),
      days: [
        PlanDay(
          label: 'Day 1',
          workoutName: 'Push Day',
          focus: 'Chest',
          exercises: [
            ExerciseModel(
              name: 'Push Up',
              category: 'Chest',
              difficulty: 'Beginner',
              target: 'Chest',
              equipment: 'Bodyweight',
              sets: '3',
              reps: '10',
              rest: '60s',
              pr: '0 kg',
            ),
          ],
        ),
      ],
      createdAt: DateTime(2026, 11, 20, 12),
    );

    await LocalStore.instance.write(
      'workout_app.plan_result.v1',
      plan.toJson(),
    );

    final restored = GeneratedPlan.fromJson(
      LocalStore.instance.readMap('workout_app.plan_result.v1')!,
    );

    expect(restored.id, 'plan-1');
    expect(restored.scope, PlanScope.week);
    expect(restored.details.exerciseCombination, 'Chest+Tricep');
    expect(restored.days.single.exercises.single.name, 'Push Up');
    expect(restored.createdAt, DateTime(2026, 11, 20, 12));
  });

  test('plan history is scoped to the signed-in session', () async {
    final plan = GeneratedPlan(
      id: 'history-plan-1',
      scope: PlanScope.week,
      title: 'Guest History Plan',
      overview: 'Overview',
      details: const PlanDetails(
        goal: 'Build muscle',
        experienceLevel: 'Intermediate',
        equipment: 'Gym',
        daysPerWeek: 3,
        exerciseTypes: ['Strength'],
        exerciseCombination: 'Chest+Tricep',
      ),
      days: const [
        PlanDay(
          label: 'Day 1',
          workoutName: 'Push Day',
          focus: 'Chest',
          exercises: [],
        ),
      ],
      createdAt: DateTime(2026, 11, 20, 12),
    );

    await PlanHistoryStore.save(plan);

    expect(PlanHistoryStore.read().single.plan.id, 'history-plan-1');

    LocalStore.instance.setNamespace(LocalStore.newUserNamespace);
    expect(PlanHistoryStore.read(), isEmpty);

    LocalStore.instance.setNamespace(LocalStore.guestNamespace);
    await LocalStore.instance.deleteNamespace(LocalStore.guestNamespace);
    expect(PlanHistoryStore.read(), isEmpty);
  });

  test(
    'live tracking history survives a round trip and is session scoped',
    () async {
      final session = LiveTrackingSession(
        id: 'live-1',
        startedAt: DateTime(2026, 11, 23, 9),
        endedAt: DateTime(2026, 11, 23, 9, 1),
        exerciseName: 'Bodyweight Squat',
        repCount: 12,
        squatCount: 12,
        curlCount: 0,
        pushupCount: 0,
        kneeAngle: 95.2,
        elbowAngle: 160.4,
        minKneeAngle: 82.1,
        minElbowAngle: null,
        feedback: 'Deep squat',
        engine: 'ML Kit',
        cameraName: 'Back camera',
        videoPath: '/tmp/live.webm',
        videoBase64: 'ZmFrZSB2aWRlbyBieXRlcw==',
        videoMimeType: 'video/webm',
        keypoints: const [
          PoseKeypointSnapshot(
            name: 'left_knee',
            x: 0.4,
            y: 0.7,
            confidence: 0.9,
          ),
        ],
      );

      await LiveTrackingHistoryStore.save(session);
      final restored = LiveTrackingHistoryStore.read().single;
      expect(restored.id, 'live-1');
      expect(restored.exerciseName, 'Bodyweight Squat');
      expect(restored.repCount, 12);
      expect(restored.formattedDuration, '1m');
      expect(restored.keypoints.single.name, 'left_knee');
      expect(restored.hasVideo, isTrue);
      expect(restored.videoPath, '/tmp/live.webm');
      expect(restored.videoBase64, 'ZmFrZSB2aWRlbyBieXRlcw==');
      expect(restored.videoMimeType, 'video/webm');

      LocalStore.instance.setNamespace(LocalStore.newUserNamespace);
      expect(LiveTrackingHistoryStore.read(), isEmpty);
      LocalStore.instance.setNamespace(LocalStore.guestNamespace);
    },
  );

  test('calorie and BMI results survive a local-store round trip', () async {
    const profile = CalorieProfile(
      age: 30,
      gender: 'Male',
      heightCm: 175,
      weightKg: 70,
      activity: '1-3 days/week (Light)',
    );
    final weekly = WeeklyCalorieEstimate(
      id: 'weekly-1',
      profile: profile,
      bmr: 1600,
      tdee: 2200,
      dailyTarget: 2000,
      weeklyTarget: 14000,
      summary: 'Summary',
      days: const [DayCalorieEstimate(day: 'Monday', calories: 2000)],
      tips: const ['Stay hydrated'],
      createdAt: DateTime(2026, 11, 20, 12),
    );
    final bmi = BmiEstimate(
      id: 'bmi-1',
      profile: profile,
      bmi: 22.9,
      category: 'Normal weight',
      healthyWeightRange: '57 - 76 kg',
      interpretation: 'Healthy',
      recommendations: const ['Keep it up'],
      createdAt: DateTime(2026, 11, 20, 12),
    );

    await LocalStore.instance.write('workout_app.calories_results.v1', {
      'weekly': weekly.toJson(),
      'bmi': bmi.toJson(),
    });

    final saved = LocalStore.instance.readMap(
      'workout_app.calories_results.v1',
    )!;
    final restoredWeekly = WeeklyCalorieEstimate.fromJson(
      saved['weekly'] as Map<String, dynamic>,
    );
    final restoredBmi = BmiEstimate.fromJson(
      saved['bmi'] as Map<String, dynamic>,
    );

    expect(restoredWeekly.dailyTarget, 2000);
    expect(restoredWeekly.days.single.day, 'Monday');
    expect(restoredBmi.bmi, 22.9);
    expect(restoredBmi.recommendations.single, 'Keep it up');
  });
}
