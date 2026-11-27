import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/diet_models.dart';
import 'package:workout_app/services/nutrient_analysis.dart';
import 'package:workout_app/state/diet_state.dart';
import 'package:workout_app/widgets/nutrient_chart.dart';

FoodAnalysis _analysis({
  required String food,
  required int calories,
  required List<FoodNutrient> nutrients,
}) {
  return FoodAnalysis(
    foodItem: food,
    foodType: 'Veg',
    quantity: '1 bowl',
    calories: calories,
    nutrients: nutrients,
    summary: '',
    analysedAt: DateTime(2026, 1, 5),
  );
}

DietEntry _foodEntry(DateTime date, String id, FoodAnalysis analysis) {
  return DietEntry(
    id: id,
    slotHour: 9,
    type: DietActivityType.food,
    label: analysis.foodItem,
    detail: analysis.quantity,
    calories: analysis.calories,
    analysis: analysis,
    createdAt: date,
  );
}

void main() {
  test('single food nutrients are parsed and normalised for the graph', () {
    final breakdown = breakdownForAnalysis(
      _analysis(
        food: 'Oats',
        calories: 350,
        nutrients: const [
          FoodNutrient(name: 'Protein', amount: '12 g'),
          FoodNutrient(name: 'Carbohydrates', amount: '45 g'),
          FoodNutrient(name: 'Fat', amount: '10 g'),
          FoodNutrient(name: 'Fibre', amount: '4 g'),
          FoodNutrient(name: 'Sodium', amount: '300 mg'),
        ],
      ),
    );

    expect(breakdown.foodCount, 1);
    expect(breakdown.totals.length, 5);
    final protein = breakdown.totals.firstWhere((n) => n.name == 'Protein');
    expect(protein.value, 12);
    expect(protein.display, '12 g');

    final sodium = breakdown.totals.firstWhere((n) => n.name == 'Sodium');
    expect(sodium.value, closeTo(0.3, 0.0001));
    expect(sodium.display, '300 mg');

    // The chart shows the largest nutrients first.
    expect(breakdown.chartTotals.first.name, 'Carbohydrates');
    expect(breakdown.chartTotals.length, 5);
  });

  test('weekly breakdown adds foods and ranks the biggest contributors', () {
    final monday = DateTime(2026, 1, 5);
    final tuesday = DateTime(2026, 1, 6);
    final oats = _foodEntry(
      monday,
      'f1',
      _analysis(
        food: 'Oats',
        calories: 350,
        nutrients: const [
          FoodNutrient(name: 'Protein', amount: '12 g'),
          FoodNutrient(name: 'Carbohydrates', amount: '45 g'),
        ],
      ),
    );
    final dal = _foodEntry(
      tuesday,
      'f2',
      _analysis(
        food: 'Dal',
        calories: 220,
        nutrients: const [
          FoodNutrient(name: 'Protein', amount: '18 g'),
          FoodNutrient(name: 'Carbohydrates', amount: '60 g'),
        ],
      ),
    );

    final breakdown = breakdownForEntries([oats, dal]);
    final protein = breakdown.totals.firstWhere((n) => n.name == 'Protein');
    final carbs = breakdown.totals.firstWhere((n) => n.name == 'Carbohydrates');
    expect(protein.value, 30);
    expect(carbs.value, 105);
    expect(breakdown.foodCount, 2);
    expect(breakdown.contributors.first.label, 'Dal');
    expect(breakdown.contributors.first.topNutrient?.name, 'Carbohydrates');
  });

  test('summary date range only includes the selected days', () {
    final store = DietState.instance;
    store.reset();
    final analysis = _analysis(
      food: 'Oats',
      calories: 300,
      nutrients: const [FoodNutrient(name: 'Protein', amount: '10 g')],
    );
    store.addEntry(
      DateTime(2026, 1, 5),
      _foodEntry(DateTime(2026, 1, 5), 'a', analysis),
    );
    store.addEntry(
      DateTime(2026, 1, 7),
      _foodEntry(DateTime(2026, 1, 7), 'b', analysis),
    );
    store.addEntry(
      DateTime(2026, 1, 9),
      _foodEntry(DateTime(2026, 1, 9), 'c', analysis),
    );

    final all = store.buildSummary(DateTime(2026, 1, 9));
    expect(all.days.length, 3);
    expect(all.scope, 'All activities up to now');

    final ranged = store.buildSummary(
      DateTime(2026, 1, 9),
      from: DateTime(2026, 1, 6),
      to: DateTime(2026, 1, 8),
    );
    expect(ranged.days.length, 1);
    expect(ranged.totalCalories, 300);
    expect(ranged.scope, contains('Activities 06/01/2026 - 08/01/2026'));
  });

  testWidgets('nutrient chart renders bars and contributor foods', (
    tester,
  ) async {
    final breakdown = breakdownForEntries([
      _foodEntry(
        DateTime(2026, 1, 5),
        'f1',
        _analysis(
          food: 'Oats',
          calories: 350,
          nutrients: const [
            FoodNutrient(name: 'Protein', amount: '12 g'),
            FoodNutrient(name: 'Carbohydrates', amount: '45 g'),
          ],
        ),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              NutrientBarChart(breakdown: breakdown),
              NutrientContributorList(breakdown: breakdown),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carbohydrates'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('45 g'), findsOneWidget);
    expect(find.text('12 g'), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);
  });
}
