import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens exercise demonstration videos reliably on Android.
///
/// Android 11+ hides other apps from `canLaunchUrl` unless they are declared in
/// the manifest's `<queries>`, so checking first made perfectly valid
/// YouTube/browser URLs look unlaunchable. This helper simply attempts the
/// launch, falls back from the YouTube app to the default browser, and only
/// reports failure when every option has been tried.
abstract final class VideoLaunchService {
  static Future<bool> open(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return Future.value(false);
    if (kIsWeb) {
      return _try(
        () => launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        ),
      );
    }

    return _openNative(uri);
  }

  static Future<bool> _openNative(Uri uri) async {
    final videoId = _youtubeVideoId(uri);
    if (videoId != null) {
      // Prefer the native YouTube app when it is installed.
      final appUri = Uri.parse('vnd.youtube://$videoId');
      if (await _try(
        () => launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication),
      )) {
        return true;
      }
    }

    // External application covers Chrome / YouTube; platformDefault opens an
    // in-app browser tab when no external handler is available.
    for (final mode in [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      if (await _try(() => launchUrl(uri, mode: mode))) return true;
    }
    return false;
  }

  static Future<bool> _try(Future<bool> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return false;
    }
  }

  /// Supports the watch, youtu.be, embed and shorts forms of a YouTube link.
  static String? _youtubeVideoId(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be') {
      final id = uri.pathSegments.where((part) => part.isNotEmpty).firstOrNull;
      return id != null && id.length >= 8 ? id : null;
    }
    if (host == 'www.youtube.com' ||
        host == 'youtube.com' ||
        host == 'm.youtube.com') {
      if (uri.path == '/watch') {
        final id = uri.queryParameters['v'];
        return id != null && id.length >= 8 ? id : null;
      }
      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          (segments.first == 'embed' || segments.first == 'shorts')) {
        final id = segments[1];
        return id.length >= 8 ? id : null;
      }
    }
    return null;
  }
}
