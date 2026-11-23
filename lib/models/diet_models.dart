enum DietActivityType { food, water, rest }

/// Default daily targets shown before the user saves their own goals.
const int kDefaultDailyCalorieGoal = 2000;
const int kDefaultDailyWaterGoalMl = 2500;

/// Default weekly targets = 7 days of the default daily targets.
const int kDefaultWeeklyCalorieGoal = kDefaultDailyCalorieGoal * 7;
const int kDefaultWeeklyWaterGoalMl = kDefaultDailyWaterGoalMl * 7;

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
    this.sleepMinutes = 0,
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
  /// Sleep tracked by a `rest` activity, in minutes.
  final int sleepMinutes;
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
    'sleepMinutes': sleepMinutes,
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
    sleepMinutes: (json['sleepMinutes'] as num?)?.toInt() ?? 0,
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
    this.calorieGoal = kDefaultDailyCalorieGoal,
    this.waterGoalMl = kDefaultDailyWaterGoalMl,
    this.entries = const [],
  });

  final int calorieGoal;
  final int waterGoalMl;
  final List<DietEntry> entries;

  int get caloriesConsumed =>
      entries.fold(0, (sum, entry) => sum + entry.calories);

  int get waterConsumedMl =>
      entries.fold(0, (sum, entry) => sum + entry.waterMl);

  int get sleepMinutes =>
      entries.fold(0, (sum, entry) => sum + entry.sleepMinutes);

  int get caloriesRemaining => calorieGoal - caloriesConsumed;

  int get waterRemainingMl => waterGoalMl - waterConsumedMl;

  /// 0-1 fraction of the calorie goal reached today.
  double get calorieProgress => calorieGoal > 0
      ? (caloriesConsumed / calorieGoal).clamp(0.0, 1.0).toDouble()
      : 0;

  /// 0-1 fraction of the water goal reached today.
  double get waterProgress => waterGoalMl > 0
      ? (waterConsumedMl / waterGoalMl).clamp(0.0, 1.0).toDouble()
      : 0;

  /// A day is "on track" (green) once either goal reaches at least 50%.
  bool get isGoalHalfMet =>
      calorieProgress >= 0.5 || waterProgress >= 0.5;

  bool get isUsingDefaultGoals =>
      calorieGoal == kDefaultDailyCalorieGoal &&
      waterGoalMl == kDefaultDailyWaterGoalMl;

  List<DietEntry> entriesForSlot(int hour) =>
      entries.where((entry) => entry.slotHour == hour).toList();

  Map<String, dynamic> toJson() => {
    'calorieGoal': calorieGoal,
    'waterGoalMl': waterGoalMl,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory DietDay.fromJson(Map<String, dynamic> json) => DietDay(
    calorieGoal:
        (json['calorieGoal'] as num?)?.toInt() ?? kDefaultDailyCalorieGoal,
    waterGoalMl:
        (json['waterGoalMl'] as num?)?.toInt() ?? kDefaultDailyWaterGoalMl,
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

/// Editable targets for one calendar week (Monday - Sunday).
class DietWeekGoals {
  const DietWeekGoals({
    this.calorieGoal = kDefaultWeeklyCalorieGoal,
    this.waterGoalMl = kDefaultWeeklyWaterGoalMl,
  });

  final int calorieGoal;
  final int waterGoalMl;

  bool get isUsingDefaultGoals =>
      calorieGoal == kDefaultWeeklyCalorieGoal &&
      waterGoalMl == kDefaultWeeklyWaterGoalMl;

  DietWeekGoals copyWith({int? calorieGoal, int? waterGoalMl}) =>
      DietWeekGoals(
        calorieGoal: calorieGoal ?? this.calorieGoal,
        waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      );

  Map<String, dynamic> toJson() => {
    'calorieGoal': calorieGoal,
    'waterGoalMl': waterGoalMl,
  };

  factory DietWeekGoals.fromJson(Map<String, dynamic> json) => DietWeekGoals(
    calorieGoal:
        (json['calorieGoal'] as num?)?.toInt() ?? kDefaultWeeklyCalorieGoal,
    waterGoalMl:
        (json['waterGoalMl'] as num?)?.toInt() ?? kDefaultWeeklyWaterGoalMl,
  );
}

/// One day as it appears in the diet summary/export.
class DietSummaryDay {
  const DietSummaryDay({
    required this.date,
    required this.calorieGoal,
    required this.waterGoalMl,
    required this.caloriesConsumed,
    required this.waterConsumedMl,
    required this.sleepMinutes,
    required this.activityCount,
  });

  factory DietSummaryDay.fromDietDay(DateTime date, DietDay day) =>
      DietSummaryDay(
        date: date,
        calorieGoal: day.calorieGoal,
        waterGoalMl: day.waterGoalMl,
        caloriesConsumed: day.caloriesConsumed,
        waterConsumedMl: day.waterConsumedMl,
        sleepMinutes: day.sleepMinutes,
        activityCount: day.entries.length,
      );

  final DateTime date;
  final int calorieGoal;
  final int waterGoalMl;
  final int caloriesConsumed;
  final int waterConsumedMl;
  final int sleepMinutes;
  final int activityCount;

  bool get isGoalHalfMet =>
      (calorieGoal > 0 && caloriesConsumed >= calorieGoal / 2) ||
      (waterGoalMl > 0 && waterConsumedMl >= waterGoalMl / 2);
}

/// One saved activity as it appears in the diet summary/export.
class DietSummaryEntry {
  const DietSummaryEntry({required this.date, required this.entry});

  final DateTime date;
  final DietEntry entry;
}

/// Immutable snapshot of every diet activity recorded up to now.
class DietSummary {
  const DietSummary({
    required this.generatedAt,
    required this.scope,
    required this.weekCalorieGoal,
    required this.weekWaterGoalMl,
    required this.days,
    required this.entries,
  });

  final DateTime generatedAt;
  final String scope;
  final int weekCalorieGoal;
  final int weekWaterGoalMl;
  final List<DietSummaryDay> days;
  final List<DietSummaryEntry> entries;

  int get totalCalories =>
      days.fold(0, (sum, day) => sum + day.caloriesConsumed);
  int get totalWaterMl =>
      days.fold(0, (sum, day) => sum + day.waterConsumedMl);
  int get totalSleepMinutes =>
      days.fold(0, (sum, day) => sum + day.sleepMinutes);
  int get totalActivities =>
      days.fold(0, (sum, day) => sum + day.activityCount);
  int get foodCount =>
      entries.where((item) => item.entry.type == DietActivityType.food).length;
  int get waterCount =>
      entries.where((item) => item.entry.type == DietActivityType.water).length;
  int get restCount =>
      entries.where((item) => item.entry.type == DietActivityType.rest).length;
  int get daysGoalMet => days.where((day) => day.isGoalHalfMet).length;
}
