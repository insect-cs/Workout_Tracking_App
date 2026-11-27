import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Details of the latest GitHub release, ready to show to the user.
@immutable
class AppUpdate {
  const AppUpdate({
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.apkUrl,
    required this.isNewer,
  });

  /// Tag name with a leading `v` removed, e.g. `1.0.0`.
  final String latestVersion;
  final String releaseName;
  final String releaseNotes;
  final String releaseUrl;

  /// Browser-download URL of the first `.apk` asset, when one exists.
  final String? apkUrl;

  /// True when the release is newer than [UpdateService.currentVersion].
  final bool isNewer;
}

/// Signature used by the login screen so tests can inject a fake response.
typedef UpdateChecker = Future<AppUpdate> Function();

/// Checks the project's GitHub Releases feed for a newer app version.
abstract final class UpdateService {
  static const String owner = 'insect-cs';
  static const String repo = 'Workout_Tracking_App';

  /// Keep in sync with `version:` in `pubspec.yaml` (build number excluded).
  /// This used to lag behind the released APK, so a v1.2.0 build kept offering
  /// the same v1.2.0 release as an update. `update_service_test.dart` now
  /// asserts this value matches pubspec.yaml.
  static const String currentVersion = '1.3.0';

  static const String releasesPage = 'https://github.com/$owner/$repo/releases';
  static const String _latestReleaseApi =
      'https://api.github.com/repos/$owner/$repo/releases/latest';
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetches the latest release. Throws on network/API/JSON errors so the
  /// caller can show a friendly "could not check" message.
  static Future<AppUpdate> check({http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(
            Uri.parse(_latestReleaseApi),
            headers: const {
              'Accept': 'application/vnd.github+json',
              // GitHub rejects API requests without a User-Agent.
              'User-Agent': 'Workout-Tracking-App',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('GitHub returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected GitHub response');
      }

      final tag = (decoded['tag_name'] as String? ?? '').trim();
      final latest = tag.isEmpty ? currentVersion : stripPrefix(tag);
      final assets = decoded['assets'] as List<dynamic>? ?? const [];
      String? apkUrl;
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = asset['browser_download_url'] as String?;
        if (name.endsWith('.apk') && url != null) {
          apkUrl = url;
          break;
        }
      }

      return AppUpdate(
        latestVersion: latest,
        releaseName: (decoded['name'] as String? ?? '').trim(),
        releaseNotes: (decoded['body'] as String? ?? '').trim(),
        releaseUrl: (decoded['html_url'] as String? ?? releasesPage).trim(),
        apkUrl: apkUrl,
        isNewer: compareVersions(latest, currentVersion) > 0,
      );
    } finally {
      // Only close clients we created; injected (test) clients are reused.
      if (client == null) httpClient.close();
    }
  }

  /// Removes a leading `v`/`V` and any `+build` suffix from a version string.
  static String stripPrefix(String version) {
    final trimmed = version.trim();
    final withoutV = RegExp(r'^[vV]').hasMatch(trimmed)
        ? trimmed.substring(1)
        : trimmed;
    return withoutV.split('+').first;
  }

  /// Returns 1 if [a] is newer, -1 if [b] is newer, 0 if equal.
  static int compareVersions(String a, String b) {
    final left = _parts(a);
    final right = _parts(b);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final av = i < left.length ? left[i] : 0;
      final bv = i < right.length ? right[i] : 0;
      if (av != bv) return av > bv ? 1 : -1;
    }
    return 0;
  }

  static List<int> _parts(String version) =>
      stripPrefix(version)
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList(growable: false);

  /// Opens the APK asset when available, otherwise the release page.
  static Future<bool> openRelease(AppUpdate update) async {
    final url = update.apkUrl ?? update.releaseUrl;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;

    if (kIsWeb) {
      return _tryLaunch(
        () => launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        ),
      );
    }
    // Android 11+ needs the <queries> entries in the manifest for this to work.
    for (final mode in [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      if (await _tryLaunch(() => launchUrl(uri, mode: mode))) return true;
    }
    return false;
  }

  static Future<bool> _tryLaunch(Future<bool> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return false;
    }
  }
}
