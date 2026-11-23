import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../services/pose_analysis_service.dart';

/// Real-time pose detection on web using TensorFlow.js MoveNet.
///
/// Captured video frames (PNG bytes) are decoded into an HTMLImageElement
/// and passed to `poseDetection.createDetector(MoveNet).estimatePoses()`.
/// Keypoints are returned normalized (0-1) using the frame dimensions, and
/// mapped to the same keypoint names the skeleton painter expects, so the
/// overlay works for ANY subject in the video - detection re-runs per frame.
@JS('poseDetection')
external JSPoseDetectionNamespace get _poseDetection;

extension type JSPoseDetectionNamespace._(JSObject _) implements JSObject {
  // ignore: non_constant_identifier_names
  external JSSupportedModels get SupportedModels;
  external JSPromise<JSObject?> createDetector(JSAny? model, JSAny? config);
}

extension type JSSupportedModels._(JSObject _) implements JSObject {
  // MoveNet is a JS *string* constant ('MoveNet'), not an object.
  // ignore: non_constant_identifier_names
  external JSString get MoveNet;
}

@JS('tf')
external JSTfNamespace get _tf;

extension type JSTfNamespace._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> ready();
  external JSPromise<JSBoolean> setBackend(JSString backend);
  external JSString? getBackend();
}

class WebPoseService {
  static bool _initialized = false;
  static bool _failed = false;
  static JSObject? _detector;
  static String? _lastStatus;
  static int _noPersonTicks = 0;

  // Our own hidden <video> element fed with the same blob URL as the picked
  // file. Flutter's video_player on web embeds its <video> inside a shadow
  // DOM which document.querySelector cannot reach, so we drive our own
  // element and keep it in sync with the Flutter player for detection.
  static web.HTMLVideoElement? _hiddenVideo;
  static String? _sourceUrl;

  // Offscreen canvas that receives raw RGBA8888 frames from camera_web's
  // image stream so MoveNet can detect poses on the live webcam.
  static web.HTMLCanvasElement? _frameCanvas;
  static web.CanvasRenderingContext2D? _frameContext;

  static String? get lastStatus => _lastStatus;

  /// Sets (or replaces) the video source for detection. [url] is the blob:
  /// URL of the picked video file on web (XFile.path).
  static void setVideoSource(String url) {
    if (_sourceUrl == url && _hiddenVideo != null) return;
    // Replacing a source must not leave old video elements decoding in the
    // background; that was an additional source of UI stalls after switching
    // videos.
    _hiddenVideo?.remove();
    _sourceUrl = url;
    final v = web.HTMLVideoElement();
    v.src = url;
    v.muted = true;
    v.loop = false;
    v.playsInline = true;
    v.style.display = 'none';
    web.document.body!.append(v);
    _hiddenVideo = v;
  }

  static void clearVideoSource() {
    _hiddenVideo?.remove();
    _hiddenVideo = null;
    _sourceUrl = null;
  }

  /// Keeps the hidden detection video in sync with the Flutter player.
  static void syncPlayback({
    required bool playing,
    required double positionSec,
  }) {
    final v = _hiddenVideo;
    if (v == null) return;
    try {
      if (playing && v.paused) {
        v.play().toDart.catchError((_) => null);
      }
      if (!playing && !v.paused) {
        v.pause();
      }
      // Resync if drift exceeds 400ms (e.g. after seek/replay)
      if ((v.currentTime - positionSec).abs() > 0.4) {
        v.currentTime = positionSec;
      }
    } catch (_) {}
  }

  static Future<bool>? _initializationFuture;

  /// Returns the shared initialization future so warm-up and the first video
  /// frame can never load the model twice.
  static Future<bool> ensureInitialized() {
    if (_initialized) return Future<bool>.value(true);
    if (_failed) return Future<bool>.value(false);

    final pending = _initializationFuture;
    if (pending != null) return pending;

    final future = _initializePoseEngine();
    _initializationFuture = future;
    return future.whenComplete(() {
      _initializationFuture = null;
    });
  }

  static Future<bool> _initializePoseEngine() async {
    try {
      _lastStatus = 'Loading TensorFlow backend...';
      // Prefer WebGL but fall back to CPU (some browsers/VMs block WebGL,
      // which makes tf.ready() reject).
      try {
        await _tf.setBackend('webgl'.toJS).toDart;
      } catch (_) {}
      try {
        await _tf.ready().toDart;
      } catch (_) {
        _lastStatus = 'WebGL unavailable - switching to CPU backend...';
        try {
          await _tf.setBackend('cpu'.toJS).toDart;
          await _tf.ready().toDart;
        } catch (_) {}
      }

      final backendRaw = _tf.getBackend();
      final backend = backendRaw == null ? 'none' : backendRaw.toDart;
      debugPrint('[WebPose] TF backend: $backend');
      if (backend == 'none' || backend == 'null') {
        _failed = true;
        _lastStatus = 'TF backend unavailable: $backend';
        return false;
      }

      _lastStatus = 'Loading MoveNet model...';
      final model = _poseDetection.SupportedModels.MoveNet;
      // Weights are bundled in the app (web/models/movenet_lightning) so
      // nothing is downloaded from tfhub/CDN at runtime - works offline
      // and behind firewalls that block storage.googleapis.com.
      final modelUrl = _absoluteUrl('models/movenet_lightning/model.json');
      final config = {
        'modelType': 'SinglePose.Lightning',
        'modelUrl': modelUrl,
        'fromTFHub': false,
      }.jsify();

      debugPrint('[WebPose] Creating detector, modelUrl: $modelUrl');
      final detector = await _poseDetection
          .createDetector(model, config!)
          .toDart;
      if (detector == null) {
        _failed = true;
        _lastStatus = 'Pose model failed to create';
        return false;
      }
      _detector = detector;
      _initialized = true;
      _lastStatus = null;
      debugPrint('[WebPose] MoveNet detector ready (backend: $backend)');
      return true;
    } catch (e) {
      _failed = true;
      final detail = e.toString();
      debugPrint('[WebPose] Detector init FAILED: $detail');
      _lastStatus = 'Model load failed: $detail';
      return false;
    }
  }

  /// Resolves a relative asset path against the page base URL so the model
  /// loads regardless of how the app is served (root, subpath, debug).
  static String _absoluteUrl(String relative) {
    final base = Uri.base;
    final trimmed = base.path.endsWith('/') ? base.path : base.path;
    return base.scheme == 'file'
        ? relative
        : '${base.origin}${trimmed.endsWith('/') ? trimmed : '$trimmed/'}$relative';
  }

  /// Detects pose keypoints from the live <video> element that
  /// video_player renders on web.
  ///
  /// IMPORTANT: RepaintBoundary.toImage() cannot capture platform views on
  /// web, so video frames captured that way are blank. Instead we locate the
  /// underlying <video> element in the DOM and pass it DIRECTLY to MoveNet
  /// (estimatePoses accepts HTMLVideoElement). This makes detection work for
  /// ANY subject in the stream, re-identified fresh on every call.
  static Future<List<PoseKeypoint>?> detectFromVideoElement() async {
    final ok = await ensureInitialized();
    if (!ok || _detector == null) return null;

    try {
      // Use our synced hidden video (created from the picked file's blob
      // URL); fall back to a DOM search in case it isn't ready yet.
      final video = _hiddenVideo ?? _findVideoElement();
      if (video == null) {
        _lastStatus = 'Video source not attached yet';
        return null;
      }

      // Video must have decoded at least one frame
      if (video.readyState < 2 || video.videoWidth == 0) {
        _lastStatus = 'Buffering video stream...';
        return null;
      }

      final poses = await ((_detector!.callMethod(
        'estimatePoses'.toJS,
        video as JSObject,
      )) as JSPromise<JSObject?>).toDart;

      return _keypointsFromPoses(
        poses,
        video.videoWidth.toDouble(),
        video.videoHeight.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Detects pose keypoints from a raw frame emitted by the `camera` plugin's
  /// image stream. camera_web delivers a single RGBA8888 plane (format
  /// `ImageFormatGroup.unknown`, raw `rgba8888`); it is copied row-by-row into
  /// an offscreen canvas which MoveNet accepts as an image source.
  static Future<List<PoseKeypoint>?> detectFromCameraImageWeb(
    CameraImage image, {
    bool mirrorX = false,
  }) async {
    final ok = await ensureInitialized();
    if (!ok || _detector == null) return null;

    try {
      if (image.planes.isEmpty) return null;
      final width = image.width;
      final height = image.height;
      if (width <= 0 || height <= 0) return null;

      final canvas = _frameCanvas ??= web.HTMLCanvasElement();
      if (canvas.width != width || canvas.height != height) {
        canvas.width = width;
        canvas.height = height;
        _frameContext = null;
      }
      final context = _frameContext ??= canvas.context2D;

      final imageData = context.createImageData(width.toJS, height);
      final destination = imageData.data.toDart;
      final source = image.planes.first.bytes;
      final stride = image.planes.first.bytesPerRow;
      final rowBytes = width * 4;
      for (var y = 0; y < height; y++) {
        final sourceStart = y * stride;
        if (sourceStart >= source.length) break;
        final destinationStart = y * rowBytes;
        final length = math.min(rowBytes, source.length - sourceStart);
        for (var i = 0; i < length; i++) {
          destination[destinationStart + i] = source[sourceStart + i];
        }
      }
      context.putImageData(imageData, 0, 0);

      final poses = await ((_detector!.callMethod(
        'estimatePoses'.toJS,
        canvas as JSObject,
      )) as JSPromise<JSObject?>).toDart;

      return _keypointsFromPoses(
        poses,
        width.toDouble(),
        height.toDouble(),
        mirrorX: mirrorX,
      );
    } catch (e) {
      debugPrint('[WebPose] Live camera frame detection failed: $e');
      return null;
    }
  }

  /// Converts the JS MoveNet result into app keypoints, normalized to 0-1.
  static List<PoseKeypoint>? _keypointsFromPoses(
    JSObject? poses,
    double frameWidth,
    double frameHeight, {
    bool mirrorX = false,
  }) {
    if (poses == null) {
      _lastStatus = 'Detection returned nothing';
      return null;
    }

    final posesArray = (poses as JSArray<JSObject>).toDart;
    if (posesArray.isEmpty) {
      _noPersonTicks++;
      _lastStatus = _noPersonTicks > 5
          ? 'No person detected in video stream'
          : 'Detecting subject...';
      return null;
    }
    _noPersonTicks = 0;
    _lastStatus = null;

    final kps = posesArray.first.getProperty<JSObject?>('keypoints'.toJS);
    if (kps == null) return null;

    final keypoints = <PoseKeypoint>[];
    for (final kp in (kps as JSArray<JSObject>).toDart) {
      final rawName = (kp.getProperty<JSString?>('name'.toJS))?.toDart;
      final rawX = (kp.getProperty<JSNumber>('x'.toJS)).toDartDouble;
      final y = (kp.getProperty<JSNumber>('y'.toJS)).toDartDouble;
      final score = (kp.getProperty<JSNumber>('score'.toJS)).toDartDouble;

      final name = _mapName(rawName);
      if (name == null) continue;

      var x = frameWidth > 0 ? (rawX / frameWidth) : 0.5;
      if (mirrorX) x = 1 - x;
      final normY = frameHeight > 0 ? (y / frameHeight) : 0.5;

      keypoints.add(
        PoseKeypoint(
          name: name,
          x: x.clamp(0.0, 1.0).toDouble(),
          y: normY.clamp(0.0, 1.0).toDouble(),
          confidence: score,
        ),
      );
    }

    return keypoints.isEmpty ? null : keypoints;
  }

  /// Locates the <video> element that video_player created in the DOM.
  /// Prefers the largest (most likely the main playback) video.
  static web.HTMLVideoElement? _findVideoElement() {
    try {
      final list = web.document.querySelectorAll('video');
      final len = list.length;
      web.HTMLVideoElement? best;
      int bestArea = 0;
      for (var i = 0; i < len; i++) {
        final el = list.item(i);
        if (el != null) {
          // querySelectorAll('video') only returns video elements
          final v = el as web.HTMLVideoElement;
          final area = v.videoWidth * v.videoHeight;
          if (area > bestArea) {
            bestArea = area;
            best = v;
          }
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  /// Maps COCO-17 keypoint names to the app's landmark names.
  /// Returns null for keypoints we don't visualize.
  static String? _mapName(String? cocoName) {
    switch (cocoName) {
      case 'nose':
        return 'head';
      case 'left_shoulder':
      case 'right_shoulder':
      case 'left_elbow':
      case 'right_elbow':
      case 'left_wrist':
      case 'right_wrist':
      case 'left_hip':
      case 'right_hip':
      case 'left_knee':
      case 'right_knee':
      case 'left_ankle':
      case 'right_ankle':
        return cocoName;
      default:
        return null;
    }
  }
}
