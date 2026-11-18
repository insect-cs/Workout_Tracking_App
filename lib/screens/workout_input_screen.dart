import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_hero_tags.dart';
import '../state/workout_state.dart';

class WorkoutInputScreen extends StatefulWidget {
  final WorkoutState state;
  final String? initialExercise;
  final VoidCallback onBackToHome;
  final VoidCallback onGenerated;

  const WorkoutInputScreen({
    super.key,
    required this.state,
    this.initialExercise,
    required this.onBackToHome,
    required this.onGenerated,
  });

  @override
  State<WorkoutInputScreen> createState() => _WorkoutInputScreenState();
}

class _WorkoutInputScreenState extends State<WorkoutInputScreen> {
  late TextEditingController _nameController;
  final Set<String> _selectedMuscles = {'Chest', 'Shoulders'};
  String _selectedDuration = '45 min';
  String _selectedDifficulty = 'Intermediate';
  String _selectedEquipment = 'Full Gym';

  final List<String> _suggestedNames = [
    "Explosive Push & Delts",
    "Torque & Heavy Back Pull",
    "Posterior Chain Hypertrophy",
    "Upper Kinetic Annihilation",
    "Quad & Glute Power Drive",
    "Savage Shoulder Boulder Blitz",
    "Full Body Core & Conditioning",
  ];
  int _nameIdx = 0;

  @override
  void initState() {
    super.initState();
    final initName = widget.initialExercise != null
        ? "${widget.initialExercise} Focused Routine"
        : "Explosive Push & Delts";
    _nameController = TextEditingController(text: initName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _shuffleName() {
    setState(() {
      _nameIdx = (_nameIdx + 1) % _suggestedNames.length;
      _nameController.text = _suggestedNames[_nameIdx];
    });
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
                // Header
                _buildHeader(context),

                // Main Form Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: [
                      // Section 1: Workout Routine Name
                      _buildNameSection(),
                      const SizedBox(height: 20),

                      // Section 2: Target Focus
                      _buildMuscleFocusSection(),
                      const SizedBox(height: 20),

                      // Section 3: Duration
                      _buildDurationSection(),
                      const SizedBox(height: 20),

                      // Section 4: Difficulty
                      _buildDifficultySection(),
                      const SizedBox(height: 20),

                      // Section 5: Equipment
                      _buildEquipmentSection(),
                      const SizedBox(height: 24),

                      // Section 6: Generate CTA
                      _buildGenerateCTA(),
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

  Widget _buildHeader(BuildContext context) {
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
                    width: 38,
                    height: 38,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Workout',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      Text(
                        'AI Routine Builder',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSlate,
                        ),
                      ),
                      if (widget.initialExercise != null) ...[
                        const SizedBox(height: 4),
                        Hero(
                          tag: AppHeroTags.exercise(widget.initialExercise!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orangeSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.initialExercise!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                  Hero(
                    tag: AppHeroTags.aiGenerator,
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primaryOrange,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'AI GENERATOR',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                        letterSpacing: 0.8,
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

  Widget _buildNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'WORKOUT NAME',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  ' *',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: _shuffleName,
              child: Row(
                children: [
                  const Icon(
                    Icons.casino_outlined,
                    color: AppColors.primaryOrange,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Suggest Name',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: _nameController,
            style: GoogleFonts.inter(
              color: AppColors.textWhite,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'e.g., Explosive Push & Delts',
              hintStyle: GoogleFonts.inter(
                color: AppColors.textSlate.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Type custom routine name or tap suggest to roll instant workout archetypes.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
        ),
      ],
    );
  }

  Widget _buildMuscleFocusSection() {
    final allMuscles = [
      'Chest',
      'Shoulders',
      'Triceps',
      'Back',
      'Legs',
      'Core',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'TARGET FOCUS (MULTI-SELECT)',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.textWhite,
                ),
              ),
            ),
            Flexible(
              child: Text(
                '${_selectedMuscles.length} Selected',
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
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allMuscles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.7,
          ),
          itemBuilder: (context, index) {
            final muscle = allMuscles[index];
            final isSelected = _selectedMuscles.contains(muscle);
            return FilterChip(
              label: Text(
                muscle,
                style: GoogleFonts.spaceGrotesk(fontSize: 11),
              ),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) {
                setState(() {
                  if (isSelected) {
                    if (_selectedMuscles.length > 1) {
                      _selectedMuscles.remove(muscle);
                    }
                  } else {
                    _selectedMuscles.add(muscle);
                  }
                });
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDurationSection() {
    final durations = ['30 min', '45 min', '60 min', '75 min'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TARGET DURATION',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textWhite,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            for (final d in durations)
              ButtonSegment<String>(
                value: d,
                label: Text(d.replaceAll(' min', 'm')),
              ),
          ],
          selected: {_selectedDuration},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              setState(() => _selectedDuration = selection.first);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDifficultySection() {
    final diffs = [
      {'name': 'Beginner', 'rpe': 'RPE 6-7'},
      {'name': 'Intermediate', 'rpe': 'RPE 8-8.5'},
      {'name': 'Advanced', 'rpe': 'RPE 9-10'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIFFICULTY LEVEL',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textWhite,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: diffs.map((diff) {
            final name = diff['name']!;
            final rpe = diff['rpe']!;
            final isSelected = name == _selectedDifficulty;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDifficulty = name;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.orangeSoft
                          : AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryOrange
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.primaryOrange
                                : AppColors.textSlate,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rpe,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isSelected
                                ? AppColors.primaryOrange.withValues(alpha: 0.8)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEquipmentSection() {
    final eqOptions = [
      {
        'id': 'Full Gym',
        'title': 'Full Commercial Gym',
        'desc': 'Barbells, Dumbbells, Cables, Machines',
        'icon': Icons.fitness_center,
      },
      {
        'id': 'Dumbbells & Bench',
        'title': 'Dumbbells & Bench Only',
        'desc': 'Home or hotel gym friendly setup',
        'icon': Icons.sports_gymnastics,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EQUIPMENT AVAILABLE',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textWhite,
          ),
        ),
        const SizedBox(height: 8),
        ...eqOptions.map((eq) {
          final isSelected = eq['id'] == _selectedEquipment;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedEquipment = eq['id'] as String;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.orangeSoft
                            : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        eq['icon'] as IconData,
                        color: isSelected
                            ? AppColors.primaryOrange
                            : AppColors.textSlate,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eq['title'] as String,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textWhite,
                            ),
                          ),
                          Text(
                            eq['desc'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSlate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.primaryOrange
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryOrange
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 12,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGenerateCTA() {
    final isLoading = widget.state.isGenerating;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: isLoading
                ? null
                : () async {
                    final name = _nameController.text.trim().isEmpty
                        ? 'Explosive Push & Delts'
                        : _nameController.text.trim();

                    final success = await widget.state.generateWorkoutFromAI(
                      name: name,
                      muscles: _selectedMuscles.toList(),
                      duration: _selectedDuration,
                      difficulty: _selectedDifficulty,
                      equipment: _selectedEquipment,
                    );

                    if (success && mounted) {
                      widget.onGenerated();
                    }
                  },
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AI is generating…',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Generate Workout',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ),

        // Error banner
        if (widget.state.generationError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFF4D4D).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF6B6B),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.state.generationError!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFFF6B6B),
                      height: 1.4,
                    ),
                  ),
                ),
                InkWell(
                  onTap: widget.state.clearError,
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFFFF6B6B),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
        Text(
          isLoading
              ? 'Gemini AI is building your personalised plan…'
              : 'AI-powered by Gemini · Proceeds to Step-by-Step Instructions.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
