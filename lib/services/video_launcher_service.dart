import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens exercise demonstration videos reliably on Android.
///
/// YouTube video IDs are case-sensitive. Dart lowercases the host component of
/// a URI, so the previous `vnd.youtube://<id>` deep link rewrote IDs such as
/// `8iPEnn-ltC8` to `8ipenn-ltc8` and YouTube showed "Video unavailable". We now
/// open a canonical `https://www.youtube.com/watch?v=<id>` URL, which keeps the
/// ID in the query string with its original case. That URL opens the YouTube
/// app through Android App Links when installed, and otherwise opens the same
/// page in the browser that works in the web build.
///
/// Android 11+ also hides other apps from `canLaunchUrl` unless they are
/// declared in the manifest's `<queries>`, so this helper attempts the launch
/// directly and only reports failure after every fallback has been tried.
abstract final class VideoLaunchService {
  static const Set<String> _youtubeHosts = <String>{
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
  };
  static final RegExp _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// Opens [url] in the YouTube app or a browser.
  ///
  /// [searchQuery] is used only when the URL is a YouTube link without a valid
  /// video id (for example a hallucinated short watch link), so the user still
  /// lands on usable YouTube results instead of an unavailable video page.
  static Future<bool> open(String url, {String? searchQuery}) {
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

    return _openNative(uri, searchQuery: searchQuery);
  }

  static Future<bool> _openNative(Uri uri, {String? searchQuery}) async {
    final watchUrl = canonicalWatchUrl(uri.toString());
    final Uri target;
    if (watchUrl != null) {
      // Case-sensitive id stays intact in the query string.
      target = Uri.parse(watchUrl);
    } else if (_isYouTubeUri(uri)) {
      target = _searchUri(searchQuery) ?? uri;
    } else {
      target = uri;
    }

    // externalApplication reaches YouTube/browser; platformDefault is the
    // last-resort in-app browser if no external handler is available.
    for (final mode in [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      if (await _try(() => launchUrl(target, mode: mode))) return true;
    }
    return false;
  }

  static Uri? _searchUri(String? query) {
    final trimmed = query?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final encoded = Uri.encodeComponent('$trimmed exercise form tutorial');
    return Uri.parse('https://www.youtube.com/results?search_query=$encoded');
  }

  static bool _isYouTubeUri(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'youtu.be' || _youtubeHosts.contains(host);
  }

  /// Extracts the case-sensitive 11-character video id from watch, youtu.be,
  /// embed and shorts URLs. Returns null for search URLs or malformed ids.
  static String? youTubeVideoId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    String? id;

    if (host == 'youtu.be') {
      if (segments.isNotEmpty) id = segments.first;
    } else if (_youtubeHosts.contains(host)) {
      if (segments.isNotEmpty && segments.first == 'watch') {
        id = uri.queryParameters['v'];
      } else if (segments.length >= 2 &&
          (segments.first == 'embed' || segments.first == 'shorts')) {
        id = segments[1];
      }
    }

    if (id == null || !_videoIdPattern.hasMatch(id)) return null;
    return id;
  }

  /// Returns a canonical watch URL for a direct YouTube video link, or null
  /// when [url] is not a recognised video URL.
  static String? canonicalWatchUrl(String url) {
    final id = youTubeVideoId(url);
    return id == null ? null : 'https://www.youtube.com/watch?v=$id';
  }

  static Future<bool> _try(Future<bool> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return false;
    }
  }
}
