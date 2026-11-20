class ExerciseModel {
  final String name;
  final String category;
  final String difficulty;
  final String target;
  final String equipment;
  final String sets;
  final String reps;
  final String rest;
  final String pr;
  final String note;
  final List<String> cues;
  final String? videoUrl;

  const ExerciseModel({
    required this.name,
    required this.category,
    required this.difficulty,
    required this.target,
    required this.equipment,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.pr,
    this.note = '',
    this.cues = const [],
    this.videoUrl,
  });

  ExerciseModel copyWith({
    String? name,
    String? category,
    String? difficulty,
    String? target,
    String? equipment,
    String? sets,
    String? reps,
    String? rest,
    String? pr,
    String? note,
    List<String>? cues,
    String? videoUrl,
  }) {
    return ExerciseModel(
      name: name ?? this.name,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      target: target ?? this.target,
      equipment: equipment ?? this.equipment,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      rest: rest ?? this.rest,
      pr: pr ?? this.pr,
      note: note ?? this.note,
      cues: cues ?? this.cues,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'difficulty': difficulty,
    'target': target,
    'equipment': equipment,
    'sets': sets,
    'reps': reps,
    'rest': rest,
    'pr': pr,
    'note': note,
    'cues': cues,
    if (videoUrl != null) 'videoUrl': videoUrl,
  };

  factory ExerciseModel.fromJson(Map<String, dynamic> json) => ExerciseModel(
    name: (json['name'] as String?) ?? '',
    category: (json['category'] as String?) ?? '',
    difficulty: (json['difficulty'] as String?) ?? '',
    target: (json['target'] as String?) ?? '',
    equipment: (json['equipment'] as String?) ?? '',
    sets: (json['sets'] as String?) ?? '',
    reps: (json['reps'] as String?) ?? '',
    rest: (json['rest'] as String?) ?? '',
    pr: (json['pr'] as String?) ?? '',
    note: (json['note'] as String?) ?? '',
    cues:
        (json['cues'] as List<dynamic>?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[],
    videoUrl: json['videoUrl'] as String?,
  );
}

class WorkoutModel {
  final String id;
  final String name;
  final String focus;
  final String duration;
  final String difficulty;
  final String date;
  final List<ExerciseModel> exercises;

  const WorkoutModel({
    required this.id,
    required this.name,
    required this.focus,
    required this.duration,
    required this.difficulty,
    required this.date,
    required this.exercises,
  });

  WorkoutModel copyWith({
    String? id,
    String? name,
    String? focus,
    String? duration,
    String? difficulty,
    String? date,
    List<ExerciseModel>? exercises,
  }) {
    return WorkoutModel(
      id: id ?? this.id,
      name: name ?? this.name,
      focus: focus ?? this.focus,
      duration: duration ?? this.duration,
      difficulty: difficulty ?? this.difficulty,
      date: date ?? this.date,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'focus': focus,
    'duration': duration,
    'difficulty': difficulty,
    'date': date,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };

  factory WorkoutModel.fromJson(Map<String, dynamic> json) => WorkoutModel(
    id: (json['id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    focus: (json['focus'] as String?) ?? '',
    duration: (json['duration'] as String?) ?? '',
    difficulty: (json['difficulty'] as String?) ?? '',
    date: (json['date'] as String?) ?? '',
    exercises:
        (json['exercises'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(ExerciseModel.fromJson)
            .toList() ??
        const <ExerciseModel>[],
  );
}

class ExerciseSetLog {
  final int setNumber;
  final double weight;
  final int reps;
  final int durationSeconds; // Duration of active set execution
  final int restSeconds; // Rest taken after set
  final DateTime completedAt;

  const ExerciseSetLog({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.durationSeconds = 0,
    this.restSeconds = 0,
    required this.completedAt,
  });

  ExerciseSetLog copyWith({
    int? setNumber,
    double? weight,
    int? reps,
    int? durationSeconds,
    int? restSeconds,
    DateTime? completedAt,
  }) {
    return ExerciseSetLog(
      setNumber: setNumber ?? this.setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'setNumber': setNumber,
    'weight': weight,
    'reps': reps,
    'durationSeconds': durationSeconds,
    'restSeconds': restSeconds,
    'completedAt': completedAt.toIso8601String(),
  };

  factory ExerciseSetLog.fromJson(Map<String, dynamic> json) => ExerciseSetLog(
    setNumber: (json['setNumber'] as num?)?.toInt() ?? 1,
    weight: (json['weight'] as num?)?.toDouble() ?? 0,
    reps: (json['reps'] as num?)?.toInt() ?? 0,
    durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 0,
    completedAt:
        DateTime.tryParse((json['completedAt'] as String?) ?? '') ??
        DateTime.now(),
  );
}

class WorkoutSessionLog {
  final String id;
  final String exerciseName;
  final String category;
  final DateTime timestamp;
  final int totalDurationSeconds;
  final List<ExerciseSetLog> sets;
  final String notes;

  const WorkoutSessionLog({
    required this.id,
    required this.exerciseName,
    required this.category,
    required this.timestamp,
    required this.totalDurationSeconds,
    required this.sets,
    this.notes = '',
  });

  int get totalReps => sets.fold(0, (sum, set) => sum + set.reps);
  double get maxWeight => sets.isEmpty
      ? 0.0
      : sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);

  /// Volume capture rule: only the set weight is counted as a singular
  /// value (e.g. a 30 kg set contributes exactly 30 kg). The weight is
  /// NOT multiplied against the reps.
  double get totalVolume => sets.fold(0.0, (sum, set) => sum + set.weight);

  WorkoutSessionLog copyWith({
    String? id,
    String? exerciseName,
    String? category,
    DateTime? timestamp,
    int? totalDurationSeconds,
    List<ExerciseSetLog>? sets,
    String? notes,
  }) {
    return WorkoutSessionLog(
      id: id ?? this.id,
      exerciseName: exerciseName ?? this.exerciseName,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseName': exerciseName,
    'category': category,
    'timestamp': timestamp.toIso8601String(),
    'totalDurationSeconds': totalDurationSeconds,
    'sets': sets.map((set) => set.toJson()).toList(),
    'notes': notes,
  };

  factory WorkoutSessionLog.fromJson(Map<String, dynamic> json) =>
      WorkoutSessionLog(
        id: (json['id'] as String?) ?? '',
        exerciseName: (json['exerciseName'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        timestamp:
            DateTime.tryParse((json['timestamp'] as String?) ?? '') ??
            DateTime.now(),
        totalDurationSeconds:
            (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
        sets:
            (json['sets'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ExerciseSetLog.fromJson)
                .toList() ??
            const <ExerciseSetLog>[],
        notes: (json['notes'] as String?) ?? '',
      );
}
