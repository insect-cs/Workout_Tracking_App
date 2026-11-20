import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class YouTubeService {
  // In-memory cache for resolved exercise video URLs
  static final Map<String, String> _videoCache = {};

  // Curated database of verified high-quality video demonstrations
  static final Map<String, String> _curatedVideos = {
    // Chest
    'incline dumbbell press': 'https://www.youtube.com/watch?v=8iPEnn-ltC8',
    'dumbbell bench press': 'https://www.youtube.com/watch?v=VmB1G1K7v94',
    'barbell bench press': 'https://www.youtube.com/watch?v=rT7DgCr-3pg',
    'flat bench press': 'https://www.youtube.com/watch?v=rT7DgCr-3pg',
    'push up': 'https://www.youtube.com/watch?v=IODxDxX7oi4',
    'push-up': 'https://www.youtube.com/watch?v=IODxDxX7oi4',
    'push ups': 'https://www.youtube.com/watch?v=IODxDxX7oi4',
    'cable fly': 'https://www.youtube.com/watch?v=Iwe6AmxVf7o',
    'cable crossover': 'https://www.youtube.com/watch?v=taI4XduLpTk',
    'chest dip': 'https://www.youtube.com/watch?v=2z8JmcrW-As',
    'dips': 'https://www.youtube.com/watch?v=2z8JmcrW-As',
    'decline dumbbell press': 'https://www.youtube.com/watch?v=0xRvl4Qv3EY',

    // Shoulders
    'cable lateral raise': 'https://www.youtube.com/watch?v=PPrzBWZDOhA',
    'dumbbell lateral raise': 'https://www.youtube.com/watch?v=3VcKaXpzqRo',
    'lateral raise': 'https://www.youtube.com/watch?v=3VcKaXpzqRo',
    'barbell overhead press': 'https://www.youtube.com/watch?v=2yjwXTZQDDI',
    'overhead press': 'https://www.youtube.com/watch?v=2yjwXTZQDDI',
    'standing overhead barbell press':
        'https://www.youtube.com/watch?v=2yjwXTZQDDI',
    'dumbbell shoulder press': 'https://www.youtube.com/watch?v=qEwKCR5JCog',
    'arnold press': 'https://www.youtube.com/watch?v=6Z15_WdXmVw',
    'face pull': 'https://www.youtube.com/watch?v=rep-qVOkqgk',
    'face pulls': 'https://www.youtube.com/watch?v=rep-qVOkqgk',
    'rear delt fly': 'https://www.youtube.com/watch?v=EA7uKBcf_h8',
    'reverse pec deck': 'https://www.youtube.com/watch?v=nN40Xm_i9e4',

    // Back
    'barbell deadlift': 'https://www.youtube.com/watch?v=op9kVnSso6Q',
    'deadlift': 'https://www.youtube.com/watch?v=op9kVnSso6Q',
    'pull up': 'https://www.youtube.com/watch?v=eGo4IYlbE5g',
    'pull-up': 'https://www.youtube.com/watch?v=eGo4IYlbE5g',
    'pull ups': 'https://www.youtube.com/watch?v=eGo4IYlbE5g',
    'weighted pull-ups': 'https://www.youtube.com/watch?v=huWP8tWwV7k',
    'lat pulldown': 'https://www.youtube.com/watch?v=CAwf7n6Luuc',
    'barbell row': 'https://www.youtube.com/watch?v=FWJR5Ve8gkQ',
    'bent over row': 'https://www.youtube.com/watch?v=FWJR5Ve8gkQ',
    'dumbbell row': 'https://www.youtube.com/watch?v=roCP6wCXPqo',
    'single arm dumbbell row': 'https://www.youtube.com/watch?v=roCP6wCXPqo',
    'seated cable row': 'https://www.youtube.com/watch?v=GZbfZ033f74',
    't-bar row': 'https://www.youtube.com/watch?v=j3Igk5nyZE4',

    // Legs
    'barbell back squat': 'https://www.youtube.com/watch?v=bEv6CCg2BC8',
    'barbell squat': 'https://www.youtube.com/watch?v=bEv6CCg2BC8',
    'squat': 'https://www.youtube.com/watch?v=bEv6CCg2BC8',
    'front squat': 'https://www.youtube.com/watch?v=mBwfflSgG54',
    'bulgarian split squat': 'https://www.youtube.com/watch?v=2C-uNgKwPLE',
    'leg press': 'https://www.youtube.com/watch?v=IZxyjW7MPJQ',
    'romanian deadlift': 'https://www.youtube.com/watch?v=_oyxCn2iSjU',
    'dumbbell romanian deadlift': 'https://www.youtube.com/watch?v=FQKfr1YDhEk',
    'rdl': 'https://www.youtube.com/watch?v=_oyxCn2iSjU',
    'hamstring curl': 'https://www.youtube.com/watch?v=1Tq3QdYUuHs',
    'leg curl': 'https://www.youtube.com/watch?v=1Tq3QdYUuHs',
    'leg extension': 'https://www.youtube.com/watch?v=YyvSfVjQeL0',
    'standing calf raise': 'https://www.youtube.com/watch?v=-M4-G8p8fmc',
    'calf raise': 'https://www.youtube.com/watch?v=-M4-G8p8fmc',
    'hip thrust': 'https://www.youtube.com/watch?v=LM8XHLYJoYs',
    'barbell hip thrust': 'https://www.youtube.com/watch?v=LM8XHLYJoYs',
    'lunges': 'https://www.youtube.com/watch?v=QOVaHwm-Q6U',
    'walking lunges': 'https://www.youtube.com/watch?v=D7KaRcUTQeE',

    // Arms
    'incline bicep curl': 'https://www.youtube.com/watch?v=soxrZlIl35U',
    'bicep curl': 'https://www.youtube.com/watch?v=ykJmrZ5v0Oo',
    'dumbbell bicep curl': 'https://www.youtube.com/watch?v=ykJmrZ5v0Oo',
    'barbell curl': 'https://www.youtube.com/watch?v=QZEqB6wUPxQ',
    'hammer curl': 'https://www.youtube.com/watch?v=zC3nLlEvin4',
    'preacher curl': 'https://www.youtube.com/watch?v=fIWP-FRFNU0',
    'overhead rope tricep extension':
        'https://www.youtube.com/watch?v=kqidUIf1eJE',
    'tricep rope pushdown': 'https://www.youtube.com/watch?v=vB5OHsJ3EME',
    'cable tricep pushdown': 'https://www.youtube.com/watch?v=2-LAMcpzODU',
    'skull crusher': 'https://www.youtube.com/watch?v=d_KZxkY_0cM',
    'skull crushers': 'https://www.youtube.com/watch?v=d_KZxkY_0cM',

    // Core
    'hanging leg raise': 'https://www.youtube.com/watch?v=Pr1ieGZ5atk',
    'plank': 'https://www.youtube.com/watch?v=pvIjsG5Svck',
    'ab wheel rollout': 'https://www.youtube.com/watch?v=rqiTPdK1cWg',
    'cable crunch': 'https://www.youtube.com/watch?v=2fO41lq7b40',
    'russian twist': 'https://www.youtube.com/watch?v=wkD8rjkodUI',

    // Cardio
    'assault air bike sprints': 'https://www.youtube.com/watch?v=PHReR7tC_tw',
    'air bike': 'https://www.youtube.com/watch?v=PHReR7tC_tw',
    'rowing machine': 'https://www.youtube.com/watch?v=H0r_ZGSym3k',
    'kettlebell swing': 'https://www.youtube.com/watch?v=sSESeQAir2M',
  };

  /// Normalizes exercise title for dictionary lookup
  static String _cleanKey(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '') // remove parentheses like (OHP)
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ') // remove symbols
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Gets an exact matching video for [exerciseName].
  /// First checks curated library, then cache, then scrapes the top exact video ID from YouTube.
  static Future<String> getExactVideoUrl(String exerciseName) async {
    final cleaned = _cleanKey(exerciseName);

    // 1. Direct check in curated library
    if (_curatedVideos.containsKey(cleaned)) {
      return _curatedVideos[cleaned]!;
    }

    // Partial key matching against curated dictionary
    for (final entry in _curatedVideos.entries) {
      if (cleaned.contains(entry.key) || entry.key.contains(cleaned)) {
        return entry.value;
      }
    }

    // 2. Cache check
    if (_videoCache.containsKey(cleaned)) {
      return _videoCache[cleaned]!;
    }

    // 3. Browsers block scraping youtube.com directly with CORS. On web, go
    // straight to the search URL instead of producing console errors.
    if (kIsWeb) {
      final webQuery = Uri.encodeComponent(
        '$exerciseName exercise form tutorial',
      );
      return 'https://www.youtube.com/results?search_query=$webQuery';
    }

    // 4. Resolve exact video ID from YouTube search endpoint (native only).
    try {
      final query = Uri.encodeComponent('$exerciseName exercise form tutorial');
      final searchUri = Uri.parse(
        'https://www.youtube.com/results?search_query=$query',
      );

      final response = await http
          .get(
            searchUri,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept-Language': 'en-US,en;q=0.9',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = response.body;

        // Extract first videoId from YouTube results page
        // Format 1: "videoId":"XXXXXXXXXXX"
        final match1 = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"')
            .firstMatch(body);
        if (match1 != null) {
          final videoId = match1.group(1);
          final exactUrl = 'https://www.youtube.com/watch?v=$videoId';
          _videoCache[cleaned] = exactUrl;
          return exactUrl;
        }

        // Format 2: /watch?v=XXXXXXXXXXX
        final match2 = RegExp(r'/watch\?v=([a-zA-Z0-9_-]{11})')
            .firstMatch(body);
        if (match2 != null) {
          final videoId = match2.group(1);
          final exactUrl = 'https://www.youtube.com/watch?v=$videoId';
          _videoCache[cleaned] = exactUrl;
          return exactUrl;
        }
      }
    } catch (_) {
      // In case network query fails or times out
    }

    // Fallback: direct watch URL targeting the query if resolution failed
    final fallbackQuery = Uri.encodeComponent('$exerciseName tutorial');
    final directSearchUrl =
        'https://www.youtube.com/results?search_query=$fallbackQuery';
    return directSearchUrl;
  }
}
