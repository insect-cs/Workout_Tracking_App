import '../models/diet_models.dart';

/// One nutrient aggregated for the charts.
///
/// [value] is always in a single display unit per [family] so bars from
/// different foods can be compared. Mass nutrients are normalised to grams.
class NutrientTotal {
  const NutrientTotal({
    required this.name,
    required this.value,
    required this.unit,
    required this.family,
  });

  final String name;
  final double value;
  final String unit;

  /// `mass`, `energy`, `volume` or `other:<unit>`.
  final String family;

  /// Human readable amount, e.g. `12 g`, `450 mg`, `310 kcal`.
  String get display {
    if (family == 'mass') {
      if (value >= 1) {
        return '${_trim(value)} g';
      }
      return '${_trim(value * 1000)} mg';
    }
    return '${_trim(value)} $unit';
  }

  static String _trim(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

/// A food source ranked by the nutrients it contributed.
class FoodContribution {
  const FoodContribution({
    required this.label,
    required this.calories,
    required this.nutrientMass,
    required this.topNutrient,
  });

  final String label;
  final int calories;

  /// Sum of parsed protein/carb/fat/fibre mass in grams. Used only for
  /// ranking; it is not a calorie replacement.
  final double nutrientMass;
  final NutrientTotal? topNutrient;
}

/// Aggregated nutrient picture for a list of food entries.
class NutrientBreakdown {
  const NutrientBreakdown({
    this.totals = const <NutrientTotal>[],
    this.contributors = const <FoodContribution>[],
    this.foodCount = 0,
  });

  final List<NutrientTotal> totals;
  final List<FoodContribution> contributors;
  final int foodCount;

  bool get isEmpty => totals.isEmpty;

  /// Biggest nutrient bars, in the order most useful for a chart.
  List<NutrientTotal> get chartTotals {
    final sorted = [...totals]
      ..sort((a, b) => _sortValue(b).compareTo(_sortValue(a)));
    return sorted.take(6).toList();
  }

  static double _sortValue(NutrientTotal total) {
    // Mass nutrients are already in grams. Energy/volume are only ranked
    // against their own family, and they are appended after macros.
    if (total.family == 'mass') return total.value;
    if (total.family == 'energy') return total.value / 1000;
    return total.value / 1000;
  }

  /// The largest bar, used to scale the chart.
  double get maxChartValue {
    var max = 0.0;
    for (final total in chartTotals) {
      if (total.value > max) max = total.value;
    }
    return max <= 0 ? 1 : max;
  }
}

const Map<String, String> _canonicalNames = {
  'protein': 'Protein',
  'proteins': 'Protein',
  'carbohydrate': 'Carbohydrates',
  'carbohydrates': 'Carbohydrates',
  'carbs': 'Carbohydrates',
  'fat': 'Fat',
  'fats': 'Fat',
  'fibre': 'Fibre',
  'fiber': 'Fibre',
  'sugar': 'Sugar',
  'sugars': 'Sugar',
  'sodium': 'Sodium',
  'potassium': 'Potassium',
  'calcium': 'Calcium',
  'iron': 'Iron',
  'vitamin c': 'Vitamin C',
  'vitamin a': 'Vitamin A',
  'cholesterol': 'Cholesterol',
  'saturated fat': 'Saturated fat',
};

String _canonicalName(String raw) {
  final key = raw.trim().toLowerCase();
  return _canonicalNames[key] ?? _titleCase(raw.trim());
}

String _titleCase(String value) {
  if (value.isEmpty) return 'Nutrient';
  return value
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _ParsedAmount {
  const _ParsedAmount(this.value, this.unit, this.family);

  final double value;
  final String unit;
  final String family;
}

_ParsedAmount? _parseAmount(String raw) {
  final match = RegExp(r'([-+]?\d+(?:\.\d+)?)\s*([a-zA-Zµμ%]+)?')
      .firstMatch(raw.trim());
  if (match == null) return null;
  final value = double.tryParse(match.group(1) ?? '');
  if (value == null) return null;
  final unitRaw = (match.group(2) ?? '').toLowerCase();
  final unit = unitRaw.replaceAll('μ', 'µ');

  switch (unit) {
    case 'g':
    case 'gram':
    case 'grams':
      return _ParsedAmount(value, 'g', 'mass');
    case 'mg':
      return _ParsedAmount(value / 1000, 'g', 'mass');
    case 'ug':
    case 'µg':
    case 'mcg':
      return _ParsedAmount(value / 1000000, 'g', 'mass');
    case 'kg':
      return _ParsedAmount(value * 1000, 'g', 'mass');
    case 'kcal':
    case 'cal':
    case 'calorie':
    case 'calories':
      return _ParsedAmount(value, 'kcal', 'energy');
    case 'ml':
    case 'millilitre':
    case 'milliliter':
      return _ParsedAmount(value, 'ml', 'volume');
    case '':
      return null;
    default:
      return _ParsedAmount(value, unit, 'other:$unit');
  }
}

/// Builds the nutrient chart for a single analysed food.
NutrientBreakdown breakdownForAnalysis(FoodAnalysis analysis) {
  final totals = <String, NutrientTotal>{};
  for (final nutrient in analysis.nutrients) {
    final parsed = _parseAmount(nutrient.amount);
    if (parsed == null) continue;
    final name = _canonicalName(nutrient.name);
    final key = '${name.toLowerCase()}|${parsed.family}';
    final existing = totals[key];
    totals[key] = NutrientTotal(
      name: name,
      value: (existing?.value ?? 0) + parsed.value,
      unit: parsed.unit,
      family: parsed.family,
    );
  }
  final list = totals.values.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return NutrientBreakdown(totals: list, foodCount: 1);
}

/// Builds nutrient totals and ranked food sources from saved diet entries.
NutrientBreakdown breakdownForEntries(Iterable<DietEntry> entries) {
  final totals = <String, NutrientTotal>{};
  final contributors = <FoodContribution>[];
  var foodCount = 0;

  for (final entry in entries) {
    if (entry.type != DietActivityType.food) continue;
    final analysis = entry.analysis;
    if (analysis == null) continue;
    foodCount++;

    final perFood = <String, NutrientTotal>{};
    var mass = 0.0;
    for (final nutrient in analysis.nutrients) {
      final parsed = _parseAmount(nutrient.amount);
      if (parsed == null) continue;
      final name = _canonicalName(nutrient.name);
      final key = '${name.toLowerCase()}|${parsed.family}';
      final existing = totals[key];
      totals[key] = NutrientTotal(
        name: name,
        value: (existing?.value ?? 0) + parsed.value,
        unit: parsed.unit,
        family: parsed.family,
      );
      final foodExisting = perFood[key];
      perFood[key] = NutrientTotal(
        name: name,
        value: (foodExisting?.value ?? 0) + parsed.value,
        unit: parsed.unit,
        family: parsed.family,
      );
      if (parsed.family == 'mass') mass += parsed.value;
    }

    final top = perFood.values.isEmpty
        ? null
        : (perFood.values.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .first;
    contributors.add(
      FoodContribution(
        label: entry.label.trim().isEmpty ? analysis.foodItem : entry.label,
        calories: entry.calories,
        nutrientMass: mass,
        topNutrient: top,
      ),
    );
  }

  final list = totals.values.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  contributors.sort((a, b) {
    final byMass = b.nutrientMass.compareTo(a.nutrientMass);
    if (byMass != 0) return byMass;
    return b.calories.compareTo(a.calories);
  });
  return NutrientBreakdown(
    totals: list,
    contributors: contributors,
    foodCount: foodCount,
  );
}
