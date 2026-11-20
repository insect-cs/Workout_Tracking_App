import 'package:flutter/material.dart';

import '../models/diet_models.dart';

/// In-memory store for daily diet goals and saved slot activities. A single
/// shared instance keeps entries when the user switches bottom-nav tabs.
class DietState extends ChangeNotifier {
  static final DietState instance = DietState();

  final Map<String, DietDay> _days = {};

  static String keyFor(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  DietDay day(DateTime date) =>
      _days.putIfAbsent(keyFor(date), () => const DietDay());

  void setGoals(DateTime date, {int? calorieGoal, int? waterGoalMl}) {
    final current = day(date);
    _days[keyFor(date)] = DietDay(
      calorieGoal: calorieGoal ?? current.calorieGoal,
      waterGoalMl: waterGoalMl ?? current.waterGoalMl,
      entries: current.entries,
    );
    notifyListeners();
  }

  void addEntry(DateTime date, DietEntry entry) {
    final current = day(date);
    _days[keyFor(date)] = DietDay(
      calorieGoal: current.calorieGoal,
      waterGoalMl: current.waterGoalMl,
      entries: [...current.entries, entry],
    );
    notifyListeners();
  }

  void removeEntry(DateTime date, String id) {
    final current = day(date);
    _days[keyFor(date)] = DietDay(
      calorieGoal: current.calorieGoal,
      waterGoalMl: current.waterGoalMl,
      entries: current.entries.where((entry) => entry.id != id).toList(),
    );
    notifyListeners();
  }

  /// Test helper: clears all stored days.
  void reset() {
    _days.clear();
    notifyListeners();
  }
}
