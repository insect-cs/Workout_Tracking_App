import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/screens/plan_screen.dart';

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
}
