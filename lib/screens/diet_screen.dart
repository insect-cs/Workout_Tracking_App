import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diet_models.dart';
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
  final TextEditingController _calorieGoalController = TextEditingController(
    text: '2000',
  );
  final TextEditingController _waterGoalController = TextEditingController(
    text: '2500',
  );

  late DateTime _selectedDate;
  int? _selectedHour;
  DietActivityType _activityType = DietActivityType.food;
  String _foodType = 'Veg';
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
    _calorieGoalController.dispose();
    _waterGoalController.dispose();
    super.dispose();
  }

  void _syncGoalControllers() {
    final day = _store.day(_selectedDate);
    _calorieGoalController.text = '${day.calorieGoal}';
    _waterGoalController.text = '${day.waterGoalMl}';
  }

  String get _formattedDate =>
      '${_weekdays[_selectedDate.weekday - 1]}, '
      '${_months[_selectedDate.month - 1]} ${_selectedDate.day}, '
      '${_selectedDate.year}';

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
    _foodType = _foodTypes.first;
    _photo = null;
    _analysis = null;
    _isAnalysing = false;
    _error = null;
  }

  bool _updateGoals() {
    final calorieGoal = int.tryParse(_calorieGoalController.text.trim());
    final waterGoal = int.tryParse(_waterGoalController.text.trim());
    if (calorieGoal == null ||
        calorieGoal <= 0 ||
        waterGoal == null ||
        waterGoal <= 0) {
      return false;
    }
    _store.setGoals(
      _selectedDate,
      calorieGoal: calorieGoal,
      waterGoalMl: waterGoal,
    );
    return true;
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
    final quantity = _quantityController.text.trim();
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
        photoName: _photo?.name,
        analysis: analysis,
        createdAt: DateTime.now(),
      );
    } else {
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
                          'Tap a one-hour slot to add a food or water activity.',
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
    return InkWell(
      onTap: () => _selectHour(hour),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : AppColors.border,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.onPrimary : AppColors.textWhite,
              ),
            ),
            if (entryCount > 0)
              Positioned(
                right: 5,
                top: 5,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.onPrimary : AppColors.emerald,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
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
          const SizedBox(height: 12),
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
                          : 'Enter positive numbers for both goals',
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
        ],
      ),
    );
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
    required String unit,
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
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlate,
              ),
            ),
            const Spacer(),
            Text(
              '$value $unit',
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
          else
            _buildWaterEditor(),
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

  Widget _editorField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool numeric = false,
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
                : Icons.water_drop_outlined,
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
                : '${entry.waterMl} ml',
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
