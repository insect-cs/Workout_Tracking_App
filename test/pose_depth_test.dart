import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:workout_app/services/pose_analysis_service.dart';

void main() {
  setUp(() => PoseAnalysisService.resetLiveTracking());

  test('ML Kit depth is normalized by frame width and clamped', () {
    final landmarks = <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftKnee: PoseLandmark(
        type: PoseLandmarkType.leftKnee,
        x: 120,
        y: 300,
        z: -120,
        likelihood: 0.9,
      ),
      PoseLandmarkType.rightKnee: PoseLandmark(
        type: PoseLandmarkType.rightKnee,
        x: 280,
        y: 300,
        z: 200,
        likelihood: 0.9,
      ),
      PoseLandmarkType.leftWrist: PoseLandmark(
        type: PoseLandmarkType.leftWrist,
        x: 100,
        y: 120,
        z: -900,
        likelihood: 0.8,
      ),
    };

    final depths = PoseAnalysisService.depthByNameFromLandmarks(landmarks, 400);

    expect(depths['left_knee'], closeTo(-0.3, 1e-12));
    expect(depths['right_knee'], closeTo(0.5, 1e-12));
    expect(depths['left_wrist'], -1.0);
    expect(PoseAnalysisService.depthByNameFromLandmarks(landmarks, 0), isEmpty);
  });

  test('cached depth is merged onto MoveNet keypoints by landmark name', () {
    const keypoints = <PoseKeypoint>[
      PoseKeypoint(name: 'left_knee', x: 0.4, y: 0.7, confidence: 0.9),
      PoseKeypoint(name: 'head', x: 0.5, y: 0.2, confidence: 0.9),
    ];

    final merged = PoseAnalysisService.applyDepthToKeypoints(
      keypoints,
      depthByName: const <String, double>{'left_knee': -0.3},
    );

    expect(merged, hasLength(2));
    expect(merged.first.z, closeTo(-0.3, 1e-12));
    expect(merged.first.x, 0.4);
    expect(merged.last.z, 0.0);
    expect(identical(merged, keypoints), isFalse);
  });
}
