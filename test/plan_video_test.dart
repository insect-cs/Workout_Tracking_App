import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/screens/plan_screen.dart';
import 'package:workout_app/services/video_launcher_service.dart';

void main() {
  test('recognises accurate YouTube video URLs', () {
    const id = 'bEv6CCg2BC8';
    expect(youtubeVideoIdFromUrl('https://www.youtube.com/watch?v=$id'), id);
    expect(youtubeVideoIdFromUrl('https://youtu.be/$id'), id);
    expect(youtubeVideoIdFromUrl('https://www.youtube.com/embed/$id'), id);
    expect(youtubeVideoIdFromUrl('https://www.youtube.com/shorts/$id'), id);
  });

  test('rejects non-video URLs so search links are handled safely', () {
    expect(
      youtubeVideoIdFromUrl(
        'https://www.youtube.com/results?search_query=push+up',
      ),
      isNull,
    );
    expect(youtubeVideoIdFromUrl(''), isNull);
    expect(youtubeVideoIdFromUrl('https://vimeo.com/12345'), isNull);
  });

  test('keeps mixed-case video IDs intact for the launcher', () {
    const id = '8iPEnn-ltC8';

    expect(VideoLaunchService.youTubeVideoId('https://youtu.be/$id?t=30'), id);
    expect(
      VideoLaunchService.youTubeVideoId(
        'https://m.youtube.com/watch?v=$id&feature=share',
      ),
      id,
    );
    expect(youtubeVideoIdFromUrl('https://youtu.be/$id'), id);
  });

  test('canonical watch URLs preserve ID case and reject malformed IDs', () {
    const id = '8iPEnn-ltC8';

    expect(
      VideoLaunchService.canonicalWatchUrl('https://youtu.be/$id'),
      'https://www.youtube.com/watch?v=$id',
    );
    expect(
      VideoLaunchService.canonicalWatchUrl(
        'https://www.youtube.com/shorts/$id',
      ),
      'https://www.youtube.com/watch?v=$id',
    );
    expect(
      VideoLaunchService.canonicalWatchUrl(
        'https://www.youtube.com/watch?v=short',
      ),
      isNull,
    );
    expect(
      VideoLaunchService.canonicalWatchUrl(
        'https://www.youtube.com/results?search_query=push+up',
      ),
      isNull,
    );
  });
}
