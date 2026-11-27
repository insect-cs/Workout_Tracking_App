import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/services/pose_analysis_service.dart';
import 'package:workout_app/widgets/pose_skeleton_3d_painter.dart';

void main() {
  const size = Size(360, 190);
  const painter = PoseSkeleton3DPainter(keypoints: []);

  PoseKeypoint joint(String name, double x, double y, {double z = 0}) =>
      PoseKeypoint(name: name, x: x, y: y, z: z, confidence: 0.9);

  setUp(() => PoseAnalysisService.resetLiveTracking());

  test('world y is up and x is centred at zero', () {
    final right = PoseSkeleton3DPainter.projectWorld(
      1,
      1,
      0,
      size: size,
      yaw: 0,
      pitch: 0,
      fovDegrees: 60,
      cameraDistance: 3,
    );
    final center = PoseSkeleton3DPainter.projectWorld(
      0,
      0,
      0,
      size: size,
      yaw: 0,
      pitch: 0,
      fovDegrees: 60,
      cameraDistance: 3,
    );

    expect(right.offset.dx, greaterThan(center.offset.dx));
    expect(right.offset.dy, lessThan(center.offset.dy));
    expect(center.offset.dx, closeTo(size.width / 2, 1e-12));
    expect(center.offset.dy, closeTo(size.height / 2, 1e-12));
    expect(center.depth, 3);
  });

  test('farther joints get larger camera-space depth', () {
    // Negative landmark z means closer to the camera, so it reduces depth.
    final near = PoseSkeleton3DPainter.projectWorld(
      0,
      0,
      -0.5,
      size: size,
      yaw: 0,
      pitch: 0,
      fovDegrees: 60,
      cameraDistance: 3,
    );
    final far = PoseSkeleton3DPainter.projectWorld(
      0,
      0,
      0.5,
      size: size,
      yaw: 0,
      pitch: 0,
      fovDegrees: 60,
      cameraDistance: 3,
    );

    expect(near.depth, lessThan(3));
    expect(far.depth, greaterThan(3));
  });

  test('yaw rotates around the vertical axis', () {
    final side = PoseSkeleton3DPainter.projectWorld(
      1,
      0,
      0,
      size: size,
      yaw: math.pi / 2,
      pitch: 0,
      fovDegrees: 60,
      cameraDistance: 3,
    );
    expect(side.offset.dx, closeTo(size.width / 2, 1e-12));
    expect(side.depth, lessThan(3));
  });

  test('floor is the lowest confident ankle and head stands above it', () {
    final keypoints = [
      joint('head', 0.5, 0.1),
      joint('left_ankle', 0.45, 0.8),
      joint('right_ankle', 0.55, 0.9),
    ];
    expect(PoseSkeleton3DPainter.floorYFor(keypoints), closeTo(0.9, 1e-12));

    final head = PoseSkeleton3DPainter.project(
      keypoints.first,
      size: size,
      floorY: 0.9,
      yaw: 0,
      pitch: 0,
      fovDegrees: 60,
      worldWidth: 1.6,
      worldHeight: 1.8,
      depthScale: 1.2,
      cameraDistance: 3,
    );
    expect(head.offset.dy, lessThan(size.height / 2));

    final ankle = PoseSkeleton3DPainter.project(
      keypoints.last,
      size: size,
      floorY: 0.9,
      yaw: 0,
      pitch: 0,
      fovDegrees: 60,
      worldWidth: 1.6,
      worldHeight: 1.8,
      depthScale: 1.2,
      cameraDistance: 3,
    );
    expect(ankle.offset.dx, greaterThan(size.width / 2));
    expect(ankle.offset.dy, closeTo(size.height / 2, 1e-12));
  });

  test('depth samples are low-pass filtered across frames', () {
    const first = <PoseKeypoint>[
      PoseKeypoint(name: 'left_knee', x: 0.4, y: 0.7, confidence: 0.9),
    ];

    final initial = PoseAnalysisService.applyDepthToKeypoints(
      first,
      depthByName: const {'left_knee': -0.8},
    );
    expect(initial.single.z, closeTo(-0.8, 1e-12));

    final second = PoseAnalysisService.applyDepthToKeypoints(
      first,
      depthByName: const {'left_knee': 0.8},
    );
    expect(second.single.z, greaterThan(-0.8));
    expect(second.single.z, lessThan(0.8));
  });

  testWidgets('painter renders without exceptions', (tester) async {
    final keypoints = [
      joint('head', 0.5, 0.1, z: -0.2),
      joint('left_shoulder', 0.4, 0.3),
      joint('right_shoulder', 0.6, 0.3),
      joint('left_hip', 0.45, 0.55),
      joint('right_hip', 0.55, 0.55),
      joint('left_ankle', 0.45, 0.9),
      joint('right_ankle', 0.55, 0.9),
    ];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 360,
          height: 190,
          child: CustomPaint(
            painter: PoseSkeleton3DPainter(keypoints: keypoints),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(painter.shouldRepaint(painter), isFalse);
  });
}
