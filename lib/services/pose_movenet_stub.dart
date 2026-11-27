import 'package:camera/camera.dart';

import 'pose_analysis_service.dart';

/// Web stub for the native TensorFlow Lite MoveNet detector.
///
/// Web already runs the TF.js MoveNet model in `web_pose_web.dart`, and other
/// unsupported platforms keep the ML Kit path in `PoseAnalysisService`.
abstract final class PoseMoveNetService {
  static String? get lastError => null;
  static double? get lastPoseScore => null;
  static double? get lastMaxKeypointScore => null;
  static int? get lastKeypointsAboveCropThreshold => null;
  static int? get lastRotation => null;
  static int? get lastEmptyFrameCount => null;
  static String? get lastInputFormat => null;
  static bool? get lastOutputHasSignal => null;
  static String? get lastDiagnostics => null;

  static Future<List<PoseKeypoint>?> detectFromCameraImage(
    CameraImage image, {
    required CameraDescription camera,
    bool mirrorX = false,
  }) async => null;

  static void reset() {}

  static void dispose() {}
}
