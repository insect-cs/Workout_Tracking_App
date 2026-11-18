import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_hero_tags.dart';
import '../state/workout_state.dart';
import '../models/workout_models.dart';

class SavedWorkoutsScreen extends StatefulWidget {
  final WorkoutState state;
  final VoidCallback onBackToHome;
  final VoidCallback onNavigateToInput;
  final Function(WorkoutModel) onViewWorkout;

  const SavedWorkoutsScreen({
    super.key,
    required this.state,
    required this.onBackToHome,
    required this.onNavigateToInput,
    required this.onViewWorkout,
  });

  @override
  State<SavedWorkoutsScreen> createState() => _SavedWorkoutsScreenState();
}

class _SavedWorkoutsScreenState extends State<SavedWorkoutsScreen> {
  String _activeFilter = 'All';

  final List<String> _filters = [
    'All',
    'Upper Body',
    'Lower Body',
    'Full Body',
  ];

  @override
  Widget build(BuildContext context) {
    final workouts = widget.state.savedWorkouts;

    final filtered = workouts.where((w) {
      if (_activeFilter == 'All') return true;
      final focus = w.focus.toLowerCase();
      if (_activeFilter == 'Upper Body') {
        return focus.contains('chest') ||
            focus.contains('back') ||
            focus.contains('shoulder') ||
            focus.contains('arm');
      }
      if (_activeFilter == 'Lower Body') {
        return focus.contains('leg') ||
            focus.contains('quad') ||
            focus.contains('glute');
      }
      if (_activeFilter == 'Full Body') {
        return focus.contains('full') || focus.contains('core');
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                // Header
                _buildHeader(context, workouts.length),

                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: [
                      // Quick Filter Tabs
                      _buildFilterChips(),
                      const SizedBox(height: 16),

                      // Grid or Empty State
                      if (filtered.isEmpty)
                        _buildEmptyState()
                      else
                        _buildWorkoutsGrid(filtered),

                      const SizedBox(height: 20),

                      // AI Generator Callout Banner
                      _buildAICalloutBanner(),
                      const SizedBox(height: 32),
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

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textLight,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Saved Workouts',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '$count Saved',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Plus Action Button
          InkWell(
            onTap: widget.onNavigateToInput,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == _activeFilter;

          return FilterChip(
            label: Text(
              filter.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(fontSize: 11, letterSpacing: 0.6),
            ),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => setState(() => _activeFilter = filter),
          );
        },
      ),
    );
  }

  Widget _buildWorkoutsGrid(List<WorkoutModel> list) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.76,
      ),
      itemBuilder: (context, index) {
        final w = list[index];
        return _buildWorkoutGridCard(w);
      },
    );
  }

  Widget _buildWorkoutGridCard(WorkoutModel w) {
    return InkWell(
      onTap: () => widget.onViewWorkout(w),
      borderRadius: BorderRadius.circular(20),
      child: Hero(
        tag: AppHeroTags.workout(w.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: date and delete
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        w.date.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSlate,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          widget.state.deleteWorkout(w.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.surfaceLow,
                              content: Text(
                                'Removed ${w.name}',
                                style: GoogleFonts.inter(
                                  color: AppColors.textWhite,
                                ),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    w.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      w.focus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom metrics & launch button
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x3320293A))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'TIME',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 8,
                                    color: AppColors.textSlate,
                                  ),
                                ),
                                Text(
                                  w.duration,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'EX',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 8,
                                    color: AppColors.textSlate,
                                  ),
                                ),
                                Text(
                                  '${w.exercises.length}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: FilledButton.tonal(
                      onPressed: () => widget.onViewWorkout(w),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('View'),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.bookmark_border,
              color: AppColors.primaryOrange,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Saved Workouts',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generate customized workouts with step-by-step instructions and save them here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlate),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.onNavigateToInput,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Generate Routine'),
          ),
        ],
      ),
    );
  }

  Widget _buildAICalloutBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surfaceLow, Color(0xFF1D1F27)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Hero(
                      tag: AppHeroTags.aiGenerator,
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primaryOrange,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'DYNAMIC AI',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Need a fresh routine?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  'Generate custom sets & rest times',
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
          FilledButton(
            onPressed: widget.onNavigateToInput,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              minimumSize: const Size(0, 40),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Create'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
