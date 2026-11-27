import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// A Gemini-compatible endpoint. Different models produce noticeably different
/// results, so the active endpoint is stored alongside the key and shown in the
/// Keys page.
class AiEndpoint {
  const AiEndpoint({
    required this.id,
    required this.label,
    required this.provider,
    required this.baseUrl,
    required this.model,
  });

  final String id;
  final String label;
  final String provider;
  final String baseUrl;
  final String model;

  static const String googleBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String customId = 'custom';

  static const List<AiEndpoint> presets = [
    AiEndpoint(
      id: 'gemini-3.1-flash-lite',
      label: 'Gemini 3.1 Flash Lite',
      provider: 'Google AI Studio',
      baseUrl: googleBaseUrl,
      model: 'gemini-3.1-flash-lite',
    ),
    AiEndpoint(
      id: 'gemini-3.8-flash',
      label: 'Gemini 3.8 Flash',
      provider: 'Google AI Studio',
      baseUrl: googleBaseUrl,
      model: 'gemini-3.8-flash',
    ),
    AiEndpoint(
      id: 'gemini-3.5-flash-lite',
      label: 'Gemini 3.5 Flash Lite',
      provider: 'Google AI Studio',
      baseUrl: googleBaseUrl,
      model: 'gemini-3.5-flash-lite',
    ),
    AiEndpoint(
      id: customId,
      label: 'Custom / Bring your own',
      provider: 'Custom endpoint',
      baseUrl: '',
      model: '',
    ),
  ];

  static AiEndpoint byId(String? id) {
    for (final endpoint in presets) {
      if (endpoint.id == id) return endpoint;
    }
    return presets.first;
  }

  /// Builds a custom endpoint from user-supplied values.
  factory AiEndpoint.custom(String baseUrl, String model) => AiEndpoint(
    id: customId,
    label: 'Custom / Bring your own',
    provider: 'Custom endpoint',
    baseUrl: baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
    model: model.trim(),
  );

  /// The URL used for both validation and generation.
  String get generateUrl {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final modelName = model.trim();

    // Custom endpoints are sometimes pasted as a full generateContent URL.
    // Avoid producing `...:generateContent/{model}:generateContent`.
    if (base.endsWith(':generateContent')) return base;
    if (modelName.isEmpty) return base;
    if (base.endsWith('/$modelName')) return '$base:generateContent';
    return '$base/$modelName:generateContent';
  }

  bool get isCustom => id == customId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'provider': provider,
    'baseUrl': baseUrl,
    'model': model,
  };

  factory AiEndpoint.fromJson(Map<String, dynamic> json) => AiEndpoint(
    id: (json['id'] as String?) ?? presets.first.id,
    label: (json['label'] as String?) ?? 'Gemini endpoint',
    provider: (json['provider'] as String?) ?? 'Google AI Studio',
    baseUrl: (json['baseUrl'] as String?) ?? googleBaseUrl,
    model: (json['model'] as String?) ?? presets.first.model,
  );
}

/// One user-supplied key together with the endpoint it belongs to.
class ApiKeyEntry {
  const ApiKeyEntry({
    required this.id,
    required this.key,
    required this.endpoint,
    required this.createdAt,
  });

  final String id;
  final String key;
  final AiEndpoint endpoint;
  final DateTime createdAt;

  /// A fixed-width mask that reveals neither characters nor key length.
  static const String _fullMask = '••••••••••••';

  String get maskedKey => key.isEmpty ? '' : _fullMask;

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'endpoint': endpoint.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory ApiKeyEntry.fromJson(Map<String, dynamic> json) => ApiKeyEntry(
    id:
        (json['id'] as String?) ??
        'key-${DateTime.now().microsecondsSinceEpoch}',
    key: (json['key'] as String?) ?? '',
    endpoint: AiEndpoint.fromJson(
      (json['endpoint'] as Map<String, dynamic>?) ?? {},
    ),
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now(),
  );
}

/// The key + endpoint currently used by every AI feature.
class ActiveAiConfig {
  const ActiveAiConfig({required this.key, required this.endpoint});

  final String key;
  final AiEndpoint endpoint;

  String get generateUrl => endpoint.generateUrl;
}

/// Headers for Gemini-compatible requests.
///
/// The key is sent as `x-goog-api-key` instead of a `?key=` query parameter so
/// browser network errors do not print the secret in the failed request URL.
Map<String, String> geminiHeaders(String key) => {
  'Content-Type': 'application/json',
  'x-goog-api-key': key,
};

/// Thrown when an AI action is attempted without a configured key.
class ApiKeyException implements Exception {
  const ApiKeyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Result of validating a candidate key against its endpoint.
class ValidationResult {
  const ValidationResult._({this.error, this.model});

  final String? error;
  final String? model;
  bool get isValid => error == null;

  static const valid = ValidationResult._();
  static ValidationResult failure(String error) =>
      ValidationResult._(error: error);
  static ValidationResult success(String model) =>
      ValidationResult._(model: model);
}

/// Validates a key by making a tiny real request to the selected endpoint.
class ApiKeyValidator {
  static const String _missingKeyMessage = 'Enter an API key first.';

  static Future<ValidationResult> validate(ApiKeyEntry candidate) async {
    final key = candidate.key.trim();
    if (key.isEmpty) return ValidationResult.failure(_missingKeyMessage);
    final baseUrl = candidate.endpoint.baseUrl.trim();
    final modelName = candidate.endpoint.model.trim();
    if (baseUrl.isEmpty ||
        (modelName.isEmpty && !baseUrl.endsWith(':generateContent'))) {
      return ValidationResult.failure(
        'Enter a valid endpoint base URL and model name.',
      );
    }

    final uri = Uri.parse(candidate.endpoint.generateUrl);
    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: geminiHeaders(key),
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': 'Reply with OK.'},
                  ],
                },
              ],
              'generationConfig': {'maxOutputTokens': 16},
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      return ValidationResult.failure('Could not reach the endpoint: $e');
    }

    if (response.statusCode == 200) {
      return ValidationResult.success(candidate.endpoint.model);
    }

    final message = _errorMessage(response.body);
    final normalized = message.toLowerCase();
    final isAuthProblem =
        response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 400 ||
        normalized.contains('api key') ||
        normalized.contains('api_key') ||
        normalized.contains('expired') ||
        normalized.contains('unauthor');

    if (isAuthProblem) {
      return ValidationResult.failure(
        'This API key is invalid, expired or not authorised. '
        '$message',
      );
    }
    return ValidationResult.failure(
      'Key validation failed (HTTP ${response.statusCode}). $message',
    );
  }

  static String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          return (error['message'] as String?)?.isNotEmpty == true
              ? error['message'] as String
              : 'Unknown error from the endpoint.';
        }
      }
    } catch (_) {
      // Fall through to the raw body.
    }
    final trimmed = body.trim();
    return trimmed.isEmpty ? 'Unknown error from the endpoint.' : trimmed;
  }
}

/// Secure, app-wide storage for user-supplied AI keys. The secure plugin is
/// used when available; an in-memory mirror keeps the store usable in tests
/// and on platforms where the plugin is not yet registered.
class ApiKeyStore with ChangeNotifier {
  ApiKeyStore._();

  static final ApiKeyStore instance = ApiKeyStore._();

  static const String _entriesKey = 'workout_app.ai_keys.v1';
  static const String _activeIdKey = 'workout_app.ai_active_key.v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Map<String, String> _memory = <String, String>{};

  List<ApiKeyEntry> _entries = <ApiKeyEntry>[];
  String? _activeId;
  bool _loaded = false;
  bool _testMode = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    if (!_testMode) {
      try {
        _memory.addAll(await _storage.readAll());
      } catch (e) {
        debugPrint('Secure key storage unavailable, using memory only: $e');
      }
    }
    _decode();
  }

  void _decode() {
    final raw = _memory[_entriesKey];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _entries = decoded
            .whereType<Map<String, dynamic>>()
            .map(ApiKeyEntry.fromJson)
            .toList();
      } catch (_) {
        _entries = <ApiKeyEntry>[];
      }
    }
    _activeId = _memory[_activeIdKey];
    if (_activeId == null && _entries.isNotEmpty) {
      _activeId = _entries.first.id;
    }
    if (_activeId != null && !_entries.any((e) => e.id == _activeId)) {
      _activeId = _entries.isNotEmpty ? _entries.first.id : null;
    }
  }

  Future<void> _persist() async {
    _memory[_entriesKey] = jsonEncode(
      _entries.map((entry) => entry.toJson()).toList(),
    );
    if (_activeId == null) {
      _memory.remove(_activeIdKey);
    } else {
      _memory[_activeIdKey] = _activeId!;
    }
    if (_testMode) return;
    try {
      await _storage.write(key: _entriesKey, value: _memory[_entriesKey]!);
      final id = _activeId;
      if (id == null) {
        await _storage.delete(key: _activeIdKey);
      } else {
        await _storage.write(key: _activeIdKey, value: id);
      }
    } catch (e) {
      debugPrint('Could not persist AI keys to secure storage: $e');
    }
    notifyListeners();
  }

  List<ApiKeyEntry> get entries => List.unmodifiable(_entries);

  ApiKeyEntry? get active {
    if (_activeId == null) return null;
    for (final entry in _entries) {
      if (entry.id == _activeId) return entry;
    }
    return null;
  }

  bool get hasActiveKey {
    final entry = active;
    return entry != null && entry.key.trim().isNotEmpty;
  }

  ActiveAiConfig get activeConfig {
    final entry = active;
    if (entry == null || entry.key.trim().isEmpty) {
      throw const ApiKeyException(
        'No AI API key is configured. Add and validate one in Keys, or when '
        'you use an AI feature.',
      );
    }
    return ActiveAiConfig(key: entry.key.trim(), endpoint: entry.endpoint);
  }

  Future<ActiveAiConfig> requireActiveConfig() async {
    await ensureLoaded();
    return activeConfig;
  }

  Future<ApiKeyEntry> addKey(
    String key,
    AiEndpoint endpoint, {
    bool setActive = true,
  }) async {
    await ensureLoaded();
    final entry = ApiKeyEntry(
      id: 'key-${DateTime.now().microsecondsSinceEpoch}',
      key: key.trim(),
      endpoint: endpoint,
      createdAt: DateTime.now(),
    );
    _entries = [..._entries, entry];
    if (setActive || _activeId == null) _activeId = entry.id;
    await _persist();
    return entry;
  }

  Future<void> setActive(String id) async {
    await ensureLoaded();
    if (!_entries.any((entry) => entry.id == id)) return;
    _activeId = id;
    await _persist();
  }

  Future<void> removeKey(String id) async {
    await ensureLoaded();
    _entries = _entries.where((entry) => entry.id != id).toList();
    if (_activeId == id) {
      _activeId = _entries.isNotEmpty ? _entries.first.id : null;
    }
    await _persist();
  }

  /// Removes every saved key when a local session is deleted.
  Future<void> clear() async {
    await ensureLoaded();
    _entries = <ApiKeyEntry>[];
    _activeId = null;
    _memory.remove(_entriesKey);
    _memory.remove(_activeIdKey);
    if (!_testMode) {
      try {
        await _storage.delete(key: _entriesKey);
        await _storage.delete(key: _activeIdKey);
      } catch (e) {
        debugPrint('Could not clear AI keys from secure storage: $e');
      }
    }
    notifyListeners();
  }

  /// Test-only: disables the plugin and clears all in-memory keys.
  Future<void> resetForTesting() async {
    _testMode = true;
    _memory.clear();
    _entries = <ApiKeyEntry>[];
    _activeId = null;
    _loaded = true;
  }
}
