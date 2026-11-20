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
}
