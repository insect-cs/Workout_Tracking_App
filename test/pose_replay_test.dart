import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/pose_history_models.dart';
import 'package:workout_app/widgets/pose_replay_overlay.dart';
import 'package:workout_app/widgets/pose_skeleton_painter.dart';

void main() {
  test('replay frames quantize only the visualised landmarks', () {
    final frame = PoseReplayFrame.fromSnapshots(250, const [
      PoseKeypointSnapshot(
        name: 'left_knee',
        x: 0.4004,
        y: 0.7006,
        confidence: 0.912,
        z: -0.25,
      ),
      PoseKeypointSnapshot(name: 'right_knee', x: 0.6, y: 0.8, confidence: 0.2),
      PoseKeypointSnapshot(
        name: 'ignored_extra_landmark',
        x: 0.1,
        y: 0.1,
        confidence: 0.99,
      ),
    ])!;

    expect(frame.tMs, 250);
    expect(frame.values, hasLength(PoseReplayFrame.landmarkNames.length * 4));

    final decoded = frame.toPoseKeypoints();
    expect(decoded.map((point) => point.name), <String>['left_knee']);
    expect(decoded.single.x, closeTo(0.4, 0.002));
    expect(decoded.single.y, closeTo(0.701, 0.002));
    expect(decoded.single.z, closeTo(-0.25, 0.002));
    expect(decoded.single.confidence, closeTo(0.91, 0.01));

    expect(
      PoseReplayFrame.fromSnapshots(1, const [
        PoseKeypointSnapshot(
          name: 'left_knee',
          x: 0.5,
          y: 0.5,
          confidence: 0.1,
        ),
      ]),
      isNull,
    );
  });

  test('replay frames round-trip JSON and skip malformed samples', () {
    final frame = PoseReplayFrame.fromSnapshots(400, const [
      PoseKeypointSnapshot(
        name: 'head',
        x: 0.5,
        y: 0.25,
        confidence: 0.9,
        z: 0.4,
      ),
    ])!;

    final restored = PoseReplayFrame.tryFromJson(frame.toJson())!;
    expect(restored.tMs, 400);
    expect(restored.values, frame.values);
    expect(restored.toPoseKeypoints().single.z, closeTo(0.4, 0.002));
    expect(
      PoseReplayFrame.tryFromJson(<String, dynamic>{
        't': 1,
        'p': <int>[1, 2],
      }),
      isNull,
    );

    final clamped = PoseReplayFrame.tryFromJson(<String, dynamic>{
      't': 1,
      'p': List<int>.filled(PoseReplayFrame.landmarkNames.length * 4, 5000),
    })!;
    expect(clamped.values.first, 1000);
    expect(clamped.values[2], 1000);
    expect(clamped.values.last, 100);
  });

  test('low-confidence MoveNet joints can be decoded for replay', () {
    final frame = PoseReplayFrame.fromSnapshots(350, const [
      PoseKeypointSnapshot(name: 'left_knee', x: 0.4, y: 0.7, confidence: 0.2),
    ])!;

    expect(frame.toPoseKeypoints(), isEmpty);
    expect(frame.toPoseKeypoints(minConfidence: 0.12), hasLength(1));
  });

  test('legacy replay frames without depth still decode', () {
    final legacy = PoseReplayFrame.tryFromJson(<String, dynamic>{
      't': 300,
      'p': List<int>.filled(PoseReplayFrame.landmarkNames.length * 3, 0)
        ..[0] = 400
        ..[1] = 700
        ..[2] = 900,
    })!;

    expect(legacy.values, hasLength(PoseReplayFrame.landmarkNames.length * 4));
    expect(legacy.toPoseKeypoints().single.z, 0);
  });

  test('old sessions without replay frames still load', () {
    final session = LiveTrackingSession.fromJson(<String, dynamic>{
      'id': 'legacy',
      'exerciseName': 'Bodyweight Squat',
    });

    expect(session.poseFrames, isEmpty);
    expect(session.hasNoTrackingData, isTrue);
    expect(session.streamRotationDegrees, 0);
  });

  test('legacy sessions keep their 180-degree rotation flag on load', () {
    final session = LiveTrackingSession.fromJson(<String, dynamic>{
      'id': 'legacy-180',
      'exerciseName': 'Bodyweight Squat',
      'streamRotated180': true,
    });

    expect(session.streamRotationDegrees, 180);
    expect(
      session.toJson()['streamRotationDegrees'],
      180,
      reason: 'migrated rotation must be written back in the new format',
    );
  });

  test('replay frame lookup holds the previous sample and clamps ends', () {
    final frames = [
      PoseReplayFrame(tMs: 0, values: List<int>.filled(52, 0)),
      PoseReplayFrame(tMs: 200, values: List<int>.filled(52, 0)),
      PoseReplayFrame(tMs: 400, values: List<int>.filled(52, 0)),
    ];

    expect(PoseReplayFrame.indexAt(const [], Duration.zero), -1);
    expect(PoseReplayFrame.indexAt(frames, Duration.zero), 0);
    expect(
      PoseReplayFrame.indexAt(frames, const Duration(milliseconds: 199)),
      0,
    );
    expect(
      PoseReplayFrame.indexAt(frames, const Duration(milliseconds: 250)),
      1,
    );
    expect(PoseReplayFrame.indexAt(frames, const Duration(seconds: 5)), 2);
  });

  testWidgets('replay overlay paints the recorded skeleton', (tester) async {
    final frame = PoseReplayFrame.fromSnapshots(200, const [
      PoseKeypointSnapshot(name: 'left_knee', x: 0.4, y: 0.7, confidence: 0.9),
    ])!;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 100,
          child: PoseReplayOverlay(frames: [frame], frameIndex: 0),
        ),
      ),
    );

    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('pose-replay-overlay')),
                )
                .painter
            as PoseSkeletonPainter;
    expect(painter.keypoints.single.name, 'left_knee');
    expect(painter.keypoints.single.x, closeTo(0.4, 0.002));
    expect(painter.keypoints.single.y, closeTo(0.7, 0.002));
  });

  testWidgets('overlay unmirrors front-camera frames for raw replay video', (
    tester,
  ) async {
    final frame = PoseReplayFrame.fromSnapshots(200, const [
      PoseKeypointSnapshot(name: 'left_knee', x: 0.4, y: 0.7, confidence: 0.9),
    ])!;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 100,
          child: PoseReplayOverlay(
            frames: [frame],
            frameIndex: 0,
            unmirrorX: true,
          ),
        ),
      ),
    );

    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('pose-replay-overlay')),
                )
                .painter
            as PoseSkeletonPainter;
    expect(painter.keypoints.single.x, closeTo(0.6, 0.002));
  });

  testWidgets('overlay rotates replay skeletons 270 degrees with the video', (
    tester,
  ) async {
    final frame = PoseReplayFrame.fromSnapshots(200, const [
      PoseKeypointSnapshot(name: 'left_knee', x: 0.4, y: 0.7, confidence: 0.9),
    ])!;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 100,
          child: PoseReplayOverlay(
            frames: [frame],
            frameIndex: 0,
            rotationDegrees: 270,
          ),
        ),
      ),
    );

    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('pose-replay-overlay')),
                )
                .painter
            as PoseSkeletonPainter;
    expect(painter.keypoints.single.x, closeTo(0.7, 0.002));
    expect(painter.keypoints.single.y, closeTo(0.6, 0.002));
  });

  testWidgets('overlay still supports legacy 180-degree sessions', (
    tester,
  ) async {
    final frame = PoseReplayFrame.fromSnapshots(200, const [
      PoseKeypointSnapshot(name: 'left_knee', x: 0.4, y: 0.7, confidence: 0.9),
    ])!;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 100,
          child: PoseReplayOverlay(
            frames: [frame],
            frameIndex: 0,
            rotationDegrees: 180,
          ),
        ),
      ),
    );

    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('pose-replay-overlay')),
                )
                .painter
            as PoseSkeletonPainter;
    expect(painter.keypoints.single.x, closeTo(0.6, 0.002));
    expect(painter.keypoints.single.y, closeTo(0.3, 0.002));
  });
}
