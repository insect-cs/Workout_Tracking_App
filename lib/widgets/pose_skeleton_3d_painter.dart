import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/pose_analysis_service.dart';
import 'pose_skeleton_painter.dart';

typedef ProjectedPoint = ({Offset offset, double depth});

/// A joint after it has been rotated into camera space and perspective-divided.
/// [depth] is the camera-space Z used to draw far joints first.
class ProjectedJoint {
  const ProjectedJoint({
    required this.name,
    required this.offset,
    required this.depth,
    required this.keypoint,
  });

  final String name;
  final Offset offset;
  final double depth;
  final PoseKeypoint keypoint;
}

/// Draws the same 13-joint skeleton in a real perspective view.
///
/// Input landmarks stay in the app's normalized upright image space (x right,
/// y down, z relative depth). They are converted to a y-up world with the floor
/// at y = 0 and the hips centred on x = 0, then rotated by [yaw]/[pitch] and
/// projected through a pinhole camera. This is a display-only viewport: the 2D
/// overlay and the rep counters keep using the original x/y values.
class PoseSkeleton3DPainter extends CustomPainter {
  const PoseSkeleton3DPainter({
    required this.keypoints,
    this.yaw = 0,
    this.pitch = -0.08,
    this.fovDegrees = 60,
    this.worldWidth = 1.6,
    this.worldHeight = 1.8,
    this.depthScale = 1.2,
    this.cameraDistance = 3,
    this.lineColor = const Color(0xFFFF6B00),
    this.pointColor = const Color(0xFFFFFFFF),
    this.minConfidence = 0.12,
    this.showFloor = true,
  }) : assert(fovDegrees > 0 && fovDegrees < 180),
       assert(cameraDistance > 0),
       assert(worldWidth > 0),
       assert(worldHeight > 0);

  final List<PoseKeypoint> keypoints;
  final double yaw;
  final double pitch;
  final double fovDegrees;
  final double worldWidth;
  final double worldHeight;
  final double depthScale;
  final double cameraDistance;
  final Color lineColor;
  final Color pointColor;
  final double minConfidence;
  final bool showFloor;

  /// Normalized y of the floor. The lowest confident ankle becomes y = 0 so
  /// the skeleton stands on the grid instead of floating above it.
  static double floorYFor(
    List<PoseKeypoint> keypoints, {
    double minConfidence = 0.12,
  }) {
    var floor = 0.0;
    var foundAnkle = false;
    for (final kp in keypoints) {
      if ((kp.name == 'left_ankle' || kp.name == 'right_ankle') &&
          kp.confidence >= minConfidence) {
        floor = math.max(floor, kp.y);
        foundAnkle = true;
      }
    }
    return foundAnkle ? floor.clamp(0.0, 1.0) : 1.0;
  }

  /// Perspective projection of a y-up point in world units. Camera space is
  /// x right / y up / z forward; negative landmark z (closer) reduces depth.
  static ProjectedPoint projectWorld(
    double x,
    double y,
    double z, {
    required Size size,
    required double yaw,
    required double pitch,
    required double fovDegrees,
    required double cameraDistance,
  }) {
    if (size.width <= 0 || size.height <= 0) {
      return (offset: Offset.zero, depth: cameraDistance);
    }

    // Yaw about the vertical axis, then pitch about the horizontal axis.
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final rotatedX = x * cosYaw + z * sinYaw;
    final rotatedZ = -x * sinYaw + z * cosYaw;

    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final cameraY = y * cosPitch - rotatedZ * sinPitch;
    final cameraZ = y * sinPitch + rotatedZ * cosPitch;

    final depth = math.max(0.25, cameraDistance + cameraZ);
    final focalLength =
        (size.height / 2) / math.tan((fovDegrees * math.pi / 180) / 2);

    return (
      offset: Offset(
        size.width / 2 + focalLength * rotatedX / depth,
        // Flutter y grows downward, world y grows upward.
        size.height / 2 - focalLength * cameraY / depth,
      ),
      depth: depth,
    );
  }

  /// Converts one normalized landmark into the projected screen point.
  static ProjectedJoint project(
    PoseKeypoint point, {
    required Size size,
    required double floorY,
    required double yaw,
    required double pitch,
    required double fovDegrees,
    required double worldWidth,
    required double worldHeight,
    required double depthScale,
    required double cameraDistance,
  }) {
    final worldX = (point.x - 0.5) * worldWidth;
    final worldY = (floorY - point.y) * worldHeight;
    final worldZ = point.z * depthScale;
    final projected = projectWorld(
      worldX,
      worldY,
      worldZ,
      size: size,
      yaw: yaw,
      pitch: pitch,
      fovDegrees: fovDegrees,
      cameraDistance: cameraDistance,
    );
    return ProjectedJoint(
      name: point.name,
      offset: projected.offset,
      depth: projected.depth,
      keypoint: point,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final floor = floorYFor(keypoints, minConfidence: minConfidence);

    ProjectedPoint at(double x, double y, double z) => projectWorld(
      x,
      y,
      z,
      size: size,
      yaw: yaw,
      pitch: pitch,
      fovDegrees: fovDegrees,
      cameraDistance: cameraDistance,
    );

    if (showFloor) {
      final gridPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.16)
        ..strokeWidth = 1;
      for (var i = -2; i <= 2; i++) {
        final offset = i * 0.5;
        canvas.drawLine(
          at(offset, 0, -1).offset,
          at(offset, 0, 1).offset,
          gridPaint,
        );
        canvas.drawLine(
          at(-1, 0, offset).offset,
          at(1, 0, offset).offset,
          gridPaint,
        );
      }
    }

    final projected = <String, ProjectedJoint>{};
    for (final kp in keypoints) {
      if (kp.confidence < minConfidence) continue;
      projected[kp.name] = project(
        kp,
        size: size,
        floorY: floor,
        yaw: yaw,
        pitch: pitch,
        fovDegrees: fovDegrees,
        worldWidth: worldWidth,
        worldHeight: worldHeight,
        depthScale: depthScale,
        cameraDistance: cameraDistance,
      );
    }

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final connection in PoseSkeletonPainter.connections) {
      final a = projected[connection[0]];
      final b = projected[connection[1]];
      if (a != null && b != null) {
        canvas.drawLine(a.offset, b.offset, linePaint);
      }
    }

    final pointPaint = Paint()..style = PaintingStyle.fill;
    final ordered = projected.values.toList()
      ..sort((a, b) => b.depth.compareTo(a.depth));
    for (final joint in ordered) {
      final nodeColor = PoseSkeletonPainter.depthColor(
        joint.keypoint.z,
        pointColor,
      );
      final radius = PoseSkeletonPainter.depthRadius(joint.keypoint.z) * 0.9;
      canvas.drawCircle(
        joint.offset,
        radius + 3,
        Paint()..color = nodeColor.withValues(alpha: 0.3),
      );
      pointPaint.color = nodeColor;
      canvas.drawCircle(joint.offset, radius, pointPaint);
      canvas.drawCircle(
        joint.offset,
        radius * 0.5,
        Paint()..color = lineColor.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(PoseSkeleton3DPainter oldDelegate) =>
      oldDelegate.keypoints != keypoints ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.fovDegrees != fovDegrees ||
      oldDelegate.worldWidth != worldWidth ||
      oldDelegate.worldHeight != worldHeight ||
      oldDelegate.depthScale != depthScale ||
      oldDelegate.cameraDistance != cameraDistance ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.pointColor != pointColor ||
      oldDelegate.minConfidence != minConfidence ||
      oldDelegate.showFloor != showFloor;
}
