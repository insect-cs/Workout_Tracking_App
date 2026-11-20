import 'workout_models.dart';

/// Which type of plan the user asked for.
enum PlanScope { week, day }

/// All of the inputs collected on the Plan form.
class PlanDetails {
  final String goal;
  final String experienceLevel;
  final String equipment;
  final int daysPerWeek;
  final List<String> exerciseTypes;

  /// Muscle groups to train together, e.g. "Chest+Tricep", "Back+Bicep",
  /// "Legs+Shoulder" or a custom plus-separated string of any length.
  final String exerciseCombination;

  /// For a single-day plan this is the selected day (e.g. "Day 1"), which is
  /// the default. Weekly plans leave it null and use [daysPerWeek] instead.
  final String? dayLabel;

  const PlanDetails({
    required this.goal,
    required this.experienceLevel,
    required this.equipment,
    required this.daysPerWeek,
    required this.exerciseTypes,
    required this.exerciseCombination,
    this.dayLabel,
  });

  /// The individual groups parsed out of [exerciseCombination].
  List<String> get combinationParts => exerciseCombination
      .split('+')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'experienceLevel': experienceLevel,
    'equipment': equipment,
    'daysPerWeek': daysPerWeek,
    'exerciseTypes': exerciseTypes,
    'exerciseCombination': exerciseCombination,
    if (dayLabel != null) 'dayLabel': dayLabel,
  };
}

/// A single day (or the only day) of a generated plan.
class PlanDay {
  final String label;
  final String workoutName;
  final String focus;
  final List<ExerciseModel> exercises;
  final String note;

  const PlanDay({
    required this.label,
    required this.workoutName,
    required this.focus,
    required this.exercises,
    this.note = '',
  });
}

/// The complete AI-generated plan returned by Gemini.
class GeneratedPlan {
  final String id;
  final PlanScope scope;
  final String title;
  final String overview;
  final PlanDetails details;
  final List<PlanDay> days;
  final DateTime createdAt;

  const GeneratedPlan({
    required this.id,
    required this.scope,
    required this.title,
    required this.overview,
    required this.details,
    required this.days,
    required this.createdAt,
  });

  bool get isWeekly => scope == PlanScope.week;
}
