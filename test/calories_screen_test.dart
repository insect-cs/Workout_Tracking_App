import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/calories_models.dart';
import 'package:workout_app/screens/calories_screen.dart';
import 'package:workout_app/services/api_key_service.dart';

void main() {
  setUp(() => ApiKeyStore.instance.resetForTesting());

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
}
