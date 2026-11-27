import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'pose_analysis_service.dart';

/// Native Android TensorFlow Lite MoveNet Lightning detector.
///
/// This mirrors the web TF.js MoveNet path: the same 17 COCO keypoints, the
/// same crop-centered single-pose preprocessing, the same 0.25 pose-score
/// rejection, and the same front-camera x mirroring done by the UI. Android
/// live tracking uses this detector exclusively; ML Kit is not a fallback.
abstract final class PoseMoveNetService {
  static const String _modelAsset = 'assets/models/movenet_lightning.tflite';
  static const int _inputSize = 192;
  static const int _keypointCount = 17;
  static const double _minCropKeypointScore = 0.2;
  static const double _minPoseScore = 0.25;
  static const double _cropFilterAlpha = 0.9;

  // COCO MoveNet keypoint order.
  static const int _leftShoulder = 5;
  static const int _rightShoulder = 6;
  static const int _leftHip = 11;
  static const int _rightHip = 12;
  static const List<int> _torsoIndices = [
    _leftShoulder,
    _rightShoulder,
    _leftHip,
    _rightHip,
  ];

  static Interpreter? _interpreter;
  static Future<Interpreter?>? _initialization;
  static bool _loadFailed = false;
  static String? _loadFailureMessage;

  static String? _lastError;
  static String? get lastError => _lastError;

  /// Last inference diagnostics, surfaced in the live overlay so an empty
  /// result can be told apart from a stalled camera stream or a silent
  /// pose-score rejection on device.
  static double? lastPoseScore;
  static double? lastMaxKeypointScore;
  static int? lastKeypointsAboveCropThreshold;
  static int? lastRotation;
  static int? lastEmptyFrameCount;
  static String? lastInputFormat;
  static bool? lastOutputHasSignal;
  static String? lastDiagnostics;

  // CameraX image-analysis frames are already rotated on some devices while
  // CameraDescription still reports the physical sensor rotation. Like the
  // original ML Kit path, probe the four rotations until one produces a pose,
  // then keep it for the rest of the session. This is detector-side metadata
  // selection only; it never changes the Activity or capture orientation.
  static const List<int> _allRotations = [0, 90, 180, 270];
  static const int _rotationProbeAfterEmptyFrames = 6;
  static int? _preferredRotation;
  static int _rotationProbeIndex = 0;
  static int _emptyFrameCount = 0;

  static MoveNetCropRegion? _cropRegion;
  static int? _lastFrameWidth;
  static int? _lastFrameHeight;
  static int? _lastRotation;
  static int _lastTimestampUs = 0;
  static final List<_SmoothPoint> _smoothed = List<_SmoothPoint>.generate(
    _keypointCount,
    (_) => _SmoothPoint(),
  );

  /// Detects MoveNet keypoints from a live camera frame.
  ///
  /// Returns null both for "no person" and for an engine failure. Callers
  /// distinguish them with [lastError] so a normal empty frame does not
  /// silently switch back to the old detector.
  static Future<List<PoseKeypoint>?> detectFromCameraImage(
    CameraImage image, {
    required CameraDescription camera,
    bool mirrorX = false,
  }) async {
    _lastError = null;
    lastPoseScore = null;
    lastMaxKeypointScore = null;
    lastKeypointsAboveCropThreshold = null;
    lastOutputHasSignal = null;
    lastInputFormat =
        '${image.width}x${image.height}, '
        '${image.planes.length} plane(s), format ${image.format.raw}';

    final interpreter = await _ensureInterpreter();
    if (interpreter == null) {
      lastDiagnostics = _lastError ?? 'MoveNet interpreter unavailable';
      return null;
    }

    try {
      final sensorRotation = camera.sensorOrientation % 360;
      final baseRotation = _allRotations.contains(sensorRotation)
          ? sensorRotation
          : 0;
      final rotation = _selectRotation(baseRotation);
      lastRotation = rotation;

      final swapped = rotation == 90 || rotation == 270;
      final frameWidth = swapped ? image.height : image.width;
      final frameHeight = swapped ? image.width : image.height;
      if (frameWidth <= 0 || frameHeight <= 0) {
        _lastError = 'Invalid camera frame ${image.width}x${image.height}';
        lastDiagnostics = _lastError;
        return null;
      }

      if (_lastRotation != rotation ||
          _lastFrameWidth != frameWidth ||
          _lastFrameHeight != frameHeight) {
        _resetTrackingWindow();
        _lastRotation = rotation;
        _lastFrameWidth = frameWidth;
        _lastFrameHeight = frameHeight;
      }

      final crop =
          _cropRegion ?? _initCropRegion(true, frameWidth, frameHeight);
      final input = _buildModelInput(image, crop, rotation);
      if (input == null) {
        _lastError = 'Unsupported camera frame ($lastInputFormat)';
        lastDiagnostics = _lastError;
        return null;
      }

      final output = _allocateOutput(interpreter);
      interpreter.run(input, output);

      final raw = _readOutput(output as List);
      if (raw == null || raw.length < _keypointCount) {
        _lastError = 'Unexpected MoveNet output shape';
        lastDiagnostics = _lastError;
        return null;
      }

      var poseScoreSum = 0.0;
      var validKeypoints = 0;
      var maxKeypointScore = 0.0;
      var outputHasSignal = false;
      for (final point in raw) {
        maxKeypointScore = math.max(maxKeypointScore, point.score);
        if (point.x != 0 || point.y != 0 || point.score != 0) {
          outputHasSignal = true;
        }
        if (point.score > _minCropKeypointScore) {
          poseScoreSum += point.score;
          validKeypoints++;
        }
      }
      final poseScore = validKeypoints > 0
          ? poseScoreSum / validKeypoints
          : 0.0;
      lastPoseScore = poseScore;
      lastMaxKeypointScore = maxKeypointScore;
      lastKeypointsAboveCropThreshold = validKeypoints;
      lastOutputHasSignal = outputHasSignal;
      lastEmptyFrameCount = _emptyFrameCount;
      if (poseScore < _minPoseScore) {
        _emptyFrameCount++;
        _resetTrackingWindow();
        lastDiagnostics =
            'pose ${poseScore.toStringAsFixed(2)} '
            '(max ${maxKeypointScore.toStringAsFixed(2)}, '
            '$validKeypoints/${raw.length} joints > 0.20), '
            'rot $rotation°, $lastInputFormat';
        return null;
      }

      // This rotation produced a valid pose. Remember it so the crop and
      // smoothing state are not thrown away by probing on later frames.
      _preferredRotation = rotation;
      _rotationProbeIndex = 0;
      _emptyFrameCount = 0;

      final fullFramePoints = <MoveNetPoint>[];
      for (final point in raw) {
        fullFramePoints.add(
          MoveNetPoint(
            y: (crop.yMin + point.y * crop.height).clamp(0.0, 1.0),
            x: (crop.xMin + point.x * crop.width).clamp(0.0, 1.0),
            score: point.score,
          ),
        );
      }

      final smoothed = _smoothPoints(fullFramePoints);
      _cropRegion = _filterCropRegion(
        _determineNextCropRegion(smoothed, frameWidth, frameHeight),
      );

      final keypoints = mapKeypoints(smoothed, mirrorX: mirrorX);
      if (keypoints.isEmpty) {
        _emptyFrameCount++;
        lastEmptyFrameCount = _emptyFrameCount;
        lastDiagnostics = 'no mapped joints, rot $rotation°, $lastInputFormat';
        return null;
      }
      lastDiagnostics = 'pose ${poseScore.toStringAsFixed(2)}, rot $rotation°';
      return keypoints;
    } catch (e) {
      _lastError = 'MoveNet detection error: $e';
      lastDiagnostics = _lastError;
      debugPrint('[MoveNet] $e');
      return null;
    }
  }

  /// Clears crop/smoothing state and any rotation learned from a previous
  /// session. The interpreter stays loaded and ready for the next frame.
  static void reset() {
    _preferredRotation = null;
    _rotationProbeIndex = 0;
    _emptyFrameCount = 0;
    lastPoseScore = null;
    lastMaxKeypointScore = null;
    lastKeypointsAboveCropThreshold = null;
    lastRotation = null;
    lastEmptyFrameCount = null;
    lastInputFormat = null;
    lastOutputHasSignal = null;
    lastDiagnostics = null;
    _resetTrackingWindow();
  }

  /// Chooses the frame rotation to feed into MoveNet. A device that reports a
  /// sensor orientation mismatching its image-analysis rotation is detected by
  /// trying the alternatives after a short run of empty frames, mirroring the
  /// rotation fallback the release ML Kit detector used.
  static int _selectRotation(int sensorRotation) {
    final preferred = _preferredRotation;
    if (preferred != null) return preferred;
    if (_emptyFrameCount < _rotationProbeAfterEmptyFrames) {
      return sensorRotation;
    }
    final rotation = probeRotation(
      sensorRotation: sensorRotation,
      probeIndex: _rotationProbeIndex,
    );
    _rotationProbeIndex++;
    return rotation;
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialization = null;
    _loadFailed = false;
    _loadFailureMessage = null;
    _lastError = null;
    reset();
  }

  static void _resetTrackingWindow() {
    _cropRegion = null;
    _lastFrameWidth = null;
    _lastFrameHeight = null;
    _lastRotation = null;
    _lastTimestampUs = 0;
    for (final point in _smoothed) {
      point.x = null;
      point.y = null;
    }
  }

  static Future<Interpreter?> _ensureInterpreter() async {
    final interpreter = _interpreter;
    if (interpreter != null) return interpreter;
    if (_loadFailed) {
      _lastError = _loadFailureMessage ?? 'MoveNet model unavailable';
      return null;
    }

    final pending = _initialization;
    if (pending != null) return pending;

    final future = _loadInterpreter();
    _initialization = future;
    try {
      final loaded = await future;
      _interpreter = loaded;
      if (loaded == null) {
        _loadFailed = true;
        _loadFailureMessage = _lastError;
      }
      return loaded;
    } finally {
      _initialization = null;
    }
  }

  static Future<Interpreter?> _loadInterpreter() async {
    try {
      final options = InterpreterOptions();
      if (Platform.isAndroid) {
        // XNNPACK is the safest fast delegate across Android devices; GPU
        // delegates vary too much by vendor to use for a shipped live path.
        try {
          options.addDelegate(XNNPackDelegate());
        } catch (e) {
          debugPrint('[MoveNet] XNNPACK unavailable, using CPU: $e');
        }
      }
      final interpreter = await Interpreter.fromAsset(
        _modelAsset,
        options: options,
      );
      debugPrint('[MoveNet] TFLite interpreter ready');
      return interpreter;
    } catch (e) {
      _lastError = 'MoveNet model failed to load: $e';
      debugPrint('[MoveNet] $_lastError');
      return null;
    }
  }

  /// Allocates an output buffer with the model's exact shape so
  /// `Interpreter.run` does not reject it. MoveNet normally emits
  /// `[1, 1, 17, 3]`, but accepting `[1, 17, 3]` keeps this resilient to other
  /// bundled variants.
  static Object _allocateOutput(Interpreter interpreter) {
    final shape = interpreter.getOutputTensor(0).shape;
    if (shape.length == 4) {
      return List.generate(
        shape[0],
        (_) => List.generate(
          shape[1],
          (_) => List.generate(
            shape[2],
            (_) => List<double>.filled(shape[3], 0.0),
          ),
        ),
      );
    }
    if (shape.length == 3) {
      return List.generate(
        shape[0],
        (_) =>
            List.generate(shape[1], (_) => List<double>.filled(shape[2], 0.0)),
      );
    }
    return List<double>.filled(_keypointCount * 3, 0.0);
  }

  /// Converts the model's [1, 1, 17, 3] output (or the equivalent [1, 17, 3])
  /// into a flat list of [y, x, score] points.
  static List<MoveNetPoint>? _readOutput(List output) {
    try {
      if (output.isEmpty) return null;
      final batch = output[0] as List;
      if (batch.isEmpty) return null;

      // Accept both [1, 17, 3] and [1, 1, 17, 3] output layouts.
      late final List person;
      if (batch.length >= _keypointCount) {
        person = batch;
      } else if (batch.first is List &&
          (batch.first as List).length >= _keypointCount) {
        person = batch.first as List;
      } else {
        return null;
      }
      if (person.length < _keypointCount) return null;

      final points = <MoveNetPoint>[];
      for (var i = 0; i < _keypointCount; i++) {
        final keypoint = person[i] as List;
        points.add(
          MoveNetPoint(
            y: (keypoint[0] as num).toDouble(),
            x: (keypoint[1] as num).toDouble(),
            score: (keypoint[2] as num).toDouble(),
          ),
        );
      }
      return points;
    } catch (_) {
      return null;
    }
  }

  /// Builds the 192x192 RGB tensor, sampling the upright camera frame through
  /// the current crop region. Out-of-crop pixels stay black, which is what
  /// TF.js `cropAndResize` does for the padded/full-frame crop fallback.
  static Uint8List? _buildModelInput(
    CameraImage image,
    MoveNetCropRegion crop,
    int rotation,
  ) {
    final nv21 = packedNv21FromCameraImage(image);
    if (nv21 == null) return null;

    final rawWidth = image.width;
    final rawHeight = image.height;
    final chromaWidth = rawWidth ~/ 2;
    final chromaHeight = rawHeight ~/ 2;
    if (chromaWidth <= 0 || chromaHeight <= 0) return null;

    final swapped = rotation == 90 || rotation == 270;
    final frameWidth = swapped ? rawHeight : rawWidth;
    final frameHeight = swapped ? rawWidth : rawHeight;
    final chromaOffset = rawWidth * rawHeight;
    // A typed Uint8List keeps tflite_flutter from reshaping the input tensor
    // to a flat [110592] list before inference.
    final input = Uint8List(_inputSize * _inputSize * 3);

    for (var my = 0; my < _inputSize; my++) {
      final cropY = crop.yMin + ((my + 0.5) / _inputSize) * crop.height;
      for (var mx = 0; mx < _inputSize; mx++) {
        final cropX = crop.xMin + ((mx + 0.5) / _inputSize) * crop.width;
        if (cropX < 0 || cropX >= 1 || cropY < 0 || cropY >= 1) continue;

        // Half-pixel centers, matching bilinear cropAndResize sampling.
        final uprightX = cropX * frameWidth - 0.5;
        final uprightY = cropY * frameHeight - 0.5;
        final raw = _rawCoordinates(
          uprightX,
          uprightY,
          rotation,
          rawWidth,
          rawHeight,
        );

        final y = _bilinear(
          nv21,
          0,
          rawWidth,
          rawHeight,
          rawWidth,
          1,
          raw.x,
          raw.y,
        );
        final v = _bilinear(
          nv21,
          chromaOffset,
          chromaWidth,
          chromaHeight,
          chromaWidth * 2,
          2,
          raw.x / 2,
          raw.y / 2,
        );
        final u = _bilinear(
          nv21,
          chromaOffset + 1,
          chromaWidth,
          chromaHeight,
          chromaWidth * 2,
          2,
          raw.x / 2,
          raw.y / 2,
        );

        final vAdjusted = v - 128;
        final uAdjusted = u - 128;
        final dst = (my * _inputSize + mx) * 3;
        input[dst] = _byte(y + 1.402 * vAdjusted);
        input[dst + 1] = _byte(y - 0.344136 * uAdjusted - 0.714136 * vAdjusted);
        input[dst + 2] = _byte(y + 1.772 * uAdjusted);
      }
    }

    return input;
  }

  /// Inverse of the clockwise rotation ML Kit metadata describes, so the
  /// model always sees an upright person regardless of sensor orientation.
  static ({double x, double y}) _rawCoordinates(
    double uprightX,
    double uprightY,
    int rotation,
    int rawWidth,
    int rawHeight,
  ) {
    switch (rotation) {
      case 90:
        return (x: uprightY, y: rawHeight - 1 - uprightX);
      case 180:
        return (x: rawWidth - 1 - uprightX, y: rawHeight - 1 - uprightY);
      case 270:
        return (x: rawWidth - 1 - uprightY, y: uprightX);
      default:
        return (x: uprightX, y: uprightY);
    }
  }

  static double _bilinear(
    Uint8List bytes,
    int offset,
    int width,
    int height,
    int rowStride,
    int pixelStride,
    double x,
    double y,
  ) {
    final x0 = x.floor();
    final y0 = y.floor();
    final fx = x - x0;
    final fy = y - y0;
    final top =
        _planeSample(
              bytes,
              offset,
              width,
              height,
              rowStride,
              pixelStride,
              x0,
              y0,
            ) *
            (1 - fx) +
        _planeSample(
              bytes,
              offset,
              width,
              height,
              rowStride,
              pixelStride,
              x0 + 1,
              y0,
            ) *
            fx;
    final bottom =
        _planeSample(
              bytes,
              offset,
              width,
              height,
              rowStride,
              pixelStride,
              x0,
              y0 + 1,
            ) *
            (1 - fx) +
        _planeSample(
              bytes,
              offset,
              width,
              height,
              rowStride,
              pixelStride,
              x0 + 1,
              y0 + 1,
            ) *
            fx;
    return top * (1 - fy) + bottom * fy;
  }

  static double _planeSample(
    Uint8List bytes,
    int offset,
    int width,
    int height,
    int rowStride,
    int pixelStride,
    int x,
    int y,
  ) {
    final cx = x < 0 ? 0 : (x >= width ? width - 1 : x);
    final cy = y < 0 ? 0 : (y >= height ? height - 1 : y);
    return bytes[offset + cy * rowStride + cx * pixelStride].toDouble();
  }

  static int _byte(double value) => value.round().clamp(0, 255).toInt();

  /// Light temporal smoothing so the skeleton does not jitter between frames.
  /// Web uses a One Euro filter; this simpler low-pass has the same effect of
  /// damping high-frequency noise without delaying large movements.
  static List<MoveNetPoint> _smoothPoints(List<MoveNetPoint> points) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final deltaSeconds = _lastTimestampUs == 0
        ? 0.0
        : (now - _lastTimestampUs) / 1000000.0;
    _lastTimestampUs = now;
    final alpha = deltaSeconds <= 0
        ? 0.5
        : (1 - math.exp(-deltaSeconds / 0.05)).clamp(0.05, 1.0);

    final smoothed = <MoveNetPoint>[];
    for (var i = 0; i < points.length; i++) {
      final previous = _smoothed[i];
      final point = points[i];
      double x;
      double y;
      if (previous.x == null || deltaSeconds > 0.25) {
        x = point.x;
        y = point.y;
      } else {
        x = previous.x! + (point.x - previous.x!) * alpha;
        y = previous.y! + (point.y - previous.y!) * alpha;
      }
      previous.x = x;
      previous.y = y;
      smoothed.add(MoveNetPoint(y: y, x: x, score: point.score));
    }
    return smoothed;
  }

  /// Same square, hip-centered crop strategy used by TF.js MoveNet. Returns
  /// null when the torso is not confident enough, which resets the detector
  /// to the padded full-frame crop on the next frame.
  static MoveNetCropRegion? _determineNextCropRegion(
    List<MoveNetPoint> points,
    int width,
    int height,
  ) {
    final leftHip = points[_leftHip];
    final rightHip = points[_rightHip];
    final leftShoulder = points[_leftShoulder];
    final rightShoulder = points[_rightShoulder];
    final torsoVisible =
        (leftHip.score > _minCropKeypointScore ||
            rightHip.score > _minCropKeypointScore) &&
        (leftShoulder.score > _minCropKeypointScore ||
            rightShoulder.score > _minCropKeypointScore);
    if (!torsoVisible || points.length < _keypointCount) {
      return _initCropRegion(false, width, height);
    }

    final centerX = (leftHip.x + rightHip.x) * 0.5 * width;
    final centerY = (leftHip.y + rightHip.y) * 0.5 * height;
    var maxTorsoX = 0.0;
    var maxTorsoY = 0.0;
    for (final index in _torsoIndices) {
      final point = points[index];
      maxTorsoX = math.max(maxTorsoX, (point.x * width - centerX).abs());
      maxTorsoY = math.max(maxTorsoY, (point.y * height - centerY).abs());
    }

    var maxBodyX = 0.0;
    var maxBodyY = 0.0;
    for (final point in points) {
      if (point.score < _minCropKeypointScore) continue;
      maxBodyX = math.max(maxBodyX, (point.x * width - centerX).abs());
      maxBodyY = math.max(maxBodyY, (point.y * height - centerY).abs());
    }

    var half = math.max(
      math.max(maxTorsoX * 1.9, maxTorsoY * 1.9),
      math.max(maxBodyY * 1.2, maxBodyX * 1.2),
    );
    // Match TF.js: the crop may extend past the frame edge (those pixels are
    // padded black), so only a very large crop falls back to the full frame.
    // Using the *minimum* edge distance here used to shrink the crop to a tiny
    // box whenever the hips were off-center and lost the rest of the body.
    half = math.min(
      half,
      math.max(
        math.max(centerX, width - centerX),
        math.max(centerY, height - centerY),
      ),
    );
    if (half > math.max(width, height) / 2) {
      return _initCropRegion(false, width, height);
    }

    final left = centerX - half;
    final top = centerY - half;
    final size = half * 2;
    return MoveNetCropRegion(
      yMin: top / height,
      xMin: left / width,
      yMax: (top + size) / height,
      xMax: (left + size) / width,
      width: size / width,
      height: size / height,
    );
  }

  static MoveNetCropRegion _initCropRegion(
    bool firstFrame,
    int width,
    int height,
  ) {
    late final double boxWidth;
    late final double boxHeight;
    late final double xMin;
    late final double yMin;

    if (firstFrame) {
      // Best guess from the centre so the first inference has a good chance
      // of finding the person and locking into crop tracking.
      if (width > height) {
        boxHeight = 1.0;
        boxWidth = height / width;
        yMin = 0.0;
        xMin = 0.5 - boxWidth / 2;
      } else {
        boxHeight = width / height;
        boxWidth = 1.0;
        yMin = 0.5 - boxHeight / 2;
        xMin = 0.0;
      }
    } else {
      // No reliable torso: run the model on the whole frame, padded to
      // square with black outside the image.
      if (width > height) {
        boxHeight = width / height;
        boxWidth = 1.0;
        yMin = 0.5 - boxHeight / 2;
        xMin = 0.0;
      } else {
        boxHeight = 1.0;
        boxWidth = height / width;
        yMin = 0.0;
        xMin = 0.5 - boxWidth / 2;
      }
    }

    return MoveNetCropRegion(
      yMin: yMin,
      xMin: xMin,
      yMax: yMin + boxHeight,
      xMax: xMin + boxWidth,
      width: boxWidth,
      height: boxHeight,
    );
  }

  static MoveNetCropRegion? _filterCropRegion(MoveNetCropRegion? next) {
    if (next == null) return null;
    final previous = _cropRegion;
    if (previous == null) return next;

    final yMin =
        _cropFilterAlpha * previous.yMin + (1 - _cropFilterAlpha) * next.yMin;
    final xMin =
        _cropFilterAlpha * previous.xMin + (1 - _cropFilterAlpha) * next.xMin;
    final yMax =
        _cropFilterAlpha * previous.yMax + (1 - _cropFilterAlpha) * next.yMax;
    final xMax =
        _cropFilterAlpha * previous.xMax + (1 - _cropFilterAlpha) * next.xMax;
    return MoveNetCropRegion(
      yMin: yMin,
      xMin: xMin,
      yMax: yMax,
      xMax: xMax,
      width: xMax - xMin,
      height: yMax - yMin,
    );
  }

  static String? _keypointName(int index) {
    switch (index) {
      case 0:
        return 'head';
      case 5:
        return 'left_shoulder';
      case 6:
        return 'right_shoulder';
      case 7:
        return 'left_elbow';
      case 8:
        return 'right_elbow';
      case 9:
        return 'left_wrist';
      case 10:
        return 'right_wrist';
      case 11:
        return 'left_hip';
      case 12:
        return 'right_hip';
      case 13:
        return 'left_knee';
      case 14:
        return 'right_knee';
      case 15:
        return 'left_ankle';
      case 16:
        return 'right_ankle';
      default:
        return null;
    }
  }

  /// Next rotation in the detector's empty-frame probe sequence.
  @visibleForTesting
  static int probeRotation({
    required int sensorRotation,
    required int probeIndex,
  }) {
    final alternatives = _allRotations
        .where((rotation) => rotation != sensorRotation)
        .toList(growable: false);
    return alternatives[probeIndex % alternatives.length];
  }

  /// Test-only access to the pure preprocessing helpers. These do not touch
  /// the TFLite interpreter, so they can be verified without the model asset.
  @visibleForTesting
  static MoveNetCropRegion initialCropRegion({
    required bool firstFrame,
    required int width,
    required int height,
  }) => _initCropRegion(firstFrame, width, height);

  @visibleForTesting
  static MoveNetCropRegion? nextCropRegion(
    List<MoveNetPoint> points,
    int width,
    int height,
  ) => _determineNextCropRegion(points, width, height);

  @visibleForTesting
  static ({double x, double y}) rawCoordinates(
    double uprightX,
    double uprightY,
    int rotation,
    int rawWidth,
    int rawHeight,
  ) => _rawCoordinates(uprightX, uprightY, rotation, rawWidth, rawHeight);

  @visibleForTesting
  static String? keypointName(int index) => _keypointName(index);

  @visibleForTesting
  static List<MoveNetPoint>? readOutput(List output) => _readOutput(output);

  @visibleForTesting
  static List<PoseKeypoint> mapKeypoints(
    List<MoveNetPoint> points, {
    bool mirrorX = false,
  }) {
    final keypoints = <PoseKeypoint>[];
    for (var i = 0; i < points.length; i++) {
      final name = _keypointName(i);
      if (name == null) continue;
      final point = points[i];
      keypoints.add(
        PoseKeypoint(
          name: name,
          x: mirrorX ? 1 - point.x : point.x,
          y: point.y,
          confidence: point.score,
        ),
      );
    }
    return keypoints;
  }
}

class MoveNetPoint {
  const MoveNetPoint({required this.y, required this.x, required this.score});

  final double y;
  final double x;
  final double score;
}

class _SmoothPoint {
  double? x;
  double? y;
}

class MoveNetCropRegion {
  const MoveNetCropRegion({
    required this.yMin,
    required this.xMin,
    required this.yMax,
    required this.xMax,
    required this.width,
    required this.height,
  });

  final double yMin;
  final double xMin;
  final double yMax;
  final double xMax;
  final double width;
  final double height;
}
