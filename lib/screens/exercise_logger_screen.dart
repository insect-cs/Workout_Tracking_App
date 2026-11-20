import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/workout_models.dart';
import '../services/export_service.dart';
import '../state/workout_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_hero_tags.dart';
import '../widgets/app_dialog.dart';

class ExerciseLoggerScreen extends StatefulWidget {
  final WorkoutState state;
  final VoidCallback onBackToHome;
  final String? initialExerciseName;

  const ExerciseLoggerScreen({
    super.key,
    required this.state,
    required this.onBackToHome,
    this.initialExerciseName,
  });

  @override
  State<ExerciseLoggerScreen> createState() => _ExerciseLoggerScreenState();
}

class _ExerciseLoggerScreenState extends State<ExerciseLoggerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selected Exercise for active logging
  late String _selectedExercise;
  late TextEditingController _customExerciseController;
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late TextEditingController _notesController;

  // Progress Graph filter: 'Daily', 'Weekly', 'Monthly'
  String _graphTimeframe = 'Weekly';

  // Overall progress graph visualization type: 'Bars', 'Line', 'Area'
  String _overallVizType = 'Bars';

  // Active workout timers
  Timer? _sessionTimer;
  int _sessionSeconds = 0;
  bool _isSessionRunning = false;

  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  int _targetRestSeconds = 90;
  bool _isRestActive = false;

  // Timer for active set execution
  Timer? _setExecutionTimer;
  int _setExecutionSeconds = 0;
  bool _isSetExecuting = false;
  DateTime? _setExecutionStartTime;

  // Current session in-progress sets
  final List<ExerciseSetLog> _currentSessionSets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initial exercise selection
    final catalog = widget.state.exerciseCatalog;
    _selectedExercise =
        widget.initialExerciseName ??
        (catalog.isNotEmpty ? catalog.first.name : 'Incline Dumbbell Press');

    _customExerciseController = TextEditingController();
    _weightController = TextEditingController(text: '30');
    _repsController = TextEditingController(text: '10');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    _setExecutionTimer?.cancel();
    _tabController.dispose();
    _customExerciseController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Session Timer Controls ──────────────────────────────────────────────
  void _startSessionTimer() {
    if (_isSessionRunning) return;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionSeconds++;
        });
      }
    });
    setState(() {
      _isSessionRunning = true;
    });
  }

  void _pauseSessionTimer() {
    _sessionTimer?.cancel();
    setState(() {
      _isSessionRunning = false;
    });
  }

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    setState(() {
      _isSessionRunning = false;
      _sessionSeconds = 0;
    });
  }

  // ── Set Timer Controls ──────────────────────────────────────────────────
  void _startSetTimer() {
    if (!_isSessionRunning) _startSessionTimer();
    // Stop rest timer if user starts the next set while resting
    _restTimer?.cancel();
    _isRestActive = false;

    _setExecutionTimer?.cancel();
    final now = DateTime.now();
    setState(() {
      _setExecutionStartTime = now;
      _setExecutionSeconds = 0;
      _isSetExecuting = true;
    });
    _setExecutionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _setExecutionSeconds = DateTime.now()
              .difference(_setExecutionStartTime ?? now)
              .inSeconds;
        });
      }
    });
  }

  void _stopSetTimer() {
    _setExecutionTimer?.cancel();
    if (_setExecutionStartTime != null) {
      _setExecutionSeconds = DateTime.now()
          .difference(_setExecutionStartTime!)
          .inSeconds;
    }
    setState(() {
      _isSetExecuting = false;
    });
  }

  // ── Rest Countdown Timer Controls ───────────────────────────────────────
  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _targetRestSeconds = seconds;
      _restSecondsRemaining = seconds;
      _isRestActive = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_restSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _restSecondsRemaining = 0;
          _isRestActive = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.primaryOrange),
            ),
            content: Row(
              children: [
                Icon(Icons.alarm_on, color: AppColors.primaryOrange, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Rest time finished! Time for the next set.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _restSecondsRemaining--;
        });
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isRestActive = false;
      _restSecondsRemaining = 0;
    });
  }

  // ── Log Set Logic ────────────────────────────────────────────────────────
  void _logCompletedSet() {
    if (!_isSessionRunning) {
      _startSessionTimer();
    }

    int measuredSetDuration = _setExecutionSeconds;
    if (_isSetExecuting && _setExecutionStartTime != null) {
      measuredSetDuration = DateTime.now()
          .difference(_setExecutionStartTime!)
          .inSeconds;
    }
    _stopSetTimer();

    final weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final reps = int.tryParse(_repsController.text.trim()) ?? 0;
    final currentSetNumber = _currentSessionSets.length + 1;

    // Use measured active timer if > 0, otherwise default to a realistic estimated working duration
    final finalSetDuration = measuredSetDuration > 0 ? measuredSetDuration : 40;

    final newSet = ExerciseSetLog(
      setNumber: currentSetNumber,
      weight: weight,
      reps: reps,
      durationSeconds: finalSetDuration,
      restSeconds: _targetRestSeconds,
      completedAt: DateTime.now(),
    );

    setState(() {
      _currentSessionSets.add(newSet);
      _setExecutionSeconds = 0;
      _setExecutionStartTime = null;
    });

    // Auto-trigger rest countdown for the next set (Set 2 and onwards)
    _startRestTimer(_targetRestSeconds);
  }

  void _finishAndSaveSession() {
    if (_currentSessionSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.cardSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.rose),
          ),
          content: Text(
            'Log at least 1 set before saving session.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: AppColors.textWhite,
            ),
          ),
        ),
      );
      return;
    }

    final category = widget.state.exerciseCatalog
        .firstWhere(
          (e) => e.name.toLowerCase() == _selectedExercise.toLowerCase(),
          orElse: () => const ExerciseModel(
            name: '',
            category: 'Strength',
            difficulty: '',
            target: '',
            equipment: '',
            sets: '',
            reps: '',
            rest: '',
            pr: '',
          ),
        )
        .category;

    final sessionLog = WorkoutSessionLog(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      exerciseName: _selectedExercise,
      category: category.isNotEmpty ? category : 'Strength',
      timestamp: DateTime.now(),
      totalDurationSeconds: _sessionSeconds > 0 ? _sessionSeconds : 300,
      sets: List.from(_currentSessionSets),
      notes: _notesController.text.trim(),
    );

    widget.state.addExerciseLog(sessionLog);

    _sessionTimer?.cancel();
    _restTimer?.cancel();
    _setExecutionTimer?.cancel();

    setState(() {
      _currentSessionSets.clear();
      _sessionSeconds = 0;
      _isSessionRunning = false;
      _isRestActive = false;
      _notesController.clear();
      _tabController.animateTo(1); // switch to history tab
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.cardSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.emerald),
        ),
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.emerald, size: 20),
            const SizedBox(width: 10),
            Text(
              'Exercise session logged successfully!',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Formats a weight double cleanly: 32.0 → "32", 32.5 → "32.5"
  String _formatWeight(double w) {
    if (w == w.truncateToDouble()) return w.toInt().toString();
    return w.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveLoggerTab(),
                      _buildHistoryTab(),
                      _buildProgressGraphTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: Color(0x3320293A))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                InkWell(
                  onTap: widget.onBackToHome,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.textLight,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exercise Tracker',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      Text(
                        'Live Timers & Performance Log',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.orangeBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, color: AppColors.primaryOrange, size: 12),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _formatTime(_sessionSeconds),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(icon: Icon(Icons.timer_outlined, size: 20), text: 'TRACKER'),
        Tab(icon: Icon(Icons.history, size: 20), text: 'HISTORY'),
        Tab(icon: Icon(Icons.insights, size: 20), text: 'PROGRESS GRAPH'),
      ],
    );
  }

  // ── Active Tracker View ──────────────────────────────────────────────────
  Widget _buildActiveLoggerTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Live Stopwatch & Rest Timer Card
        _buildTimersHeroCard(),
        const SizedBox(height: 16),

        // Exercise Selector
        _buildExerciseSelector(),
        const SizedBox(height: 16),

        // Log Set Form (Weight & Reps)
        _buildSetInputForm(),
        const SizedBox(height: 16),

        // Logged Sets Table for this session
        _buildSessionSetsList(),
        const SizedBox(height: 20),

        // Notes Input
        _buildNotesField(),
        const SizedBox(height: 20),

        // Save Completed Session Button
        _buildSaveSessionButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTimersHeroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Session Stopwatch
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL SESSION TIMER',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppColors.textSlate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(_sessionSeconds),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        InkWell(
                          onTap: _isSessionRunning
                              ? _pauseSessionTimer
                              : _startSessionTimer,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _isSessionRunning
                                  ? AppColors.amber.withValues(alpha: 0.2)
                                  : AppColors.emerald.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isSessionRunning
                                    ? AppColors.amber
                                    : AppColors.emerald,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isSessionRunning
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: _isSessionRunning
                                      ? AppColors.amber
                                      : AppColors.emerald,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isSessionRunning ? 'Pause' : 'Start',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isSessionRunning
                                        ? AppColors.amber
                                        : AppColors.emerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _resetSessionTimer,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(
                              Icons.refresh,
                              color: AppColors.textSlate,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                width: 1,
                height: 80,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // Rest Countdown Timer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'REST COUNTDOWN',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: _isRestActive
                            ? AppColors.primaryOrange
                            : AppColors.textSlate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRestActive
                          ? _formatTime(_restSecondsRemaining)
                          : _formatTime(_targetRestSeconds),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _isRestActive
                            ? AppColors.primaryOrange
                            : AppColors.textSlate,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isRestActive)
                          InkWell(
                            onTap: _stopRestTimer,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.rose.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.rose),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stop,
                                    color: AppColors.rose,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Stop',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.rose,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 4,
                            children: [60, 90, 120].map((sec) {
                              final isCurrent = _targetRestSeconds == sec;
                              return InkWell(
                                onTap: () => _startRestTimer(sec),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? AppColors.orangeSoft
                                        : AppColors.surfaceLow,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isCurrent
                                          ? AppColors.primaryOrange
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    '${sec}s',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent
                                          ? AppColors.primaryOrange
                                          : AppColors.textSlate,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),

          // Active Set Under-Tension Execution Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSetExecuting
                            ? AppColors.emerald
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isSetExecuting
                            ? 'SET UNDER TENSION: ${_formatTime(_setExecutionSeconds)}'
                            : 'SET TIMER: IDLE',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: _isSetExecuting
                              ? AppColors.emerald
                              : AppColors.textSlate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InkWell(
                  onTap: _isSetExecuting ? _stopSetTimer : _startSetTimer,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isSetExecuting
                          ? AppColors.rose.withValues(alpha: 0.2)
                          : AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSetExecuting
                            ? AppColors.rose
                            : AppColors.primaryOrange,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSetExecuting ? Icons.stop : Icons.play_arrow,
                          color: _isSetExecuting
                              ? AppColors.rose
                              : AppColors.primaryOrange,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _isSetExecuting ? 'Stop Set' : 'Start Set Timer',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isSetExecuting
                                  ? AppColors.rose
                                  : AppColors.primaryOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSelector() {
    final catalog = widget.state.exerciseCatalog;
    final exerciseNames = catalog.map((e) => e.name).toList();
    if (!exerciseNames.contains(_selectedExercise)) {
      exerciseNames.insert(0, _selectedExercise);
    }

    return Hero(
      tag: AppHeroTags.logExercise(_selectedExercise),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TARGET EXERCISE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  'Select or type',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: exerciseNames.contains(_selectedExercise)
                      ? _selectedExercise
                      : exerciseNames.first,
                  dropdownColor: AppColors.cardSurface,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.primaryOrange,
                  ),
                  items: exerciseNames.map((name) {
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(
                        name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textWhite,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedExercise = val;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetInputForm() {
    final nextSetNumber = _currentSessionSets.length + 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SET $nextSetNumber',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Log Performance',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                ],
              ),
              if (_isSetExecuting)
                Row(
                  children: [
                    Icon(Icons.timer, color: AppColors.emerald, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_setExecutionSeconds),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Inputs row: Weight & Reps
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEIGHT (KG)',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppColors.textSlate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildAdjustButton(
                          icon: Icons.remove,
                          onTap: () {
                            final cur =
                                double.tryParse(_weightController.text) ?? 0.0;
                            if (cur >= 2.5) {
                              _weightController.text = (cur - 2.5)
                                  .toStringAsFixed(1)
                                  .replaceAll('.0', '');
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textWhite,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildAdjustButton(
                          icon: Icons.add,
                          onTap: () {
                            final cur =
                                double.tryParse(_weightController.text) ?? 0.0;
                            _weightController.text = (cur + 2.5)
                                .toStringAsFixed(1)
                                .replaceAll('.0', '');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REPETITIONS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppColors.textSlate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildAdjustButton(
                          icon: Icons.remove,
                          onTap: () {
                            final cur = int.tryParse(_repsController.text) ?? 0;
                            if (cur > 1) {
                              _repsController.text = (cur - 1).toString();
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _repsController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textWhite,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildAdjustButton(
                          icon: Icons.add,
                          onTap: () {
                            final cur = int.tryParse(_repsController.text) ?? 0;
                            _repsController.text = (cur + 1).toString();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Log Set Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _logCompletedSet,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Complete Set & Start Rest Timer (${_targetRestSeconds}s)',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.primaryOrange, size: 16),
      ),
    );
  }

  Widget _buildSessionSetsList() {
    if (_currentSessionSets.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.fitness_center, color: AppColors.textSlate, size: 28),
            const SizedBox(height: 8),
            Text(
              'No sets logged in this session yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hit "Complete Set" above to record sets and trigger rest countdown.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlate,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SETS COMPLETED (${_currentSessionSets.length})',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  '${_currentSessionSets.fold(0, (sum, s) => sum + s.reps)} Total Reps',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          ..._currentSessionSets.map((s) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x2220293A))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.orangeSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.orangeBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${s.setNumber}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${s.weight} kg  ×  ${s.reps} reps',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.hourglass_top,
                        color: AppColors.textSlate,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${s.durationSeconds}s work',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSlate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _currentSessionSets.remove(s);
                            // Renumber remaining sets sequentially
                            for (
                              int i = 0;
                              i < _currentSessionSets.length;
                              i++
                            ) {
                              _currentSessionSets[i] = _currentSessionSets[i]
                                  .copyWith(setNumber: i + 1);
                            }
                          });
                        },
                        child: Icon(
                          Icons.close,
                          color: AppColors.rose,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SESSION NOTES (OPTIONAL)',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textLight),
            decoration: InputDecoration(
              hintText:
                  'e.g., Felt powerful on sets 2 and 3. Kept rest strict.',
              hintStyle: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveSessionButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.tonal(
        onPressed: _finishAndSaveSession,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Save Completed Session to History',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── History Tab View ─────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    final logs = widget.state.exerciseLogs;

    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_toggle_off,
                size: 48,
                color: AppColors.textSlate,
              ),
              const SizedBox(height: 14),
              Text(
                'No exercise logs recorded yet',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use the Active Tracker to log your sets with real-time timers.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSlate,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Top Toolbar: Total Count & Clear History Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AppColors.primaryOrange, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${logs.length} LOGGED SESSIONS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _confirmClearHistory(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.rose.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_sweep, color: AppColors.rose, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Clear History',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.rose,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Session Cards
        ...logs.map((log) {
          final formattedDate =
              '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} • ${_formatTime(log.totalDurationSeconds)} total';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.exerciseName,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textWhite,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        log.category,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Metrics Chips Row
                Row(
                  children: [
                    _buildMetricPill(
                      Icons.fitness_center,
                      '${log.sets.length} Sets',
                    ),
                    const SizedBox(width: 8),
                    _buildMetricPill(Icons.repeat, '${log.totalReps} Reps'),
                    const SizedBox(width: 8),
                    _buildMetricPill(
                      Icons.arrow_upward,
                      'Max ${_formatWeight(log.maxWeight)} kg',
                    ),
                    const SizedBox(width: 8),
                    _buildMetricPill(
                      Icons.scale,
                      '${log.totalVolume.toInt()} kg vol',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 10),

                // Sets Details Grid/List
                ...log.sets.map((s) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Set ${s.setNumber}:  ${_formatWeight(s.weight)} kg  ×  ${s.reps} reps',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLight,
                          ),
                        ),
                        Text(
                          '${s.durationSeconds}s work • ${s.restSeconds}s rest',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                if (log.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.notes,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSlate,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AppDialog(
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.rose,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Clear History?',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                ),
              ),
            ],
          ),
          content: Text(
            'This will permanently delete all logged exercise sessions and reset progress graphs. This action cannot be undone.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textLight,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: AppColors.textSlate,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.state.clearExerciseLogs();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.cardSurface,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.rose),
                    ),
                    content: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: AppColors.rose,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Exercise history cleared.',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.black,
              ),
              child: Text(
                'Clear All',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryOrange, size: 11),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Progress Graph Tab (Overall & Category-Wise with Daily/Weekly/Monthly)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildProgressGraphTab() {
    final logs = widget.state.exerciseLogs;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Timeframe selector bar: Daily / Weekly / Monthly
        _buildTimeframeSelector(),
        const SizedBox(height: 10),

        // Export the currently selected timeframe's graph data
        _buildExportDataButton(logs),
        const SizedBox(height: 16),

        // Summary Quick Stats
        _buildGraphSummaryBanner(logs),
        const SizedBox(height: 16),

        // Graph 1: Overall Exercise Progress (Volume & Timers over time)
        _buildOverallProgressCard(logs),
        const SizedBox(height: 20),

        // Graph 2: Category-Wise Breakdown (Chest, Back, Legs, Shoulders, Arms, Core)
        _buildCategoryProgressCard(logs),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildTimeframeSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'Daily',
          icon: Icon(Icons.calendar_view_day, size: 16),
          label: Text('Daily'),
        ),
        ButtonSegment(
          value: 'Weekly',
          icon: Icon(Icons.calendar_view_week, size: 16),
          label: Text('Weekly'),
        ),
        ButtonSegment(
          value: 'Monthly',
          icon: Icon(Icons.calendar_month, size: 16),
          label: Text('Monthly'),
        ),
      ],
      selected: {_graphTimeframe},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          setState(() => _graphTimeframe = selection.first);
        }
      },
    );
  }

  /// Builds the timeframe-scoped export snapshot: only the aggregated
  /// column data of the currently selected view (Daily / Weekly / Monthly).
  ExportData _buildExportSnapshot(List<WorkoutSessionLog> logs) {
    final filtered = _filterLogsByTimeframe(logs, _graphTimeframe);
    final overall = _aggregateOverallData(logs, _graphTimeframe);
    final categories = _aggregateCategoryData(logs, _graphTimeframe);

    return ExportData(
      timeframe: _graphTimeframe,
      overallPoints: overall
          .map((p) => (label: p.label, value: p.value))
          .toList(),
      categoryPoints: categories
          .map(
            (c) => (
              category: c.category,
              volume: c.volume,
              percentage: c.percentage,
              sessionCount: c.sessionCount,
              durationSeconds: c.durationSeconds,
            ),
          )
          .toList(),
      sessions: filtered,
    );
  }

  /// "Export Data" button: exports the progress-graph data of the currently
  /// selected timeframe (that view's column data only) to CSV or PDF.
  Widget _buildExportDataButton(List<WorkoutSessionLog> logs) {
    return GestureDetector(
      onTap: () => _showExportOptions(logs),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.orangeBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.file_download_outlined,
                color: AppColors.primaryOrange,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPORT DATA',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  Text(
                    'Export $_graphTimeframe progress-graph data as .csv or .pdf',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textSlate,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSlate, size: 18),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(List<WorkoutSessionLog> logs) {
    final snapshot = _buildExportSnapshot(logs);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export $_graphTimeframe Data',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only the data captured for the $_graphTimeframe view is '
                  'included (${snapshot.sessions.length} sessions).',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                _buildExportOption(
                  icon: Icons.table_view,
                  title: 'Export as CSV',
                  subtitle: 'Rows & columns, fully segregated entities',
                  color: AppColors.emerald,
                  onTap: () => _runExport(sheetContext, snapshot, 'csv'),
                ),
                const SizedBox(height: 10),
                _buildExportOption(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Export as PDF',
                  subtitle: 'Formatted report with tables',
                  color: AppColors.primaryOrange,
                  onTap: () => _runExport(sheetContext, snapshot, 'pdf'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.download, color: AppColors.textSlate, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _runExport(
    BuildContext sheetContext,
    ExportData snapshot,
    String format,
  ) async {
    Navigator.of(sheetContext).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.cardSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.primaryOrange),
        ),
        content: Text(
          'Generating ${format.toUpperCase()} export...',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textWhite),
        ),
        duration: const Duration(seconds: 8),
      ),
    );

    try {
      final path = format == 'csv'
          ? await ExportService.saveCsv(snapshot)
          : await ExportService.savePdf(snapshot);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.emerald),
            ),
            content: Text(
              kIsWeb
                  ? '$format export started - check your downloads ($path)'
                  : 'Exported to: $path',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textWhite,
              ),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cardSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.rose),
            ),
            content: Text(
              'Export failed: $e',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.rose),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
    }
  }

  Widget _buildGraphSummaryBanner(List<WorkoutSessionLog> logs) {
    final filtered = _filterLogsByTimeframe(logs, _graphTimeframe);

    final totalVolume = filtered.fold(0.0, (sum, log) => sum + log.totalVolume);
    final totalReps = filtered.fold(0, (sum, log) => sum + log.totalReps);
    final totalDurationSec = filtered.fold(
      0,
      (sum, log) => sum + log.totalDurationSeconds,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            label: 'TOTAL VOLUME',
            value: totalVolume >= 1000
                ? '${(totalVolume / 1000).toStringAsFixed(1)}t'
                : '${totalVolume.toStringAsFixed(0)} kg',
            sub: totalVolume >= 1000
                ? '${totalVolume.toInt()} kg'
                : '${filtered.length} sessions',
            color: AppColors.primaryOrange,
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          _buildSummaryItem(
            label: 'TIME RECORDED',
            value: _formatTime(totalDurationSec),
            sub: '${filtered.length} sessions',
            color: AppColors.emerald,
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          _buildSummaryItem(
            label: 'TOTAL REPS',
            value: '$totalReps',
            sub: 'Across sets',
            color: AppColors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: AppColors.textSlate,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          sub,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }

  // ── Graph 1: Overall Progress Chart ──────────────────────────────────────
  Widget _buildOverallProgressCard(List<WorkoutSessionLog> logs) {
    final chartPoints = _aggregateOverallData(logs, _graphTimeframe);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.orangeSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.show_chart,
                      color: AppColors.primaryOrange,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Overall Exercise Progress',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      Text(
                        'Total Volume Load (kg) • $_graphTimeframe view',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${chartPoints.length} bins',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Visualization type selector: Bars / Line / Area
          _buildVizTypeSelector(),
          const SizedBox(height: 16),

          // Chart Canvas (renders the selected visualization)
          SizedBox(height: 160, child: _buildOverallChart(chartPoints)),
          const SizedBox(height: 12),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),

          // Footnote stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Volume trend shows consistency & progressive overload.',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Volume (kg)',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSlate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Renders the overall progress chart in the currently selected
  /// visualization type (Bars / Line / Area).
  Widget _buildOverallChart(List<_GraphDataPoint> points) {
    switch (_overallVizType) {
      case 'Line':
        return _buildLineChart(points);
      case 'Area':
        return _buildAreaChart(points);
      case 'Pie':
        return _buildPieChart(points);
      default:
        return _buildBarChart(points);
    }
  }

  /// Visualization type selector chips for the overall progress graph.
  Widget _buildVizTypeSelector() {
    const vizTypes = [
      ('Bars', Icons.bar_chart),
      ('Line', Icons.show_chart),
      ('Area', Icons.area_chart),
      ('Pie', Icons.pie_chart),
    ];

    return Row(
      children: [
        Text(
          'VIEW',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textSlate,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SegmentedButton<String>(
            segments: [
              for (final type in vizTypes)
                ButtonSegment<String>(
                  value: type.$1,
                  icon: Icon(type.$2, size: 16),
                  label: Text(type.$1),
                ),
            ],
            selected: {_overallVizType},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                setState(() => _overallVizType = selection.first);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<_GraphDataPoint> points) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No workout sessions recorded for this timeframe',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        ),
      );
    }

    final maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final ceiling = maxVal == 0 ? 100.0 : maxVal;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points.map((point) {
        final ratio = (point.value / ceiling).clamp(0.08, 1.0);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (point.value > 0)
                  Text(
                    point.value >= 1000
                        ? '${(point.value / 1000).toStringAsFixed(1)}k'
                        : point.value >= 1
                        ? point.value.toInt().toString()
                        : point.value.toStringAsFixed(1),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                  )
                else
                  const SizedBox(height: 12),
                const SizedBox(height: 4),
                // Animated colored bar
                Container(
                  height: 105 * ratio,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: point.value > 0
                          ? [AppColors.primaryOrange, AppColors.orangeDark]
                          : [AppColors.surfaceLow, AppColors.surfaceLow],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: point.value > 0
                          ? AppColors.primaryOrange
                          : AppColors.border,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  point.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Line chart: value polyline with dots and labels.
  Widget _buildLineChart(List<_GraphDataPoint> points) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No workout sessions recorded for this timeframe',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        ),
      );
    }

    final maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final ceiling = maxVal == 0 ? 100.0 : maxVal;

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _LineChartPainter(
              values: points.map((p) => p.value / ceiling).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: points.map((p) {
            return Expanded(
              child: Text(
                p.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSlate,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Area chart: filled gradient under the value polyline.
  Widget _buildAreaChart(List<_GraphDataPoint> points) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No workout sessions recorded for this timeframe',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        ),
      );
    }

    final maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final ceiling = maxVal == 0 ? 100.0 : maxVal;

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _AreaChartPainter(
              values: points.map((p) => p.value / ceiling).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: points.map((p) {
            return Expanded(
              child: Text(
                p.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSlate,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Pie chart: distribution of volume across time bins, with a legend
  /// showing each bin's label, value and percentage share.
  Widget _buildPieChart(List<_GraphDataPoint> points) {
    final nonEmpty = points.where((p) => p.value > 0).toList();
    if (nonEmpty.isEmpty) {
      return Center(
        child: Text(
          'No workout sessions recorded for this timeframe',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
        ),
      );
    }

    final total = nonEmpty.fold(0.0, (a, b) => a + b.value);
    final sliceColors = [
      AppColors.primaryOrange,
      AppColors.emerald,
      AppColors.amber,
      Color(0xFF6366F1), // Indigo
      Color(0xFFEC4899), // Pink
      Color(0xFF06B6D4), // Cyan
    ];

    final slices = nonEmpty.asMap().entries.map((e) {
      final colorIndex = e.key % sliceColors.length;
      return (
        label: e.value.label,
        value: e.value.value,
        fraction: total > 0 ? e.value.value / total : 0.0,
        color: sliceColors[colorIndex],
      );
    }).toList();

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            size: const Size(130, 130),
            painter: _PieChartPainter(slices: slices),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: slices.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.value >= 1000 ? '${(s.value / 1000).toStringAsFixed(1)}k' : s.value.toInt()}kg'
                      ' (${(s.fraction * 100).toStringAsFixed(0)}%)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Graph 2: Category-Wise Breakdown Chart ───────────────────────────────
  Widget _buildCategoryProgressCard(List<WorkoutSessionLog> logs) {
    final categoryData = _aggregateCategoryData(logs, _graphTimeframe);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pie_chart,
                      color: AppColors.emerald,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. Category-Wise Distribution',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      Text(
                        'Muscular Volume & Time Focus • $_graphTimeframe',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSlate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${categoryData.length} groups',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (categoryData.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No categories logged in this timeframe',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          else ...[
            ...categoryData.map((cat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cat.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cat.category,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textWhite,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${cat.volume.toInt()} kg',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: cat.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${cat.percentage.toStringAsFixed(0)}%)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSlate,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            color: AppColors.surfaceLow,
                          ),
                          FractionallySizedBox(
                            widthFactor: (cat.percentage / 100).clamp(
                              0.04,
                              1.0,
                            ),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: cat.color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${cat.sessionCount} sessions logged',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          _formatTime(cat.durationSeconds),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textSlate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Set splits: per-session segmented bars, each set
                    // sized by its time-under-tension with the duration
                    // written on it.
                    ..._buildSessionSetSplits(cat),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Formats the set weight as a singular value (e.g. "30kg"). Weight is
  /// shown exactly as logged and is NOT multiplied against reps. A 0 kg
  /// (bodyweight) set omits the weight part.
  String _formatSetWeight(double weight) {
    if (weight <= 0) return 'BW';
    final w = weight == weight.roundToDouble()
        ? weight.round().toString()
        : weight.toStringAsFixed(1);
    return '${w}kg';
  }

  /// Builds the per-session set-split visualization for a category:
  /// each logged session gets one row where every set is a segment sized
  /// proportionally to its duration, with the set number and time duration
  /// written on the segment (e.g. "S2 · 45s").
  List<Widget> _buildSessionSetSplits(_CategoryDataPoint cat) {
    if (cat.sessions.isEmpty) return const [];

    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Text(
          'SET SPLITS • WEIGHT, REPS & TIME PER SET',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.textMuted,
          ),
        ),
      ),
    ];

    for (final session in cat.sessions) {
      if (session.sets.isEmpty) continue;
      final totalSetSeconds = session.sets.fold<int>(
        0,
        (sum, s) => sum + (s.durationSeconds > 0 ? s.durationSeconds : 0),
      );

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${session.exerciseName} • '
                '${session.timestamp.day}/${session.timestamp.month}/${session.timestamp.year}',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  height: 20,
                  child: Row(
                    children: session.sets.map((set) {
                      final seconds = set.durationSeconds > 0
                          ? set.durationSeconds
                          : 0;
                      final flex = totalSetSeconds > 0 && seconds > 0
                          ? seconds
                          : 1;
                      return Expanded(
                        flex: flex,
                        child: Container(
                          decoration: BoxDecoration(
                            color: cat.color.withValues(
                              alpha: 0.25 + 0.15 * (set.setNumber % 3),
                            ),
                            border: Border(
                              right: BorderSide(
                                color: AppColors.surface,
                                width: 1.5,
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Text(
                                'S${set.setNumber} ${_formatSetWeight(set.weight)} '
                                'Rep-${set.reps}'
                                '${seconds > 0 ? ' time:${seconds}s' : ''}',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: cat.color,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  // ── Aggregation & Filtering Helpers ─────────────────────────────────────
  List<WorkoutSessionLog> _filterLogsByTimeframe(
    List<WorkoutSessionLog> logs,
    String timeframe,
  ) {
    final now = DateTime.now();

    if (timeframe == 'Daily') {
      // Last 7 days
      final cutoff = now.subtract(const Duration(days: 7));
      return logs.where((l) => l.timestamp.isAfter(cutoff)).toList();
    } else if (timeframe == 'Weekly') {
      // Last 4 weeks (28 days)
      final cutoff = now.subtract(const Duration(days: 28));
      return logs.where((l) => l.timestamp.isAfter(cutoff)).toList();
    } else {
      // Monthly: Last 6 months (180 days)
      final cutoff = now.subtract(const Duration(days: 180));
      return logs.where((l) => l.timestamp.isAfter(cutoff)).toList();
    }
  }

  List<_GraphDataPoint> _aggregateOverallData(
    List<WorkoutSessionLog> logs,
    String timeframe,
  ) {
    final now = DateTime.now();

    if (timeframe == 'Daily') {
      // Show each of the last 7 days
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final List<_GraphDataPoint> points = [];

      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final dayLabel = days[targetDate.weekday - 1];

        final matchingLogs = logs.where((l) {
          return l.timestamp.year == targetDate.year &&
              l.timestamp.month == targetDate.month &&
              l.timestamp.day == targetDate.day;
        });

        final dayVolume = matchingLogs.fold(
          0.0,
          (sum, l) => sum + l.totalVolume,
        );

        points.add(
          _GraphDataPoint(label: i == 0 ? 'Today' : dayLabel, value: dayVolume),
        );
      }
      return points;
    } else if (timeframe == 'Weekly') {
      // Show last 4 weeks (W1 to W4)
      final List<_GraphDataPoint> points = [];

      for (int w = 3; w >= 0; w--) {
        final start = now.subtract(Duration(days: (w + 1) * 7));
        final end = now.subtract(Duration(days: w * 7));

        final matchingLogs = logs.where((l) {
          return l.timestamp.isAfter(start) &&
              l.timestamp.isBefore(end.add(const Duration(days: 1)));
        });

        final weekVolume = matchingLogs.fold(
          0.0,
          (sum, l) => sum + l.totalVolume,
        );

        points.add(
          _GraphDataPoint(
            label: w == 0 ? 'This Wk' : 'Wk -$w',
            value: weekVolume,
          ),
        );
      }
      return points;
    } else {
      // Monthly: Show last 6 months
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final List<_GraphDataPoint> points = [];

      for (int m = 5; m >= 0; m--) {
        final monthDate = DateTime(now.year, now.month - m, 1);
        final label = monthNames[monthDate.month - 1];

        final matchingLogs = logs.where((l) {
          return l.timestamp.year == monthDate.year &&
              l.timestamp.month == monthDate.month;
        });

        final monthVolume = matchingLogs.fold(
          0.0,
          (sum, l) => sum + l.totalVolume,
        );

        points.add(_GraphDataPoint(label: label, value: monthVolume));
      }
      return points;
    }
  }

  List<_CategoryDataPoint> _aggregateCategoryData(
    List<WorkoutSessionLog> logs,
    String timeframe,
  ) {
    final filtered = _filterLogsByTimeframe(logs, timeframe);

    if (filtered.isEmpty) {
      return [];
    }

    final Map<String, double> categoryVolume = {};
    final Map<String, int> categorySessions = {};
    final Map<String, int> categoryDuration = {};
    final Map<String, List<WorkoutSessionLog>> categoryLogs = {};

    for (final log in filtered) {
      final cat = log.category.isNotEmpty ? log.category : 'General';
      categoryVolume[cat] = (categoryVolume[cat] ?? 0.0) + log.totalVolume;
      categorySessions[cat] = (categorySessions[cat] ?? 0) + 1;
      categoryDuration[cat] =
          (categoryDuration[cat] ?? 0) + log.totalDurationSeconds;
      categoryLogs.putIfAbsent(cat, () => []).add(log);
    }

    final totalVol = categoryVolume.values.fold(0.0, (a, b) => a + b);
    final colors = [
      AppColors.primaryOrange,
      AppColors.emerald,
      AppColors.amber,
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
    ];

    int colorIndex = 0;
    return categoryVolume.entries.map((e) {
      final percentage = totalVol > 0 ? (e.value / totalVol) * 100 : 0.0;
      final color = colors[colorIndex % colors.length];
      colorIndex++;

      return _CategoryDataPoint(
        category: e.key,
        volume: e.value,
        percentage: percentage,
        sessionCount: categorySessions[e.key] ?? 0,
        durationSeconds: categoryDuration[e.key] ?? 0,
        sessions: categoryLogs[e.key] ?? const [],
        color: color,
      );
    }).toList();
  }
}

/// Painter for the pie-chart visualization of overall progress.
class _PieChartPainter extends CustomPainter {
  final List<({String label, double value, double fraction, Color color})>
  slices;
  const _PieChartPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    // Donut hole
    final holeRadius = radius * 0.45;
    final holePaint = Paint()..color = AppColors.cardSurface;

    double startAngle = -90 * 3.14159 / 180; // start at 12 o'clock
    for (final slice in slices) {
      final sweep = slice.fraction * 2 * 3.14159;
      final paint = Paint()..color = slice.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }

    canvas.drawCircle(center, holeRadius, holePaint);

    // Center total label
    final totalKg = slices.fold(0.0, (a, b) => a + b.value);
    final textPainter = TextPainter(
      text: TextSpan(
        text: totalKg >= 1000
            ? '${(totalKg / 1000).toStringAsFixed(1)}t'
            : '${totalKg.round()}kg',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter old) =>
      old.slices.length != slices.length;
}

class _GraphDataPoint {
  final String label;
  final double value;
  const _GraphDataPoint({required this.label, required this.value});
}

/// Painter for the line-chart visualization of overall progress.
class _LineChartPainter extends CustomPainter {
  final List<double> values; // normalized 0..1
  const _LineChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dx = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      points.add(
        Offset(
          values.length == 1 ? size.width / 2 : dx * i,
          size.height * 0.92 - values[i] * size.height * 0.82,
        ),
      );
    }

    // Grid lines
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) {
      final y = size.height * 0.92 - g * size.height * 0.205;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = AppColors.primaryOrange;
    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = AppColors.cardSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => _changed(old.values);

  bool _changed(List<double> oldValues) {
    if (oldValues.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (oldValues[i] != values[i]) return true;
    }
    return false;
  }
}

/// Painter for the area-chart visualization of overall progress.
class _AreaChartPainter extends CustomPainter {
  final List<double> values; // normalized 0..1
  const _AreaChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final dx = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      points.add(
        Offset(
          values.length == 1 ? size.width / 2 : dx * i,
          size.height * 0.92 - values[i] * size.height * 0.82,
        ),
      );
    }

    // Grid lines
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (int g = 0; g <= 4; g++) {
      final y = size.height * 0.92 - g * size.height * 0.205;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final areaPath = Path()..moveTo(points.first.dx, size.height * 0.92);
    for (final p in points) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(points.last.dx, size.height * 0.92);
    areaPath.close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryOrange.withValues(alpha: 0.55),
            AppColors.primaryOrange.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.primaryOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    final dotPaint = Paint()..color = AppColors.primaryOrange;
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) {
    if (old.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (old.values[i] != values[i]) return true;
    }
    return false;
  }
}

class _CategoryDataPoint {
  final String category;
  final double volume;
  final double percentage;
  final int sessionCount;
  final int durationSeconds;
  final List<WorkoutSessionLog> sessions;
  final Color color;

  const _CategoryDataPoint({
    required this.category,
    required this.volume,
    required this.percentage,
    required this.sessionCount,
    required this.durationSeconds,
    required this.sessions,
    required this.color,
  });
}
