import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/services/pose_movenet_native.dart';

void main() {
  group('MoveNet preprocessing', () {
    test('maps upright coordinates back into each sensor rotation', () {
      const rawWidth = 4;
      const rawHeight = 8;

      expect(PoseMoveNetService.rawCoordinates(0, 0, 0, rawWidth, rawHeight), (
        x: 0.0,
        y: 0.0,
      ));
      expect(PoseMoveNetService.rawCoordinates(0, 0, 90, rawWidth, rawHeight), (
        x: 0.0,
        y: 7.0,
      ));
      expect(
        PoseMoveNetService.rawCoordinates(0, 0, 180, rawWidth, rawHeight),
        (x: 3.0, y: 7.0),
      );
      expect(
        PoseMoveNetService.rawCoordinates(0, 0, 270, rawWidth, rawHeight),
        (x: 3.0, y: 0.0),
      );
    });

    test('uses a centered square first crop and a padded fallback crop', () {
      final first = PoseMoveNetService.initialCropRegion(
        firstFrame: true,
        width: 200,
        height: 100,
      );
      expect(first.xMin, closeTo(0.25, 1e-12));
      expect(first.yMin, 0.0);
      expect(first.width, closeTo(0.5, 1e-12));
      expect(first.height, 1.0);

      final fallback = PoseMoveNetService.initialCropRegion(
        firstFrame: false,
        width: 200,
        height: 100,
      );
      expect(fallback.xMin, 0.0);
      expect(fallback.yMin, closeTo(-0.5, 1e-12));
      expect(fallback.width, 1.0);
      expect(fallback.height, 2.0);
    });

    test('tracks a square crop centered on a visible torso', () {
      final points = List<MoveNetPoint>.generate(
        17,
        (_) => const MoveNetPoint(x: 0.5, y: 0.5, score: 0.0),
      );
      points[5] = const MoveNetPoint(x: 0.4, y: 0.45, score: 0.9);
      points[6] = const MoveNetPoint(x: 0.6, y: 0.45, score: 0.9);
      points[11] = const MoveNetPoint(x: 0.4, y: 0.65, score: 0.9);
      points[12] = const MoveNetPoint(x: 0.6, y: 0.65, score: 0.9);

      final crop = PoseMoveNetService.nextCropRegion(points, 100, 100);
      expect(crop, isNotNull);
      expect(crop!.xMin + crop.width / 2, closeTo(0.5, 1e-12));
      expect(crop.yMin + crop.height / 2, closeTo(0.65, 1e-12));
      expect(crop.width, closeTo(crop.height, 1e-12));
    });

    test('lets the torso crop extend past frame edges like TF.js', () {
      final points = List<MoveNetPoint>.generate(
        17,
        (_) => const MoveNetPoint(x: 0.2, y: 0.55, score: 0.0),
      );
      points[5] = const MoveNetPoint(x: 0.2, y: 0.4, score: 0.9);
      points[6] = const MoveNetPoint(x: 0.2, y: 0.4, score: 0.9);
      points[9] = const MoveNetPoint(x: 0.9, y: 0.55, score: 0.9);
      points[11] = const MoveNetPoint(x: 0.2, y: 0.55, score: 0.9);
      points[12] = const MoveNetPoint(x: 0.2, y: 0.55, score: 0.9);

      final crop = PoseMoveNetService.nextCropRegion(points, 100, 200);
      expect(crop, isNotNull);
      expect(crop!.xMin, closeTo(-0.64, 1e-12));
      expect(crop.width, closeTo(1.68, 1e-12));
      expect(crop.yMin, closeTo(0.13, 1e-12));
      expect(crop.height, closeTo(0.84, 1e-12));
    });

    test('probes every rotation except the reported sensor rotation', () {
      expect(
        PoseMoveNetService.probeRotation(sensorRotation: 90, probeIndex: 0),
        0,
      );
      expect(
        PoseMoveNetService.probeRotation(sensorRotation: 90, probeIndex: 1),
        180,
      );
      expect(
        PoseMoveNetService.probeRotation(sensorRotation: 90, probeIndex: 2),
        270,
      );
      expect(
        PoseMoveNetService.probeRotation(sensorRotation: 90, probeIndex: 3),
        0,
      );
    });

    test('maps only the app-visible COCO keypoints', () {
      expect(PoseMoveNetService.keypointName(0), 'head');
      expect(PoseMoveNetService.keypointName(5), 'left_shoulder');
      expect(PoseMoveNetService.keypointName(16), 'right_ankle');
      expect(PoseMoveNetService.keypointName(1), isNull);
      expect(PoseMoveNetService.keypointName(2), isNull);
    });

    test('mirrors only the x coordinate for front cameras', () {
      final points = List<MoveNetPoint>.generate(
        17,
        (i) => MoveNetPoint(x: 0.25 + i * 0.01, y: 0.5, score: 0.8),
      );

      final plain = PoseMoveNetService.mapKeypoints(points);
      final mirrored = PoseMoveNetService.mapKeypoints(points, mirrorX: true);
      expect(plain.length, 13);
      expect(mirrored.length, 13);

      final plainShoulder = plain.firstWhere((k) => k.name == 'left_shoulder');
      final mirroredShoulder = mirrored.firstWhere(
        (k) => k.name == 'left_shoulder',
      );
      expect(plainShoulder.x, closeTo(0.3, 1e-12));
      expect(mirroredShoulder.x, closeTo(0.7, 1e-12));
      expect(mirroredShoulder.y, plainShoulder.y);
      expect(mirroredShoulder.confidence, plainShoulder.confidence);
    });

    test('reads both MoveNet output layouts', () {
      final keypoints = List<List<double>>.generate(
        17,
        (i) => [i / 100, (i + 1) / 100, 0.9],
      );

      for (final output in <List>[
        [keypoints],
        [
          [keypoints],
        ],
      ]) {
        final points = PoseMoveNetService.readOutput(output);
        expect(points, isNotNull);
        expect(points!.length, 17);
        expect(points[0].y, closeTo(0.0, 1e-12));
        expect(points[0].x, closeTo(0.01, 1e-12));
        expect(points[16].y, closeTo(0.16, 1e-12));
        expect(points[16].x, closeTo(0.17, 1e-12));
        expect(points[16].score, closeTo(0.9, 1e-12));
      }
    });
  });
}
