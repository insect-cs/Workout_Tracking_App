import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/plan_models.dart';
import '../models/workout_models.dart';
import '../services/local_store.dart';
import '../services/plan_history_service.dart';
import '../services/plan_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_colors.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/app_dialog.dart';

/// Extracts the 11-character video id from a YouTube watch/embed/shorts URL.
/// Returns null for search URLs or anything that is not a direct video link.
String? youtubeVideoIdFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  if (host == 'youtu.be') {
    final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return id.length == 11 ? id : null;
  }
  if (!host.contains('youtube.com')) return null;

  final queryId = uri.queryParameters['v'];
  if (queryId != null && queryId.length == 11) return queryId;

  final segments = uri.pathSegments;
  if (segments.length >= 2 &&
      (segments.first == 'embed' || segments.first == 'shorts') &&
      segments[1].length == 11) {
    return segments[1];
  }
  return null;
}

/// State for one of the two Plan forms (Weekly / Single day). Keeping the two
/// instances separate means switching tabs never loses the user's selections.
class _PlanFormData {
  _PlanFormData({required this.isWeekly}) : daysPerWeek = isWeekly ? 3 : 1;

  final bool isWeekly;
  final TextEditingController customCombinationController =
      TextEditingController();

  String goal = 'Fat loss';
  String experienceLevel = 'Beginner';
  String equipment = 'Full commercial gym';
  int daysPerWeek;
  int singleDayIndex = 1; // Single-day Schedule defaults to Day 1.
  String combination = 'Chest+Tricep';
  final Set<String> exerciseTypes = {'Full Body'};

  void dispose() => customCombinationController.dispose();

  /// Individual groups in the custom "A+B+Nth" string.
  List<String> get customParts => customCombinationController.text
      .split('+')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  String get effectiveCombination =>
      combination == 'Custom' ? customParts.join('+') : combination;

  PlanDetails toDetails() => PlanDetails(
    goal: goal,
    experienceLevel: experienceLevel,
    equipment: equipment,
    daysPerWeek: isWeekly ? daysPerWeek : 1,
    exerciseTypes: exerciseTypes.toList(),
    exerciseCombination: effectiveCombination,
    dayLabel: isWeekly ? null : 'Day $singleDayIndex',
  );

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'experienceLevel': experienceLevel,
    'equipment': equipment,
    'daysPerWeek': daysPerWeek,
    'singleDayIndex': singleDayIndex,
    'combination': combination,
    'customCombination': customCombinationController.text,
    'exerciseTypes': exerciseTypes.toList(),
  };

  void applyJson(Map<String, dynamic> json) {
    goal = (json['goal'] as String?) ?? goal;
    experienceLevel = (json['experienceLevel'] as String?) ?? experienceLevel;
    equipment = (json['equipment'] as String?) ?? equipment;
    daysPerWeek = (json['daysPerWeek'] as num?)?.toInt() ?? daysPerWeek;
    singleDayIndex =
        (json['singleDayIndex'] as num?)?.toInt() ?? singleDayIndex;
    combination = (json['combination'] as String?) ?? combination;
    customCombinationController.text =
        (json['customCombination'] as String?) ?? '';
    final types = json['exerciseTypes'] as List<dynamic>?;
    if (types != null) {
      exerciseTypes
        ..clear()
        ..addAll(types.map((value) => value.toString()));
    }
  }
}

/// The Plan section: collect training preferences, then generate a weekly or
/// single-day plan with Gemini. The bottom CTA is gated on the configured
/// Gemini API key; without one an explicit error is shown and nothing is sent.
class PlanScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PlanScreen({super.key, this.onBack});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen>
    with SingleTickerProviderStateMixin {
  static const String _formsKey = 'workout_app.plan_forms.v1';
  static const String _planKey = 'workout_app.plan_result.v1';
  static const String _tabKey = 'workout_app.plan_tab.v1';

  late final TabController _tabController;

  final _PlanFormData _weeklyForm = _PlanFormData(isWeekly: true);
  final _PlanFormData _singleForm = _PlanFormData(isWeekly: false);

  bool _isGenerating = false;
  String? _error;
  GeneratedPlan? _generatedPlan;
  List<SavedPlanEntry> _history = const <SavedPlanEntry>[];
  int _formTabIndex = 0;
  int _lastTabIndex = 0;

  static const List<String> _goals = [
    'Fat loss',
    'Weight gain',
    'Muscle building',
    'Raw strength',
    'General endurance',
  ];
  static const List<String> _levels = ['Beginner', 'Intermediate', 'Advanced'];
  static const List<String> _equipment = [
    'Bodyweight only',
    'Dumbbells',
    'Resistance bands',
    'Full commercial gym',
  ];
  static const List<String> _exerciseTypes = [
    'Full Body',
    'Push',
    'Pull',
    'Legs',
    'Upper',
    'Lower',
    'Rest/Light Cardio',
  ];
  static const List<String> _combinations = [
    'Chest+Tricep',
    'Back+Bicep',
    'Legs+Shoulder',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();

    final forms = LocalStore.instance.readMap(_formsKey);
    final weekly = forms?['weekly'] as Map<String, dynamic>?;
    final single = forms?['single'] as Map<String, dynamic>?;
    if (weekly != null) _weeklyForm.applyJson(weekly);
    if (single != null) _singleForm.applyJson(single);

    final savedPlan = LocalStore.instance.readMap(_planKey);
    if (savedPlan != null) _generatedPlan = GeneratedPlan.fromJson(savedPlan);

    _history = PlanHistoryStore.read();

    final savedTab = LocalStore.instance.readInt(_tabKey) ?? 0;
    final initialTab = savedTab >= 0 && savedTab <= 2 ? savedTab : 0;
    _formTabIndex = initialTab == 1 ? 1 : 0;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab,
    );
    _lastTabIndex = _tabController.index;
    _tabController.addListener(() {
      if (_tabController.index != _lastTabIndex) {
        _lastTabIndex = _tabController.index;
        // History is not a form: keep the last selected generator tab so the
        // CTA label and scope do not change when the user visits History.
        if (_lastTabIndex != 2) _formTabIndex = _lastTabIndex;
        unawaited(LocalStore.instance.write(_tabKey, _lastTabIndex));
        if (mounted) setState(() {});
      }
    });
  }

  void _persistForms() {
    unawaited(
      LocalStore.instance.write(_formsKey, {
        'weekly': _weeklyForm.toJson(),
        'single': _singleForm.toJson(),
      }),
    );
  }

  void _persistPlan() {
    unawaited(LocalStore.instance.write(_planKey, _generatedPlan?.toJson()));
  }

  void _clearPlan() {
    setState(() => _generatedPlan = null);
    _persistPlan();
  }

  bool get _isCurrentPlanSaved =>
      _generatedPlan != null &&
      _history.any((entry) => entry.plan.id == _generatedPlan!.id);

  Future<void> _savePlanToHistory() async {
    final plan = _generatedPlan;
    if (plan == null || _isCurrentPlanSaved) return;

    final entry = await PlanHistoryStore.save(plan);
    if (!mounted) return;

    setState(() {
      _history = <SavedPlanEntry>[
        entry,
        ..._history.where((existing) => existing.id != entry.id),
      ];
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
              'Plan saved to History',
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

  void _openHistoryFromResult() {
    _clearPlan();
    _tabController.animateTo(2);
  }

  void _openSavedPlan(SavedPlanEntry entry) {
    setState(() => _generatedPlan = entry.plan);
    _persistPlan();
  }

  Future<void> _confirmDeleteSavedPlan(SavedPlanEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(
          'Delete saved plan?',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        content: Text(
          '“${entry.plan.title}” will be removed from Plan History.',
          style: GoogleFonts.inter(color: AppColors.textSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await PlanHistoryStore.remove(entry.id);
    if (!mounted) return;
    setState(() {
      _history = _history.where((saved) => saved.id != entry.id).toList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _weeklyForm.dispose();
    _singleForm.dispose();
    super.dispose();
  }

  bool get _isWeekly => _formTabIndex == 0;

  bool get _isHistoryTab => !_hasResult && _tabController.index == 2;

  bool get _hasResult => _generatedPlan != null;

  _PlanFormData get _activeForm => _isWeekly ? _weeklyForm : _singleForm;

  String get _generateLabel =>
      _isWeekly ? 'Generate Plan for a week' : 'Generate Plan for a single day';

  Future<void> _generate() async {
    if (_isGenerating) return;

    // Ask for a validated key the first time an AI action is used (or after
    // the user removes the active key in the Keys page).
    if (!await ensureAiAccess(context)) return;
    if (!mounted) return;

    final form = _activeForm;
    final scope = _isWeekly ? PlanScope.week : PlanScope.day;
    final details = form.toDetails();

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final plan = await PlanService.generatePlan(
        details: details,
        scope: scope,
      );
      if (!mounted) return;
      setState(() {
        _generatedPlan = plan;
        _isGenerating = false;
      });
      _persistPlan();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _error = e.toString();
      });
    }
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
                if (!_hasResult) _buildTabBar(),
                Expanded(
                  child: _hasResult
                      ? _buildResultView(_generatedPlan!)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPlanForm(_weeklyForm),
                            _buildPlanForm(_singleForm),
                            _buildHistoryView(),
                          ],
                        ),
                ),
                if (!_hasResult && !_isHistoryTab) _buildBottomBar(),
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
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            InkWell(
              onTap: widget.onBack,
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
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLAN',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  'AI Training Planner',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.orangeBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month,
                  color: AppColors.primaryOrange,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'PLAN BUILDER',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Weekly'),
          Tab(text: 'Single day'),
          Tab(icon: Icon(Icons.history, size: 18), text: 'History'),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    if (_history.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.orangeSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.history_toggle_off,
                    color: AppColors.primaryOrange,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No saved plans yet',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a weekly or single-day plan, then tap '
                  '“Save to History” at the end of the result.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSlate,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            Icon(Icons.history, color: AppColors.primaryOrange, size: 18),
            const SizedBox(width: 8),
            Text(
              'SAVED PLANS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppColors.textWhite,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.orangeBorder),
              ),
              child: Text(
                '${_history.length}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in _history) _buildHistoryCard(entry),
      ],
    );
  }

  Widget _buildHistoryCard(SavedPlanEntry entry) {
    final plan = entry.plan;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  plan.isWeekly ? Icons.calendar_month : Icons.calendar_today,
                  color: AppColors.primaryOrange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan.isWeekly ? 'Weekly plan' : 'Single-day plan',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _confirmDeleteSavedPlan(entry),
                tooltip: 'Delete saved plan',
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.rose,
                  size: 20,
                ),
              ),
            ],
          ),
          if (plan.overview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              plan.overview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlate,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Saved ${_formatSavedAt(entry.savedAt)}',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSlate),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openSavedPlan(entry),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open saved plan'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSavedAt(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Widget _buildPlanForm(_PlanFormData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _buildIntroCard(),
        const SizedBox(height: 18),
        _buildGoalSection(data),
        const SizedBox(height: 18),
        _buildExperienceSection(data),
        const SizedBox(height: 18),
        _buildEquipmentSection(data),
        const SizedBox(height: 18),
        _buildScheduleSection(data),
        const SizedBox(height: 18),
        _buildExerciseTypesSection(data),
        const SizedBox(height: 18),
        _buildCombinationSection(data),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.primaryOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tell us how you train and Gemini will build a ${_isWeekly ? 'full week' : 'single day'} plan tailored to you.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSlate,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppColors.textWhite,
      ),
    );
  }

  Widget _buildGoalSection(_PlanFormData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PRIMARY GOAL'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final goal in _goals)
              ChoiceChip(
                label: Text(goal),
                selected: data.goal == goal,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => data.goal = goal);
                  _persistForms();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildExperienceSection(_PlanFormData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('EXPERIENCE LEVEL'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            for (final level in _levels)
              ButtonSegment<String>(value: level, label: Text(level)),
          ],
          selected: {data.experienceLevel},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              setState(() => data.experienceLevel = selection.first);
              _persistForms();
            }
          },
        ),
      ],
    );
  }

  Widget _buildEquipmentSection(_PlanFormData data) {
    final icons = <String, IconData>{
      'Bodyweight only': Icons.self_improvement,
      'Dumbbells': Icons.fitness_center,
      'Resistance bands': Icons.sports_gymnastics,
      'Full commercial gym': Icons.sports_bar,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('EQUIPMENT'),
        const SizedBox(height: 8),
        ..._equipment.map((option) {
          final isSelected = data.equipment == option;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() => data.equipment = option);
                _persistForms();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                    Icon(
                      icons[option] ?? Icons.fitness_center,
                      color: isSelected
                          ? AppColors.primaryOrange
                          : AppColors.textSlate,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ),
                    Container(
                      width: 18,
                      height: 18,
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
                          ? Icon(
                              Icons.check,
                              color: AppColors.onPrimary,
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

  Widget _buildScheduleSection(_PlanFormData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SCHEDULE'),
        const SizedBox(height: 4),
        Text(
          data.isWeekly
              ? 'How many days per week can you commit to training?'
              : 'Which day is this single-day plan for? (Day 1 by default)',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
        ),
        const SizedBox(height: 10),
        if (data.isWeekly)
          Row(
            children: [
              Container(
                width: 58,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.orangeBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${data.daysPerWeek}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                    Text(
                      'DAYS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Slider(
                  value: data.daysPerWeek.toDouble(),
                  min: 2,
                  max: 7,
                  divisions: 5,
                  label: '${data.daysPerWeek} days',
                  onChanged: (value) {
                    setState(() => data.daysPerWeek = value.round());
                    _persistForms();
                  },
                ),
              ),
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int day = 1; day <= 7; day++)
                ChoiceChip(
                  label: Text('Day $day'),
                  selected: data.singleDayIndex == day,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => data.singleDayIndex = day);
                    _persistForms();
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildExerciseTypesSection(_PlanFormData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('EXERCISE TYPES'),
        const SizedBox(height: 4),
        Text(
          'Optional — select any that apply, or deselect all for no '
          'preference. Rest/light cardio can be added for recovery.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in _exerciseTypes)
              FilterChip(
                label: Text(type),
                selected: data.exerciseTypes.contains(type),
                showCheckmark: false,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      data.exerciseTypes.add(type);
                    } else {
                      data.exerciseTypes.remove(type);
                    }
                  });
                  _persistForms();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCombinationSection(_PlanFormData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('EXERCISE COMBINATIONS'),
        const SizedBox(height: 4),
        Text(
          'Optional — pick a preset, enter a custom string, or tap the '
          'selected option again to clear it.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in _combinations)
              ChoiceChip(
                label: Text(option),
                selected: data.combination == option,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    data.combination = data.combination == option ? '' : option;
                  });
                  _persistForms();
                },
              ),
          ],
        ),
        if (data.combination == 'Custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: data.customCombinationController,
            onChanged: (_) {
              setState(() {});
              _persistForms();
            },
            decoration: InputDecoration(
              hintText: 'e.g., Chest+Triceps+Core',
              prefixIcon: Icon(
                Icons.edit_note,
                color: AppColors.primaryOrange,
                size: 18,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Separate each group with "+". Add as many as you like '
            '(A+B+...+Nth).',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
          ),
          if (data.customParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final part in data.customParts) _detailPill(part),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) _buildErrorBanner(_error!),
          if (_error != null) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isGenerating ? null : _generate,
              child: _isGenerating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textWhite.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Building your plan & finding demos…',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _generateLabel,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: AppColors.rose, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.rose,
                height: 1.4,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _error = null),
            child: Icon(Icons.close, color: AppColors.rose, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(GeneratedPlan plan) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.orangeBorder),
              ),
              child: Text(
                plan.isWeekly ? 'WEEKLY PLAN' : 'SINGLE-DAY PLAN',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryOrange,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _clearPlan,
              tooltip: 'Edit plan details',
              icon: Icon(Icons.edit_outlined, color: AppColors.textSlate),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          plan.title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        if (plan.overview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            plan.overview,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSlate,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _infoChip(plan.details.goal),
            _infoChip(plan.details.experienceLevel),
            if (plan.details.exerciseTypes.isNotEmpty)
              _infoChip(plan.details.exerciseTypes.join(' · ')),
            if (plan.details.exerciseCombination.isNotEmpty)
              _infoChip(plan.details.combinationParts.join(' + ')),
            _infoChip(plan.details.equipment),
            _infoChip(
              plan.details.dayLabel ?? '${plan.details.daysPerWeek} days/week',
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...plan.days.map(_buildDayCard),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _isCurrentPlanSaved ? null : _savePlanToHistory,
            icon: Icon(
              _isCurrentPlanSaved ? Icons.check_circle : Icons.bookmark_add,
              size: 18,
            ),
            label: Text(
              _isCurrentPlanSaved ? 'Saved to History' : 'Save to History',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_isCurrentPlanSaved) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _openHistoryFromResult,
              icon: const Icon(Icons.history, size: 16),
              label: Text(
                'View History',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _clearPlan,
            icon: const Icon(Icons.refresh),
            label: Text(
              'Create another plan',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
      ),
    );
  }

  Widget _buildDayCard(PlanDay day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today,
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
                      day.label,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                    Text(
                      day.workoutName,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (day.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                day.note.isEmpty ? 'Recovery day.' : day.note,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSlate,
                ),
              ),
            ),
          ...day.exercises.map(_buildExerciseRow),
          if (day.exercises.isNotEmpty && day.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              day.note,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlate,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseRow(ExerciseModel exercise) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _detailPill(exercise.sets),
                _detailPill(exercise.reps),
                _detailPill(exercise.rest),
                _detailPill(exercise.category),
              ],
            ),
            ...exercise.cues.map(
              (cue) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppColors.emerald,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cue,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSlate,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (exercise.videoUrl != null && exercise.videoUrl!.isNotEmpty)
              _buildVideoCard(exercise),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(ExerciseModel exercise) {
    final videoId = youtubeVideoIdFromUrl(exercise.videoUrl!);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => _openExerciseVideo(exercise),
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(
                height: 118,
                width: double.infinity,
                color: const Color(0xFF0F0F0F),
                child: videoId != null
                    ? Image.network(
                        'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return _videoPlaceholder();
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            _videoPlaceholder(),
                      )
                    : _videoPlaceholder(),
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 42,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    videoId == null
                        ? 'Find demo on YouTube'
                        : 'Watch exercise demo',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoPlaceholder() {
    return Container(
      height: 118,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardSurface, AppColors.surfaceHigh],
        ),
      ),
      child: Icon(
        Icons.play_circle_outline,
        color: AppColors.textMuted,
        size: 40,
      ),
    );
  }

  Future<void> _openExerciseVideo(ExerciseModel exercise) async {
    var url = exercise.videoUrl ?? '';
    if (url.isEmpty || url.contains('search_query')) {
      url = await YouTubeService.getExactVideoUrl(exercise.name);
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        _showVideoError();
      }
    } catch (_) {
      if (mounted) _showVideoError();
    }
  }

  void _showVideoError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.cardSurface,
        content: Text(
          'Could not open the video on this device.',
          style: GoogleFonts.inter(color: AppColors.textWhite, fontSize: 12),
        ),
      ),
    );
  }

  Widget _detailPill(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryOrange,
        ),
      ),
    );
  }
}
