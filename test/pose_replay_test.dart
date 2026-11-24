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
    expect(frame.values, hasLength(PoseReplayFrame.landmarkNames.length * 3));

    final decoded = frame.toPoseKeypoints();
    expect(decoded.map((point) => point.name), <String>['left_knee']);
    expect(decoded.single.x, closeTo(0.4, 0.002));
    expect(decoded.single.y, closeTo(0.701, 0.002));
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
      PoseKeypointSnapshot(name: 'head', x: 0.5, y: 0.25, confidence: 0.9),
    ])!;

    final restored = PoseReplayFrame.tryFromJson(frame.toJson())!;
    expect(restored.tMs, 400);
    expect(restored.values, frame.values);
    expect(
      PoseReplayFrame.tryFromJson(<String, dynamic>{
        't': 1,
        'p': <int>[1, 2],
      }),
      isNull,
    );

    final clamped = PoseReplayFrame.tryFromJson(<String, dynamic>{
      't': 1,
      'p': List<int>.filled(PoseReplayFrame.landmarkNames.length * 3, 5000),
    })!;
    expect(clamped.values.first, 1000);
    expect(clamped.values.last, 100);
  });

  test('old sessions without replay frames still load', () {
    final session = LiveTrackingSession.fromJson(<String, dynamic>{
      'id': 'legacy',
      'exerciseName': 'Bodyweight Squat',
    });

    expect(session.poseFrames, isEmpty);
    expect(session.hasNoTrackingData, isTrue);
  });

  test('replay frame lookup holds the previous sample and clamps ends', () {
    final frames = [
      PoseReplayFrame(tMs: 0, values: List<int>.filled(39, 0)),
      PoseReplayFrame(tMs: 200, values: List<int>.filled(39, 0)),
      PoseReplayFrame(tMs: 400, values: List<int>.filled(39, 0)),
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
}
