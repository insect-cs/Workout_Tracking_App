/// Local reference math used both to seed the Gemini prompt and to sanity
/// check the values shown in the UI. Kept separate from parsing so it is
/// independently testable.
class CalorieMath {
  static const List<String> activityLevels = [
    'Little or no exercise',
    '1-3 days/week (Light)',
    '4-5 days/week (moderate)',
    'intense exercise 3-4 days/week (active)',
    'intense exercise 6-7 days/week (very active)',
    'very intense exercise daily (Extra active)',
  ];

  static const List<double> activityMultipliers = [
    1.2,
    1.375,
    1.55,
    1.725,
    1.9,
    2.0,
  ];

  /// Mifflin-St Jeor basal metabolic rate (kcal/day).
  static double bmr({
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
  }) {
    const genderOffset = {'male': 5.0, 'female': -161.0, 'other': -78.0};
    return 10 * weightKg +
        6.25 * heightCm -
        5 * age +
        (genderOffset[gender.toLowerCase()] ?? -78.0);
  }

  static double activityMultiplier(String activity) {
    final index = activityLevels.indexOf(activity);
    return index < 0 ? 1.2 : activityMultipliers[index];
  }

  static double tdee({
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String activity,
  }) {
    return bmr(
          age: age,
          gender: gender,
          heightCm: heightCm,
          weightKg: weightKg,
        ) *
        activityMultiplier(activity);
  }

  static double bmi({required double heightCm, required double weightKg}) {
    if (heightCm <= 0) return 0;
    final meters = heightCm / 100;
    return weightKg / (meters * meters);
  }

  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  /// WHO healthy weight range (BMI 18.5 - 24.9) for a given height.
  static String healthyWeightRange(double heightCm) {
    if (heightCm <= 0) return '-';
    final meters = heightCm / 100;
    final low = 18.5 * meters * meters;
    final high = 24.9 * meters * meters;
    return '${low.round()} - ${high.round()} kg';
  }
}

class CalorieProfile {
  final int age;
  final String gender;
  final double heightCm;
  final double weightKg;
  final String activity;

  const CalorieProfile({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
  });

  Map<String, dynamic> toJson() => {
    'age': age,
    'gender': gender,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'activity': activity,
  };

  factory CalorieProfile.fromJson(Map<String, dynamic> json) => CalorieProfile(
    age: (json['age'] as num?)?.toInt() ?? 30,
    gender: (json['gender'] as String?) ?? 'Male',
    heightCm: (json['heightCm'] as num?)?.toDouble() ?? 175,
    weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70,
    activity: (json['activity'] as String?) ?? CalorieMath.activityLevels.first,
  );
}

class DayCalorieEstimate {
  final String day;
  final int calories;
  final String note;

  const DayCalorieEstimate({
    required this.day,
    required this.calories,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'day': day,
    'calories': calories,
    'note': note,
  };

  factory DayCalorieEstimate.fromJson(Map<String, dynamic> json) =>
      DayCalorieEstimate(
        day: (json['day'] as String?) ?? '',
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        note: (json['note'] as String?) ?? '',
      );
}

class WeeklyCalorieEstimate {
  final String id;
  final CalorieProfile profile;
  final int bmr;
  final int tdee;
  final int dailyTarget;
  final int weeklyTarget;
  final String summary;
  final List<DayCalorieEstimate> days;
  final List<String> tips;
  final DateTime createdAt;

  const WeeklyCalorieEstimate({
    required this.id,
    required this.profile,
    required this.bmr,
    required this.tdee,
    required this.dailyTarget,
    required this.weeklyTarget,
    required this.summary,
    required this.days,
    required this.tips,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile': profile.toJson(),
    'bmr': bmr,
    'tdee': tdee,
    'dailyTarget': dailyTarget,
    'weeklyTarget': weeklyTarget,
    'summary': summary,
    'days': days.map((day) => day.toJson()).toList(),
    'tips': tips,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WeeklyCalorieEstimate.fromJson(Map<String, dynamic> json) =>
      WeeklyCalorieEstimate(
        id: (json['id'] as String?) ?? '',
        profile: CalorieProfile.fromJson(
          (json['profile'] as Map<String, dynamic>?) ?? const {},
        ),
        bmr: (json['bmr'] as num?)?.toInt() ?? 0,
        tdee: (json['tdee'] as num?)?.toInt() ?? 0,
        dailyTarget: (json['dailyTarget'] as num?)?.toInt() ?? 0,
        weeklyTarget: (json['weeklyTarget'] as num?)?.toInt() ?? 0,
        summary: (json['summary'] as String?) ?? '',
        days:
            (json['days'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(DayCalorieEstimate.fromJson)
                .toList() ??
            const <DayCalorieEstimate>[],
        tips:
            (json['tips'] as List<dynamic>?)
                ?.map((value) => value.toString())
                .toList() ??
            const <String>[],
        createdAt:
            DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}

class BmiEstimate {
  final String id;
  final CalorieProfile profile;
  final double bmi;
  final String category;
  final String healthyWeightRange;
  final String interpretation;
  final List<String> recommendations;
  final DateTime createdAt;

  const BmiEstimate({
    required this.id,
    required this.profile,
    required this.bmi,
    required this.category,
    required this.healthyWeightRange,
    required this.interpretation,
    required this.recommendations,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile': profile.toJson(),
    'bmi': bmi,
    'category': category,
    'healthyWeightRange': healthyWeightRange,
    'interpretation': interpretation,
    'recommendations': recommendations,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BmiEstimate.fromJson(Map<String, dynamic> json) => BmiEstimate(
    id: (json['id'] as String?) ?? '',
    profile: CalorieProfile.fromJson(
      (json['profile'] as Map<String, dynamic>?) ?? const {},
    ),
    bmi: (json['bmi'] as num?)?.toDouble() ?? 0,
    category: (json['category'] as String?) ?? '',
    healthyWeightRange: (json['healthyWeightRange'] as String?) ?? '',
    interpretation: (json['interpretation'] as String?) ?? '',
    recommendations:
        (json['recommendations'] as List<dynamic>?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[],
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now(),
  );
}
