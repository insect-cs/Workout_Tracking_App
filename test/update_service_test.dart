import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:workout_app/services/update_service.dart';

void main() {
  group('UpdateService version parsing', () {
    test('stripPrefix removes v and build metadata', () {
      expect(UpdateService.stripPrefix('v1.2.3'), '1.2.3');
      expect(UpdateService.stripPrefix('V2.0.1+42'), '2.0.1');
      expect(UpdateService.stripPrefix('1.0.0'), '1.0.0');
    });

    test('compareVersions handles different lengths', () {
      expect(UpdateService.compareVersions('1.0.1', '1.0.0'), 1);
      expect(UpdateService.compareVersions('1.0', '1.0.0'), 0);
      expect(UpdateService.compareVersions('v0.9.9', '1.0.0'), -1);
      expect(UpdateService.compareVersions('2.0', '1.99.99'), 1);
    });
  });

  group('UpdateService.check', () {
    test('parses a newer release and its APK asset', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'api.github.com');
        expect(request.headers['User-Agent'], 'Workout-Tracking-App');
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.1.0',
            'name': 'Big update',
            'body': 'New features',
            'html_url': 'https://github.com/insect-cs/Workout_Tracking_App/releases/tag/v2.1.0',
            'assets': [
              {
                'name': 'app-release.apk',
                'browser_download_url': 'https://github.com/x/app-release.apk',
              },
            ],
          }),
          200,
        );
      });

      final update = await UpdateService.check(client: client);
      expect(update.latestVersion, '2.1.0');
      expect(update.releaseName, 'Big update');
      expect(update.releaseNotes, 'New features');
      expect(update.isNewer, isTrue);
      expect(update.apkUrl, 'https://github.com/x/app-release.apk');
    });

    test('reports up to date when tags match', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'tag_name': 'v1.1.0', 'assets': []}),
          200,
        ),
      );

      final update = await UpdateService.check(client: client);
      expect(update.latestVersion, '1.1.0');
      expect(update.isNewer, isFalse);
      expect(update.apkUrl, isNull);
      expect(update.releaseUrl, UpdateService.releasesPage);
    });

    test('throws on a failed API response', () async {
      final client = MockClient((_) async => http.Response('nope', 403));
      expect(UpdateService.check(client: client), throwsException);
    });
  });
}
