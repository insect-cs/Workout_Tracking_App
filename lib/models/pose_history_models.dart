/// Saved snapshot of one completed live-camera tracking session.
///
/// Keypoints are normalised (0..1) so the history screen can redraw the last
/// detected skeleton. The recorded camera video is kept alongside the metrics:
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

  bool get hasVideo =>
      (videoPath != null && videoPath!.isNotEmpty) ||
      (videoBase64 != null && videoBase64!.isNotEmpty);

  /// True when the session has no skeleton, exercise or reps to report.
  bool get hasNoTrackingData =>
      keypoints.isEmpty &&
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
  };

  factory LiveTrackingSession.fromJson(Map<String, dynamic> json) =>
      LiveTrackingSession(
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
            (json['keypoints'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(PoseKeypointSnapshot.fromJson)
                .toList() ??
            const [],
        videoPath: json['videoPath'] as String?,
        videoBase64: json['videoBase64'] as String?,
        videoMimeType: json['videoMimeType'] as String?,
      );
}
