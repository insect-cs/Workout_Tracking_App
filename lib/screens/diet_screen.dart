import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diet_models.dart';
import '../services/diet_export_service.dart';
import '../services/diet_service.dart';
import '../state/diet_state.dart';
import '../theme/app_colors.dart';
import '../widgets/api_key_dialog.dart';

/// Day planner: pick a date, choose one of the 24 hourly slots, add Food or
/// Water activities, analyse food with Gemini and track the remainder of the
/// daily calorie / water goals.
class DietScreen extends StatefulWidget {
  const DietScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final DietState _store = DietState.instance;
  final TextEditingController _foodItemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _waterController = TextEditingController();
  final TextEditingController _sleepHoursController = TextEditingController();
  final TextEditingController _sleepMinutesController = TextEditingController();
  final TextEditingController _calorieGoalController = TextEditingController(
    text: '$kDefaultDailyCalorieGoal',
  );
  final TextEditingController _waterGoalController = TextEditingController(
    text: '$kDefaultDailyWaterGoalMl',
  );
  final TextEditingController _restGoalController = TextEditingController(
    text: '$kDefaultDailyRestGoalMinutes',
  );
  final TextEditingController _weekCalorieGoalController =
      TextEditingController(text: '$kDefaultWeeklyCalorieGoal');
  final TextEditingController _weekWaterGoalController = TextEditingController(
    text: '$kDefaultWeeklyWaterGoalMl',
  );
  final TextEditingController _weekRestGoalController = TextEditingController(
    text: '$kDefaultWeeklyRestGoalMinutes',
  );

  late DateTime _selectedDate;
  int? _selectedHour;
  DietActivityType _activityType = DietActivityType.food;
  String _foodType = 'Veg';
  String _quantityUnit = kFoodQuantityUnits.first;
  XFile? _photo;
  FoodAnalysis? _analysis;
  bool _isAnalysing = false;
  String? _error;

  static const List<String> _foodTypes = ['Veg', 'Non veg'];
  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _months = [
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _syncGoalControllers();
  }

  @override
  void dispose() {
    _foodItemController.dispose();
    _quantityController.dispose();
    _waterController.dispose();
    _sleepHoursController.dispose();
    _sleepMinutesController.dispose();
    _calorieGoalController.dispose();
    _waterGoalController.dispose();
    _restGoalController.dispose();
    _weekCalorieGoalController.dispose();
    _weekWaterGoalController.dispose();
    _weekRestGoalController.dispose();
    super.dispose();
  }

  void _syncGoalControllers() {
    final day = _store.day(_selectedDate);
    _calorieGoalController.text = '${day.calorieGoal}';
    _waterGoalController.text = '${day.waterGoalMl}';
    _restGoalController.text = '${day.restGoalMinutes}';
    final week = _store.weekGoals(_selectedDate);
    _weekCalorieGoalController.text = '${week.calorieGoal}';
    _weekWaterGoalController.text = '${week.waterGoalMl}';
    _weekRestGoalController.text = '${week.restGoalMinutes}';
  }

  String get _formattedDate =>
      '${_weekdays[_selectedDate.weekday - 1]}, '
      '${_months[_selectedDate.month - 1]} ${_selectedDate.day}, '
      '${_selectedDate.year}';

  String _formatSleep(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  /// Keeps free-form quantities working (e.g. "1 bowl") while attaching the
  /// selected unit to plain numeric amounts (e.g. "250" + "g" -> "250 g").
  String _composeQuantity(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || double.tryParse(trimmed) == null) return trimmed;
    return '$trimmed $_quantityUnit';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select diet date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedHour = null;
      _clearActivity();
      _syncGoalControllers();
    });
  }

  void _selectHour(int hour) {
    setState(() {
      _selectedHour = _selectedHour == hour ? null : hour;
      _clearActivity();
    });
  }

  void _clearActivity() {
    _foodItemController.clear();
    _quantityController.clear();
    _waterController.clear();
    _sleepHoursController.clear();
    _sleepMinutesController.clear();
    _foodType = _foodTypes.first;
    _quantityUnit = kFoodQuantityUnits.first;
    _photo = null;
    _analysis = null;
    _isAnalysing = false;
    _error = null;
  }

  bool _updateGoals() {
    final calorieGoal = int.tryParse(_calorieGoalController.text.trim());
    final waterGoal = int.tryParse(_waterGoalController.text.trim());
    final restGoal = int.tryParse(_restGoalController.text.trim());
    if (calorieGoal == null ||
        calorieGoal <= 0 ||
        waterGoal == null ||
        waterGoal <= 0 ||
        restGoal == null ||
        restGoal <= 0) {
      return false;
    }
    _store.setGoals(
      _selectedDate,
      calorieGoal: calorieGoal,
      waterGoalMl: waterGoal,
      restGoalMinutes: restGoal,
    );
    return true;
  }

  bool _updateWeekGoals() {
    final calorieGoal = int.tryParse(_weekCalorieGoalController.text.trim());
    final waterGoal = int.tryParse(_weekWaterGoalController.text.trim());
    final restGoal = int.tryParse(_weekRestGoalController.text.trim());
    if (calorieGoal == null ||
        calorieGoal <= 0 ||
        waterGoal == null ||
        waterGoal <= 0 ||
        restGoal == null ||
        restGoal <= 0) {
      return false;
    }
    _store.setWeekGoals(
      _selectedDate,
      calorieGoal: calorieGoal,
      waterGoalMl: waterGoal,
      restGoalMinutes: restGoal,
    );
    return true;
  }

  void _restoreDefaultGoals({required bool weekly}) {
    setState(() {
      if (weekly) {
        _weekCalorieGoalController.text = '$kDefaultWeeklyCalorieGoal';
        _weekWaterGoalController.text = '$kDefaultWeeklyWaterGoalMl';
        _weekRestGoalController.text = '$kDefaultWeeklyRestGoalMinutes';
      } else {
        _calorieGoalController.text = '$kDefaultDailyCalorieGoal';
        _waterGoalController.text = '$kDefaultDailyWaterGoalMl';
        _restGoalController.text = '$kDefaultDailyRestGoalMinutes';
      }
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null && mounted) setState(() => _photo = picked);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not attach photo: $e');
    }
  }

  Future<void> _validateFood() async {
    if (_isAnalysing) return;
    final item = _foodItemController.text.trim();
    final quantity = _composeQuantity(_quantityController.text);
    if (item.isEmpty || quantity.isEmpty) {
      setState(() => _error = 'Enter a food item and quantity first.');
      return;
    }
    if (!await ensureAiAccess(context)) return;
    if (!mounted) return;

    setState(() {
      _isAnalysing = true;
      _error = null;
      _analysis = null;
    });

    try {
      final result = await DietService.analyzeFood(
        foodItem: item,
        foodType: _foodType,
        quantity: quantity,
        photoName: _photo?.name,
      );
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _isAnalysing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalysing = false;
        _error = e.toString();
      });
    }
  }

  void _saveEntry() {
    final hour = _selectedHour;
    if (hour == null) return;

    final DietEntry entry;
    if (_activityType == DietActivityType.food) {
      final analysis = _analysis;
      if (analysis == null) {
        setState(() => _error = 'Validate the food before saving it.');
        return;
      }
      entry = DietEntry(
        id: 'd-${DateTime.now().microsecondsSinceEpoch}',
        slotHour: hour,
        type: DietActivityType.food,
        label: analysis.foodItem,
        detail: '${analysis.foodType} • ${analysis.quantity}',
        calories: analysis.calories,
        quantityUnit: _quantityUnit,
        photoName: _photo?.name,
        analysis: analysis,
        createdAt: DateTime.now(),
      );
    } else if (_activityType == DietActivityType.water) {
      final ml = int.tryParse(_waterController.text.trim()) ?? 0;
      if (ml <= 0) {
        setState(() => _error = 'Enter a water quantity in ml.');
        return;
      }
      entry = DietEntry(
        id: 'd-${DateTime.now().microsecondsSinceEpoch}',
        slotHour: hour,
        type: DietActivityType.water,
        label: 'Water',
        detail: '$ml ml',
        waterMl: ml,
        createdAt: DateTime.now(),
      );
    } else {
      final hours = int.tryParse(_sleepHoursController.text.trim()) ?? 0;
      final minutes = int.tryParse(_sleepMinutesController.text.trim()) ?? 0;
      final totalMinutes = hours * 60 + minutes;
      if (totalMinutes <= 0) {
        setState(() => _error = 'Enter a sleep duration greater than zero.');
        return;
      }
      entry = DietEntry(
        id: 'd-${DateTime.now().microsecondsSinceEpoch}',
        slotHour: hour,
        type: DietActivityType.rest,
        label: 'Rest',
        detail: _formatSleep(totalMinutes),
        sleepMinutes: totalMinutes,
        createdAt: DateTime.now(),
      );
    }

    _store.addEntry(_selectedDate, entry);
    _clearActivity();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${slotLabel(hour)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                Expanded(
                  child: AnimatedBuilder(
                    animation: _store,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      children: [
                        _buildDateCard(),
                        const SizedBox(height: 18),
                        _sectionLabel('TIME SLOTS'),
                        const SizedBox(height: 4),
                        Text(
                          'Tap a one-hour slot to add Food, Water or Rest '
                          '(sleep). Green = filled, red = idle.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSlate,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildSlotGrid(),
                        const SizedBox(height: 20),
                        _buildGoalsCard(),
                        if (_selectedHour != null) ...[
                          const SizedBox(height: 20),
                          _buildEditor(_selectedHour!),
                        ],
                        const SizedBox(height: 20),
                        _buildWeeklyGoalsCard(),
                        const SizedBox(height: 20),
                        _buildSummaryButton(),
                      ],
                    ),
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
                  'DIET',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  'Daily food & water planner',
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
            child: Text(
              'PLANNER',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
                letterSpacing: 0.6,
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

  /// Shows the seed values and a one-tap way to go back to them.
  Widget _buildDefaultHint(
    String label, {
    required bool isDefault,
    required VoidCallback onRestore,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          ),
        ),
        if (isDefault)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'DEFAULT',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
              ),
            ),
          ),
        const SizedBox(width: 6),
        InkWell(
          onTap: onRestore,
          child: Text(
            'Restore',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.primaryOrange,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_month,
                color: AppColors.primaryOrange,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECTED DATE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.textSlate,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formattedDate,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_calendar, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotGrid() {
    final day = _store.day(_selectedDate);
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: [
        for (var hour = 0; hour < 24; hour++)
          _slotTile(hour, day.entriesForSlot(hour).length),
      ],
    );
  }

  Widget _slotTile(int hour, int entryCount) {
    final isSelected = _selectedHour == hour;
    // A slot turns green as soon as it has an activity and goes back to red
    // when its last activity is removed.
    final isFilled = entryCount > 0;
    final label = '${hour.toString().padLeft(2, '0')}:00';
    return Semantics(
      label: isFilled ? 'Filled slot $label' : 'Empty slot $label',
      child: InkWell(
        onTap: () => _selectHour(hour),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isFilled ? AppColors.emerald : AppColors.rose,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: AppColors.primaryOrange, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalsCard() {
    final day = _store.day(_selectedDate);
    final caloriesLeft = day.caloriesRemaining;
    final waterLeft = day.waterRemainingMl;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('DAILY GOALS'),
          const SizedBox(height: 6),
          _buildDefaultHint(
            'Default: $kDefaultDailyCalorieGoal kcal  •  '
            '$kDefaultDailyWaterGoalMl ml  •  '
            '${_formatSleep(kDefaultDailyRestGoalMinutes)} rest',
            isDefault: day.isUsingDefaultGoals,
            onRestore: () => _restoreDefaultGoals(weekly: false),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _goalField(
                  'CALORIE GOAL',
                  _calorieGoalController,
                  'kcal',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _goalField('WATER GOAL', _waterGoalController, 'ml'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _goalField('REST GOAL', _restGoalController, 'min'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                final saved = _updateGoals();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      saved
                          ? 'Daily goals updated'
                          : 'Enter positive numbers for all goals',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.check, size: 15),
              label: Text(
                'Save goals',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _goalProgress(
            icon: Icons.local_fire_department,
            label: 'Calories left',
            value: caloriesLeft,
            unit: 'kcal',
            used: day.caloriesConsumed,
            goal: day.calorieGoal,
          ),
          const SizedBox(height: 10),
          _goalProgress(
            icon: Icons.water_drop_outlined,
            label: 'Water left',
            value: waterLeft,
            unit: 'ml',
            used: day.waterConsumedMl,
            goal: day.waterGoalMl,
          ),
          const SizedBox(height: 10),
          _goalProgress(
            icon: Icons.bedtime_outlined,
            label: 'Rest left',
            value: day.sleepRemainingMinutes,
            displayValue: _formatSleep(day.sleepRemainingMinutes),
            used: day.sleepMinutes,
            goal: day.restGoalMinutes,
          ),
        ],
      ),
    );
  }

  /// Weekly targets are independent of the daily targets, but everything
  /// logged each day is deducted from these totals as well.
  Widget _buildWeeklyGoalsCard() {
    final week = _store.weekGoals(_selectedDate);
    final consumed = _store.weekConsumed(_selectedDate);
    final caloriesLeft = week.calorieGoal - consumed.calories;
    final waterLeft = week.waterGoalMl - consumed.waterMl;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('WEEKLY GOALS'),
          const SizedBox(height: 6),
          _buildDefaultHint(
            'Default: $kDefaultWeeklyCalorieGoal kcal  •  '
            '$kDefaultWeeklyWaterGoalMl ml  •  '
            '${_formatSleep(kDefaultWeeklyRestGoalMinutes)} rest (7 days)',
            isDefault: week.isUsingDefaultGoals,
            onRestore: () => _restoreDefaultGoals(weekly: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _goalField(
                  'WEEK CALORIE GOAL',
                  _weekCalorieGoalController,
                  'kcal',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _goalField(
                  'WEEK WATER GOAL',
                  _weekWaterGoalController,
                  'ml',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _goalField('WEEK REST GOAL', _weekRestGoalController, 'min'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                final saved = _updateWeekGoals();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      saved
                          ? 'Weekly goals updated'
                          : 'Enter positive numbers for all goals',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.check, size: 15),
              label: Text(
                'Save week goals',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _goalProgress(
            icon: Icons.local_fire_department,
            label: 'Calories left this week',
            value: caloriesLeft,
            unit: 'kcal',
            used: consumed.calories,
            goal: week.calorieGoal,
          ),
          const SizedBox(height: 10),
          _goalProgress(
            icon: Icons.water_drop_outlined,
            label: 'Water left this week',
            value: waterLeft,
            unit: 'ml',
            used: consumed.waterMl,
            goal: week.waterGoalMl,
          ),
          const SizedBox(height: 10),
          _goalProgress(
            icon: Icons.bedtime_outlined,
            label: 'Rest left this week',
            value: week.restGoalMinutes - consumed.sleepMinutes,
            displayValue: _formatSleep(
              week.restGoalMinutes - consumed.sleepMinutes,
            ),
            used: consumed.sleepMinutes,
            goal: week.restGoalMinutes,
          ),
          const SizedBox(height: 10),
          Text(
            'Sleep tracked this week: ${_formatSleep(consumed.sleepMinutes)}',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
          ),
          const SizedBox(height: 16),
          _sectionLabel('THIS WEEK'),
          const SizedBox(height: 8),
          _buildWeekStrip(),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendDot(AppColors.emerald, '50%+ goal met'),
              const SizedBox(width: 12),
              _buildLegendDot(AppColors.rose, 'Below 50%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSlate),
        ),
      ],
    );
  }

  Widget _buildWeekStrip() {
    return Row(
      children: [
        for (final date in DietState.weekDates(_selectedDate))
          Expanded(child: _buildDayTile(date)),
      ],
    );
  }

  Widget _buildDayTile(DateTime date) {
    final day = _store.day(date);
    final met = day.isGoalHalfMet;
    final isSelected =
        DietState.keyFor(date) == DietState.keyFor(_selectedDate);
    final now = DateTime.now();
    final isToday = DietState.keyFor(date) == DietState.keyFor(now);
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = DateTime(date.year, date.month, date.day);
          _selectedHour = null;
          _clearActivity();
          _syncGoalControllers();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: met ? AppColors.emerald : AppColors.rose,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppColors.primaryOrange, width: 2)
              : null,
        ),
        child: Column(
          children: [
            Text(
              _weekdays[date.weekday - 1].substring(0, 1),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (isToday)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryButton() {
    return InkWell(
      onTap: _showSummarySheet,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.orangeBorder),
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
                Icons.assessment_outlined,
                color: AppColors.primaryOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIET SUMMARY',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'All activities till now  •  export as CSV or PDF',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textSlate,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showSummarySheet() {
    final summary = _store.buildSummary(_selectedDate);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'DIET SUMMARY',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              summary.scope,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlate,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: [
                _summaryMetric(
                  Icons.local_fire_department,
                  'Calories',
                  '${summary.totalCalories} kcal',
                  AppColors.primaryOrange,
                ),
                _summaryMetric(
                  Icons.water_drop_outlined,
                  'Water',
                  '${summary.totalWaterMl} ml',
                  AppColors.emerald,
                ),
                _summaryMetric(
                  Icons.bedtime_outlined,
                  'Sleep',
                  _formatSleep(summary.totalSleepMinutes),
                  AppColors.primaryOrange,
                ),
                _summaryMetric(
                  Icons.event_available_outlined,
                  'Days at 50%+',
                  '${summary.daysGoalMet}/${summary.days.length}',
                  AppColors.rose,
                ),
                _summaryMetric(
                  Icons.restaurant_menu,
                  'Food logs',
                  '${summary.foodCount}',
                  AppColors.primaryOrange,
                ),
                _summaryMetric(
                  Icons.check_circle_outline,
                  'Activities',
                  '${summary.totalActivities}',
                  AppColors.emerald,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionLabel('DAILY BREAKDOWN'),
            const SizedBox(height: 8),
            if (summary.days.isEmpty)
              Text(
                'No activities logged yet.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSlate,
                ),
              )
            else
              ...summary.days.map(_buildSummaryDayRow),
            const SizedBox(height: 18),
            _sectionLabel('EXPORT'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _runDietExport(sheetContext, summary, 'csv'),
                    icon: const Icon(Icons.table_view, size: 16),
                    label: Text(
                      'Export as CSV',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _runDietExport(sheetContext, summary, 'pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: Text(
                      'Export as PDF',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: AppColors.textSlate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDayRow(DietSummaryDay day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: day.isGoalHalfMet ? AppColors.emerald : AppColors.rose,
        ),
      ),
      child: Row(
        children: [
          Icon(
            day.isGoalHalfMet
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 15,
            color: day.isGoalHalfMet ? AppColors.emerald : AppColors.rose,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${day.date.day}/${day.date.month}/${day.date.year}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textWhite,
              ),
            ),
          ),
          Text(
            '${day.caloriesConsumed} kcal',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSlate),
          ),
          const SizedBox(width: 8),
          Text(
            '${day.waterConsumedMl} ml',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSlate),
          ),
        ],
      ),
    );
  }

  Future<void> _runDietExport(
    BuildContext sheetContext,
    DietSummary summary,
    String format,
  ) async {
    Navigator.of(sheetContext).pop();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Generating diet summary…')));
    try {
      final path = format == 'csv'
          ? await DietExportService.saveCsv(summary)
          : await DietExportService.savePdf(summary);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? '$format export started - check your downloads ($path)'
                : 'Exported to: $path',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Widget _goalField(
    String label,
    TextEditingController controller,
    String unit,
  ) {
    return Column(
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
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
          decoration: InputDecoration(
            isDense: true,
            suffixText: unit,
            suffixStyle: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textSlate,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalProgress({
    required IconData icon,
    required String label,
    required int value,
    String? displayValue,
    String? unit,
    required int used,
    required int goal,
  }) {
    final remainingFraction = goal <= 0
        ? 0.0
        : (1 - used / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primaryOrange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSlate,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              displayValue ?? (unit == null ? '$value' : '$value $unit'),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: value < 0 ? AppColors.rose : AppColors.textWhite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: remainingFraction,
            minHeight: 6,
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.primaryOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(int hour) {
    final day = _store.day(_selectedDate);
    final entries = day.entriesForSlot(hour);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ACTIVITY  ·  ${slotLabel(hour)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _selectedHour = null),
                child: Icon(Icons.close, size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<DietActivityType>(
            segments: const [
              ButtonSegment(
                value: DietActivityType.food,
                label: Text('Food'),
                icon: Icon(Icons.restaurant_menu, size: 16),
              ),
              ButtonSegment(
                value: DietActivityType.water,
                label: Text('Water'),
                icon: Icon(Icons.water_drop_outlined, size: 16),
              ),
              ButtonSegment(
                value: DietActivityType.rest,
                label: Text('Rest'),
                icon: Icon(Icons.bedtime_outlined, size: 16),
              ),
            ],
            selected: {_activityType},
            onSelectionChanged: (selection) {
              setState(() {
                _activityType = selection.first;
                _clearActivity();
              });
            },
          ),
          const SizedBox(height: 16),
          if (_activityType == DietActivityType.food)
            _buildFoodEditor()
          else if (_activityType == DietActivityType.water)
            _buildWaterEditor()
          else
            _buildRestEditor(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _buildError(_error!),
          ],
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 18),
            _sectionLabel('SAVED IN THIS SLOT'),
            const SizedBox(height: 8),
            ...entries.map(_buildEntryRow),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _editorField(
          label: 'FOOD ITEM',
          controller: _foodItemController,
          hint: 'e.g., Grilled chicken bowl',
          icon: Icons.restaurant,
        ),
        const SizedBox(height: 12),
        _sectionLabel('TYPE'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _foodType,
          isExpanded: true,
          items: [
            for (final type in _foodTypes)
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _foodType = value);
          },
        ),
        const SizedBox(height: 12),
        _editorField(
          label: 'QUANTITY',
          controller: _quantityController,
          hint: 'e.g., 1 bowl (250 g)',
          icon: Icons.scale_outlined,
          suffixText: _quantityUnit,
        ),
        const SizedBox(height: 10),
        _sectionLabel('UNIT'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _quantityUnit,
          isExpanded: true,
          items: [
            for (final unit in kFoodQuantityUnits)
              DropdownMenuItem(value: unit, child: Text(unit)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _quantityUnit = value);
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.add_a_photo_outlined, size: 16),
          label: Text(
            _photo == null ? 'Attach photo (optional)' : _photo!.name,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: _isAnalysing ? null : _validateFood,
            icon: _isAnalysing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(
              _isAnalysing ? 'Analysing with Gemini…' : 'Validate with Gemini',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_analysis != null) ...[
          const SizedBox(height: 14),
          _buildAnalysisResult(_analysis!),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _analysis == null ? null : _saveEntry,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text(
              'Save to this slot',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _editorField(
          label: 'WATER QUANTITY (ML)',
          controller: _waterController,
          hint: 'e.g., 250',
          icon: Icons.water_drop_outlined,
          numeric: true,
        ),
        const SizedBox(height: 12),
        Text(
          'Saved water is deducted from your daily water intake goal.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _saveEntry,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text(
              'Save to this slot',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _editorField(
                label: 'SLEEP HOURS',
                controller: _sleepHoursController,
                hint: 'e.g., 7',
                icon: Icons.bedtime_outlined,
                numeric: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _editorField(
                label: 'SLEEP MINUTES',
                controller: _sleepMinutesController,
                hint: 'e.g., 30',
                icon: Icons.schedule,
                numeric: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Rest tracks sleep in this time slot and counts towards daily and '
          'weekly sleep totals.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _saveEntry,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text(
              'Save to this slot',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _editorField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool numeric = false,
    String? suffixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 17),
            suffixText: suffixText,
            suffixStyle: suffixText == null
                ? null
                : GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisResult(FoodAnalysis analysis) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  analysis.foodItem,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
              ),
              Text(
                '${analysis.calories} kcal',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${analysis.foodType} • ${analysis.quantity}',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
          ),
          if (analysis.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              analysis.summary,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlate,
                height: 1.4,
              ),
            ),
          ],
          if (analysis.nutrients.isNotEmpty) ...[
            const SizedBox(height: 10),
            _sectionLabel('NUTRIENTS'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final nutrient in analysis.nutrients)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orangeSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${nutrient.name}: ${nutrient.amount}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.rose),
          const SizedBox(width: 8),
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
        ],
      ),
    );
  }

  Widget _buildEntryRow(DietEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            entry.type == DietActivityType.food
                ? Icons.restaurant_menu
                : entry.type == DietActivityType.water
                ? Icons.water_drop_outlined
                : Icons.bedtime_outlined,
            size: 15,
            color: AppColors.primaryOrange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                Text(
                  entry.detail,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSlate,
                  ),
                ),
              ],
            ),
          ),
          Text(
            entry.type == DietActivityType.food
                ? '${entry.calories} kcal'
                : entry.type == DietActivityType.water
                ? '${entry.waterMl} ml'
                : _formatSleep(entry.sleepMinutes),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.emerald,
            ),
          ),
          InkWell(
            onTap: () => _store.removeEntry(_selectedDate, entry.id),
            child: Icon(Icons.delete_outline, size: 16, color: AppColors.rose),
          ),
        ],
      ),
    );
  }
}
