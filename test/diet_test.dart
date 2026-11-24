import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/diet_models.dart';
import 'package:workout_app/screens/diet_screen.dart';
import 'package:workout_app/services/api_key_service.dart';
import 'package:workout_app/services/diet_export_service.dart';
import 'package:workout_app/services/local_store.dart';
import 'package:workout_app/state/diet_state.dart';

void main() {
  setUp(() async {
    await LocalStore.instance.resetForTesting();
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
    tester.view.physicalSize = const Size(1200, 4200);
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

  test('rest activities track sleep and survive JSON round trips', () {
    final entry = DietEntry(
      id: 'r1',
      slotHour: 22,
      type: DietActivityType.rest,
      label: 'Rest',
      detail: '7h 30m',
      sleepMinutes: 450,
      createdAt: DateTime(2026, 1, 5, 22),
    );
    final day = DietDay(entries: [entry]);

    expect(day.sleepMinutes, 450);
    final restoredEntry = DietEntry.fromJson(entry.toJson());
    expect(restoredEntry.type, DietActivityType.rest);
    expect(restoredEntry.sleepMinutes, 450);
    expect(DietDay.fromJson(day.toJson()).sleepMinutes, 450);
  });

  test('weekly goals deduct each day and highlight days at 50 percent', () {
    final store = DietState.instance;
    final monday = DateTime(2026, 1, 5);
    final tuesday = DateTime(2026, 1, 6);

    expect(store.weekGoals(monday).calorieGoal, kDefaultWeeklyCalorieGoal);
    expect(store.weekGoals(monday).waterGoalMl, kDefaultWeeklyWaterGoalMl);

    store.setWeekGoals(monday, calorieGoal: 12000, waterGoalMl: 14000);
    store.addEntry(
      monday,
      DietEntry(
        id: 'f1',
        slotHour: 9,
        type: DietActivityType.food,
        label: 'Oats',
        detail: 'Veg • 1 bowl',
        calories: 600,
        createdAt: monday,
      ),
    );
    store.addEntry(
      tuesday,
      DietEntry(
        id: 'w1',
        slotHour: 10,
        type: DietActivityType.water,
        label: 'Water',
        detail: '1250 ml',
        waterMl: 1250,
        createdAt: tuesday,
      ),
    );

    final consumed = store.weekConsumed(tuesday);
    expect(consumed.calories, 600);
    expect(consumed.waterMl, 1250);
    expect(store.weekGoals(tuesday).calorieGoal, 12000);
    expect(store.day(monday).isGoalHalfMet, isFalse);
    expect(store.day(tuesday).isGoalHalfMet, isTrue);

    final summary = store.buildSummary(tuesday);
    expect(summary.scope, 'All activities up to now');
    expect(summary.totalCalories, 600);
    expect(summary.totalWaterMl, 1250);
    expect(summary.daysGoalMet, 1);
    expect(summary.entries.length, 2);
  });

  test('diet summary CSV contains daily breakdown and activity log', () {
    final store = DietState.instance;
    final today = DateTime(2026, 1, 5);
    store.addEntry(
      today,
      DietEntry(
        id: 'r1',
        slotHour: 22,
        type: DietActivityType.rest,
        label: 'Rest',
        detail: '7h 30m',
        sleepMinutes: 450,
        createdAt: today,
      ),
    );

    final csv = DietExportService.buildCsv(store.buildSummary(today));
    expect(csv, contains('Diet Summary Export'));
    expect(csv, contains('DAILY BREAKDOWN'));
    expect(csv, contains('ACTIVITY LOG'));
    expect(csv, contains('Rest'));
    expect(csv, contains('450'));
  });

  test('rest goals are editable and persist in daily and weekly state', () {
    final day = DietDay(restGoalMinutes: 420);
    expect(DietDay.fromJson(day.toJson()).restGoalMinutes, 420);
    expect(
      DietWeekGoals.fromJson(DietWeekGoals(restGoalMinutes: 2940).toJson())
          .restGoalMinutes,
      2940,
    );

    final store = DietState.instance;
    final monday = DateTime(2026, 1, 5);
    store.setGoals(monday, restGoalMinutes: 420);
    store.addEntry(
      monday,
      DietEntry(
        id: 'r1',
        slotHour: 22,
        type: DietActivityType.rest,
        label: 'Rest',
        detail: '7h',
        sleepMinutes: 420,
        createdAt: monday,
      ),
    );
    expect(store.day(monday).restGoalMinutes, 420);
    expect(store.day(monday).sleepRemainingMinutes, 0);
    expect(store.day(monday).restProgress, 1);

    store.setWeekGoals(monday, restGoalMinutes: 2940);
    expect(store.weekGoals(monday).restGoalMinutes, 2940);
    expect(store.buildSummary(monday).weekRestGoalMinutes, 2940);
  });

  test('food quantity units are stored and offered in the slot editor', () {
    expect(kFoodQuantityUnits, ['g', 'mg', 'ml', 'pcs']);
    final entry = DietEntry(
      id: 'f1',
      slotHour: 9,
      type: DietActivityType.food,
      label: 'Oats',
      detail: 'Veg • 50 g',
      quantityUnit: 'mg',
      createdAt: DateTime(2026, 1, 5),
    );
    expect(DietEntry.fromJson(entry.toJson()).quantityUnit, 'mg');
  });

  testWidgets('diet screen exposes weekly goals, summary and rest activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: DietScreen(onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('WEEKLY GOALS'), findsOneWidget);
    expect(find.text('Save week goals'), findsOneWidget);
    expect(find.text('DIET SUMMARY'), findsOneWidget);

    await tester.tap(find.text('DIET SUMMARY'));
    await tester.pumpAndSettle();
    expect(find.text('Export as CSV'), findsOneWidget);
    expect(find.text('Export as PDF'), findsOneWidget);
    final sheetContext = tester.element(find.text('Export as CSV'));
    Navigator.of(sheetContext).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('23:00'));
    await tester.pumpAndSettle();

    // Idle slots are marked red via semantics; the food editor offers all
    // four quantity units.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Empty slot 23:00',
      ),
      findsOneWidget,
    );
    final unitDropdown = find
        .byType(DropdownButton<String>)
        .evaluate()
        .map((element) => element.widget as DropdownButton<String>)
        .firstWhere(
          (widget) => widget.items?.any((item) => item.value == 'pcs') ?? false,
        );
    expect(
      unitDropdown.items!.map((item) => item.value).toList(),
      kFoodQuantityUnits,
    );

    await tester.tap(find.text('Rest'));
    await tester.pumpAndSettle();

    final hoursField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'e.g., 7',
    );
    final minutesField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'e.g., 30',
    );
    await tester.enterText(hoursField, '7');
    await tester.enterText(minutesField, '30');
    await tester.pump();
    await tester.tap(find.text('Save to this slot'));
    await tester.pumpAndSettle();

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final day = DietState.instance.day(today);
    expect(day.sleepMinutes, 450);
    expect(day.entriesForSlot(23).single.type, DietActivityType.rest);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Filled slot 23:00',
      ),
      findsOneWidget,
    );
  });
}
