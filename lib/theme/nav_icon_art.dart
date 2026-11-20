import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'nav_animations.dart';

double _ease(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Home: the chimney lifts off the roof and fades away.
double chimneyRise(double progress) =>
    -11 * math.sin(math.pi * progress.clamp(0.0, 1.0));

double chimneyOpacity(double progress) {
  final p = progress.clamp(0.0, 1.0);
  if (p >= 0.9) return 0;
  return math.sin(math.pi * p / 0.9).clamp(0.0, 1.0);
}

/// Plan: a real page turn around the calendar's vertical axis.
double calendarFlipAngle(double progress) =>
    2 * math.pi * progress.clamp(0.0, 1.0);

/// Calories: swaying, stretching flame.
double flameSway(double progress) => 1.6 * math.sin(6 * math.pi * progress);

double flameStretch(double progress) =>
    1 + 0.14 * math.sin(3 * math.pi * progress);

/// Generate: the outer stars fade out, then reappear one after another.
double starOpacity(double progress, int index) {
  final p = progress.clamp(0.0, 1.0);
  final fadeEnd = 0.32 + index * 0.02;
  final appearStart = 0.42 + index * 0.12;
  final appearEnd = appearStart + 0.16;
  if (p <= fadeEnd) return 1 - _ease(p / fadeEnd);
  if (p < appearStart) return 0;
  return _ease((p - appearStart) / (appearEnd - appearStart));
}

/// Saved: shoots upward, then comes back down from below into rest position.
double bookmarkOffset(double progress) {
  final p = progress.clamp(0.0, 1.0);
  if (p < 1 / 3) return -10 * _ease(p * 3);
  if (p < 2 / 3) return -10 + 20 * _ease((p - 1 / 3) * 3);
  return 10 * (1 - _ease((p - 2 / 3) * 3));
}

/// Logger: the second hand starts at 12, sweeps and returns to 12.
double stopwatchHandAngle(double progress) =>
    1.5 * math.pi * math.sin(math.pi * progress.clamp(0.0, 1.0));

/// Pose: one hand swings sideways and returns to its resting angle.
const double _poseRestAngle = 0.6435; // atan2(3, 4)

double poseHandAngle(double progress) =>
    _poseRestAngle * (1 - math.sin(math.pi * progress.clamp(0.0, 1.0)));

/// Paints a purpose-built animated glyph for each navigation destination.
class NavIconArtPainter extends CustomPainter {
  const NavIconArtPainter({
    required this.animation,
    required this.progress,
    required this.color,
  });

  final NavIconAnimation animation;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (animation) {
      case NavIconAnimation.homeHop:
        _paintHome(canvas, fill);
      case NavIconAnimation.planFlip:
        _paintCalendar(canvas, fill, stroke);
      case NavIconAnimation.calorieFlicker:
        _paintFlame(canvas);
      case NavIconAnimation.generateSparkle:
        _paintStars(canvas);
      case NavIconAnimation.savedDrop:
        _paintBookmark(canvas, fill);
      case NavIconAnimation.loggerTick:
        _paintStopwatch(canvas, fill, stroke);
      case NavIconAnimation.poseWiggle:
        _paintPose(canvas, fill, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant NavIconArtPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color;

  void _paintHome(Canvas canvas, Paint fill) {
    final rise = chimneyRise(progress);
    final alpha = chimneyOpacity(progress);
    if (alpha > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(15.5, 4 + rise, 3.2, 7),
          const Radius.circular(0.6),
        ),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }

    final roof = Path()
      ..moveTo(2.5, 12)
      ..lineTo(12, 3.5)
      ..lineTo(21.5, 12)
      ..close();
    canvas.drawPath(roof, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5.5, 11, 13, 9),
        const Radius.circular(1.2),
      ),
      fill,
    );
  }

  void _paintCalendar(Canvas canvas, Paint fill, Paint stroke) {
    // Binding rings.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7.5, 2, 2, 5),
        const Radius.circular(1),
      ),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14.5, 2, 2, 5),
        const Radius.circular(1),
      ),
      stroke,
    );
    // Body and header band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3.5, 5, 17, 15.5),
        const Radius.circular(2.5),
      ),
      stroke,
    );
    canvas.drawRect(const Rect.fromLTWH(3.7, 5.2, 16.6, 3.8), fill);
    // Week dots.
    for (final y in [12.5, 16.5]) {
      for (final x in [8.0, 12.0, 16.0]) {
        canvas.drawCircle(Offset(x, y), 1.1, fill);
      }
    }
    // The page that physically turns.
    canvas.save();
    canvas.translate(12, 13.5);
    canvas.transform(
      (Matrix4.identity()..rotateY(calendarFlipAngle(progress))).storage,
    );
    canvas.translate(-12, -13.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 9.5, 8.5, 10.5),
        const Radius.circular(1),
      ),
      Paint()..color = color.withValues(alpha: 0.45),
    );
    final lines = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final y in [12.5, 15.5, 18.5]) {
      canvas.drawLine(Offset(13.5, y), Offset(19, y), lines);
    }
    canvas.restore();
  }

  void _paintFlame(Canvas canvas) {
    final sway = flameSway(progress);
    canvas.save();
    canvas.translate(12, 21);
    canvas.scale(1, flameStretch(progress));
    canvas.translate(-12, -21);

    final outer = Path()
      ..moveTo(12, 21)
      ..cubicTo(5.5, 21, 4, 15.5, 8, 10.5)
      ..cubicTo(
        9.5 + sway * 0.3,
        8.5,
        10 + sway * 0.5,
        6,
        10.2 + sway * 0.6,
        3.2,
      )
      ..cubicTo(
        13 + sway * 0.4,
        6,
        14.5 + sway * 0.5,
        8.5,
        14.8 + sway * 0.6,
        11,
      )
      ..cubicTo(
        16.5 + sway * 0.4,
        9.2,
        17 + sway * 0.5,
        7.4,
        16.6 + sway * 0.6,
        5,
      )
      ..cubicTo(20.2, 10.5, 19.5, 18.5, 15, 20.7)
      ..cubicTo(14, 21, 13, 21, 12, 21)
      ..close();
    canvas.drawPath(outer, Paint()..color = color.withValues(alpha: 0.65));

    final core = Path()
      ..moveTo(12, 20)
      ..cubicTo(9, 20, 8.5, 16.5, 10.5, 13.5)
      ..cubicTo(
        11.5 + sway * 0.3,
        11.5,
        12 + sway * 0.4,
        10,
        12 + sway * 0.4,
        8.5,
      )
      ..cubicTo(14.5 + sway * 0.3, 11.5, 15.5, 15, 14, 18)
      ..cubicTo(13.5, 19.5, 12.8, 20, 12, 20)
      ..close();
    canvas.drawPath(core, Paint()..color = color);
    canvas.restore();
  }

  void _paintStars(Canvas canvas) {
    _drawSparkle(canvas, const Offset(12, 12), 4.2, color);
    const spots = [
      Offset(12, 3),
      Offset(20, 8),
      Offset(18.5, 19),
      Offset(4, 16),
    ];
    for (var i = 0; i < spots.length; i++) {
      final opacity = starOpacity(progress, i);
      if (opacity <= 0) continue;
      _drawSparkle(
        canvas,
        spots[i],
        2.4 * (0.6 + 0.4 * opacity),
        color.withValues(alpha: opacity),
      );
    }
  }

  void _drawSparkle(
    Canvas canvas,
    Offset center,
    double size,
    Color paintColor,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(
        center.dx + size * 0.18,
        center.dy - size * 0.18,
        center.dx + size,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + size * 0.18,
        center.dy + size * 0.18,
        center.dx,
        center.dy + size,
      )
      ..quadraticBezierTo(
        center.dx - size * 0.18,
        center.dy + size * 0.18,
        center.dx - size,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - size * 0.18,
        center.dy - size * 0.18,
        center.dx,
        center.dy - size,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = paintColor);
  }

  void _paintBookmark(Canvas canvas, Paint fill) {
    canvas.save();
    canvas.translate(0, bookmarkOffset(progress));
    final path = Path()
      ..moveTo(6.5, 3.5)
      ..lineTo(17.5, 3.5)
      ..lineTo(17.5, 20.5)
      ..lineTo(12, 16)
      ..lineTo(6.5, 20.5)
      ..close();
    canvas.drawPath(path, fill);
    canvas.restore();
  }

  void _paintStopwatch(Canvas canvas, Paint fill, Paint stroke) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10.5, 2, 3, 3),
        const Radius.circular(0.8),
      ),
      fill,
    );
    canvas.drawCircle(const Offset(12, 13), 8.2, stroke);
    final tick = Paint()
      ..color = color
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawLine(
        Offset(12 + 6.6 * math.sin(a), 13 - 6.6 * math.cos(a)),
        Offset(12 + 7.6 * math.sin(a), 13 - 7.6 * math.cos(a)),
        tick,
      );
    }
    final angle = stopwatchHandAngle(progress);
    canvas.drawLine(
      const Offset(12, 13),
      Offset(12 + 6.2 * math.sin(angle), 13 - 6.2 * math.cos(angle)),
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(12, 13), 1.6, fill);
  }

  void _paintPose(Canvas canvas, Paint fill, Paint stroke) {
    canvas.drawCircle(const Offset(12, 4.5), 2.3, fill);
    canvas.drawLine(const Offset(12, 7), const Offset(12, 15), stroke);
    canvas.drawLine(const Offset(12, 15), const Offset(8.5, 20.5), stroke);
    canvas.drawLine(const Offset(12, 15), const Offset(15.5, 20.5), stroke);
    canvas.drawLine(const Offset(12, 9), const Offset(8, 12), stroke);

    final angle = poseHandAngle(progress);
    final hand = Offset(12 + 5.4 * math.cos(angle), 9 + 5.4 * math.sin(angle));
    canvas.drawLine(const Offset(12, 9), hand, stroke);
    canvas.drawCircle(hand, 1.5, fill);
  }
}
