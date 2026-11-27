import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/video_launcher_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_hero_tags.dart';
import '../state/workout_state.dart';
import '../models/workout_models.dart';
import '../services/youtube_service.dart';

class WorkoutResultScreen extends StatefulWidget {
  final WorkoutState state;
  final VoidCallback onBackToInput;
  final VoidCallback onSaved;
  final VoidCallback onGoHome;
  final Function(String exerciseName)? onLogExercise;

  const WorkoutResultScreen({
    super.key,
    required this.state,
    required this.onBackToInput,
    required this.onSaved,
    required this.onGoHome,
    this.onLogExercise,
  });

  @override
  State<WorkoutResultScreen> createState() => _WorkoutResultScreenState();
}

class _WorkoutResultScreenState extends State<WorkoutResultScreen> {
  // Track checked sets: key = "exerciseName-setIndex"
  final Set<String> _checkedSets = {};

  @override
  Widget build(BuildContext context) {
    final workout = widget.state.currentWorkout;
    final isGenerating = widget.state.isGenerating;
    final error = widget.state.generationError;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Stack(
              children: [
                Column(
                  children: [
                    // Header
                    _buildHeader(context),

                    // Content
                    Expanded(
                      child: error != null
                          ? _buildErrorState(error)
                          : ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              children: [
                                // Routine Summary Hero Card
                                _buildHeroCard(workout),
                                const SizedBox(height: 18),

                                // Section Title
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Step-by-Step Instructions',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textWhite,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Tap sets to log progress',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textSlate,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // List of Exercise Step Cards
                                ...workout.exercises.asMap().entries.map((
                                  entry,
                                ) {
                                  return _buildStepCard(entry.key, entry.value);
                                }),

                                const SizedBox(height: 20),

                                // Save Workout Action
                                _buildActionButtons(workout),
                                const SizedBox(height: 32),
                              ],
                            ),
                    ),
                  ],
                ),

                // Loading overlay while Gemini generates
                if (isGenerating) _buildLoadingOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Full-screen loading overlay shown while Gemini API is running.
  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.background.withValues(alpha: 0.88),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.orangeBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryOrange,
                  ),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Gemini AI is crafting\nyour workout plan…',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Analysing muscles, duration & difficulty\nto build an optimal routine for you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSlate,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryOrange,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Powered by Gemini AI',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Error state shown when Gemini API call fails.
  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF2A1A1A),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF4D4D).withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.error_outline,
              color: Color(0xFFFF6B6B),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Generation Failed',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFFFF6B6B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                widget.state.clearError();
                widget.onBackToInput();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.autorenew, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Try Again',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              widget.state.clearError();
              widget.onGoHome();
            },
            child: Text(
              'Back to Home',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: AppColors.textSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: Color(0x3320293A))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                InkWell(
                  onTap: widget.onBackToInput,
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
                        'Workout Result',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      Text(
                        'Screen 3 • Instructions & Volume',
                        maxLines: 1,
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.orangeBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryOrange,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'AI GENERATED',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(WorkoutModel workout) {
    return Hero(
      tag: AppHeroTags.workout(workout.id),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.cardInset, AppColors.cardSurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'GENERATED ROUTINE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.emerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Optimized',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              workout.name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Targeted routine calibrated for maximum muscular recruitment and explosive progression.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlate,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            // Badges row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildMetricBadge(
                  Icons.fitness_center,
                  '${workout.exercises.length} Exercises',
                ),
                _buildMetricBadge(Icons.schedule, workout.duration),
                _buildMetricBadge(
                  null,
                  workout.focus,
                  textColor: AppColors.primaryOrange,
                ),
                _buildMetricBadge(null, workout.difficulty),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBadge(IconData? icon, String text, {Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primaryOrange, size: 13),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor ?? AppColors.textWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int index, ExerciseModel ex) {
    final stepNum = (index + 1).toString().padLeft(2, '0');
    final setCount = int.tryParse(ex.sets.split(' ').first) ?? 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        stepNum,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textWhite,
                            ),
                          ),
                          Text(
                            '${ex.sets} • ${ex.reps}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_top,
                      color: AppColors.primaryOrange,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${ex.rest} Rest',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Form Instruction Cues
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x3320293A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ex.cues.map((cue) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5, right: 6),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          cue,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textLight,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Interactive Set Chips
          Row(
            children: List.generate(setCount, (sIndex) {
              final setKey = "${ex.name}-$sIndex";
              final isChecked = _checkedSets.contains(setKey);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FilterChip(
                    label: Text(
                      'SET ${sIndex + 1}',
                      style: GoogleFonts.spaceGrotesk(fontSize: 10),
                    ),
                    selected: isChecked,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        if (isChecked) {
                          _checkedSets.remove(setKey);
                        } else {
                          _checkedSets.add(setKey);
                        }
                      });
                    },
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Play Video Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: () => _openExerciseVideo(ex),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF0000),
                side: BorderSide(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: const Color(0x1AFF0000),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    size: 18,
                    color: Color(0xFFFF0000),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Play Video',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF0000),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new,
                    size: 12,
                    color: const Color(0xFFFF0000).withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
          if (widget.onLogExercise != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: Hero(
                tag: AppHeroTags.logExercise(ex.name),
                child: FilledButton.tonal(
                  onPressed: () => widget.onLogExercise!(ex.name),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Log Sets & Start Timers'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Opens the exact video demonstration for the given exercise.
  Future<void> _openExerciseVideo(ExerciseModel ex) async {
    String? targetUrl = ex.videoUrl;

    // If no exact video URL was pre-attached or if it was a general search query, resolve exact video
    if (targetUrl == null ||
        targetUrl.isEmpty ||
        targetUrl.contains('search_query')) {
      targetUrl = await YouTubeService.getExactVideoUrl(ex.name);
    }

    final opened = await VideoLaunchService.open(
      targetUrl,
      searchQuery: ex.name,
    );
    if (opened || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.cardSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFF4D4D)),
        ),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 18),
            const SizedBox(width: 10),
            Text(
              'Could not open video player.',
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

  Widget _buildActionButtons(WorkoutModel workout) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              widget.state.saveWorkout(workout);
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
                      Icon(
                        Icons.check_circle,
                        color: AppColors.primaryOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Workout saved to library!',
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

              Future.delayed(const Duration(milliseconds: 400), () {
                widget.onSaved();
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bookmark, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Save Workout',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: widget.onGoHome,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textLight,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.home, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Back to Home',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: widget.onBackToInput,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textLight,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.autorenew, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Regenerate',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
