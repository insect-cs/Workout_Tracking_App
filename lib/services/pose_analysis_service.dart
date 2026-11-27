import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api_key_service.dart';
import 'pose_movenet.dart';

class PoseAnalysisResult {
  final String exerciseName;
  final String confidence;
  final String description;
  final List<String> keyPoints;
  final List<String> formTips;
  final String musclesWorked;
  final List<PoseKeypoint> detectedKeypoints;
  final String
  engineUsed; // e.g. 'MoveNet + ML Kit depth' or 'Gemini AI Vision'

  const PoseAnalysisResult({
    required this.exerciseName,
    required this.confidence,
    required this.description,
    required this.keyPoints,
    required this.formTips,
    required this.musclesWorked,
    required this.detectedKeypoints,
    this.engineUsed = 'ML Kit + AI',
  });
}

class PoseKeypoint {
  final String name;
  final double x; // 0.0 to 1.0 normalized
  final double y; // 0.0 to 1.0 normalized
  final double confidence;

  /// Signed depth relative to the camera frame width. Negative values are
  /// closer to the camera, positive values are farther away, and 0 means
  /// unavailable or at the depth origin. MoveNet is 2D, so Android live frames
  /// carry this only when the low-frequency depth sampler has supplied it.
  final double z;

  const PoseKeypoint({
    required this.name,
    required this.x,
    required this.y,
    required this.confidence,
    this.z = 0.0,
  });

  PoseKeypoint copyWith({double? z}) => PoseKeypoint(
    name: name,
    x: x,
    y: y,
    confidence: confidence,
    z: z ?? this.z,
  );
}

class PoseAnalysisService {
  /// Rotates normalized keypoints clockwise by [degrees] for a display-only
  /// stream flip. Joint angles are invariant under rotation, so counters and
  /// classification keep using the detector's original coordinates.
  static List<PoseKeypoint> rotateStream(
    List<PoseKeypoint> keypoints,
    int degrees,
  ) {
    final turn = ((degrees % 360) + 360) % 360;
    if (turn == 0) return keypoints;

    return keypoints
        .map((point) {
          final x = switch (turn) {
            90 => 1 - point.y,
            180 => 1 - point.x,
            270 => point.y,
            _ => point.x,
          };
          final y = switch (turn) {
            90 => point.x,
            180 => 1 - point.y,
            270 => 1 - point.x,
            _ => point.y,
          };
          return PoseKeypoint(
            name: point.name,
            x: x,
            y: y,
            confidence: point.confidence,
            z: point.z,
          );
        })
        .toList(growable: false);
  }

  /// Last error reported by the native detector. The live-tracking UI shows
  /// this instead of silently claiming "no person detected", which used to
  /// hide frame-format / detector failures completely.
  static String? _lastNativeDetectionError;
  static String? get lastNativeDetectionError => _lastNativeDetectionError;

  /// Diagnostics from the Android MoveNet engine, shown in the live overlay so
  /// a low-confidence pose can be distinguished from a stalled frame stream.
  static double? get lastMoveNetPoseScore => PoseMoveNetService.lastPoseScore;
  static double? get lastMoveNetMaxKeypointScore =>
      PoseMoveNetService.lastMaxKeypointScore;
  static int? get lastMoveNetKeypointsAboveCropThreshold =>
      PoseMoveNetService.lastKeypointsAboveCropThreshold;
  static int? get lastMoveNetRotation => PoseMoveNetService.lastRotation;
  static int? get lastMoveNetEmptyFrameCount =>
      PoseMoveNetService.lastEmptyFrameCount;
  static String? get lastMoveNetInputFormat =>
      PoseMoveNetService.lastInputFormat;
  static bool? get lastMoveNetOutputHasSignal =>
      PoseMoveNetService.lastOutputHasSignal;
  static String? get lastMoveNetDiagnostics =>
      PoseMoveNetService.lastDiagnostics;

  // CameraX reports a sensor orientation that does not always match the
  // rotation of the frames it delivers (notably on newer Android devices).
  // Remember the rotation that actually produces landmarks and probe the
  // alternatives if frames keep coming back empty.
  static InputImageRotation? _preferredRotation;
  static int _emptyFrameCount = 0;
  static int _rotationProbeIndex = 0;
  static const _allRotations = [
    InputImageRotation.rotation0deg,
    InputImageRotation.rotation90deg,
    InputImageRotation.rotation180deg,
    InputImageRotation.rotation270deg,
  ];

  static PoseDetector? _mlkitPoseDetector;

  static PoseDetector get mlkitDetector {
    _mlkitPoseDetector ??= PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.base,
      ),
    );
    return _mlkitPoseDetector!;
  }

  /// Dedicated streaming-mode detector for live camera tracking.
  static PoseDetector? _streamingPoseDetector;

  static PoseDetector get streamingDetector {
    _streamingPoseDetector ??= PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
    return _streamingPoseDetector!;
  }

  // MoveNet stays the live detector on Android because it is smooth and
  // accurate. ML Kit is sampled at a low rate only to supply the experimental
  // relative z value that MoveNet cannot produce. Its result is cached and
  // merged into the next MoveNet skeletons so the visible stream never waits
  // for the second detector.
  static const Duration _depthSampleInterval = Duration(milliseconds: 250);
  static DateTime? _lastDepthSampleAt;
  static bool _depthSampleInFlight = false;
  static int _depthSession = 0;
  static final Map<String, double> _latestDepthByLandmark = <String, double>{};

  /// MoveNet supplies x/y every frame but depth is only sampled four times a
  /// second. Smoothing per joint turns those steps into a continuous stream so
  /// the 3D viewport does not pop. The first sample is used as-is; later ones
  /// converge with this alpha.
  static const double _depthSmoothingAlpha = 0.25;
  static final Map<String, double> _smoothedDepthByLandmark =
      <String, double>{};

  /// Applies the same per-joint low-pass to detectors that already emit z on
  /// every frame (iOS ML Kit), keeping live 2D and 3D overlays consistent.
  @visibleForTesting
  static List<PoseKeypoint> smoothLiveDepth(List<PoseKeypoint> keypoints) {
    var changed = false;
    final result = keypoints
        .map((point) {
          final previous = _smoothedDepthByLandmark[point.name];
          if (previous == null) {
            _smoothedDepthByLandmark[point.name] = point.z;
            return point;
          }
          final smoothed =
              previous + _depthSmoothingAlpha * (point.z - previous);
          _smoothedDepthByLandmark[point.name] = smoothed;
          changed = true;
          return point.copyWith(z: smoothed);
        })
        .toList(growable: false);
    return changed ? result : keypoints;
  }

  /// Detects pose landmarks from a live camera frame in real time.
  /// Returns normalized (0.0 - 1.0) keypoints ready for the skeleton painter.
  /// Set [mirrorX] to true for the front-facing camera so the plotted
  /// skeleton matches the mirrored preview exactly.
  static Future<List<PoseKeypoint>?> detectFromCameraImage(
    CameraImage image, {
    required CameraDescription camera,
    bool mirrorX = false,
  }) async {
    _lastNativeDetectionError = null;

    // Android keeps MoveNet as the live detector. ML Kit is sampled in the
    // background at a low rate only for relative depth, never as a fallback
    // for x/y tracking. If MoveNet fails, tracking stays empty.
    if (Platform.isAndroid) {
      final moveNetKeypoints = await PoseMoveNetService.detectFromCameraImage(
        image,
        camera: camera,
        mirrorX: mirrorX,
      );
      final moveNetError = PoseMoveNetService.lastError;
      if (moveNetError != null) {
        _lastNativeDetectionError = moveNetError;
        debugPrint('[Pose] MoveNet error: $moveNetError');
      }
      if (moveNetKeypoints == null) {
        _emptyFrameCount++;
        _latestDepthByLandmark.clear();
        return null;
      }
      _emptyFrameCount = 0;
      _requestDepthSample(image, camera);
      return applyDepthToKeypoints(moveNetKeypoints);
    }

    try {
      final sensorRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      var rotation = _preferredRotation ?? sensorRotation;

      // If the device keeps returning no poses with the reported rotation,
      // try the other three on successive frames and lock in whichever one
      // actually sees the person.
      if (_preferredRotation == null && _emptyFrameCount >= 8) {
        final alternatives = _allRotations
            .where((candidate) => candidate != sensorRotation)
            .toList();
        rotation = alternatives[_rotationProbeIndex % alternatives.length];
        _rotationProbeIndex++;
      }

      // Only iOS reaches this block; Android returns from MoveNet above.
      final inputImage = InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      List<Pose> poses = const [];
      try {
        poses = await streamingDetector.processImage(inputImage);
      } catch (e) {
        _lastNativeDetectionError = 'Streaming detector error: $e';
      }

      // Some devices report no poses in STREAM mode on the first frames.
      // Fall back to the single-image detector so tracking still starts.
      if (poses.isEmpty) {
        try {
          final fallback = await mlkitDetector.processImage(inputImage);
          if (fallback.isNotEmpty) {
            poses = fallback;
            _lastNativeDetectionError = null;
          }
        } catch (e) {
          _lastNativeDetectionError ??= 'Pose detector error: $e';
        }
      }
      if (poses.isEmpty) {
        _emptyFrameCount++;
        return null;
      }

      final landmarks = poses.first.landmarks;
      if (landmarks.isEmpty) {
        _emptyFrameCount++;
        return null;
      }

      _preferredRotation = rotation;
      _emptyFrameCount = 0;

      // ML Kit reports landmark positions in the *rotated* frame coordinate
      // space. Normalize against those true dimensions so the skeleton lines
      // up with the camera preview (dividing by the largest landmark instead
      // used to squish/shift the skeleton and break angle calculations).
      final frameSize = poseFrameSize(image.width, image.height, rotation);

      final keypoints = <PoseKeypoint>[];
      landmarks.forEach((type, lm) {
        var normX = lm.x / frameSize.width;
        var normY = lm.y / frameSize.height;
        if (mirrorX) normX = 1 - normX;
        keypoints.add(
          PoseKeypoint(
            name: _landmarkTypeName(type),
            x: normX.clamp(0.0, 1.0),
            y: normY.clamp(0.0, 1.0),
            confidence: lm.likelihood,
            z: frameSize.width > 0
                ? (lm.z / frameSize.width).clamp(-1.0, 1.0)
                : 0.0,
          ),
        );
      });

      return smoothLiveDepth(keypoints);
    } catch (e) {
      _lastNativeDetectionError = e.toString();
      debugPrint('ML Kit streaming pose detection error: $e');
      return null;
    }
  }

  /// Requests an ML Kit depth sample without blocking the MoveNet stream. Only
  /// one sample is ever in flight, and samples are throttled to four per second.
  static void _requestDepthSample(CameraImage image, CameraDescription camera) {
    final now = DateTime.now();
    final last = _lastDepthSampleAt;
    if (_depthSampleInFlight ||
        (last != null && now.difference(last) < _depthSampleInterval)) {
      return;
    }
    _lastDepthSampleAt = now;
    _depthSampleInFlight = true;
    final session = _depthSession;
    unawaited(
      _sampleDepth(image, camera, session).whenComplete(() {
        _depthSampleInFlight = false;
      }),
    );
  }

  static Future<void> _sampleDepth(
    CameraImage image,
    CameraDescription camera,
    int session,
  ) async {
    try {
      final nv21 = packedNv21FromCameraImage(image);
      if (nv21 == null) return;

      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final inputImage = InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      final poses = await streamingDetector.processImage(inputImage);
      if (poses.isEmpty) return;

      final frameWidth = poseFrameSize(
        image.width,
        image.height,
        rotation,
      ).width;
      if (frameWidth <= 0) return;

      final depths = depthByNameFromLandmarks(
        poses.first.landmarks,
        frameWidth,
      );
      if (depths.isEmpty || session != _depthSession) return;
      _latestDepthByLandmark
        ..clear()
        ..addAll(depths);
    } catch (e) {
      // Depth is supplementary. Never surface this as a tracking failure: the
      // smooth MoveNet x/y stream is still valid without it.
      debugPrint('[Pose] depth sample skipped: $e');
    }
  }

  /// Normalizes ML Kit's experimental z values by the frame width and maps
  /// them onto the app's landmark names. Negative values are toward the camera.
  @visibleForTesting
  static Map<String, double> depthByNameFromLandmarks(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    double frameWidth,
  ) {
    if (frameWidth <= 0) return const <String, double>{};
    final depths = <String, double>{};
    landmarks.forEach((type, landmark) {
      final z = landmark.z / frameWidth;
      if (z.isFinite) {
        depths[_landmarkTypeName(type)] = z.clamp(-1.0, 1.0);
      }
    });
    return depths;
  }

  /// Copies the cached depth onto MoveNet keypoints by landmark name, applying
  /// the per-joint low-pass so the 4 Hz depth samples do not step visibly.
  /// Keypoints without a depth sample keep `z == 0` instead of reusing another
  /// body part.
  @visibleForTesting
  static List<PoseKeypoint> applyDepthToKeypoints(
    List<PoseKeypoint> keypoints, {
    Map<String, double>? depthByName,
  }) {
    final depths = depthByName ?? _latestDepthByLandmark;
    if (depths.isEmpty) return keypoints;

    var changed = false;
    final merged = keypoints
        .map((point) {
          final depth = depths[point.name];
          if (depth == null) return point;
          final previous = _smoothedDepthByLandmark[point.name];
          final smoothed = previous == null
              ? depth
              : previous + _depthSmoothingAlpha * (depth - previous);
          _smoothedDepthByLandmark[point.name] = smoothed;
          changed = true;
          return point.copyWith(z: smoothed);
        })
        .toList(growable: false);
    return changed ? merged : keypoints;
  }

  /// Clears per-session live tracking heuristics. Call when a new live camera
  /// session starts so a rotation learned from a previous camera is not reused.
  static void resetLiveTracking() {
    _depthSession++;
    _preferredRotation = null;
    _emptyFrameCount = 0;
    _rotationProbeIndex = 0;
    _lastNativeDetectionError = null;
    _lastDepthSampleAt = null;
    _depthSampleInFlight = false;
    _latestDepthByLandmark.clear();
    _smoothedDepthByLandmark.clear();
    PoseMoveNetService.reset();
  }

  static void dispose() {
    PoseMoveNetService.dispose();
    _mlkitPoseDetector?.close();
    _mlkitPoseDetector = null;
    _streamingPoseDetector?.close();
    _streamingPoseDetector = null;
    resetLiveTracking();
  }

  /// Attempts native Google ML Kit pose detection on mobile (Android/iOS).
  /// Returns detected keypoints normalized if successful, or null on unsupported platform or error.
  static Future<List<PoseKeypoint>?> tryDetectWithMLKit(
    String imagePath,
  ) async {
    // google_mlkit_pose_detection is only supported on Android and iOS
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final poses = await mlkitDetector.processImage(inputImage);
      if (poses.isEmpty) return null;

      final pose = poses.first;
      final keypoints = <PoseKeypoint>[];

      // Convert ML Kit landmarks
      final landmarks = pose.landmarks;

      // Find bounds for normalization
      double minX = double.infinity, maxX = -double.infinity;
      double minY = double.infinity, maxY = -double.infinity;

      for (final lm in landmarks.values) {
        if (lm.x < minX) minX = lm.x;
        if (lm.x > maxX) maxX = lm.x;
        if (lm.y < minY) minY = lm.y;
        if (lm.y > maxY) maxY = lm.y;
      }

      final width = (maxX - minX).abs();
      final height = (maxY - minY).abs();

      // ML Kit's z is in image pixels like x/y. Normalize by the visible body
      // width here because static-image analysis does not carry frame metadata.
      final depthScale = width > 0 ? width : 1.0;
      landmarks.forEach((type, landmark) {
        final normX = width > 0
            ? ((landmark.x - minX) / width).clamp(0.05, 0.95)
            : 0.5;
        final normY = height > 0
            ? ((landmark.y - minY) / height).clamp(0.05, 0.95)
            : 0.5;

        keypoints.add(
          PoseKeypoint(
            name: _landmarkTypeName(type),
            x: normX,
            y: normY,
            confidence: landmark.likelihood,
            z: (landmark.z / depthScale).clamp(-1.0, 1.0),
          ),
        );
      });

      return keypoints;
    } catch (e) {
      debugPrint('ML Kit Pose detection error: $e');
      return null;
    }
  }

  static String _landmarkTypeName(PoseLandmarkType type) {
    switch (type) {
      case PoseLandmarkType.nose:
        return 'head';
      case PoseLandmarkType.leftShoulder:
        return 'left_shoulder';
      case PoseLandmarkType.rightShoulder:
        return 'right_shoulder';
      case PoseLandmarkType.leftElbow:
        return 'left_elbow';
      case PoseLandmarkType.rightElbow:
        return 'right_elbow';
      case PoseLandmarkType.leftWrist:
        return 'left_wrist';
      case PoseLandmarkType.rightWrist:
        return 'right_wrist';
      case PoseLandmarkType.leftHip:
        return 'left_hip';
      case PoseLandmarkType.rightHip:
        return 'right_hip';
      case PoseLandmarkType.leftKnee:
        return 'left_knee';
      case PoseLandmarkType.rightKnee:
        return 'right_knee';
      case PoseLandmarkType.leftAnkle:
        return 'left_ankle';
      case PoseLandmarkType.rightAnkle:
        return 'right_ankle';
      default:
        return type.name;
    }
  }

  /// Detects pose landmarks from a single video frame (PNG bytes captured
  /// from the playing video stream). Works on any subject: every frame is
  /// re-detected independently, so the skeleton adapts to whichever person
  /// is visible. Landmarks are normalized against the FULL frame dimensions
  /// so they plot accurately on top of the video preview.
  static Future<List<PoseKeypoint>?> detectFromVideoFrameBytes(
    Uint8List pngBytes,
  ) async {
    // google_mlkit_pose_detection is only supported on Android and iOS
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }

    try {
      // Decode the PNG to get true frame dimensions for accurate normalization
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final frameWidth = frame.image.width.toDouble();
      final frameHeight = frame.image.height.toDouble();
      frame.image.dispose();
      codec.dispose();

      // ML Kit needs a file path on this platform
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/pose_frame_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      final inputImage = InputImage.fromFilePath(file.path);
      final poses = await mlkitDetector.processImage(inputImage);

      // Clean up temp frame immediately
      try {
        await file.delete();
      } catch (_) {}

      if (poses.isEmpty) return null;

      final pose = poses.first;
      final landmarks = pose.landmarks;
      if (landmarks.isEmpty) return null;

      final keypoints = <PoseKeypoint>[];
      landmarks.forEach((type, landmark) {
        // Normalize against the full frame so the skeleton aligns with the
        // video preview exactly, regardless of subject position or size.
        final normX = frameWidth > 0 ? (landmark.x / frameWidth) : 0.5;
        final normY = frameHeight > 0 ? (landmark.y / frameHeight) : 0.5;
        keypoints.add(
          PoseKeypoint(
            name: _landmarkTypeName(type),
            x: normX.clamp(0.0, 1.0),
            y: normY.clamp(0.0, 1.0),
            confidence: landmark.likelihood,
            z: frameWidth > 0
                ? (landmark.z / frameWidth).clamp(-1.0, 1.0)
                : 0.0,
          ),
        );
      });

      return keypoints;
    } catch (e) {
      debugPrint('ML Kit video frame pose detection error: $e');
      return null;
    }
  }

  /// Analyzes image bytes with Gemini AI Vision (cross-platform compatible with Web, Windows, Android, iOS)
  static Future<PoseAnalysisResult> analyzeImageBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
    List<PoseKeypoint>? predetectedPoints,
  }) async {
    final config = await ApiKeyStore.instance.requireActiveConfig();

    final base64Image = base64Encode(bytes);

    final prompt = '''
You are an expert fitness coach and biomechanics specialist. Analyze this image or video frame of an individual exercising.

Identify:
1. Exact exercise being performed (e.g., Barbell Back Squat, Push-up, Deadlift, Bicep Curl, Plank, Lunge, Bench Press, Shoulder Press).
2. Quality of posture and form.
3. 3 specific biomechanical key observations.
4. 3 actionable form correction cues.
5. Primary and secondary muscles activated.
6. Body keypoint positions (normalized 0.0 to 1.0 for x and y coordinates).

Return ONLY valid JSON (no markdown, no backticks):
{
  "exerciseName": "Exercise Name",
  "confidence": "High",
  "description": "Clear 1-2 sentence description of the observed exercise motion.",
  "keyPoints": [
    "Observation 1 regarding angle, joint alignment or spinal posture",
    "Observation 2 regarding range of motion",
    "Observation 3 regarding balance or bar path"
  ],
  "formTips": [
    "Actionable cue 1",
    "Actionable cue 2",
    "Actionable cue 3"
  ],
  "musclesWorked": "Primary: X, Y | Secondary: A, B",
  "detectedKeypoints": [
    {"name": "head", "x": 0.5, "y": 0.1, "confidence": 0.95},
    {"name": "left_shoulder", "x": 0.4, "y": 0.25, "confidence": 0.9},
    {"name": "right_shoulder", "x": 0.6, "y": 0.25, "confidence": 0.9},
    {"name": "left_elbow", "x": 0.35, "y": 0.4, "confidence": 0.85},
    {"name": "right_elbow", "x": 0.65, "y": 0.4, "confidence": 0.85},
    {"name": "left_wrist", "x": 0.3, "y": 0.55, "confidence": 0.8},
    {"name": "right_wrist", "x": 0.7, "y": 0.55, "confidence": 0.8},
    {"name": "left_hip", "x": 0.42, "y": 0.55, "confidence": 0.9},
    {"name": "right_hip", "x": 0.58, "y": 0.55, "confidence": 0.9},
    {"name": "left_knee", "x": 0.4, "y": 0.72, "confidence": 0.85},
    {"name": "right_knee", "x": 0.6, "y": 0.72, "confidence": 0.85},
    {"name": "left_ankle", "x": 0.38, "y": 0.9, "confidence": 0.8},
    {"name": "right_ankle", "x": 0.62, "y": 0.9, "confidence": 0.8}
  ]
}
''';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {'mimeType': mimeType, 'data': base64Image},
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 1024},
    };

    final uri = Uri.parse(config.generateUrl);
    final response = await http
        .post(
          uri,
          headers: geminiHeaders(config.key),
          body: jsonEncode(requestBody),
        )
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception(
            'Analysis timed out - the video may be too large for cloud analysis. '
            'Real-time landmark tracking still runs locally on every frame.',
          ),
        );

    if (response.statusCode != 200) {
      throw Exception('API Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini Vision API');
    }

    String rawText = candidates[0]['content']['parts'][0]['text'] as String;
    rawText = rawText.trim();
    if (rawText.startsWith('```')) {
      rawText = rawText.replaceFirst(RegExp(r'^```[a-z]*\n?'), '');
      rawText = rawText.replaceFirst(RegExp(r'\n?```$'), '');
      rawText = rawText.trim();
    }

    final parsed = jsonDecode(rawText) as Map<String, dynamic>;

    List<PoseKeypoint> finalKeypoints;
    String engine = 'Gemini AI Vision';

    if (predetectedPoints != null && predetectedPoints.isNotEmpty) {
      finalKeypoints = predetectedPoints;
      engine = 'Google ML Kit + Gemini';
    } else {
      final keypointsJson = parsed['detectedKeypoints'] as List<dynamic>? ?? [];
      finalKeypoints = keypointsJson.map((kp) {
        final k = kp as Map<String, dynamic>;
        return PoseKeypoint(
          name: k['name'] as String? ?? '',
          x: (k['x'] as num?)?.toDouble() ?? 0.5,
          y: (k['y'] as num?)?.toDouble() ?? 0.5,
          confidence: (k['confidence'] as num?)?.toDouble() ?? 0.0,
          z: (k['z'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    }

    return PoseAnalysisResult(
      exerciseName: parsed['exerciseName'] as String? ?? 'Identified Exercise',
      confidence: parsed['confidence'] as String? ?? 'High',
      description: parsed['description'] as String? ?? '',
      keyPoints:
          (parsed['keyPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      formTips:
          (parsed['formTips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      musclesWorked: parsed['musclesWorked'] as String? ?? '',
      detectedKeypoints: finalKeypoints,
      engineUsed: engine,
    );
  }

  /// Analyzes an image file with Google ML Kit + Gemini AI Vision
  static Future<PoseAnalysisResult> analyzeImage(File imageFile) async {
    // 1. Try Google ML Kit Pose Detection first if on Android/iOS
    List<PoseKeypoint>? mlkitPoints;
    try {
      mlkitPoints = await tryDetectWithMLKit(imageFile.path);
    } catch (_) {}

    // 2. Perform AI Vision Biomechanical Analysis
    final bytes = await imageFile.readAsBytes();
    final mimeType = _getMimeType(imageFile.path);

    return analyzeImageBytes(
      bytes,
      mimeType: mimeType,
      predetectedPoints: mlkitPoints,
    );
  }

  static String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'image/jpeg';
    }
  }
}

/// Packs a camera frame into a tightly sized NV21 byte array (`width *
/// height * 3 / 2` bytes exactly) for the native pose detectors.
///
/// `camera_android_camerax` either returns one already-NV21 plane (sometimes
/// overallocated because the Y plane has a padded row stride), or three
/// YUV_420_888 planes when NV21 output is unavailable on the device. Both are
/// handled here. Returns null when the frame cannot be converted safely.
Uint8List? packedNv21FromCameraImage(CameraImage image) {
  final width = image.width;
  final height = image.height;
  if (width <= 0 || height <= 0 || width.isOdd || height.isOdd) return null;

  final expectedLength = width * height * 3 ~/ 2;
  final planes = image.planes;

  if (planes.isEmpty) return null;

  if (planes.length == 1) {
    final bytes = planes.first.bytes;
    // A padded NV21 buffer from CameraX can be longer than ML Kit expects.
    // Y and VU bytes are already packed contiguously, so trimming is enough.
    if (bytes.length < expectedLength) return null;
    if (bytes.length == expectedLength) return bytes;
    return Uint8List.sublistView(bytes, 0, expectedLength);
  }

  if (planes.length < 3) return null;

  final yPlane = planes[0];
  final uPlane = planes[1];
  final vPlane = planes[2];
  final yBytes = yPlane.bytes;
  final uBytes = uPlane.bytes;
  final vBytes = vPlane.bytes;

  final yStride = yPlane.bytesPerRow;
  final uStride = uPlane.bytesPerRow;
  final vStride = vPlane.bytesPerRow;
  if (yStride < width || uStride == 0 || vStride == 0) return null;

  final uPixelStride = uPlane.bytesPerPixel ?? 1;
  final vPixelStride = vPlane.bytesPerPixel ?? 1;

  final nv21 = Uint8List(expectedLength);
  var offset = 0;

  // Full-resolution luma plane.
  for (var row = 0; row < height; row++) {
    final start = row * yStride;
    if (start + width > yBytes.length) return null;
    nv21.setRange(offset, offset + width, yBytes, start);
    offset += width;
  }

  // Half-resolution chroma planes, interleaved as VU for NV21.
  for (var row = 0; row < height ~/ 2; row++) {
    for (var col = 0; col < width ~/ 2; col++) {
      final uIndex = row * uStride + col * uPixelStride;
      final vIndex = row * vStride + col * vPixelStride;
      if (uIndex >= uBytes.length || vIndex >= vBytes.length) return null;
      nv21[offset++] = vBytes[vIndex];
      nv21[offset++] = uBytes[uIndex];
    }
  }

  return nv21;
}

/// Size of the coordinate space ML Kit uses for detected landmarks. A 90 or
/// 270 degree rotation swaps width and height.
@visibleForTesting
Size poseFrameSize(int width, int height, InputImageRotation rotation) {
  final swapped =
      rotation == InputImageRotation.rotation90deg ||
      rotation == InputImageRotation.rotation270deg;
  return swapped
      ? Size(height.toDouble(), width.toDouble())
      : Size(width.toDouble(), height.toDouble());
}
