import 'dart:async';

import 'package:flutter/material.dart';

import '../models/diet_models.dart';
import '../services/local_store.dart';

/// Device-local store for daily/weekly diet goals and saved slot activities.
/// A single shared instance keeps entries when the user switches bottom-nav
/// tabs and restores them after an app restart.
class DietState extends ChangeNotifier {
  DietState();

  static final DietState instance = DietState();

  static const String _storeKey = 'workout_app.diet_state.v1';
  static const String _weekStoreKey = 'workout_app.diet_weekly_goals.v1';

  final Map<String, DietDay> _days = {};
  final Map<String, DietWeekGoals> _weekGoals = {};
  bool _loaded = false;

  static String keyFor(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Key of the Monday of the week containing [date].
  static String weekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return keyFor(DateTime(monday.year, monday.month, monday.day));
  }

  /// The seven dates (Monday - Sunday) of the week containing [date].
  static List<DateTime> weekDates(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await LocalStore.instance.ensureLoaded();

    final savedDays = LocalStore.instance.readMap(_storeKey);
    if (savedDays != null) {
      savedDays.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          _days[key] = DietDay.fromJson(value);
        }
      });
    }

    final savedWeeks = LocalStore.instance.readMap(_weekStoreKey);
    if (savedWeeks != null) {
      savedWeeks.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          _weekGoals[key] = DietWeekGoals.fromJson(value);
        }
      });
    }
    notifyListeners();
  }

  /// Reloads the active session's data, dropping the previous user's cache.
  Future<void> reload() async {
    _days.clear();
    _weekGoals.clear();
    _loaded = false;
    await ensureLoaded();
    notifyListeners();
  }

  Future<void> _persistDays() {
    return LocalStore.instance.write(
      _storeKey,
      _days.map((key, day) => MapEntry(key, day.toJson())),
    );
  }

  Future<void> _persistWeekGoals() {
    return LocalStore.instance.write(
      _weekStoreKey,
      _weekGoals.map((key, goals) => MapEntry(key, goals.toJson())),
    );
  }

  DietDay day(DateTime date) =>
      _days.putIfAbsent(keyFor(date), () => const DietDay());

  void setGoals(
    DateTime date, {
    int? calorieGoal,
    int? waterGoalMl,
    int? restGoalMinutes,
  }) {
    final current = day(date);
    _days[keyFor(date)] = DietDay(
      calorieGoal: calorieGoal ?? current.calorieGoal,
      waterGoalMl: waterGoalMl ?? current.waterGoalMl,
      restGoalMinutes: restGoalMinutes ?? current.restGoalMinutes,
      entries: current.entries,
    );
    unawaited(_persistDays());
    notifyListeners();
  }

  void addEntry(DateTime date, DietEntry entry) {
    final current = day(date);
    _days[keyFor(date)] = DietDay(
      calorieGoal: current.calorieGoal,
      waterGoalMl: current.waterGoalMl,
      restGoalMinutes: current.restGoalMinutes,
      entries: [...current.entries, entry],
    );
    unawaited(_persistDays());
    notifyListeners();
  }

  void removeEntry(DateTime date, String id) {
    final current = day(date);
    _days[keyFor(date)] = DietDay(
      calorieGoal: current.calorieGoal,
      waterGoalMl: current.waterGoalMl,
      restGoalMinutes: current.restGoalMinutes,
      entries: current.entries.where((entry) => entry.id != id).toList(),
    );
    unawaited(_persistDays());
    notifyListeners();
  }

  /// Weekly goals for the week containing [date]. Until the user saves their
  /// own targets, the default is seven times the Monday daily goal.
  DietWeekGoals weekGoals(DateTime date) {
    final stored = _weekGoals[weekKey(date)];
    if (stored != null) return stored;
    final monday = day(weekDates(date).first);
    return DietWeekGoals(
      calorieGoal: monday.calorieGoal * 7,
      waterGoalMl: monday.waterGoalMl * 7,
      restGoalMinutes: monday.restGoalMinutes * 7,
    );
  }

  void setWeekGoals(
    DateTime date, {
    int? calorieGoal,
    int? waterGoalMl,
    int? restGoalMinutes,
  }) {
    final current = weekGoals(date);
    _weekGoals[weekKey(date)] = current.copyWith(
      calorieGoal: calorieGoal,
      waterGoalMl: waterGoalMl,
      restGoalMinutes: restGoalMinutes,
    );
    unawaited(_persistWeekGoals());
    notifyListeners();
  }

  /// Totals consumed across the whole week containing [date]. Every saved
  /// daily activity is deducted from the weekly goals.
  ({int calories, int waterMl, int sleepMinutes}) weekConsumed(DateTime date) {
    var calories = 0;
    var waterMl = 0;
    var sleepMinutes = 0;
    for (final weekDate in weekDates(date)) {
      final stored = _days[keyFor(weekDate)];
      if (stored == null) continue;
      calories += stored.caloriesConsumed;
      waterMl += stored.waterConsumedMl;
      sleepMinutes += stored.sleepMinutes;
    }
    return (calories: calories, waterMl: waterMl, sleepMinutes: sleepMinutes);
  }

  /// All stored days, oldest first.
  List<({DateTime date, DietDay day})> get daySnapshots {
    final sorted = _days.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((item) {
      final parts = item.key.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return (date: date, day: item.value);
    }).toList();
  }

  /// Snapshot of every activity recorded up to now, used by the summary UI
  /// and its CSV/PDF exports.
  DietSummary buildSummary(DateTime date) {
    final now = DateTime.now();
    final snapshots = daySnapshots
        .where((item) => !item.date.isAfter(now))
        .toList();
    final days = snapshots
        .map((item) => DietSummaryDay.fromDietDay(item.date, item.day))
        .toList();

    final entries = <DietSummaryEntry>[];
    for (final item in snapshots) {
      for (final entry in item.day.entries) {
        entries.add(DietSummaryEntry(date: item.date, entry: entry));
      }
    }
    entries.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final bySlot = a.entry.slotHour.compareTo(b.entry.slotHour);
      if (bySlot != 0) return bySlot;
      return a.entry.createdAt.compareTo(b.entry.createdAt);
    });

    final goals = weekGoals(date);
    return DietSummary(
      generatedAt: DateTime.now(),
      scope: 'All activities up to now',
      weekCalorieGoal: goals.calorieGoal,
      weekWaterGoalMl: goals.waterGoalMl,
      weekRestGoalMinutes: goals.restGoalMinutes,
      days: days,
      entries: entries,
    );
  }

  /// Test helper: clears all stored days and weekly goals.
  void reset() {
    _days.clear();
    _weekGoals.clear();
    unawaited(_persistDays());
    unawaited(_persistWeekGoals());
    notifyListeners();
  }
}
