import '../models/calories_models.dart';
import 'local_store.dart';

/// Device-local history for calorie and BMI responses explicitly saved from a
/// result view.
///
/// It uses the ordinary namespaced [LocalStore], so a guest and a new user can
/// never see each other's saved responses. Session deletion removes the
/// namespace and therefore this history as well.
abstract final class CalorieHistoryStore {
  static const String key = 'workout_app.calories_history.v1';
  static int _sequence = 0;

  /// Returns saved responses newest first.
  static List<SavedCalorieEntry> read() {
    final raw = LocalStore.instance.readList(key);
    if (raw == null) return const <SavedCalorieEntry>[];

    final entries =
        raw
            .whereType<Map<String, dynamic>>()
            .map(SavedCalorieEntry.fromJson)
            .toList()
          ..sort((a, b) {
            final byDate = b.savedAt.compareTo(a.savedAt);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
    return List<SavedCalorieEntry>.unmodifiable(entries);
  }

  /// Saves [result] as a new weekly estimate history entry.
  static Future<SavedCalorieEntry> saveWeekly(WeeklyCalorieEstimate result) =>
      _save(weekly: result);

  /// Saves [result] as a new BMI result history entry.
  static Future<SavedCalorieEntry> saveBmi(BmiEstimate result) =>
      _save(bmi: result);

  static Future<SavedCalorieEntry> _save({
    WeeklyCalorieEstimate? weekly,
    BmiEstimate? bmi,
  }) async {
    final now = DateTime.now();
    final kind = weekly != null ? 'weekly' : 'bmi';
    final entry = SavedCalorieEntry(
      id: 'saved-calorie-$kind-${now.microsecondsSinceEpoch}-${++_sequence}',
      weekly: weekly,
      bmi: bmi,
      savedAt: now,
    );
    await _write(<SavedCalorieEntry>[entry, ...read()]);
    return entry;
  }

  static Future<void> remove(String id) {
    return _write(read().where((entry) => entry.id != id).toList());
  }

  static Future<void> _write(List<SavedCalorieEntry> entries) {
    return LocalStore.instance.write(
      key,
      entries.map((entry) => entry.toJson()).toList(),
    );
  }
}
