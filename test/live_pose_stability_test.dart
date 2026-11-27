import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/services/live_pose_stability.dart';
import 'package:workout_app/services/pose_analysis_service.dart';

List<PoseKeypoint> _pose({double x = 0.5, double y = 0.5, double score = 0.9}) {
  return [
    PoseKeypoint(name: 'left_hip', x: x, y: y, confidence: score),
    PoseKeypoint(name: 'left_shoulder', x: x, y: y - 0.2, confidence: score),
  ];
}

void main() {
  group('stream rotation for landmarks', () {
    const points = [
      PoseKeypoint(name: 'left_hip', x: 0.25, y: 0.8, confidence: 0.7, z: -0.4),
    ];

    test('180-degree flip is reversible and preserves metadata', () {
      final rotated = PoseAnalysisService.rotateStream(points, 180);
      expect(rotated.single.name, 'left_hip');
      expect(rotated.single.x, closeTo(0.75, 1e-12));
      expect(rotated.single.y, closeTo(0.2, 1e-12));
      expect(rotated.single.confidence, 0.7);
      expect(rotated.single.z, -0.4);

      final restored = PoseAnalysisService.rotateStream(rotated, 180);
      expect(restored.single.x, closeTo(0.25, 1e-12));
      expect(restored.single.y, closeTo(0.8, 1e-12));
    });

    test('270-degree clockwise turn maps x to y and is reversible', () {
      final rotated = PoseAnalysisService.rotateStream(points, 270);
      expect(rotated.single.name, 'left_hip');
      expect(rotated.single.x, closeTo(0.8, 1e-12));
      expect(rotated.single.y, closeTo(0.75, 1e-12));
      expect(rotated.single.confidence, 0.7);
      expect(rotated.single.z, -0.4);

      final restored = PoseAnalysisService.rotateStream(rotated, 90);
      expect(restored.single.x, closeTo(0.25, 1e-12));
      expect(restored.single.y, closeTo(0.8, 1e-12));
    });
  });

  group('LivePoseStabilityGate', () {
    test('requires consecutive fresh frames before activity is accepted', () {
      final gate = LivePoseStabilityGate();
      final start = DateTime(2026, 11, 26, 12);

      for (var i = 0; i < LivePoseStabilityGate.requiredFreshFrames - 1; i++) {
        expect(
          gate.accept(_pose(), start.add(Duration(milliseconds: i * 30))),
          isFalse,
        );
      }
      expect(
        gate.accept(
          _pose(),
          start.add(
            Duration(
              milliseconds:
                  (LivePoseStabilityGate.requiredFreshFrames - 1) * 30,
            ),
          ),
        ),
        isTrue,
      );
    });

    test('resets when the tracked subject jumps or a frame is missed', () {
      final gate = LivePoseStabilityGate();
      final start = DateTime(2026, 11, 26, 12);
      for (var i = 0; i < LivePoseStabilityGate.requiredFreshFrames; i++) {
        gate.accept(_pose(), start.add(Duration(milliseconds: i * 30)));
      }
      expect(gate.isStable, isTrue);

      // A different person entering the frame must not keep the old rep armed.
      expect(
        gate.accept(
          _pose(x: 0.9),
          start.add(const Duration(milliseconds: 150)),
        ),
        isFalse,
      );
      expect(gate.isStable, isFalse);

      gate.reset();
      for (var i = 0; i < LivePoseStabilityGate.requiredFreshFrames; i++) {
        gate.accept(_pose(), start.add(Duration(milliseconds: 300 + i * 30)));
      }
      expect(gate.isStable, isTrue);
      expect(
        gate.accept(_pose(), start.add(const Duration(seconds: 2))),
        isFalse,
      );
    });

    test('ignores low-confidence core joints when locating the body', () {
      expect(LivePoseStabilityGate.bodyCenter(_pose(score: 0.05)), isNull);
      final center = LivePoseStabilityGate.bodyCenter(_pose(x: 0.4, y: 0.6));
      expect(center!.dx, closeTo(0.4, 1e-12));
      expect(center.dy, closeTo(0.5, 1e-12));
    });
  });
}
