import 'dart:async';

import 'package:flutter/material.dart';

import '../models/workout_models.dart';
import '../services/gemini_service.dart';
import '../services/local_store.dart';

class WorkoutState extends ChangeNotifier {
  WorkoutState() {
    _captureInitialData();
  }

  /// Shared instance used by the app shell. Additional instances (tests) read
  /// the same device-local store but stay independently notifyable.
  static final WorkoutState instance = WorkoutState._();

  WorkoutState._() {
    _captureInitialData();
  }

  static const String _storeKey = 'workout_app.workout_state.v1';

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  // ── AI generation state ──────────────────────────────────────────────────
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  String? _generationError;
  String? get generationError => _generationError;

  void clearError() {
    _generationError = null;
    notifyListeners();
  }

  /// Restores saved workouts, the active workout, logged sessions and the
  /// selected tab from device-local storage. Safe to call more than once.
  Future<void> ensureLoaded() async {
    await LocalStore.instance.ensureLoaded();
    final saved = LocalStore.instance.readMap(_storeKey);
    if (saved == null) return;

    final savedWorkouts = saved['savedWorkouts'] as List<dynamic>?;
    if (savedWorkouts != null) {
      _savedWorkouts = savedWorkouts
          .whereType<Map<String, dynamic>>()
          .map(WorkoutModel.fromJson)
          .toList();
    }

    final current = saved['currentWorkout'] as Map<String, dynamic>?;
    if (current != null) _currentWorkout = WorkoutModel.fromJson(current);

    final logs = saved['exerciseLogs'] as List<dynamic>?;
    if (logs != null) {
      _exerciseLogs = logs
          .whereType<Map<String, dynamic>>()
          .map(WorkoutSessionLog.fromJson)
          .toList();
    }

    final tab = (saved['selectedTabIndex'] as num?)?.toInt();
    if (tab != null) _selectedTabIndex = tab;
    notifyListeners();
  }

  Future<void> _persist() {
    return LocalStore.instance.write(_storeKey, {
      'savedWorkouts': _savedWorkouts
          .map((workout) => workout.toJson())
          .toList(),
      'currentWorkout': _currentWorkout.toJson(),
      'exerciseLogs': _exerciseLogs.map((log) => log.toJson()).toList(),
      'selectedTabIndex': _selectedTabIndex,
    });
  }

  /// Writes the original demo workouts/logs into the active namespace once.
  /// Used only by the guest profile.
  Future<void> ensureSeeded() async {
    await LocalStore.instance.ensureLoaded();
    if (LocalStore.instance.readMap(_storeKey) != null) return;
    _savedWorkouts = List<WorkoutModel>.from(_initialSavedWorkouts);
    _currentWorkout = _initialCurrentWorkout;
    _exerciseLogs = List<WorkoutSessionLog>.from(_initialExerciseLogs);
    _selectedTabIndex = 0;
    await _persist();
    notifyListeners();
  }

  /// Replaces in-memory state with the active session's stored data.
  ///
  /// Guest sessions fall back to the preloaded test data; new-user sessions
  /// start empty. Any saved values in the selected namespace win either way.
  Future<void> reload({required bool withDemoData}) async {
    await LocalStore.instance.ensureLoaded();
    _savedWorkouts = withDemoData
        ? List<WorkoutModel>.from(_initialSavedWorkouts)
        : <WorkoutModel>[];
    _currentWorkout = withDemoData ? _initialCurrentWorkout : _emptyWorkout;
    _exerciseLogs = withDemoData
        ? List<WorkoutSessionLog>.from(_initialExerciseLogs)
        : <WorkoutSessionLog>[];
    _selectedTabIndex = 0;

    final saved = LocalStore.instance.readMap(_storeKey);
    if (saved != null) {
      final savedWorkouts = saved['savedWorkouts'] as List<dynamic>?;
      if (savedWorkouts != null) {
        _savedWorkouts = savedWorkouts
            .whereType<Map<String, dynamic>>()
            .map(WorkoutModel.fromJson)
            .toList();
      }

      final current = saved['currentWorkout'] as Map<String, dynamic>?;
      if (current != null) _currentWorkout = WorkoutModel.fromJson(current);

      final logs = saved['exerciseLogs'] as List<dynamic>?;
      if (logs != null) {
        _exerciseLogs = logs
            .whereType<Map<String, dynamic>>()
            .map(WorkoutSessionLog.fromJson)
            .toList();
      }

      final tab = (saved['selectedTabIndex'] as num?)?.toInt();
      if (tab != null) _selectedTabIndex = tab;
    }
    notifyListeners();
  }

  void selectTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      unawaited(_persist());
      notifyListeners();
    }
  }

  // Pre-cataloged exercise library
  final List<ExerciseModel> exerciseCatalog = [
    const ExerciseModel(
      name: "Incline Dumbbell Press",
      category: "Chest",
      difficulty: "Intermediate",
      target: "Upper Pectorals • Dumbbells",
      equipment: "Dumbbells",
      sets: "4 sets",
      reps: "8-10 reps",
      rest: "90s",
      pr: "36 kg",
      note: "Keep 30° bench angle",
      videoUrl: "https://www.youtube.com/watch?v=8iPEnn-ltC8",
      cues: [
        "Set bench angle to 30 degrees to maximize clavicular head activation.",
        "Retract scapulae and drive heels into ground for stability.",
        "Lower dumbbells with controlled 3-second eccentric tempo.",
      ],
    ),
    const ExerciseModel(
      name: "Barbell Deadlift",
      category: "Back",
      difficulty: "Advanced",
      target: "Latissimus, Erector Spinae • Barbell",
      equipment: "Barbell",
      sets: "4 sets",
      reps: "5 reps",
      rest: "150s",
      pr: "180 kg",
      note: "Brace core tightly before pull",
      videoUrl: "https://www.youtube.com/watch?v=op9kVnSso6Q",
      cues: [
        "Set shins 1 inch from bar; pull slack out of bar before breaking floor.",
        "Brace lats and core as if preparing to take a punch.",
        "Push the floor away through legs, standing tall without hyperextending lower back.",
      ],
    ),
    const ExerciseModel(
      name: "Bulgarian Split Squat",
      category: "Legs",
      difficulty: "Intermediate",
      target: "Quadriceps & Gluteus • Dumbbells",
      equipment: "Dumbbells",
      sets: "3 sets",
      reps: "10 reps / leg",
      rest: "90s",
      pr: "24 kg",
      note: "Focus on front quad drive",
      videoUrl: "https://www.youtube.com/watch?v=2C-uNgKwPLE",
      cues: [
        "Elevate rear foot on bench; keep 80% of body weight on the front working heel.",
        "Descend straight down until rear knee gently taps mat.",
        "Drive through front quad and glute to ascend without leaning forward.",
      ],
    ),
    const ExerciseModel(
      name: "Cable Lateral Raise",
      category: "Shoulders",
      difficulty: "All Levels",
      target: "Lateral Deltoid • Cable Tower",
      equipment: "Cables",
      sets: "3 sets",
      reps: "15 reps",
      rest: "60s",
      pr: "12.5 kg",
      note: "Constant tension at top",
      videoUrl: "https://www.youtube.com/watch?v=PPrzBWZDOhA",
      cues: [
        "Position cable at wrist height; maintain a slight forward hinge and soft elbow bend.",
        "Lead with elbows outwards, pausing for 1 second at parallel shoulder height.",
        "Avoid using body momentum to heave the load upwards.",
      ],
    ),
    const ExerciseModel(
      name: "Incline Bicep Curl",
      category: "Arms",
      difficulty: "All Levels",
      target: "Biceps Brachii • Bench & Dumbbells",
      equipment: "Dumbbells",
      sets: "3 sets",
      reps: "10-12 reps",
      rest: "60s",
      pr: "16 kg",
      note: "Strict form, maintain deep stretch",
      videoUrl: "https://www.youtube.com/watch?v=soxrZlIl35U",
      cues: [
        "Set bench to 45° incline; let arms hang fully vertical.",
        "Supinate wrists as you curl upward, keeping upper arms pinned.",
        "Squeeze biceps hard at top for a full 1-second contraction.",
      ],
    ),
    const ExerciseModel(
      name: "Hanging Leg Raise",
      category: "Core",
      difficulty: "Intermediate",
      target: "Rectus Abdominis & Obliques • Bar",
      equipment: "Pull-Up Bar",
      sets: "4 sets",
      reps: "15 reps",
      rest: "60s",
      pr: "Bodyweight",
      note: "Control hip flexion",
      videoUrl: "https://www.youtube.com/watch?v=Pr1ieGZ5atk",
      cues: [
        "Hang with active shoulders; avoid swinging by bracing core.",
        "Roll pelvis upward to curl toes toward bar.",
        "Lower under control over 3 seconds without losing tension.",
      ],
    ),
    const ExerciseModel(
      name: "Assault Air Bike Sprints",
      category: "Cardio",
      difficulty: "High Intensity",
      target: "Full Body Conditioning & Anaerobic Threshold",
      equipment: "Air Bike",
      sets: "10 rounds",
      reps: "20s sprint / 40s rest",
      rest: "40s",
      pr: "45 cal/min",
      note: "All-out max effort intervals",
      videoUrl: "https://www.youtube.com/watch?v=PHReR7tC_tw",
      cues: [
        "Push and pull handles with maximum aggression during 20s sprint.",
        "Maintain upright posture and deep nasal breathing during recovery.",
      ],
    ),
  ];

  // Saved workouts list
  List<WorkoutModel> _savedWorkouts = [
    const WorkoutModel(
      id: "w-1",
      name: "Explosive Push & Delts",
      focus: "Chest & Shoulders",
      duration: "45m",
      difficulty: "Intermediate",
      date: "Yesterday",
      exercises: [
        ExerciseModel(
          name: "Incline Dumbbell Press",
          category: "Chest",
          difficulty: "Intermediate",
          target: "Upper Pectorals",
          equipment: "Dumbbells",
          sets: "4 sets",
          reps: "8-10 reps",
          rest: "90s",
          pr: "36 kg",
          cues: [
            "Set bench angle to 30 degrees to maximize clavicular head activation.",
            "Retract scapulae and drive heels into ground for stability.",
            "Lower dumbbells with controlled 3-second eccentric tempo.",
          ],
        ),
        ExerciseModel(
          name: "Barbell Overhead Press (OHP)",
          category: "Shoulders",
          difficulty: "Advanced",
          target: "Anterior & Lateral Deltoids",
          equipment: "Barbell",
          sets: "4 sets",
          reps: "6-8 reps",
          rest: "120s",
          pr: "70 kg",
          cues: [
            "Brace core, squeeze glutes to protect lower back under load.",
            "Drive bar vertically, tucking chin slightly until lockout overhead.",
          ],
        ),
        ExerciseModel(
          name: "Cable Lateral Raise",
          category: "Shoulders",
          difficulty: "All Levels",
          target: "Lateral Deltoids",
          equipment: "Cables",
          sets: "3 sets",
          reps: "12-15 reps",
          rest: "60s",
          pr: "12.5 kg",
          cues: [
            "Position cable at wrist height; maintain soft elbow bend.",
            "Lead with elbows, pausing for 1s at parallel height.",
          ],
        ),
        ExerciseModel(
          name: "Overhead Rope Tricep Extension",
          category: "Arms",
          difficulty: "Intermediate",
          target: "Triceps Long Head",
          equipment: "Cables",
          sets: "3 sets",
          reps: "12 reps",
          rest: "60s",
          pr: "25 kg",
          cues: [
            "Keep elbows tucked tightly alongside head.",
            "Flare rope apart at peak contraction.",
          ],
        ),
      ],
    ),
    const WorkoutModel(
      id: "w-2",
      name: "Savage Pull & Posterior",
      focus: "Back & Biceps",
      duration: "50m",
      difficulty: "Advanced",
      date: "3 days ago",
      exercises: [
        ExerciseModel(
          name: "Barbell Deadlift",
          category: "Back",
          difficulty: "Advanced",
          target: "Latissimus & Posterior Chain",
          equipment: "Barbell",
          sets: "4 sets",
          reps: "5 reps",
          rest: "150s",
          pr: "180 kg",
          cues: [
            "Set shins 1 inch from bar; pull slack out before pull.",
            "Push the floor away through legs.",
          ],
        ),
        ExerciseModel(
          name: "Weighted Pull-Ups",
          category: "Back",
          difficulty: "Intermediate",
          target: "Latissimus Dorsi",
          equipment: "Bodyweight / Belt",
          sets: "3 sets",
          reps: "6-8 reps",
          rest: "90s",
          pr: "+15 kg",
          cues: [
            "Drive elbows down to waist, touch chest to bar.",
            "Control descent for 2 seconds.",
          ],
        ),
      ],
    ),
    const WorkoutModel(
      id: "w-3",
      name: "Quad & Glute Overdrive",
      focus: "Legs & Core",
      duration: "55m",
      difficulty: "Intermediate",
      date: "5 days ago",
      exercises: [
        ExerciseModel(
          name: "Barbell Back Squat",
          category: "Legs",
          difficulty: "Advanced",
          target: "Quadriceps & Gluteus",
          equipment: "Barbell",
          sets: "4 sets",
          reps: "6-8 reps",
          rest: "120s",
          pr: "140 kg",
          cues: [
            "Hit parallel depth; knees track over toes.",
            "Drive up explosively through mid-foot.",
          ],
        ),
        ExerciseModel(
          name: "Bulgarian Split Squat",
          category: "Legs",
          difficulty: "Intermediate",
          target: "Quadriceps & Glutes",
          equipment: "Dumbbells",
          sets: "3 sets",
          reps: "10 reps / leg",
          rest: "90s",
          pr: "24 kg",
          cues: [
            "Focus pressure through front heel.",
            "Descend until rear knee touches pad.",
          ],
        ),
      ],
    ),
  ];

  List<WorkoutModel> get savedWorkouts => List.unmodifiable(_savedWorkouts);

  // Current active workout displayed on Screen 3
  WorkoutModel _currentWorkout = const WorkoutModel(
    id: "w-active",
    name: "Explosive Push & Delts",
    focus: "Chest & Shoulders",
    duration: "45 Min",
    difficulty: "Intermediate",
    date: "Generated Routine",
    exercises: [
      ExerciseModel(
        name: "Incline Dumbbell Press",
        category: "Chest",
        difficulty: "Intermediate",
        target: "Upper Pectorals • Dumbbells",
        equipment: "Dumbbells",
        sets: "4 sets",
        reps: "8-10 reps",
        rest: "90s",
        pr: "36 kg",
        videoUrl: "https://www.youtube.com/watch?v=8iPEnn-ltC8",
        cues: [
          "Set bench angle to 30 degrees to maximize clavicular head activation.",
          "Retract scapulae and drive heels into ground for stability.",
          "Lower dumbbells with controlled 3-second eccentric tempo.",
        ],
      ),
      ExerciseModel(
        name: "Standing Overhead Barbell Press (OHP)",
        category: "Shoulders",
        difficulty: "Advanced",
        target: "Anterior & Lateral Deltoids • Barbell",
        equipment: "Barbell",
        sets: "4 sets",
        reps: "6-8 reps",
        rest: "120s",
        pr: "70 kg",
        videoUrl: "https://www.youtube.com/watch?v=2yjwXTZQDDI",
        cues: [
          "Brace core, squeeze glutes to protect lower back under load.",
          "Drive bar vertically, tucking chin slightly until lockout overhead.",
        ],
      ),
      ExerciseModel(
        name: "Cable Lateral Raise",
        category: "Shoulders",
        difficulty: "All Levels",
        target: "Lateral Deltoid • Cable Tower",
        equipment: "Cables",
        sets: "3 sets",
        reps: "12-15 reps",
        rest: "60s",
        pr: "12.5 kg",
        videoUrl: "https://www.youtube.com/watch?v=PPrzBWZDOhA",
        cues: [
          "Position cable at wrist height; maintain soft elbow bend.",
          "Lead with elbows, pausing for 1s at parallel height.",
        ],
      ),
      ExerciseModel(
        name: "Overhead Rope Tricep Extension",
        category: "Arms",
        difficulty: "Intermediate",
        target: "Triceps Brachii • Cable Tower",
        equipment: "Cables",
        sets: "3 sets",
        reps: "12 reps",
        rest: "60s",
        pr: "25 kg",
        videoUrl: "https://www.youtube.com/watch?v=kqidUIf1eJE",
        cues: [
          "Keep elbows tucked tightly alongside head.",
          "Flare rope apart at peak contraction.",
        ],
      ),
    ],
  );

  WorkoutModel get currentWorkout => _currentWorkout;

  void setCurrentWorkout(WorkoutModel workout) {
    _currentWorkout = workout;
    unawaited(_persist());
    notifyListeners();
  }

  void saveWorkout(WorkoutModel workout) {
    // Avoid duplicates by ID
    _savedWorkouts.removeWhere((w) => w.id == workout.id);
    _savedWorkouts.insert(0, workout);
    unawaited(_persist());
    notifyListeners();
  }

  void deleteWorkout(String id) {
    _savedWorkouts.removeWhere((w) => w.id == id);
    unawaited(_persist());
    notifyListeners();
  }

  /// Calls Gemini API to generate a workout plan.
  /// Returns true on success, false on failure (error stored in [generationError]).
  Future<bool> generateWorkoutFromAI({
    required String name,
    required List<String> muscles,
    required String duration,
    required String difficulty,
    required String equipment,
  }) async {
    _isGenerating = true;
    _generationError = null;
    notifyListeners();

    try {
      final workout = await GeminiService.generateWorkout(
        name: name,
        muscles: muscles,
        duration: duration,
        difficulty: difficulty,
        equipment: equipment,
      );
      _currentWorkout = workout;
      _isGenerating = false;
      unawaited(_persist());
      notifyListeners();
      return true;
    } catch (e) {
      _isGenerating = false;
      _generationError = e.toString();
      notifyListeners();
      return false;
    }
  }

  void generateWorkout({
    required String name,
    required List<String> muscles,
    required String duration,
    required String difficulty,
  }) {
    final focusStr = muscles.isEmpty ? "Full Body" : muscles.join(" & ");

    // Pick matching exercises or fallbacks
    List<ExerciseModel> selectedExercises = [];
    for (final muscle in muscles) {
      final matches = exerciseCatalog
          .where((e) => e.category.toLowerCase() == muscle.toLowerCase())
          .toList();
      selectedExercises.addAll(matches);
    }

    if (selectedExercises.isEmpty) {
      selectedExercises = [
        exerciseCatalog[0],
        exerciseCatalog[1],
        exerciseCatalog[2],
        exerciseCatalog[3],
      ];
    }

    _currentWorkout = WorkoutModel(
      id: "w-${DateTime.now().millisecondsSinceEpoch}",
      name: name.trim().isEmpty ? "Custom $focusStr Blast" : name.trim(),
      focus: focusStr,
      duration: duration,
      difficulty: difficulty,
      date: "Just generated",
      exercises: selectedExercises,
    );
    unawaited(_persist());
    notifyListeners();
  }

  // ── Exercise Logger with Timers ──────────────────────────────────────────
  List<WorkoutSessionLog> _exerciseLogs = [
    WorkoutSessionLog(
      id: 'log-1',
      exerciseName: 'Incline Dumbbell Press',
      category: 'Chest',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      totalDurationSeconds: 480,
      notes: 'Solid chest pump. Increased weight on 3rd set.',
      sets: [
        ExerciseSetLog(
          setNumber: 1,
          weight: 32.0,
          reps: 10,
          durationSeconds: 38,
          restSeconds: 90,
          completedAt: DateTime.now().subtract(
            const Duration(days: 1, hours: 2, minutes: 6),
          ),
        ),
        ExerciseSetLog(
          setNumber: 2,
          weight: 34.0,
          reps: 8,
          durationSeconds: 42,
          restSeconds: 90,
          completedAt: DateTime.now().subtract(
            const Duration(days: 1, hours: 2, minutes: 4),
          ),
        ),
        ExerciseSetLog(
          setNumber: 3,
          weight: 36.0,
          reps: 8,
          durationSeconds: 45,
          restSeconds: 120,
          completedAt: DateTime.now().subtract(
            const Duration(days: 1, hours: 2, minutes: 2),
          ),
        ),
      ],
    ),
    WorkoutSessionLog(
      id: 'log-2',
      exerciseName: 'Barbell Deadlift',
      category: 'Back',
      timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
      totalDurationSeconds: 650,
      notes: 'Felt strong off the floor. Strict core bracing maintained.',
      sets: [
        ExerciseSetLog(
          setNumber: 1,
          weight: 140.0,
          reps: 6,
          durationSeconds: 32,
          restSeconds: 120,
          completedAt: DateTime.now().subtract(
            const Duration(days: 3, hours: 4, minutes: 8),
          ),
        ),
        ExerciseSetLog(
          setNumber: 2,
          weight: 160.0,
          reps: 5,
          durationSeconds: 35,
          restSeconds: 150,
          completedAt: DateTime.now().subtract(
            const Duration(days: 3, hours: 4, minutes: 5),
          ),
        ),
        ExerciseSetLog(
          setNumber: 3,
          weight: 180.0,
          reps: 3,
          durationSeconds: 30,
          restSeconds: 180,
          completedAt: DateTime.now().subtract(
            const Duration(days: 3, hours: 4, minutes: 2),
          ),
        ),
      ],
    ),
    WorkoutSessionLog(
      id: 'log-3',
      exerciseName: 'Bulgarian Split Squat',
      category: 'Legs',
      timestamp: DateTime.now().subtract(const Duration(days: 5, hours: 6)),
      totalDurationSeconds: 540,
      notes: 'Quad burning workout. Form locked in.',
      sets: [
        ExerciseSetLog(
          setNumber: 1,
          weight: 20.0,
          reps: 10,
          durationSeconds: 40,
          restSeconds: 90,
          completedAt: DateTime.now().subtract(
            const Duration(days: 5, hours: 6, minutes: 7),
          ),
        ),
        ExerciseSetLog(
          setNumber: 2,
          weight: 24.0,
          reps: 10,
          durationSeconds: 42,
          restSeconds: 90,
          completedAt: DateTime.now().subtract(
            const Duration(days: 5, hours: 6, minutes: 4),
          ),
        ),
      ],
    ),
    WorkoutSessionLog(
      id: 'log-4',
      exerciseName: 'Cable Lateral Raise',
      category: 'Shoulders',
      timestamp: DateTime.now().subtract(const Duration(days: 8, hours: 3)),
      totalDurationSeconds: 420,
      notes: 'Shoulder boulder pump.',
      sets: [
        ExerciseSetLog(
          setNumber: 1,
          weight: 10.0,
          reps: 15,
          durationSeconds: 35,
          restSeconds: 60,
          completedAt: DateTime.now().subtract(
            const Duration(days: 8, hours: 3, minutes: 6),
          ),
        ),
        ExerciseSetLog(
          setNumber: 2,
          weight: 12.5,
          reps: 12,
          durationSeconds: 38,
          restSeconds: 60,
          completedAt: DateTime.now().subtract(
            const Duration(days: 8, hours: 3, minutes: 3),
          ),
        ),
      ],
    ),
    WorkoutSessionLog(
      id: 'log-5',
      exerciseName: 'Incline Bicep Curl',
      category: 'Arms',
      timestamp: DateTime.now().subtract(const Duration(days: 14, hours: 5)),
      totalDurationSeconds: 480,
      notes: 'Deep biceps stretch on eccentric.',
      sets: [
        ExerciseSetLog(
          setNumber: 1,
          weight: 14.0,
          reps: 12,
          durationSeconds: 36,
          restSeconds: 60,
          completedAt: DateTime.now().subtract(
            const Duration(days: 14, hours: 5, minutes: 5),
          ),
        ),
        ExerciseSetLog(
          setNumber: 2,
          weight: 16.0,
          reps: 10,
          durationSeconds: 40,
          restSeconds: 75,
          completedAt: DateTime.now().subtract(
            const Duration(days: 14, hours: 5, minutes: 2),
          ),
        ),
      ],
    ),
    WorkoutSessionLog(
      id: 'log-6',
      exerciseName: 'Hanging Leg Raise',
      category: 'Core',
      timestamp: DateTime.now().subtract(const Duration(days: 20, hours: 2)),
      totalDurationSeconds: 360,
      notes: 'Strict pelvic rotation without swinging.',
      sets: [
        ExerciseSetLog(
          setNumber: 1,
          weight: 0.0,
          reps: 15,
          durationSeconds: 30,
          restSeconds: 60,
          completedAt: DateTime.now().subtract(
            const Duration(days: 20, hours: 2, minutes: 4),
          ),
        ),
        ExerciseSetLog(
          setNumber: 2,
          weight: 0.0,
          reps: 15,
          durationSeconds: 32,
          restSeconds: 60,
          completedAt: DateTime.now().subtract(
            const Duration(days: 20, hours: 2, minutes: 1),
          ),
        ),
      ],
    ),
  ];

  // Pristine copies of the preloaded test data. These are restored whenever the
  // guest profile is selected, and never copied into a new-user session.
  late final List<WorkoutModel> _initialSavedWorkouts;
  late final WorkoutModel _initialCurrentWorkout;
  late final List<WorkoutSessionLog> _initialExerciseLogs;

  static const WorkoutModel _emptyWorkout = WorkoutModel(
    id: '',
    name: '',
    focus: '',
    duration: '',
    difficulty: '',
    date: '',
    exercises: [],
  );

  void _captureInitialData() {
    _initialSavedWorkouts = List<WorkoutModel>.unmodifiable(_savedWorkouts);
    _initialCurrentWorkout = _currentWorkout;
    _initialExerciseLogs = List<WorkoutSessionLog>.unmodifiable(_exerciseLogs);
  }

  List<WorkoutSessionLog> get exerciseLogs => List.unmodifiable(_exerciseLogs);

  void addExerciseLog(WorkoutSessionLog log) {
    _exerciseLogs.insert(0, log);
    unawaited(_persist());
    notifyListeners();
  }

  void deleteExerciseLog(String id) {
    _exerciseLogs.removeWhere((l) => l.id == id);
    unawaited(_persist());
    notifyListeners();
  }

  void clearExerciseLogs() {
    _exerciseLogs.clear();
    unawaited(_persist());
    notifyListeners();
  }
}
