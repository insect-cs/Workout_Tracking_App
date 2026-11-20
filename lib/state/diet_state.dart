import 'dart:async';

import 'package:flutter/material.dart';

import '../models/diet_models.dart';
import '../services/local_store.dart';

/// Device-local store for daily diet goals and saved slot activities. A single
/// shared instance keeps entries when the user switches bottom-nav tabs and
/// restores them after an app restart.
class DietState extends ChangeNotifier {
  DietState();

  static final DietState instance = DietState();

  static const String _storeKey = 'workout_app.diet_state.v1';

  final Map<String, DietDay> _days = {};
  bool _loaded = false;

  static String keyFor(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await LocalStore.instance.ensureLoaded();
    final saved = LocalStore.instance.readMap(_storeKey);
    if (saved == null) return;
    saved.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _days[key] = DietDay.fromJson(value);
      }
    });
    notifyListeners();
  }

  /// Reloads the active session's days, dropping the previous user's cache.
  Future<void> reload() async {
    _days.clear();
    _loaded = false;
    await ensureLoaded();
    notifyListeners();
  }

  Future<void> _persist() {
    return LocalStore.instance.write(
      _storeKey,
      _days.map((key, day) => MapEntry(key, day.toJson())),
    );
  }

  DietDay day(DateTime date) =>
      _days.putIfAbsent(keyFor(date), () => const DietDay());

  void setGoals(DateTime date, {int? calorieGoal, int? waterGoalMl}) {
    final current = day(date);
    _days[keyFor(date)] = DietDay(
      calorieGoal: calorieGoal ?? current.calorieGoal,
      waterGoalMl: waterGoalMl ?? current.waterGoalMl,
      entries: current.entries,
    );
    unawaited(_persist());
    notifyListeners();
  }

  void addEntry(DateTime date, DietEntry entry) {
    final current = day(date);
    _days[keyFor(date)] = DietDay(
      calorieGoal: current.calorieGoal,
      waterGoalMl: current.waterGoalMl,
      entries: [...current.entries, entry],
    );
    unawaited(_persist());
    notifyListeners();
  }

  void removeEntry(DateTime date, String id) {
    final current = day(date);
    _days[keyFor(date)] = DietDay(
      calorieGoal: current.calorieGoal,
      waterGoalMl: current.waterGoalMl,
      entries: current.entries.where((entry) => entry.id != id).toList(),
    );
    unawaited(_persist());
    notifyListeners();
  }

  /// Test helper: clears all stored days.
  void reset() {
    _days.clear();
    unawaited(_persist());
    notifyListeners();
  }
}
