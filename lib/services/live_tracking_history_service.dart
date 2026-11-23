import 'package:flutter/foundation.dart';

import '../models/pose_history_models.dart';
import 'local_store.dart';

/// Device-local, session-scoped history of completed live tracking sessions.
///
/// Uses the ordinary namespaced [LocalStore], so guest and new-user profiles
/// cannot see each other's history and deleting a session removes it too.
abstract final class LiveTrackingHistoryStore {
  static const String key = 'workout_app.live_tracking_history.v1';

  /// Bumped whenever the history changes so open screens can refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Returns saved sessions newest first.
  static List<LiveTrackingSession> read() {
    final raw = LocalStore.instance.readList(key);
    if (raw == null) return const <LiveTrackingSession>[];

    final sessions =
        raw
            .whereType<Map<String, dynamic>>()
            .map(LiveTrackingSession.fromJson)
            .toList()
          ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return List<LiveTrackingSession>.unmodifiable(sessions);
  }

  static Future<LiveTrackingSession> save(LiveTrackingSession session) async {
    final sessions = <LiveTrackingSession>[session, ...read()];
    await _write(sessions);
    revision.value++;
    return session;
  }

  static Future<void> remove(String id) async {
    await _write(read().where((session) => session.id != id).toList());
    revision.value++;
  }

  static Future<void> clear() async {
    await _write(const <LiveTrackingSession>[]);
    revision.value++;
  }

  static Future<void> _write(List<LiveTrackingSession> sessions) {
    return LocalStore.instance.write(
      key,
      sessions.map((session) => session.toJson()).toList(),
    );
  }
}
