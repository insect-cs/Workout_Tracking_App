import 'package:flutter/material.dart';

import '../services/pose_analysis_service.dart';

/// Draws the 13-joint skeleton over a camera frame or replay video.
///
/// When [showDepth] is enabled, each joint's colour and radius encode its
/// relative z: blue/larger means closer to the camera, orange/smaller means
/// farther away, and `z == 0` keeps the neutral point colour and size. This
/// makes ML Kit's experimental depth visible without changing the smooth
/// MoveNet x/y stream.
class PoseSkeletonPainter extends CustomPainter {
  final List<PoseKeypoint> keypoints;
  final Color lineColor;
  final Color pointColor;
  final bool showDepth;

  /// Minimum landmark score to draw. MoveNet's per-joint scores are often
  /// lower than ML Kit's likelihood, so the live overlay uses a smaller value
  /// than the default to avoid dropping an otherwise valid skeleton.
  final double minConfidence;

  static const Color _nearColor = Color(0xFF29B6F6);
  static const Color _farColor = Color(0xFFFF7043);
  static const double _baseRadius = 4.0;

  /// Anatomical edges shared with the 3D viewport painter.
  static const List<List<String>> connections = [
    ['head', 'left_shoulder'],
    ['head', 'right_shoulder'],
    ['left_shoulder', 'right_shoulder'],
    ['left_shoulder', 'left_elbow'],
    ['right_shoulder', 'right_elbow'],
    ['left_elbow', 'left_wrist'],
    ['right_elbow', 'right_wrist'],
    ['left_shoulder', 'left_hip'],
    ['right_shoulder', 'right_hip'],
    ['left_hip', 'right_hip'],
    ['left_hip', 'left_knee'],
    ['right_hip', 'right_knee'],
    ['left_knee', 'left_ankle'],
    ['right_knee', 'right_ankle'],
  ];

  const PoseSkeletonPainter({
    required this.keypoints,
    this.lineColor = const Color(0xFFFF6B00),
    this.pointColor = const Color(0xFFFFFFFF),
    this.showDepth = true,
    this.minConfidence = 0.3,
  });

  /// Joint colour for a normalized z value. Negative z (toward the camera)
  /// blends toward blue; positive z blends toward orange.
  static Color depthColor(double z, Color baseColor) {
    final depth = z.clamp(-1.0, 1.0).toDouble();
    if (depth == 0) return baseColor;
    return depth < 0
        ? Color.lerp(baseColor, _nearColor, -depth) ?? baseColor
        : Color.lerp(baseColor, _farColor, depth) ?? baseColor;
  }

  /// Joint radius for a normalized z value. Closer joints are drawn larger so
  /// depth is readable even when the skeleton is small on screen.
  static double depthRadius(double z) {
    final depth = z.clamp(-1.0, 1.0).toDouble();
    if (depth < 0) return _baseRadius + (2.5 * -depth);
    return _baseRadius - (1.5 * depth);
  }

  Map<String, PoseKeypoint> get _keypointMap => {
    for (final kp in keypoints) kp.name: kp,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final map = _keypointMap;

    // Draw anatomical connections
    for (final conn in connections) {
      final a = map[conn[0]];
      final b = map[conn[1]];
      if (a != null &&
          b != null &&
          a.confidence >= minConfidence &&
          b.confidence >= minConfidence) {
        final p1 = Offset(a.x * size.width, a.y * size.height);
        final p2 = Offset(b.x * size.width, b.y * size.height);
        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    // Draw skeletal keypoints. Colour and radius carry the relative depth.
    for (final kp in keypoints) {
      if (kp.confidence >= minConfidence) {
        final pos = Offset(kp.x * size.width, kp.y * size.height);
        final nodeColor = showDepth ? depthColor(kp.z, pointColor) : pointColor;
        final radius = showDepth ? depthRadius(kp.z) : _baseRadius;

        // Outer glow aura
        canvas.drawCircle(
          pos,
          radius + 3,
          Paint()..color = nodeColor.withValues(alpha: 0.35),
        );
        // Main keypoint node
        pointPaint.color = nodeColor;
        canvas.drawCircle(pos, radius, pointPaint);
        // Inner accent
        canvas.drawCircle(
          pos,
          radius * 0.5,
          Paint()..color = lineColor.withValues(alpha: 0.9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(PoseSkeletonPainter oldDelegate) =>
      oldDelegate.keypoints != keypoints ||
      oldDelegate.showDepth != showDepth ||
      oldDelegate.minConfidence != minConfidence ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.pointColor != pointColor;
}
