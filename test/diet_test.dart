import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/diet_models.dart';
import 'package:workout_app/screens/diet_screen.dart';
import 'package:workout_app/services/api_key_service.dart';
import 'package:workout_app/state/diet_state.dart';

void main() {
  setUp(() async {
    DietState.instance.reset();
    await ApiKeyStore.instance.resetForTesting();
  });

  test('slot labels cover every hour of the day', () {
    expect(slotLabel(0), '00:00 - 01:00');
    expect(slotLabel(9), '09:00 - 10:00');
    expect(slotLabel(23), '23:00 - 00:00');
  });

  test('food calories and water are deducted from their own goals', () {
    final now = DateTime(2026, 1, 1, 9);
    final food = DietEntry(
      id: 'f1',
      slotHour: 9,
      type: DietActivityType.food,
      label: 'Rice bowl',
      detail: 'Veg • 1 bowl',
      calories: 420,
      createdAt: now,
    );
    final water = DietEntry(
      id: 'w1',
      slotHour: 10,
      type: DietActivityType.water,
      label: 'Water',
      detail: '500 ml',
      waterMl: 500,
      createdAt: now,
    );
    final day = DietDay(
      calorieGoal: 2000,
      waterGoalMl: 2500,
      entries: [food, water],
    );

    expect(day.caloriesConsumed, 420);
    expect(day.caloriesRemaining, 1580);
    expect(day.waterConsumedMl, 500);
    expect(day.waterRemainingMl, 2000);
    expect(day.entriesForSlot(9), [food]);
    expect(day.entriesForSlot(10), [water]);
    expect(day.entriesForSlot(11), isEmpty);
  });

  test(
    'state keeps separate days and updates goals without losing entries',
    () {
      final store = DietState.instance;
      final today = DateTime(2026, 1, 1);
      final tomorrow = DateTime(2026, 1, 2);
      final entry = DietEntry(
        id: 'f1',
        slotHour: 12,
        type: DietActivityType.food,
        label: 'Salad',
        detail: 'Veg • 1 plate',
        calories: 180,
        createdAt: today,
      );

      store.addEntry(today, entry);
      store.setGoals(today, calorieGoal: 1800, waterGoalMl: 3000);

      expect(store.day(today).entries, [entry]);
      expect(store.day(today).calorieGoal, 1800);
      expect(store.day(today).waterGoalMl, 3000);
      expect(store.day(today).caloriesRemaining, 1620);
      expect(store.day(today).waterRemainingMl, 3000);
      expect(store.day(tomorrow).entries, isEmpty);

      store.removeEntry(today, 'f1');
      expect(store.day(today).entries, isEmpty);
      expect(store.day(today).calorieGoal, 1800);
    },
  );

  testWidgets('Diet screen shows today, 24 hourly slots and both goals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: DietScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('DIET'), findsOneWidget);
    expect(find.textContaining(DateTime.now().year.toString()), findsOneWidget);

    final slots = find.byWidgetPredicate(
      (widget) =>
          widget is Text && RegExp(r'^\d{2}:00$').hasMatch(widget.data ?? ''),
    );
    expect(slots, findsNWidgets(24));

    expect(find.text('CALORIE GOAL'), findsOneWidget);
    expect(find.text('WATER GOAL'), findsOneWidget);
    expect(find.text('Save goals'), findsOneWidget);
    expect(find.text('TIME SLOTS'), findsOneWidget);
  });

  testWidgets('saving water deducts it from the water intake goal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: DietScreen(onBack: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('13:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();

    final waterField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'e.g., 250',
    );
    await tester.enterText(waterField, '500');
    await tester.pump();
    await tester.tap(find.text('Save to this slot'));
    await tester.pumpAndSettle();

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final day = DietState.instance.day(today);
    expect(day.waterConsumedMl, 500);
    expect(day.waterRemainingMl, 2000);
    expect(day.caloriesConsumed, 0);
    expect(day.entriesForSlot(13).single.label, 'Water');
    expect(find.text('2000 ml'), findsOneWidget);
  });

  testWidgets('food validation asks for an API key before calling Gemini', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: DietScreen(onBack: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();

    final itemField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'e.g., Grilled chicken bowl',
    );
    final quantityField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'e.g., 1 bowl (250 g)',
    );
    await tester.enterText(itemField, 'Grilled chicken');
    await tester.enterText(quantityField, '200 g');
    await tester.pump();

    await tester.tap(find.text('Validate with Gemini'));
    await tester.pumpAndSettle();

    expect(find.text('Add Gemini API key'), findsOneWidget);
    expect(find.text('Validate with Gemini'), findsOneWidget);
  });
}
