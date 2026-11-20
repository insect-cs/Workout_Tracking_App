enum DietActivityType { food, water }

class FoodNutrient {
  const FoodNutrient({required this.name, required this.amount});

  final String name;
  final String amount;

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};

  factory FoodNutrient.fromJson(Map<String, dynamic> json) => FoodNutrient(
    name: (json['name'] as String?) ?? '',
    amount: (json['amount'] as String?) ?? '',
  );
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

  Map<String, dynamic> toJson() => {
    'foodItem': foodItem,
    'foodType': foodType,
    'quantity': quantity,
    'calories': calories,
    'nutrients': nutrients.map((nutrient) => nutrient.toJson()).toList(),
    'summary': summary,
    'analysedAt': analysedAt.toIso8601String(),
  };

  factory FoodAnalysis.fromJson(Map<String, dynamic> json) => FoodAnalysis(
    foodItem: (json['foodItem'] as String?) ?? '',
    foodType: (json['foodType'] as String?) ?? '',
    quantity: (json['quantity'] as String?) ?? '',
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    nutrients:
        (json['nutrients'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(FoodNutrient.fromJson)
            .toList() ??
        const <FoodNutrient>[],
    summary: (json['summary'] as String?) ?? '',
    analysedAt:
        DateTime.tryParse((json['analysedAt'] as String?) ?? '') ??
        DateTime.now(),
  );
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'slotHour': slotHour,
    'type': type.name,
    'label': label,
    'detail': detail,
    'calories': calories,
    'waterMl': waterMl,
    if (photoName != null) 'photoName': photoName,
    if (analysis != null) 'analysis': analysis!.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory DietEntry.fromJson(Map<String, dynamic> json) => DietEntry(
    id: (json['id'] as String?) ?? '',
    slotHour: (json['slotHour'] as num?)?.toInt() ?? 0,
    type: DietActivityType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => DietActivityType.food,
    ),
    label: (json['label'] as String?) ?? '',
    detail: (json['detail'] as String?) ?? '',
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    waterMl: (json['waterMl'] as num?)?.toInt() ?? 0,
    photoName: json['photoName'] as String?,
    analysis: (json['analysis'] as Map<String, dynamic>?) == null
        ? null
        : FoodAnalysis.fromJson(json['analysis'] as Map<String, dynamic>),
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now(),
  );
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

  Map<String, dynamic> toJson() => {
    'calorieGoal': calorieGoal,
    'waterGoalMl': waterGoalMl,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory DietDay.fromJson(Map<String, dynamic> json) => DietDay(
    calorieGoal: (json['calorieGoal'] as num?)?.toInt() ?? 2000,
    waterGoalMl: (json['waterGoalMl'] as num?)?.toInt() ?? 2500,
    entries:
        (json['entries'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(DietEntry.fromJson)
            .toList() ??
        const <DietEntry>[],
  );
}

/// Formats a one-hour slot as `09:00 - 10:00`.
String slotLabel(int hour) {
  final start = hour.toString().padLeft(2, '0');
  final end = ((hour + 1) % 24).toString().padLeft(2, '0');
  return '$start:00 - $end:00';
}
