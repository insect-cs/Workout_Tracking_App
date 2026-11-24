import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/calories_models.dart';
import 'package:workout_app/screens/calories_screen.dart';
import 'package:workout_app/services/api_key_service.dart';
import 'package:workout_app/services/calorie_history_service.dart';
import 'package:workout_app/services/local_store.dart';

void main() {
  setUp(() async {
    await ApiKeyStore.instance.resetForTesting();
    await LocalStore.instance.resetForTesting();
  });

  testWidgets('Calories weekly form shows all inputs and the estimate CTA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: CaloriesScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('CALORIES'), findsOneWidget);
    expect(find.text('Weekly estimate'), findsOneWidget);
    expect(find.text('BMI calculate'), findsOneWidget);

    for (final label in [
      'AGE',
      'GENDER',
      'HEIGHT',
      'WEIGHT',
      'ACTIVITY LEVEL',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'Missing $label');
    }

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Generate Estimate'), findsOneWidget);
  });

  testWidgets('bottom CTA follows the selected tab', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: CaloriesScreen(onBack: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BMI calculate'));
    await tester.pumpAndSettle();

    expect(find.text('Generate results'), findsOneWidget);
    expect(find.text('Generate Estimate'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets(
    'generating without an API key opens the key dialog on both tabs',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: CaloriesScreen(onBack: () {})));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Estimate'));
      await tester.pumpAndSettle();
      expect(find.text('Add Gemini API key'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('BMI calculate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate results'));
      await tester.pumpAndSettle();
      expect(find.text('Add Gemini API key'), findsOneWidget);
      expect(find.text('Create another estimate'), findsNothing);
    },
  );

  test('calorie and BMI reference math is accurate', () {
    const profile = CalorieProfile(
      age: 30,
      gender: 'Male',
      heightCm: 175,
      weightKg: 70,
      activity: 'Little or no exercise',
    );

    expect(
      CalorieMath.bmr(
        age: profile.age,
        gender: profile.gender,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
      ),
      closeTo(1648.75, 0.01),
    );
    expect(
      CalorieMath.tdee(
        age: profile.age,
        gender: profile.gender,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
        activity: profile.activity,
      ),
      closeTo(1978.5, 0.01),
    );
    expect(CalorieMath.bmi(heightCm: 175, weightKg: 70), closeTo(22.86, 0.01));
    expect(CalorieMath.bmiCategory(22.86), 'Normal weight');
    expect(CalorieMath.healthyWeightRange(175), '57 - 76 kg');
    expect(CalorieMath.activityLevels.length, 6);
  });

  testWidgets('History tab sits beside BMI calculate and starts empty', (
    tester,
  ) async {
    _setCalorieTestSize(tester);
    await tester.pumpWidget(MaterialApp(home: CaloriesScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('No saved responses yet'), findsOneWidget);
    expect(find.text('Generate Estimate'), findsNothing);
    expect(find.text('Generate results'), findsNothing);
  });

  testWidgets('weekly estimate saves to History and can be reopened', (
    tester,
  ) async {
    _setCalorieTestSize(tester);
    final weekly = _sampleWeekly();
    await LocalStore.instance.write('workout_app.calories_results.v1', {
      'weekly': weekly.toJson(),
    });

    await tester.pumpWidget(MaterialApp(home: CaloriesScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Save to History'), findsOneWidget);
    await tester.tap(find.text('Save to History'));
    await tester.pumpAndSettle();

    expect(find.text('Saved to History'), findsOneWidget);
    expect(find.text('View History'), findsOneWidget);
    final history = CalorieHistoryStore.read();
    expect(history, hasLength(1));
    expect(history.single.weekly?.id, weekly.id);

    await tester.tap(find.text('View History'));
    await tester.pumpAndSettle();

    expect(find.text('SAVED RESPONSES'), findsOneWidget);
    expect(find.text('Weekly calorie estimate'), findsOneWidget);
    expect(find.text('Open saved response'), findsOneWidget);

    await tester.tap(find.text('Open saved response'));
    await tester.pumpAndSettle();

    expect(find.text('Your Calorie Estimate'), findsOneWidget);
    expect(find.text('Saved to History'), findsOneWidget);
  });

  testWidgets('BMI result saves to History', (tester) async {
    _setCalorieTestSize(tester);
    final bmi = _sampleBmi();
    await LocalStore.instance.write('workout_app.calories_results.v1', {
      'bmi': bmi.toJson(),
    });

    await tester.pumpWidget(MaterialApp(home: CaloriesScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Save to History'), findsOneWidget);
    await tester.tap(find.text('Save to History'));
    await tester.pumpAndSettle();

    final history = CalorieHistoryStore.read();
    expect(history, hasLength(1));
    expect(history.single.bmi?.id, bmi.id);

    await tester.tap(find.text('View History'));
    await tester.pumpAndSettle();

    expect(find.text('BMI result'), findsOneWidget);
    expect(find.text('Open saved response'), findsOneWidget);
  });

  testWidgets('weekly result returns to the weekly edit form', (tester) async {
    _setCalorieTestSize(tester);
    await LocalStore.instance.write('workout_app.calories_results.v1', {
      'weekly': _sampleWeekly().toJson(),
    });

    await tester.pumpWidget(MaterialApp(home: CaloriesScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Go to previous screen'), findsOneWidget);
    await tester.tap(find.text('Go to previous screen'));
    await tester.pumpAndSettle();

    expect(find.text('Your Calorie Estimate'), findsNothing);
    expect(find.text('Create another estimate'), findsNothing);
    expect(find.text('Generate Estimate'), findsOneWidget);
    expect(find.text('ACTIVITY LEVEL'), findsOneWidget);
  });

  testWidgets('BMI result returns to the BMI edit form', (tester) async {
    _setCalorieTestSize(tester);
    await LocalStore.instance.write('workout_app.calories_results.v1', {
      'bmi': _sampleBmi().toJson(),
    });

    await tester.pumpWidget(MaterialApp(home: CaloriesScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Go to previous screen'), findsOneWidget);
    await tester.tap(find.text('Go to previous screen'));
    await tester.pumpAndSettle();

    expect(find.text('BMI RESULT'), findsNothing);
    expect(find.text('Create another estimate'), findsNothing);
    expect(find.text('Generate results'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  test('calorie history is session-scoped and JSON round-trips', () async {
    final weekly = await CalorieHistoryStore.saveWeekly(_sampleWeekly());
    final bmi = await CalorieHistoryStore.saveBmi(_sampleBmi());

    final history = CalorieHistoryStore.read();
    expect(history, hasLength(2));
    expect(history.map((entry) => entry.id), containsAll([weekly.id, bmi.id]));
    expect(
      history.firstWhere((entry) => entry.id == weekly.id).weekly?.summary,
      'Maintain with balanced meals.',
    );
    expect(
      history.firstWhere((entry) => entry.id == bmi.id).bmi?.category,
      'Normal weight',
    );

    LocalStore.instance.setNamespace(LocalStore.newUserNamespace);
    expect(CalorieHistoryStore.read(), isEmpty);
    LocalStore.instance.setNamespace(LocalStore.guestNamespace);
    expect(CalorieHistoryStore.read(), hasLength(2));
  });
}

void _setCalorieTestSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

WeeklyCalorieEstimate _sampleWeekly() => WeeklyCalorieEstimate(
  id: 'weekly-1',
  profile: const CalorieProfile(
    age: 30,
    gender: 'Male',
    heightCm: 175,
    weightKg: 70,
    activity: 'Little or no exercise',
  ),
  bmr: 1650,
  tdee: 1980,
  dailyTarget: 2000,
  weeklyTarget: 14000,
  summary: 'Maintain with balanced meals.',
  days: const [DayCalorieEstimate(day: 'Monday', calories: 2000)],
  tips: const ['Stay hydrated'],
  createdAt: DateTime(2026, 11, 24, 12),
);

BmiEstimate _sampleBmi() => BmiEstimate(
  id: 'bmi-1',
  profile: const CalorieProfile(
    age: 30,
    gender: 'Male',
    heightCm: 175,
    weightKg: 70,
    activity: 'Little or no exercise',
  ),
  bmi: 22.9,
  category: 'Normal weight',
  healthyWeightRange: '57 - 76 kg',
  interpretation: 'Healthy range.',
  recommendations: const ['Keep it up'],
  createdAt: DateTime(2026, 11, 24, 12),
);
