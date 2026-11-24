import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/calories_models.dart';
import '../services/calorie_history_service.dart';
import '../services/calories_service.dart';
import '../services/local_store.dart';
import '../theme/app_colors.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/app_dialog.dart';

class _CalorieFormData {
  _CalorieFormData();

  final TextEditingController ageController = TextEditingController(text: '30');
  final TextEditingController heightController = TextEditingController(
    text: '175',
  );
  final TextEditingController weightController = TextEditingController(
    text: '70',
  );

  String gender = 'Male';
  String activity = CalorieMath.activityLevels.first;

  void dispose() {
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
  }

  Map<String, dynamic> toJson() => {
    'age': ageController.text,
    'height': heightController.text,
    'weight': weightController.text,
    'gender': gender,
    'activity': activity,
  };

  void applyJson(Map<String, dynamic> json) {
    ageController.text = (json['age'] as String?) ?? ageController.text;
    heightController.text =
        (json['height'] as String?) ?? heightController.text;
    weightController.text =
        (json['weight'] as String?) ?? weightController.text;
    gender = (json['gender'] as String?) ?? gender;
    activity = (json['activity'] as String?) ?? activity;
  }
}

/// Calories section: weekly maintenance-calorie estimates (with activity
/// level) and BMI results. Both CTAs are authenticated against the Gemini key
/// before any result is produced.
class CaloriesScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CaloriesScreen({super.key, this.onBack});

  @override
  State<CaloriesScreen> createState() => _CaloriesScreenState();
}

class _CaloriesScreenState extends State<CaloriesScreen>
    with SingleTickerProviderStateMixin {
  static const String _formKey = 'workout_app.calories_form.v1';
  static const String _resultsKey = 'workout_app.calories_results.v1';
  static const String _tabKey = 'workout_app.calories_tab.v1';

  late final TabController _tabController;
  final _CalorieFormData _form = _CalorieFormData();

  bool _isGenerating = false;
  String? _error;
  WeeklyCalorieEstimate? _weeklyResult;
  BmiEstimate? _bmiResult;
  List<SavedCalorieEntry> _history = const <SavedCalorieEntry>[];
  int _formTabIndex = 0;
  int _lastTabIndex = 0;

  static const List<String> _genders = ['Male', 'Female', 'Other'];
  static const Map<String, String> _shortActivityLabels = {
    'Little or no exercise': 'Sedentary',
    '1-3 days/week (Light)': 'Light',
    '4-5 days/week (moderate)': 'Moderate',
    'intense exercise 3-4 days/week (active)': 'Active',
    'intense exercise 6-7 days/week (very active)': 'Very active',
    'very intense exercise daily (Extra active)': 'Extra active',
  };

  @override
  void initState() {
    super.initState();

    final savedForm = LocalStore.instance.readMap(_formKey);
    if (savedForm != null) _form.applyJson(savedForm);

    final savedResults = LocalStore.instance.readMap(_resultsKey);
    if (savedResults != null) {
      final weekly = savedResults['weekly'] as Map<String, dynamic>?;
      final bmi = savedResults['bmi'] as Map<String, dynamic>?;
      if (weekly != null) {
        _weeklyResult = WeeklyCalorieEstimate.fromJson(weekly);
      }
      if (bmi != null) {
        _bmiResult = BmiEstimate.fromJson(bmi);
      }
    }

    _history = CalorieHistoryStore.read();

    final savedTab = LocalStore.instance.readInt(_tabKey) ?? 0;
    final initialTab = savedTab >= 0 && savedTab <= 2 ? savedTab : 0;
    // History is not a form: keep the last generator tab so the CTA label and
    // scope do not change when the user visits History.
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
        if (_lastTabIndex != 2) _formTabIndex = _lastTabIndex;
        unawaited(LocalStore.instance.write(_tabKey, _lastTabIndex));
        if (mounted) setState(() {});
      }
    });
  }

  void _persistForm() {
    unawaited(LocalStore.instance.write(_formKey, _form.toJson()));
  }

  void _persistResults() {
    unawaited(
      LocalStore.instance.write(_resultsKey, {
        if (_weeklyResult != null) 'weekly': _weeklyResult!.toJson(),
        if (_bmiResult != null) 'bmi': _bmiResult!.toJson(),
      }),
    );
  }

  void _clearResults() {
    setState(() {
      _weeklyResult = null;
      _bmiResult = null;
    });
    _persistResults();
  }

  bool get _isCurrentResultSaved {
    final weekly = _weeklyResult;
    if (weekly != null) {
      return _history.any((entry) => entry.weekly?.id == weekly.id);
    }
    final bmi = _bmiResult;
    return bmi != null && _history.any((entry) => entry.bmi?.id == bmi.id);
  }

  Future<void> _saveCurrentResultToHistory() async {
    final weekly = _weeklyResult;
    final bmi = _bmiResult;
    if (weekly == null && bmi == null) return;

    final entry = weekly != null
        ? await CalorieHistoryStore.saveWeekly(weekly)
        : await CalorieHistoryStore.saveBmi(bmi!);
    if (!mounted) return;

    setState(() {
      _history = <SavedCalorieEntry>[
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
              'Response saved to History',
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
    _clearResults();
    _tabController.animateTo(2);
  }

  /// Leaves a generated result and restores the matching input form. Using the
  /// result type (rather than the current tab) also handles saved responses
  /// reopened from History, where the tab controller is on tab 2.
  void _returnToEditScreen({required bool weekly}) {
    final tabIndex = weekly ? 0 : 1;
    _formTabIndex = tabIndex;
    _clearResults();
    _tabController.animateTo(tabIndex);
  }

  void _openSavedEntry(SavedCalorieEntry entry) {
    setState(() {
      _weeklyResult = entry.weekly;
      _bmiResult = entry.bmi;
    });
    _persistResults();
  }

  Future<void> _confirmDeleteSavedEntry(SavedCalorieEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(
          'Delete saved response?',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        content: Text(
          '“${entry.title}” will be removed from History.',
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

    await CalorieHistoryStore.remove(entry.id);
    if (!mounted) return;
    setState(() {
      _history = _history.where((saved) => saved.id != entry.id).toList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _form.dispose();
    super.dispose();
  }

  bool get _isWeekly => _formTabIndex == 0;

  bool get _hasResult => _weeklyResult != null || _bmiResult != null;

  bool get _isHistoryTab => !_hasResult && _tabController.index == 2;

  String get _generateLabel =>
      _isWeekly ? 'Generate Estimate' : 'Generate results';

  Future<void> _generate() async {
    if (_isGenerating) return;

    if (!await ensureAiAccess(context)) return;
    if (!mounted) return;

    final age = int.tryParse(_form.ageController.text.trim()) ?? 0;
    final height = double.tryParse(_form.heightController.text.trim()) ?? 0;
    final weight = double.tryParse(_form.weightController.text.trim()) ?? 0;

    if (age < 10 || age > 120) {
      setState(() => _error = 'Enter a valid age between 10 and 120 years.');
      return;
    }
    if (height < 100 || height > 250) {
      setState(() => _error = 'Enter a valid height between 100 and 250 cm.');
      return;
    }
    if (weight < 20 || weight > 400) {
      setState(() => _error = 'Enter a valid weight between 20 and 400 kg.');
      return;
    }

    final profile = CalorieProfile(
      age: age,
      gender: _form.gender,
      heightCm: height,
      weightKg: weight,
      activity: _form.activity,
    );

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      if (_isWeekly) {
        final result = await CaloriesService.generateWeeklyEstimate(profile);
        if (!mounted) return;
        setState(() {
          _weeklyResult = result;
          _bmiResult = null;
          _isGenerating = false;
        });
        _persistResults();
      } else {
        final result = await CaloriesService.generateBmiEstimate(profile);
        if (!mounted) return;
        setState(() {
          _bmiResult = result;
          _weeklyResult = null;
          _isGenerating = false;
        });
        _persistResults();
      }
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
    final hasResult = _hasResult;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _buildHeader(),
                if (!hasResult) _buildTabBar(),
                Expanded(
                  child: hasResult
                      ? (_weeklyResult != null
                            ? _buildWeeklyResult(_weeklyResult!)
                            : _buildBmiResult(_bmiResult!))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildForm(showActivity: true),
                            _buildForm(showActivity: false),
                            _buildHistoryView(),
                          ],
                        ),
                ),
                if (!hasResult && !_isHistoryTab) _buildBottomBar(),
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
                  'CALORIES',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  'AI Calorie & BMI Estimator',
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
                  Icons.local_fire_department,
                  color: AppColors.primaryOrange,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'ESTIMATOR',
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
          Tab(text: 'Weekly estimate'),
          Tab(text: 'BMI calculate'),
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
                  'No saved responses yet',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a weekly estimate or BMI result, then tap '
                  '“Save to History” at the end of the response.',
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
              'SAVED RESPONSES',
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

  Widget _buildHistoryCard(SavedCalorieEntry entry) {
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
                  entry.isWeekly ? Icons.calendar_month : Icons.straighten,
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
                      entry.title,
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
                      entry.isWeekly ? 'Weekly estimate' : 'BMI calculation',
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
                onPressed: () => _confirmDeleteSavedEntry(entry),
                tooltip: 'Delete saved response',
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.rose,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.preview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSlate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saved ${_formatSavedAt(entry.savedAt)}',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSlate),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openSavedEntry(entry),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open saved response'),
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

  Widget _buildForm({required bool showActivity}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _buildIntroCard(showActivity),
        const SizedBox(height: 18),
        _buildNumberField(
          label: 'AGE',
          controller: _form.ageController,
          hint: 'e.g., 30',
          suffix: 'years',
          decimals: false,
          onChanged: (_) => _persistForm(),
        ),
        const SizedBox(height: 18),
        _buildGenderSection(),
        const SizedBox(height: 18),
        _buildNumberField(
          label: 'HEIGHT',
          controller: _form.heightController,
          hint: 'e.g., 175',
          suffix: 'cm',
          decimals: true,
          onChanged: (_) => _persistForm(),
        ),
        const SizedBox(height: 18),
        _buildNumberField(
          label: 'WEIGHT',
          controller: _form.weightController,
          hint: 'e.g., 70',
          suffix: 'kg',
          decimals: true,
          onChanged: (_) => _persistForm(),
        ),
        if (showActivity) ...[
          const SizedBox(height: 18),
          _buildActivitySection(),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildIntroCard(bool showActivity) {
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
              showActivity ? Icons.calendar_month : Icons.monitor_heart,
              color: AppColors.primaryOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              showActivity
                  ? 'Gemini will estimate your daily and weekly maintenance '
                        'calories from your profile and activity level.'
                  : 'Gemini will interpret your BMI and suggest a healthy '
                        'weight range based on your profile.',
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

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String suffix,
    required bool decimals,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: decimals
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            suffixStyle: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSlate,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('GENDER'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            for (final gender in _genders)
              ButtonSegment<String>(value: gender, label: Text(gender)),
          ],
          selected: {_form.gender},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              setState(() => _form.gender = selection.first);
              _persistForm();
            }
          },
        ),
      ],
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ACTIVITY LEVEL'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _form.activity,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.directions_run),
          ),
          items: [
            for (final level in CalorieMath.activityLevels)
              DropdownMenuItem<String>(
                value: level,
                child: Text(
                  level,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
          ],
          selectedItemBuilder: (context) {
            return [
              for (final level in CalorieMath.activityLevels)
                Text(
                  _shortActivityLabels[level] ?? level,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ];
          },
          onChanged: (value) {
            if (value != null) {
              setState(() => _form.activity = value);
              _persistForm();
            }
          },
        ),
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
                          'Gemini is calculating…',
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
                        Text(
                          _generateLabel,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
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

  Widget _resultScaffold({
    required String badge,
    required bool isWeekly,
    required List<Widget> children,
  }) {
    final saved = _isCurrentResultSaved;
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
                badge,
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
              onPressed: _clearResults,
              tooltip: 'Edit details',
              icon: Icon(Icons.edit_outlined, color: AppColors.textSlate),
            ),
          ],
        ),
        ...children,
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: saved ? null : _saveCurrentResultToHistory,
            icon: Icon(
              saved ? Icons.check_circle : Icons.bookmark_add,
              size: 18,
            ),
            label: Text(
              saved ? 'Saved to History' : 'Save to History',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (saved) ...[
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
            onPressed: _clearResults,
            icon: const Icon(Icons.refresh),
            label: Text(
              'Create another estimate',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _returnToEditScreen(weekly: isWeekly),
            icon: const Icon(Icons.arrow_back),
            label: Text(
              'Go to previous screen',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyResult(WeeklyCalorieEstimate result) {
    return _resultScaffold(
      badge: 'WEEKLY ESTIMATE',
      isWeekly: true,
      children: [
        const SizedBox(height: 8),
        Text(
          'Your Calorie Estimate',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        if (result.summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            result.summary,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSlate,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statCard('BMR', '${result.bmr}', 'kcal/day')),
            const SizedBox(width: 10),
            Expanded(child: _statCard('TDEE', '${result.tdee}', 'kcal/day')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard('DAILY TARGET', '${result.dailyTarget}', 'kcal'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'WEEKLY TARGET',
                '${result.weeklyTarget}',
                'kcal',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('7-DAY BREAKDOWN'),
        const SizedBox(height: 10),
        ...result.days.map(
          (day) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.day,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      if (day.note.isNotEmpty)
                        Text(
                          day.note,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSlate,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${day.calories} kcal',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (result.tips.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionLabel('TIPS'),
          const SizedBox(height: 8),
          ...result.tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: AppColors.emerald,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
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
        ],
      ],
    );
  }

  Widget _buildBmiResult(BmiEstimate result) {
    return _resultScaffold(
      badge: 'BMI RESULT',
      isWeekly: false,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.orangeBorder, width: 2),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      result.bmi.toStringAsFixed(1),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                    Text(
                      'BMI',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.category,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Healthy range for your height',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSlate,
                    ),
                  ),
                  Text(
                    result.healthyWeightRange,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (result.interpretation.isNotEmpty) ...[
          _sectionLabel('INTERPRETATION'),
          const SizedBox(height: 8),
          Text(
            result.interpretation,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSlate,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (result.recommendations.isNotEmpty) ...[
          _sectionLabel('RECOMMENDATIONS'),
          const SizedBox(height: 8),
          ...result.recommendations.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppColors.emerald,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
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
        ],
      ],
    );
  }

  Widget _statCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.textSlate,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryOrange,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSlate),
          ),
        ],
      ),
    );
  }
}
