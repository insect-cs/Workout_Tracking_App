import '../models/plan_models.dart';
import 'local_store.dart';

/// Device-local history for plans explicitly saved from the Plan result view.
///
/// It uses the ordinary namespaced [LocalStore], so a guest and a new user can
/// never see each other's saved plans. Session deletion removes the namespace
/// and therefore this history as well.
abstract final class PlanHistoryStore {
  static const String key = 'workout_app.plan_history.v1';

  /// Returns saved plans newest first.
  static List<SavedPlanEntry> read() {
    final raw = LocalStore.instance.readList(key);
    if (raw == null) return const <SavedPlanEntry>[];

    final entries =
        raw
            .whereType<Map<String, dynamic>>()
            .map(SavedPlanEntry.fromJson)
            .toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return List<SavedPlanEntry>.unmodifiable(entries);
  }

  /// Saves [plan] as a new history entry and returns the persisted entry.
  static Future<SavedPlanEntry> save(GeneratedPlan plan) async {
    final entry = SavedPlanEntry(
      id: 'saved-plan-${DateTime.now().microsecondsSinceEpoch}',
      plan: plan,
      savedAt: DateTime.now(),
    );
    final entries = <SavedPlanEntry>[entry, ...read()];
    await _write(entries);
    return entry;
  }

  static Future<void> remove(String id) async {
    await _write(read().where((entry) => entry.id != id).toList());
  }

  static Future<void> _write(List<SavedPlanEntry> entries) {
    return LocalStore.instance.write(
      key,
      entries.map((entry) => entry.toJson()).toList(),
    );
  }
}
