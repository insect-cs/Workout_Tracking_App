enum DietActivityType { food, water }

class FoodNutrient {
  const FoodNutrient({required this.name, required this.amount});

  final String name;
  final String amount;
}

/// Result returned by Gemini for one analysed food portion.
class FoodAnalysis {
  const FoodAnalysis({
    required this.foodItem,
    required this.foodType,
    required this.quantity,
    required this.calories,
    required this.nutrients,
    required this.summary,
    required this.analysedAt,
  });

  final String foodItem;
  final String foodType;
  final String quantity;
  final int calories;
  final List<FoodNutrient> nutrients;
  final String summary;
  final DateTime analysedAt;
}

/// One saved activity inside a one-hour slot.
class DietEntry {
  const DietEntry({
    required this.id,
    required this.slotHour,
    required this.type,
    required this.label,
    required this.detail,
    this.calories = 0,
    this.waterMl = 0,
    this.photoName,
    this.analysis,
    required this.createdAt,
  });

  final String id;
  final int slotHour;
  final DietActivityType type;
  final String label;
  final String detail;
  final int calories;
  final int waterMl;
  final String? photoName;
  final FoodAnalysis? analysis;
  final DateTime createdAt;
}

/// Immutable per-day plan: goals plus every saved activity.
class DietDay {
  const DietDay({
    this.calorieGoal = 2000,
    this.waterGoalMl = 2500,
    this.entries = const [],
  });

  final int calorieGoal;
  final int waterGoalMl;
  final List<DietEntry> entries;

  int get caloriesConsumed =>
      entries.fold(0, (sum, entry) => sum + entry.calories);

  int get waterConsumedMl =>
      entries.fold(0, (sum, entry) => sum + entry.waterMl);

  int get caloriesRemaining => calorieGoal - caloriesConsumed;

  int get waterRemainingMl => waterGoalMl - waterConsumedMl;

  List<DietEntry> entriesForSlot(int hour) =>
      entries.where((entry) => entry.slotHour == hour).toList();
}

/// Formats a one-hour slot as `09:00 - 10:00`.
String slotLabel(int hour) {
  final start = hour.toString().padLeft(2, '0');
  final end = ((hour + 1) % 24).toString().padLeft(2, '0');
  return '$start:00 - $end:00';
}
