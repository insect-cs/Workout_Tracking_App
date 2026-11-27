import 'package:camera/camera.dart';

import '../services/pose_analysis_service.dart';

/// Stub used on non-web platforms (real implementation is web_pose_web.dart).
class WebPoseService {
  static String? get lastStatus => null;

  static Future<bool> ensureInitialized() async => false;

  /// No-op on native platforms - ML Kit handles tracking there.
  static void setVideoSource(String url) {}

  static void clearVideoSource() {}

  static void syncPlayback({
    required bool playing,
    required double positionSec,
  }) {}

  /// No-op on native platforms - ML Kit handles tracking there.
  static Future<List<PoseKeypoint>?> detectFromVideoElement() async => null;

  /// No-op on native platforms - ML Kit handles camera frames there.
  static Future<List<PoseKeypoint>?> detectFromCameraImageWeb(
    CameraImage image, {
    bool mirrorX = false,
  }) async => null;
}
