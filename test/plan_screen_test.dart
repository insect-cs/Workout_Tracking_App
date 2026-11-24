import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/plan_models.dart';
import 'package:workout_app/screens/plan_screen.dart';
import 'package:workout_app/services/api_key_service.dart';
import 'package:workout_app/services/local_store.dart';
import 'package:workout_app/services/plan_history_service.dart';

void main() {
  setUp(() async {
    await ApiKeyStore.instance.resetForTesting();
    await LocalStore.instance.resetForTesting();
  });

  testWidgets('Plan form shows all details and the weekly CTA', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: PlanScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('PLAN'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Single day'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    for (final label in [
      'PRIMARY GOAL',
      'EXPERIENCE LEVEL',
      'EQUIPMENT',
      'SCHEDULE',
      'EXERCISE TYPES',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'Missing $label');
    }

    for (final goal in [
      'Fat loss',
      'Weight gain',
      'Muscle building',
      'Raw strength',
      'General endurance',
    ]) {
      expect(find.text(goal), findsOneWidget, reason: 'Missing goal $goal');
    }

    for (final type in [
      'Full Body',
      'Push',
      'Pull',
      'Legs',
      'Upper',
      'Lower',
      'Rest/Light Cardio',
    ]) {
      expect(find.text(type), findsOneWidget, reason: 'Missing type $type');
    }

    expect(find.text('Generate Plan for a week'), findsOneWidget);

    // Exercise Combinations is below the fold of the lazy form ListView.
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('EXERCISE COMBINATIONS'), findsOneWidget);
    for (final combo in [
      'Chest+Tricep',
      'Back+Bicep',
      'Legs+Shoulder',
      'Custom',
    ]) {
      expect(find.text(combo), findsOneWidget, reason: 'Missing combo $combo');
    }
  });

  testWidgets('custom combination accepts an A+B+Nth string', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: PlanScreen(onBack: () {})));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Chest + Triceps + Core + Calves',
    );
    await tester.pumpAndSettle();

    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Triceps'), findsOneWidget);
    expect(find.text('Core'), findsOneWidget);
    expect(find.text('Calves'), findsOneWidget);
  });

  testWidgets('all exercise types and combinations can be deselected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: PlanScreen(onBack: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Full Body'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chest+Tricep'));
    await tester.pumpAndSettle();

    // Neither field blocks generation once cleared.
    await tester.tap(find.text('Generate Plan for a week'));
    await tester.pumpAndSettle();

    expect(find.text('Add Gemini API key'), findsOneWidget);
    expect(
      find.textContaining('Enter a custom exercise combination'),
      findsNothing,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('bottom CTA follows the selected tab', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: PlanScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Generate Plan for a week'), findsOneWidget);

    await tester.tap(find.text('Single day'));
    await tester.pumpAndSettle();

    expect(find.text('Generate Plan for a single day'), findsOneWidget);
    expect(find.text('Generate Plan for a week'), findsNothing);

    // Single-day Schedule defaults to Day 1.
    expect(find.text('Day 1'), findsOneWidget);
  });

  testWidgets('generate without an API key opens the key dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: PlanScreen(onBack: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate Plan for a week'));
    await tester.pumpAndSettle();

    expect(find.text('Add Gemini API key'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Create another plan'), findsNothing);
  });

  for (final scope in PlanScope.values) {
    testWidgets('${scope.name} result saves to History', (tester) async {
      _setTestSize(tester);
      final plan = _samplePlan(scope);
      await LocalStore.instance.write(
        'workout_app.plan_result.v1',
        plan.toJson(),
      );

      await tester.pumpWidget(MaterialApp(home: PlanScreen(onBack: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Save to History'), findsOneWidget);
      await tester.tap(find.text('Save to History'));
      await tester.pumpAndSettle();

      expect(find.text('Saved to History'), findsOneWidget);
      final history = PlanHistoryStore.read();
      expect(history, hasLength(1));
      expect(history.single.plan.id, plan.id);
      expect(history.single.plan.scope, scope);

      await tester.tap(find.text('View History'));
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      expect(find.text(plan.title), findsOneWidget);
      expect(
        find.text(scope == PlanScope.week ? 'Weekly plan' : 'Single-day plan'),
        findsOneWidget,
      );
      expect(find.text('Open saved plan'), findsOneWidget);
    });
  }

  for (final scope in PlanScope.values) {
    testWidgets('${scope.name} result returns to its edit form', (
      tester,
    ) async {
      _setTestSize(tester);
      final plan = _samplePlan(scope);
      await LocalStore.instance.write(
        'workout_app.plan_result.v1',
        plan.toJson(),
      );

      await tester.pumpWidget(MaterialApp(home: PlanScreen(onBack: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Go to previous screen'), findsOneWidget);
      await tester.tap(find.text('Go to previous screen'));
      await tester.pumpAndSettle();

      expect(find.text(plan.title), findsNothing);
      expect(find.text('Create another plan'), findsNothing);
      expect(
        find.text(
          scope == PlanScope.week
              ? 'Generate Plan for a week'
              : 'Generate Plan for a single day',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('saved plan can be reopened from History', (tester) async {
    _setTestSize(tester);
    final plan = _samplePlan(PlanScope.day);
    await PlanHistoryStore.save(plan);

    await tester.pumpWidget(MaterialApp(home: PlanScreen(onBack: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open saved plan'));
    await tester.pumpAndSettle();

    expect(find.text(plan.title), findsOneWidget);
    expect(find.text('SINGLE-DAY PLAN'), findsOneWidget);
    expect(find.text('Saved to History'), findsOneWidget);
    expect(find.text('Create another plan'), findsOneWidget);
  });
}

void _setTestSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

GeneratedPlan _samplePlan(PlanScope scope) => GeneratedPlan(
  id: 'plan-${scope.name}',
  scope: scope,
  title: scope == PlanScope.week ? 'Weekly Test Plan' : 'Single-Day Test Plan',
  overview: 'A saved plan used by the History tests.',
  details: const PlanDetails(
    goal: 'Fat loss',
    experienceLevel: 'Beginner',
    equipment: 'Full commercial gym',
    daysPerWeek: 3,
    exerciseTypes: ['Full Body'],
    exerciseCombination: 'Chest+Tricep',
  ),
  days: const [
    PlanDay(
      label: 'Day 1',
      workoutName: 'Push Day',
      focus: 'Chest',
      exercises: [],
      note: 'Recovery note.',
    ),
  ],
  createdAt: DateTime(2026, 11, 20, 12),
);
