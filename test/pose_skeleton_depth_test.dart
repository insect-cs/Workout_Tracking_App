import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/widgets/pose_skeleton_painter.dart';

void main() {
  test('joint colour and radius encode relative depth', () {
    const base = Color(0xFFFFFFFF);

    expect(PoseSkeletonPainter.depthColor(0, base), base);
    expect(PoseSkeletonPainter.depthRadius(0), 4.0);

    final near = PoseSkeletonPainter.depthColor(-0.8, base);
    final far = PoseSkeletonPainter.depthColor(0.8, base);
    expect(near.b, greaterThan(near.r));
    expect(far.r, greaterThan(far.b));
    expect(near, isNot(base));
    expect(far, isNot(base));

    expect(PoseSkeletonPainter.depthRadius(-1), closeTo(6.5, 1e-12));
    expect(PoseSkeletonPainter.depthRadius(1), closeTo(2.5, 1e-12));

    // Out-of-range values are clamped to the same near/far extremes.
    expect(
      PoseSkeletonPainter.depthColor(-4, base),
      PoseSkeletonPainter.depthColor(-1, base),
    );
    expect(PoseSkeletonPainter.depthRadius(4), 2.5);
  });
}
