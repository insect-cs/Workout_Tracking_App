import 'package:flutter/material.dart';

import '../services/pose_analysis_service.dart';

class PoseSkeletonPainter extends CustomPainter {
  final List<PoseKeypoint> keypoints;
  final Color lineColor;
  final Color pointColor;

  static const List<List<String>> _connections = [
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
  });

  Map<String, PoseKeypoint> get _keypointMap => {
    for (final kp in keypoints) kp.name: kp,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final map = _keypointMap;

    // Draw anatomical connections
    for (final conn in _connections) {
      final a = map[conn[0]];
      final b = map[conn[1]];
      if (a != null && b != null && a.confidence > 0.3 && b.confidence > 0.3) {
        final p1 = Offset(a.x * size.width, a.y * size.height);
        final p2 = Offset(b.x * size.width, b.y * size.height);
        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    // Draw skeletal keypoints
    for (final kp in keypoints) {
      if (kp.confidence > 0.3) {
        final pos = Offset(kp.x * size.width, kp.y * size.height);
        // Outer glow aura
        canvas.drawCircle(
          pos,
          7,
          Paint()..color = lineColor.withValues(alpha: 0.35),
        );
        // Main keypoint node
        canvas.drawCircle(pos, 4, pointPaint);
        // Inner accent
        canvas.drawCircle(pos, 2, Paint()..color = lineColor);
      }
    }
  }

  @override
  bool shouldRepaint(PoseSkeletonPainter oldDelegate) =>
      oldDelegate.keypoints != keypoints;
}
