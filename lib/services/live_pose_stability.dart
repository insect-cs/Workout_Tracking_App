import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'pose_analysis_service.dart';

/// Gates live exercise counters on a freshly detected, continuous subject.
///
/// MoveNet runs on every camera frame, but a weak pose can jump between
/// subjects or disappear for a frame. Drawing the last skeleton briefly is
/// fine; letting that skeleton (or a jump) update a rep counter is what makes
/// landmarks appear to generate activity by themselves. This gate keeps the
/// overlay responsive while requiring several consecutive, plausible frames
/// before any counter or exercise name is allowed to change.
class LivePoseStabilityGate {
  static const int requiredFreshFrames = 6;
  static const Duration maxFrameGap = Duration(milliseconds: 250);
  static const double maxCenterJump = 0.12;
  static const double minJointConfidence = 0.12;

  int _consecutiveFrames = 0;
  DateTime? _lastFrameAt;
  Offset? _lastCenter;

  bool get isStable => _consecutiveFrames >= requiredFreshFrames;

  /// Returns true only after [requiredFreshFrames] consecutive fresh frames of
  /// the same subject. Call [reset] whenever detection returns no pose.
  bool accept(List<PoseKeypoint> keypoints, DateTime now) {
    final center = bodyCenter(keypoints);
    if (center == null) {
      reset();
      return false;
    }

    final lastAt = _lastFrameAt;
    final lastCenter = _lastCenter;
    final continuous =
        lastAt != null &&
        lastCenter != null &&
        now.difference(lastAt) <= maxFrameGap &&
        (center - lastCenter).distance <= maxCenterJump;

    _consecutiveFrames = continuous ? _consecutiveFrames + 1 : 1;
    _lastFrameAt = now;
    _lastCenter = center;
    return isStable;
  }

  void reset() {
    _consecutiveFrames = 0;
    _lastFrameAt = null;
    _lastCenter = null;
  }

  /// Centre of the tracked body, using hips first and shoulders as a fallback.
  /// Low-confidence core joints are ignored so a phantom ankle/hip cannot make
  /// an otherwise stable subject look like a new one on every frame.
  @visibleForTesting
  static Offset? bodyCenter(List<PoseKeypoint> keypoints) {
    for (final side in ['left', 'right']) {
      final hip = _confident(keypoints, '${side}_hip');
      final shoulder = _confident(keypoints, '${side}_shoulder');
      if (hip != null && shoulder != null) {
        return Offset((hip.x + shoulder.x) / 2, (hip.y + shoulder.y) / 2);
      }
    }
    final hip =
        _confident(keypoints, 'left_hip') ?? _confident(keypoints, 'right_hip');
    if (hip != null) return Offset(hip.x, hip.y);
    final shoulder =
        _confident(keypoints, 'left_shoulder') ??
        _confident(keypoints, 'right_shoulder');
    if (shoulder != null) return Offset(shoulder.x, shoulder.y);
    return null;
  }

  static PoseKeypoint? _confident(List<PoseKeypoint> keypoints, String name) {
    for (final point in keypoints) {
      if (point.name == name && point.confidence >= minJointConfidence) {
        return point;
      }
    }
    return null;
  }
}
