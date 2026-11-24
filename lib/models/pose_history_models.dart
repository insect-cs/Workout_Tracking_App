import '../services/pose_analysis_service.dart';

/// Saved snapshot of one completed live-camera tracking session.
///
/// Keypoints are normalised (0..1) so the history screen can redraw the last
/// detected skeleton. [poseFrames] additionally stores time-stamped skeletons
/// so the recorded video can replay the landmarks that were visible while it
/// was being captured. The recorded camera video is kept alongside the metrics:
/// a file path on native platforms, base64 bytes on web (blob URLs do not
/// survive a page reload).
class PoseKeypointSnapshot {
  const PoseKeypointSnapshot({
    required this.name,
    required this.x,
    required this.y,
    required this.confidence,
  });

  final String name;
  final double x;
  final double y;
  final double confidence;

  Map<String, dynamic> toJson() => {
    'name': name,
    'x': x,
    'y': y,
    'confidence': confidence,
  };

  factory PoseKeypointSnapshot.fromJson(Map<String, dynamic> json) =>
      PoseKeypointSnapshot(
        name: (json['name'] as String?) ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

/// One skeleton sampled from the live camera while a replay video was recording.
///
/// To keep history JSON small, only the 13 landmarks drawn by
/// [PoseSkeletonPainter] are stored, in this fixed order. Each point is three
/// integers: x and y quantised to 0..1000, confidence to 0..100. [tMs] is the
/// position in the recorded video, in milliseconds.
class PoseReplayFrame {
  static const List<String> landmarkNames = <String>[
    'head',
    'left_shoulder',
    'right_shoulder',
    'left_elbow',
    'right_elbow',
    'left_wrist',
    'right_wrist',
    'left_hip',
    'right_hip',
    'left_knee',
    'right_knee',
    'left_ankle',
    'right_ankle',
  ];

  static const int _positionScale = 1000;
  static const int _confidenceScale = 100;
  static const int _valuesPerPoint = 3;
  static final int _encodedLength = landmarkNames.length * _valuesPerPoint;

  const PoseReplayFrame({required this.tMs, required this.values});

  /// Milliseconds from the start of the recorded video.
  final int tMs;

  /// Flat `[x, y, confidence, ...]` triples in [landmarkNames] order.
  final List<int> values;

  Map<String, dynamic> toJson() => {'t': tMs, 'p': values};

  /// Builds a frame from the latest detected landmarks. Returns null when none
  /// of the visualised landmarks has usable confidence, so empty frames do not
  /// bloat history.
  static PoseReplayFrame? fromSnapshots(
    int tMs,
    List<PoseKeypointSnapshot> keypoints,
  ) {
    if (tMs < 0) return null;

    final byName = <String, PoseKeypointSnapshot>{
      for (final point in keypoints) point.name: point,
    };
    final values = <int>[];
    var hasVisiblePoint = false;

    for (final name in landmarkNames) {
      final point = byName[name];
      if (point == null) {
        values.addAll(<int>[0, 0, 0]);
        continue;
      }
      final confidence = (point.confidence * _confidenceScale)
          .round()
          .clamp(0, _confidenceScale)
          .toInt();
      if (confidence > 30) hasVisiblePoint = true;
      values.add(
        (point.x * _positionScale).round().clamp(0, _positionScale).toInt(),
      );
      values.add(
        (point.y * _positionScale).round().clamp(0, _positionScale).toInt(),
      );
      values.add(confidence);
    }

    if (!hasVisiblePoint) return null;
    return PoseReplayFrame(tMs: tMs, values: values);
  }

  /// Reads older/malformed frames defensively; invalid frames are skipped.
  static PoseReplayFrame? tryFromJson(Map<String, dynamic> json) {
    final tMs = (json['t'] as num?)?.toInt();
    final raw = json['p'] as List<dynamic>?;
    if (tMs == null || tMs < 0 || raw == null || raw.length != _encodedLength) {
      return null;
    }

    final values = <int>[];
    for (var index = 0; index < raw.length; index++) {
      final value = (raw[index] as num?)?.toInt() ?? 0;
      final max = index % _valuesPerPoint == 2
          ? _confidenceScale
          : _positionScale;
      values.add(value.clamp(0, max).toInt());
    }
    return PoseReplayFrame(tMs: tMs, values: values);
  }

  /// Decodes this sample into keypoints for [PoseSkeletonPainter].
  ///
  /// Live front-camera keypoints are mirrored to match the preview, while the
  /// saved recording contains the raw camera frames. Set [unmirrorX] when
  /// replaying such a session so the skeleton lines up with the video.
  List<PoseKeypoint> toPoseKeypoints({bool unmirrorX = false}) {
    if (values.length != _encodedLength) return const <PoseKeypoint>[];

    final keypoints = <PoseKeypoint>[];
    for (var index = 0; index < landmarkNames.length; index++) {
      final base = index * _valuesPerPoint;
      final confidence = values[base + 2] / _confidenceScale;
      if (confidence <= 0.3) continue;
      final x = values[base] / _positionScale;
      keypoints.add(
        PoseKeypoint(
          name: landmarkNames[index],
          x: unmirrorX ? 1 - x : x,
          y: values[base + 1] / _positionScale,
          confidence: confidence,
        ),
      );
    }
    return keypoints;
  }

  /// Index of the frame to display at [position]. The previous sample is held
  /// until the next timestamp, and the first/last samples clamp the ends so a
  /// looping video never shows an empty skeleton.
  static int indexAt(List<PoseReplayFrame> frames, Duration position) {
    if (frames.isEmpty) return -1;

    final target = position.inMilliseconds;
    if (target <= frames.first.tMs) return 0;
    if (target >= frames.last.tMs) return frames.length - 1;

    var low = 0;
    var high = frames.length - 1;
    var result = 0;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (frames[middle].tMs <= target) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return result;
  }
}

class LiveTrackingSession {
  const LiveTrackingSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.exerciseName,
    required this.repCount,
    required this.squatCount,
    required this.curlCount,
    required this.pushupCount,
    required this.kneeAngle,
    required this.elbowAngle,
    required this.minKneeAngle,
    required this.minElbowAngle,
    required this.feedback,
    required this.engine,
    required this.cameraName,
    required this.keypoints,
    this.videoPath,
    this.videoBase64,
    this.videoMimeType,
    this.poseFrames = const <PoseReplayFrame>[],
    this.landmarksMirroredX = false,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final String exerciseName;
  final int repCount;
  final int squatCount;
  final int curlCount;
  final int pushupCount;
  final double? kneeAngle;
  final double? elbowAngle;
  final double? minKneeAngle;
  final double? minElbowAngle;
  final String feedback;
  final String engine;
  final String? cameraName;
  final List<PoseKeypointSnapshot> keypoints;

  /// Native path to the recorded camera video, when available.
  final String? videoPath;

  /// Base64-encoded video bytes, used on web where blob URLs are temporary.
  final String? videoBase64;

  /// MIME type reported by the camera recorder (for example `video/webm`).
  final String? videoMimeType;

  /// Time-stamped skeletons recorded while the replay video was captured.
  final List<PoseReplayFrame> poseFrames;

  /// True when [poseFrames] were mirrored for the live front-camera preview and
  /// must be flipped back to align with the raw recorded video.
  final bool landmarksMirroredX;

  bool get hasVideo =>
      (videoPath != null && videoPath!.isNotEmpty) ||
      (videoBase64 != null && videoBase64!.isNotEmpty);

  /// True when the session has no skeleton, exercise or reps to report.
  bool get hasNoTrackingData =>
      keypoints.isEmpty &&
      poseFrames.isEmpty &&
      repCount == 0 &&
      squatCount == 0 &&
      curlCount == 0 &&
      pushupCount == 0;

  Duration get duration => endedAt.difference(startedAt);

  String get formattedDuration {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return rest == 0 ? '${minutes}m' : '${minutes}m ${rest}s';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'exerciseName': exerciseName,
    'repCount': repCount,
    'squatCount': squatCount,
    'curlCount': curlCount,
    'pushupCount': pushupCount,
    'kneeAngle': kneeAngle,
    'elbowAngle': elbowAngle,
    'minKneeAngle': minKneeAngle,
    'minElbowAngle': minElbowAngle,
    'feedback': feedback,
    'engine': engine,
    'cameraName': cameraName,
    'keypoints': keypoints.map((point) => point.toJson()).toList(),
    'videoPath': videoPath,
    'videoBase64': videoBase64,
    'videoMimeType': videoMimeType,
    'poseFrames': poseFrames.map((frame) => frame.toJson()).toList(),
    'landmarksMirroredX': landmarksMirroredX,
  };

  factory LiveTrackingSession.fromJson(Map<String, dynamic> json) {
    final poseFrames = <PoseReplayFrame>[];
    final rawFrames = json['poseFrames'] as List<dynamic>?;
    if (rawFrames != null) {
      for (final value in rawFrames) {
        if (value is! Map<String, dynamic>) continue;
        final frame = PoseReplayFrame.tryFromJson(value);
        if (frame != null) poseFrames.add(frame);
      }
    }

    return LiveTrackingSession(
      id: (json['id'] as String?) ?? '',
      startedAt:
          DateTime.tryParse((json['startedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endedAt:
          DateTime.tryParse((json['endedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      exerciseName: (json['exerciseName'] as String?) ?? 'Exercise',
      repCount: (json['repCount'] as num?)?.toInt() ?? 0,
      squatCount: (json['squatCount'] as num?)?.toInt() ?? 0,
      curlCount: (json['curlCount'] as num?)?.toInt() ?? 0,
      pushupCount: (json['pushupCount'] as num?)?.toInt() ?? 0,
      kneeAngle: (json['kneeAngle'] as num?)?.toDouble(),
      elbowAngle: (json['elbowAngle'] as num?)?.toDouble(),
      minKneeAngle: (json['minKneeAngle'] as num?)?.toDouble(),
      minElbowAngle: (json['minElbowAngle'] as num?)?.toDouble(),
      feedback: (json['feedback'] as String?) ?? '',
      engine: (json['engine'] as String?) ?? '',
      cameraName: json['cameraName'] as String?,
      keypoints:
          (json['keypoints'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(PoseKeypointSnapshot.fromJson)
              .toList() ??
          const [],
      videoPath: json['videoPath'] as String?,
      videoBase64: json['videoBase64'] as String?,
      videoMimeType: json['videoMimeType'] as String?,
      poseFrames: poseFrames,
      landmarksMirroredX: json['landmarksMirroredX'] as bool? ?? false,
    );
  }
}
