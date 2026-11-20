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

  factory PlanDetails.fromJson(Map<String, dynamic> json) => PlanDetails(
    goal: (json['goal'] as String?) ?? '',
    experienceLevel: (json['experienceLevel'] as String?) ?? '',
    equipment: (json['equipment'] as String?) ?? '',
    daysPerWeek: (json['daysPerWeek'] as num?)?.toInt() ?? 1,
    exerciseTypes:
        (json['exerciseTypes'] as List<dynamic>?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[],
    exerciseCombination: (json['exerciseCombination'] as String?) ?? '',
    dayLabel: json['dayLabel'] as String?,
  );
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

  Map<String, dynamic> toJson() => {
    'label': label,
    'workoutName': workoutName,
    'focus': focus,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'note': note,
  };

  factory PlanDay.fromJson(Map<String, dynamic> json) => PlanDay(
    label: (json['label'] as String?) ?? '',
    workoutName: (json['workoutName'] as String?) ?? '',
    focus: (json['focus'] as String?) ?? '',
    exercises:
        (json['exercises'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(ExerciseModel.fromJson)
            .toList() ??
        const <ExerciseModel>[],
    note: (json['note'] as String?) ?? '',
  );
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'scope': scope.name,
    'title': title,
    'overview': overview,
    'details': details.toJson(),
    'days': days.map((day) => day.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory GeneratedPlan.fromJson(Map<String, dynamic> json) => GeneratedPlan(
    id: (json['id'] as String?) ?? '',
    scope: PlanScope.values.firstWhere(
      (value) => value.name == json['scope'],
      orElse: () => PlanScope.day,
    ),
    title: (json['title'] as String?) ?? '',
    overview: (json['overview'] as String?) ?? '',
    details: PlanDetails.fromJson(
      (json['details'] as Map<String, dynamic>?) ?? const {},
    ),
    days:
        (json['days'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(PlanDay.fromJson)
            .toList() ??
        const <PlanDay>[],
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now(),
  );
}

/// One generated plan explicitly saved from the Plan result view.
///
/// The wrapper keeps a separate history id and saved timestamp so the same
/// generated plan can be recognised without colliding with new generations.
class SavedPlanEntry {
  const SavedPlanEntry({
    required this.id,
    required this.plan,
    required this.savedAt,
  });

  final String id;
  final GeneratedPlan plan;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan': plan.toJson(),
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedPlanEntry.fromJson(Map<String, dynamic> json) => SavedPlanEntry(
    id:
        (json['id'] as String?) ??
        'saved-plan-${DateTime.now().microsecondsSinceEpoch}',
    plan: GeneratedPlan.fromJson(
      (json['plan'] as Map<String, dynamic>?) ?? const {},
    ),
    savedAt:
        DateTime.tryParse((json['savedAt'] as String?) ?? '') ?? DateTime.now(),
  );
}
