import 'package:flutter/foundation.dart';

import '../services/api_key_service.dart';
import '../services/local_store.dart';
import '../theme/theme_controller.dart';
import 'diet_state.dart';
import 'guest_seed.dart';
import 'workout_state.dart';

enum SessionKind { guest, newUser }

String _storageName(SessionKind kind) => kind == SessionKind.guest
    ? LocalStore.guestNamespace
    : LocalStore.newUserNamespace;

SessionKind? _kindFromStorage(Object? value) {
  if (value == LocalStore.guestNamespace) return SessionKind.guest;
  if (value == LocalStore.newUserNamespace) return SessionKind.newUser;
  return null;
}

/// Enforces the app's single-user rule.
///
/// Exactly one session may exist on the device. A signed-out session remains
/// on disk (so the login screen can offer to delete it), and only after it is
/// deleted can a different guest or new-user session be created.
abstract final class SessionState {
  static final ValueNotifier<SessionKind?> kind = ValueNotifier<SessionKind?>(
    null,
  );
  static final ValueNotifier<bool> signedIn = ValueNotifier<bool>(false);

  /// Name chosen by a new user. Stored with the session so it survives a
  /// sign-out and a full app restart.
  static final ValueNotifier<String> displayName = ValueNotifier<String>('');

  static Map<String, dynamic>? _session;

  static bool get hasSession => _session != null;
  static bool get isSignedIn => signedIn.value;
  static bool get canSignIn => _session == null;

  /// Display name for the signed-in profile, or an empty string for guests.
  static String get name => displayName.value;

  static Future<void> ensureLoaded() async {
    await LocalStore.instance.ensureLoaded();
    _session = LocalStore.instance.readGlobalMap(LocalStore.sessionKey);
    final restored = _kindFromStorage(_session?['kind']);
    LocalStore.instance.setNamespace(
      restored == null ? LocalStore.guestNamespace : _storageName(restored),
    );
    kind.value = restored;
    signedIn.value = _session?['signedIn'] == true;
    displayName.value = restored == SessionKind.newUser
        ? (_session?['name'] as String? ?? '')
        : '';
  }

  /// Creates the only allowed session. Returns false if one already exists.
  /// [name] is the display name entered by a new user on the welcome page.
  static Future<bool> signIn(SessionKind selected, {String? name}) async {
    if (_session != null) return false;

    final namespace = _storageName(selected);
    final otherNamespace = selected == SessionKind.guest
        ? LocalStore.newUserNamespace
        : LocalStore.guestNamespace;

    // Only one profile's data may exist at a time.
    await LocalStore.instance.deleteNamespace(otherNamespace);
    if (selected == SessionKind.newUser) {
      await LocalStore.instance.deleteNamespace(namespace);
      await ApiKeyStore.instance.clear();
    }

    LocalStore.instance.setNamespace(namespace);
    if (selected == SessionKind.guest) {
      await GuestSeed.ensureSeeded();
    }
    await _reloadAppState(selected);

    final storedName = selected == SessionKind.newUser
        ? (name?.trim() ?? '')
        : '';
    _session = {
      'kind': namespace,
      'signedIn': true,
      'name': storedName,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await LocalStore.instance.writeGlobal(LocalStore.sessionKey, _session);
    kind.value = selected;
    displayName.value = storedName;
    signedIn.value = true;
    await LocalStore.instance.flush();
    return true;
  }

  /// Keeps the session on disk but returns the app to the login gate.
  static Future<void> signOut() async {
    if (_session == null) return;
    _session = {..._session!, 'signedIn': false};
    await LocalStore.instance.writeGlobal(LocalStore.sessionKey, _session);
    signedIn.value = false;
    await LocalStore.instance.flush();
  }

  /// Reopens the saved session after a sign-out without deleting any data and
  /// without creating a new guest/new-user profile. Returns false when there is
  /// no valid saved session to restore.
  static Future<bool> resumeSession() async {
    final saved = _session;
    if (saved == null || signedIn.value) return false;
    final restored = _kindFromStorage(saved['kind']);
    if (restored == null) return false;

    LocalStore.instance.setNamespace(_storageName(restored));
    await _reloadAppState(restored);

    final restoredName = restored == SessionKind.newUser
        ? (saved['name'] as String? ?? '')
        : '';
    _session = {...saved, 'signedIn': true};
    await LocalStore.instance.writeGlobal(LocalStore.sessionKey, _session);
    kind.value = restored;
    displayName.value = restoredName;
    signedIn.value = true;
    await LocalStore.instance.flush();
    return true;
  }

  /// Permanently removes the only session and all of its local data.
  static Future<void> deleteSession() async {
    if (_session == null) return;
    await LocalStore.instance.deleteNamespace(LocalStore.guestNamespace);
    await LocalStore.instance.deleteNamespace(LocalStore.newUserNamespace);
    await ApiKeyStore.instance.clear();
    await LocalStore.instance.deleteGlobal(LocalStore.sessionKey);
    _session = null;
    kind.value = null;
    displayName.value = '';
    signedIn.value = false;
    LocalStore.instance.setNamespace(LocalStore.guestNamespace);
    await LocalStore.instance.flush();
  }

  static Future<void> _reloadAppState(SessionKind selected) async {
    await Future.wait([
      WorkoutState.instance.reload(withDemoData: selected == SessionKind.guest),
      DietState.instance.reload(),
      ThemeController.reload(),
      ApiKeyStore.instance.ensureLoaded(),
    ]);
  }

  /// Test helper: clears notifiers without touching persisted data.
  static void resetForTesting() {
    _session = null;
    kind.value = null;
    displayName.value = '';
    signedIn.value = false;
    LocalStore.instance.setNamespace(LocalStore.guestNamespace);
  }
}
