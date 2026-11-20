import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Device-local storage for all ordinary app data.
///
/// API keys and the AES key that encrypts this Hive box are kept in
/// `flutter_secure_storage`. Everything else is JSON in an encrypted Hive CE
/// box. Raw values are mirrored in memory so screens can restore their state
/// synchronously after [ensureLoaded] has run at startup.
///
/// Data is namespaced per session. Only one session (guest or new user) can be
/// active at a time; [setNamespace] selects which user's data logical keys
/// resolve to. Global keys such as the session marker bypass namespacing.
class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  static const String _boxName = 'workout_app_local_v1';
  static const String _hiveKeyName = 'workout_app.hive_aes_key.v1';
  static const String prefix = 'workout_app.';
  static const String sessionKey = '${prefix}session.v1';
  static const Set<String> _globalKeys = {sessionKey};

  static const String guestNamespace = 'guest';
  static const String newUserNamespace = 'new_user';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Box<String>? _box;
  final Map<String, String> _values = <String, String>{};
  String _namespace = guestNamespace;
  bool _loaded = false;
  bool _testMode = false;

  String get namespace => _namespace;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    if (_testMode) return;

    try {
      await Hive.initFlutter();
      final key = await _loadOrCreateHiveKey();
      _box = await _openBox(key);
      await _migrateLegacyKeysToGuest();
      for (final boxKey in _box!.keys) {
        final value = _box!.get(boxKey);
        if (value is String) _values[boxKey.toString()] = value;
      }
    } catch (e) {
      debugPrint('Encrypted local storage unavailable, using memory only: $e');
    }
  }

  /// Moves data written before session namespacing existed into the guest
  /// session. That data came from the pre-release test runs, so it belongs to
  /// the guest profile.
  Future<void> _migrateLegacyKeysToGuest() async {
    final legacyKeys = _box!.keys.where((key) {
      final raw = key.toString();
      return raw.startsWith(prefix) &&
          !_globalKeys.contains(raw) &&
          !raw.startsWith('${prefix}guest.') &&
          !raw.startsWith('${prefix}new_user.');
    }).toList();

    for (final key in legacyKeys) {
      final raw = _box!.get(key);
      if (raw is! String) continue;
      final suffix = key.toString().substring(prefix.length);
      await _box!.put('${prefix}guest.$suffix', raw);
      await _box!.delete(key);
    }
  }

  Future<Box<String>> _openBox(List<int> key) async {
    try {
      return await Hive.openBox<String>(
        _boxName,
        encryptionCipher: HiveAesCipher(key),
      );
    } on HiveError {
      // The secure key was lost or replaced but the Hive file still exists.
      // Recover with a fresh encrypted box instead of leaving the app unusable.
      await Hive.deleteBoxFromDisk(_boxName);
      final freshKey = Hive.generateSecureKey();
      await _saveHiveKey(freshKey);
      return Hive.openBox<String>(
        _boxName,
        encryptionCipher: HiveAesCipher(freshKey),
      );
    }
  }

  Future<List<int>> _loadOrCreateHiveKey() async {
    final stored = await _secureStorage.read(key: _hiveKeyName);
    if (stored != null) {
      try {
        final decoded = base64Decode(stored);
        if (decoded.length == 32) return decoded;
      } catch (_) {
        // Fall through and generate a valid key below.
      }
    }

    final key = Hive.generateSecureKey();
    await _saveHiveKey(key);
    return key;
  }

  Future<void> _saveHiveKey(List<int> key) {
    return _secureStorage.write(key: _hiveKeyName, value: base64Encode(key));
  }

  /// Selects the active user's data partition.
  void setNamespace(String namespace) => _namespace = namespace;

  /// Removes every stored value for [namespace], including its stale cache.
  Future<void> deleteNamespace(String namespace) async {
    await ensureLoaded();
    final target = '$prefix$namespace.';
    final keys = <String>{
      ..._values.keys.where((key) => key.startsWith(target)),
      ...?_box?.keys
          .map((key) => key.toString())
          .where((key) => key.startsWith(target)),
    };
    for (final key in keys) {
      _values.remove(key);
      try {
        await _box?.delete(key);
      } catch (e) {
        debugPrint('Could not delete local value $key: $e');
      }
    }
  }

  Map<String, dynamic>? readMap(String key) => _decode(_raw(_scoped(key)));

  List<dynamic>? readList(String key) {
    final raw = _raw(_scoped(key));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List<dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String? readString(String key) => _raw(_scoped(key));

  int? readInt(String key) {
    final raw = _raw(_scoped(key));
    return raw == null ? null : int.tryParse(raw);
  }

  bool? readBool(String key) {
    final raw = _raw(_scoped(key));
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    return null;
  }

  Future<void> write(String key, Object? value) => _write(_scoped(key), value);

  /// Session metadata is global: it must survive switching user namespaces.
  Map<String, dynamic>? readGlobalMap(String key) => _decode(_raw(key));

  Future<void> writeGlobal(String key, Object? value) => _write(key, value);

  Future<void> deleteGlobal(String key) => _write(key, null);

  Map<String, dynamic>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String rawKey, Object? value) async {
    await ensureLoaded();
    if (value == null) {
      _values.remove(rawKey);
      try {
        await _box?.delete(rawKey);
      } catch (e) {
        debugPrint('Could not remove local value $rawKey: $e');
      }
      return;
    }

    final raw = value is String ? value : jsonEncode(value);
    _values[rawKey] = raw;
    try {
      await _box?.put(rawKey, raw);
    } catch (e) {
      debugPrint('Could not persist local value $rawKey: $e');
    }
  }

  /// Waits for pending Hive writes. Hive CE also flushes on app pause.
  Future<void> flush() => _testMode ? Future<void>.value() : Hive.flush();

  /// Test-only: disables the plugin and clears all cached local values.
  Future<void> resetForTesting() async {
    _testMode = true;
    final box = _box;
    _box = null;
    _values.clear();
    _namespace = guestNamespace;
    _loaded = true;
    if (box != null && box.isOpen) await box.close();
  }

  String _scoped(String key) {
    if (_globalKeys.contains(key)) return key;
    if (!key.startsWith(prefix)) return '$prefix$_namespace.$key';
    return '$prefix$_namespace.${key.substring(prefix.length)}';
  }

  String? _raw(String rawKey) => _values[rawKey] ?? _box?.get(rawKey);
}
