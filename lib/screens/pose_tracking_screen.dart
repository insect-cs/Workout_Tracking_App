import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:ui' as dart_ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';

import '../services/pose_analysis_service.dart';
import '../theme/app_colors.dart';
import '../web/web_pose.dart';
import '../widgets/pose_skeleton_painter.dart';

class PoseTrackingScreen extends StatefulWidget {
  final VoidCallback onBackToHome;

  const PoseTrackingScreen({super.key, required this.onBackToHome});

  @override
  State<PoseTrackingScreen> createState() => _PoseTrackingScreenState();
}

class _PoseTrackingScreenState extends State<PoseTrackingScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  File? _selectedMediaFile;
  Uint8List? _selectedMediaBytes;
  bool _isVideo = false;
  VideoPlayerController? _videoPlayerController;

  PoseAnalysisResult? _analysisResult;
  bool _isAnalyzing = false;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Live camera squat tracking
  CameraController? _cameraController;
  bool _isLiveTracking = false;
  bool _isProcessingFrame = false;
  List<PoseKeypoint> _liveKeypoints = const [];
  int _squatCount = 0;
  bool _inSquatDepth = false;
  double _lastKneeAngle = 180;
  double _lastElbowAngle = 180;
  String _liveFeedback = 'Stand in frame and start squatting';
  final List<double> _kneeAngleHistory = [];

  // Live exercise identification from tracked landmark motion
  String _liveExerciseName = 'Identifying exercise...';
  double _minKneeAngleSeen = 180;
  double _minElbowAngleSeen = 180;
  int _curlCount = 0;
  int _pushupCount = 0;
  bool _armCurled = false;

  // Real-time landmark tracking on a playing video stream
  final GlobalKey _videoBoundaryKey = GlobalKey();
  Timer? _videoFrameTimer;
  bool _isProcessingVideoFrame = false;
  String? _videoTrackStatus;
  bool _videoEnded = false;

  // Preset demo workouts for testing
  static const _demoExercises = [
    {
      'name': 'Barbell Back Squat',
      'emoji': '🏋️',
      'description': 'Primary lower body compound movement. Deep hip flexion with upright torso and vertical bar path.',
      'confidence': 'High (98%)',
      'muscles': 'Primary: Quadriceps, Gluteus Maximus | Secondary: Hamstrings, Core, Erector Spinae',
      'keyPoints': [
        'Knee and hip flexion reach optimal parallel depth below 90 degrees',
        'Torso angle stays consistent with neutral spinal curvature',
        'Weight balanced evenly through mid-foot and heel',
      ],
      'formTips': [
        'Brace abdominal wall creating 360-degree intra-abdominal pressure',
        'Drive knees slightly outward tracking over 2nd & 3rd toes',
        'Lead ascent with chest and hips rising at the same speed',
      ],
      'keypoints': [
        PoseKeypoint(name: 'head', x: 0.50, y: 0.10, confidence: 0.98),
        PoseKeypoint(name: 'left_shoulder', x: 0.38, y: 0.24, confidence: 0.95),
        PoseKeypoint(
          name: 'right_shoulder',
          x: 0.62,
          y: 0.24,
          confidence: 0.95,
        ),
        PoseKeypoint(name: 'left_elbow', x: 0.30, y: 0.36, confidence: 0.90),
        PoseKeypoint(name: 'right_elbow', x: 0.70, y: 0.36, confidence: 0.90),
        PoseKeypoint(name: 'left_wrist', x: 0.34, y: 0.28, confidence: 0.88),
        PoseKeypoint(name: 'right_wrist', x: 0.66, y: 0.28, confidence: 0.88),
        PoseKeypoint(name: 'left_hip', x: 0.40, y: 0.52, confidence: 0.94),
        PoseKeypoint(name: 'right_hip', x: 0.60, y: 0.52, confidence: 0.94),
        PoseKeypoint(name: 'left_knee', x: 0.32, y: 0.73, confidence: 0.92),
        PoseKeypoint(name: 'right_knee', x: 0.68, y: 0.73, confidence: 0.92),
        PoseKeypoint(name: 'left_ankle', x: 0.36, y: 0.92, confidence: 0.90),
        PoseKeypoint(name: 'right_ankle', x: 0.64, y: 0.92, confidence: 0.90),
      ],
    },
    {
      'name': 'Standard Push-Up',
      'emoji': '💪',
      'description': 'Fundamental upper body horizontal pushing exercise engaging chest, anterior deltoids, and core stabilizers.',
      'confidence': 'High (96%)',
      'muscles': 'Primary: Pectoralis Major, Triceps Brachii | Secondary: Anterior Deltoids, Core',
      'keyPoints': [
        'Rigid plank line maintained from cervical spine to heels',
        'Humeral abduction angle maintained at safe ~45 degrees',
        'Full range of motion achieved with chest 1-2 inches above ground',
      ],
      'formTips': [
        'Squeeze glutes and engage rectus abdominis to avoid lumbar hyperextension',
        'Push floor away actively at lockout to achieve scapular protraction',
        'Maintain neutral neck gazing 6 inches in front of hands',
      ],
      'keypoints': [
        PoseKeypoint(name: 'head', x: 0.16, y: 0.40, confidence: 0.95),
        PoseKeypoint(name: 'left_shoulder', x: 0.32, y: 0.37, confidence: 0.93),
        PoseKeypoint(
          name: 'right_shoulder',
          x: 0.32,
          y: 0.53,
          confidence: 0.93,
        ),
        PoseKeypoint(name: 'left_elbow', x: 0.46, y: 0.30, confidence: 0.88),
        PoseKeypoint(name: 'right_elbow', x: 0.46, y: 0.60, confidence: 0.88),
        PoseKeypoint(name: 'left_wrist', x: 0.54, y: 0.28, confidence: 0.85),
        PoseKeypoint(name: 'right_wrist', x: 0.54, y: 0.62, confidence: 0.85),
        PoseKeypoint(name: 'left_hip', x: 0.66, y: 0.38, confidence: 0.91),
        PoseKeypoint(name: 'right_hip', x: 0.66, y: 0.52, confidence: 0.91),
        PoseKeypoint(name: 'left_knee', x: 0.80, y: 0.37, confidence: 0.89),
        PoseKeypoint(name: 'right_knee', x: 0.80, y: 0.53, confidence: 0.89),
        PoseKeypoint(name: 'left_ankle', x: 0.92, y: 0.36, confidence: 0.84),
        PoseKeypoint(name: 'right_ankle', x: 0.92, y: 0.54, confidence: 0.84),
      ],
    },
    {
      'name': 'Conventional Deadlift',
      'emoji': '⚡',
      'description': 'Posterior chain powerhouse movement. Posterior hip hinge pattern with strict neutral spine extension.',
      'confidence': 'High (97%)',
      'muscles': 'Primary: Hamstrings, Gluteus, Erector Spinae | Secondary: Latissimus Dorsi, Forearms',
      'keyPoints': [
        'Hinge initiated by driving hips backward while knees remain softly flexed',
        'Scapulae positioned directly over barbell during setup',
        'Full lockout with hips and knees extending simultaneously',
      ],
      'formTips': [
        'Pull slack out of barbell before driving away from floor',
        'Keep bar in continuous contact with shins and thighs',
        'Engage lats by imagining squeezing oranges in armpits',
      ],
      'keypoints': [
        PoseKeypoint(name: 'head', x: 0.50, y: 0.12, confidence: 0.96),
        PoseKeypoint(name: 'left_shoulder', x: 0.39, y: 0.26, confidence: 0.94),
        PoseKeypoint(
          name: 'right_shoulder',
          x: 0.61,
          y: 0.26,
          confidence: 0.94,
        ),
        PoseKeypoint(name: 'left_elbow', x: 0.35, y: 0.44, confidence: 0.89),
        PoseKeypoint(name: 'right_elbow', x: 0.65, y: 0.44, confidence: 0.89),
        PoseKeypoint(name: 'left_wrist', x: 0.36, y: 0.60, confidence: 0.87),
        PoseKeypoint(name: 'right_wrist', x: 0.64, y: 0.60, confidence: 0.87),
        PoseKeypoint(name: 'left_hip', x: 0.43, y: 0.51, confidence: 0.95),
        PoseKeypoint(name: 'right_hip', x: 0.57, y: 0.51, confidence: 0.95),
        PoseKeypoint(name: 'left_knee', x: 0.41, y: 0.73, confidence: 0.90),
        PoseKeypoint(name: 'right_knee', x: 0.59, y: 0.73, confidence: 0.90),
        PoseKeypoint(name: 'left_ankle', x: 0.40, y: 0.91, confidence: 0.88),
        PoseKeypoint(name: 'right_ankle', x: 0.60, y: 0.91, confidence: 0.88),
      ],
    },
  ];

  int _demoIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Load TF.js / MoveNet while the user is still choosing media, so the
    // first tracked video frame does not stall the UI for several seconds.
    if (kIsWeb) unawaited(WebPoseService.ensureInitialized());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _videoFrameTimer?.cancel();
    _videoPlayerController?.removeListener(_onVideoUpdate);
    _stopLiveTracking();
    _videoPlayerController?.dispose();
    WebPoseService.clearVideoSource();
    super.dispose();
  }

  void _stopLiveTracking() {
    try {
      _cameraController?.dispose();
    } catch (_) {}
    _cameraController = null;
    _isLiveTracking = false;
  }

  /// Resets all live tracking counters and exercise identification state.
  void _resetLiveTrackingState() {
    _squatCount = 0;
    _inSquatDepth = false;
    _kneeAngleHistory.clear();
    _lastKneeAngle = 180;
    _lastElbowAngle = 180;
    _liveFeedback = 'Detecting landmarks...';
    _liveExerciseName = 'Identifying exercise...';
    _minKneeAngleSeen = 180;
    _minElbowAngleSeen = 180;
    _curlCount = 0;
    _pushupCount = 0;
    _armCurled = false;
  }

  Future<void> _pickImage() async {
    _videoPlayerController?.pause();
    WebPoseService.clearVideoSource();
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedMediaFile = kIsWeb ? null : File(picked.path);
        _selectedMediaBytes = bytes;
        _isVideo = false;
        _analysisResult = null;
        _error = null;
      });
      await _analyzeCurrentMedia();
    } catch (e) {
      setState(() => _error = 'Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    _videoPlayerController?.pause();
    try {
      final XFile? picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null) return;

      // Show progress before the (potentially slow) player initialization.
      if (mounted) {
        setState(() {
          _isAnalyzing = true;
          _error = null;
          _videoTrackStatus = kIsWeb ? 'Loading video...' : null;
        });
      }

      _videoPlayerController?.removeListener(_onVideoUpdate);
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      WebPoseService.clearVideoSource();

      final VideoPlayerController controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(picked.path))
          : VideoPlayerController.file(File(picked.path));

      await controller.initialize();
      // No looping: playback stops at the end and a replay button appears.
      controller.setLooping(false);
      controller.setVolume(0.0);
      controller.addListener(_onVideoUpdate);
      _videoPlayerController = controller;
      controller.play();

      // On web, attach the picked file's blob URL to a hidden <video>
      // element that the pose detector reads frames from (kept in sync
      // with the Flutter player below).
      if (kIsWeb) {
        WebPoseService.setVideoSource(picked.path);
      }

      // Video analysis is entirely local; reading the whole file into memory
      // here used to stall the UI for seconds and was never used.
      if (!mounted) return;
      setState(() {
        _selectedMediaFile = kIsWeb ? null : File(picked.path);
        _selectedMediaBytes = null;
        _isVideo = true;
        _videoPlayerController = controller;
        _videoEnded = false;
        _analysisResult = null;
        _error = null;
        _liveKeypoints = const [];
        _videoTrackStatus = kIsWeb
            ? (WebPoseService.lastStatus ?? 'Starting pose tracking...')
            : null;
        _resetLiveTrackingState();
      });

      await _analyzeCurrentMedia();
      // Start real-time landmark tracking on the playing video stream
      if (mounted) _startVideoFrameTracking();
    } catch (e) {
      _videoPlayerController?.removeListener(_onVideoUpdate);
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      WebPoseService.clearVideoSource();
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _error = 'Error loading video: $e';
        });
      }
    }
  }

  /// Tracks video playback state: completion (for the replay button) and
  /// position sync for the hidden web detection video.
  void _onVideoUpdate() {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;

    if (kIsWeb) {
      WebPoseService.syncPlayback(
        playing: value.isPlaying,
        positionSec: value.position.inMilliseconds / 1000.0,
      );
    }

    final ended =
        value.position >= value.duration &&
        value.duration > Duration.zero &&
        !value.isPlaying;
    if (ended && !_videoEnded) {
      setState(() => _videoEnded = true);
    } else if (!ended && _videoEnded) {
      // Seek back or replay resets the flag
      setState(() => _videoEnded = false);
    }
  }

  void _replayVideo() {
    final controller = _videoPlayerController;
    if (controller == null) return;
    controller.seekTo(Duration.zero).then((_) {
      controller.play();
    });
    setState(() {
      _videoEnded = false;
      _resetLiveTrackingState();
      _liveFeedback = 'Replaying - tracking restarted';
    });
  }

  Future<void> _takePhoto() async {
    _videoPlayerController?.pause();
    WebPoseService.clearVideoSource();
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedMediaFile = kIsWeb ? null : File(picked.path);
        _selectedMediaBytes = bytes;
        _isVideo = false;
        _analysisResult = null;
        _error = null;
      });
      await _analyzeCurrentMedia();
    } catch (e) {
      setState(() => _error = 'Camera unavailable: $e');
    }
  }

  /// Starts live camera tracking: the person stands in front of the camera
  /// doing squats, and ML Kit streaming pose detection plots their landmarks
  /// on screen in real time.
  ///
  /// NOTE: Live landmark tracking requires Android or iOS. ML Kit pose
  /// detection and the camera image-stream API are native-only plugins.
  Future<void> _startLiveSquatTracking() async {
    _stopVideoFrameTracking();
    if (kIsWeb) {
      setState(() {
        _isAnalyzing = false;
        _error =
            'Live squat tracking needs a mobile device. Run "flutter run" on an '
            'Android phone or emulator - ML Kit pose detection and camera frame '
            'streaming are native-only and cannot run in a web browser.';
      });
      return;
    }

    try {
      setState(() {
        _isAnalyzing = true;
        _error = null;
        _analysisResult = null;
      });

      _videoPlayerController?.pause();
      _stopLiveTracking();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera found on this device');
      }

      // Prefer the front camera so the user can face the screen while squatting
      CameraDescription camera;
      try {
        camera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
      } catch (_) {
        camera = cameras.first;
      }

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      await controller.startImageStream(_processLiveFrame);

      setState(() {
        _cameraController = controller;
        _isLiveTracking = true;
        _isAnalyzing = false;
        _isVideo = false;
        _selectedMediaFile = null;
        _selectedMediaBytes = null;
        _liveKeypoints = const [];
        _resetLiveTrackingState();
        _liveFeedback = 'Stand in frame and start exercising';
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _isLiveTracking = false;
        _error = 'Could not start live camera: ${e.toString()}';
      });
    }
  }

  void _stopLiveTrackingSession() {
    _stopLiveTracking();
    _stopVideoFrameTracking();
    WebPoseService.clearVideoSource();
    setState(() {
      _isVideo = false;
      _selectedMediaFile = null;
      _selectedMediaBytes = null;
      _analysisResult = null;
      _liveKeypoints = const [];
    });
  }

  Future<void> _processLiveFrame(CameraImage image) async {
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) return;

      final camera = controller.description;
      final keypoints = await PoseAnalysisService.detectFromCameraImage(
        image,
        camera: camera,
        mirrorX: camera.lensDirection == CameraLensDirection.front,
      );

      if (!mounted) return;
      if (keypoints == null || keypoints.isEmpty) {
        setState(() {
          _liveFeedback = 'No person detected - step back into frame';
        });
        return;
      }

      final angle = _computeKneeAngle(keypoints);
      if (angle != null) {
        _updateSquatCounter(angle);
      }
      final elbow = _computeElbowAngle(keypoints);
      if (elbow != null) {
        _lastElbowAngle = elbow;
      }
      // Continuously re-identify the exercise from the live landmark motion
      _classifyExercise(keypoints);

      setState(() {
        _liveKeypoints = keypoints;
        if (angle == null) {
          _liveFeedback = 'Tracking landmarks - full body not visible';
        }
      });
    } catch (e) {
      debugPrint('Live frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Starts sampling frames from the playing video stream and re-detecting
  /// landmarks on each sample with ML Kit. Detection is per-frame and
  /// subject-agnostic: it re-identifies whatever person(s) appear in the
  /// video and re-plots the skeleton in real time as they move.
  void _startVideoFrameTracking() {
    _videoFrameTimer?.cancel();
    _videoFrameTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _captureAndTrackVideoFrame(),
    );
  }

  void _stopVideoFrameTracking() {
    _videoFrameTimer?.cancel();
    _videoFrameTimer = null;
  }

  Future<void> _captureAndTrackVideoFrame() async {
    final controller = _videoPlayerController;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying ||
        _isProcessingVideoFrame) {
      return;
    }

    _isProcessingVideoFrame = true;
    try {
      // On web, RepaintBoundary.toImage() cannot capture the video platform
      // view (frames come out blank), so we detect directly on the <video>
      // element. On mobile we capture the frame and run ML Kit on the PNG.
      final List<PoseKeypoint>? keypoints;
      if (kIsWeb) {
        keypoints = await WebPoseService.detectFromVideoElement();
      } else {
        final boundary =
            _videoBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary == null || !boundary.attached) return;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(
          format: dart_ui.ImageByteFormat.png,
        );
        image.dispose();
        if (byteData == null || !mounted) return;
        keypoints = await PoseAnalysisService.detectFromVideoFrameBytes(
          byteData.buffer.asUint8List(),
        );
      }
      if (!mounted) return;

      if (keypoints != null && keypoints.isNotEmpty) {
        final detected = keypoints;
        final angle = _computeKneeAngle(detected);
        if (angle != null) {
          _updateSquatCounter(angle);
        }
        final elbow = _computeElbowAngle(detected);
        if (elbow != null) {
          _lastElbowAngle = elbow;
        }
        setState(() {
          _liveKeypoints = detected;
          _videoTrackStatus = null;
          if (angle == null) {
            _liveFeedback = 'Tracking landmarks - full body not visible';
          }
        });
        _classifyExercise(detected);
      } else if (kIsWeb) {
        // Surface engine status so tracking problems are visible on screen
        final status = WebPoseService.lastStatus;
        if (status != null && status != _videoTrackStatus) {
          setState(() => _videoTrackStatus = status);
        }
      }
      // If detection returns null (no person / detection hiccup), keep the
      // previous skeleton for one tick to avoid flicker.
    } catch (e) {
      debugPrint('Video frame tracking error: $e');
    } finally {
      _isProcessingVideoFrame = false;
    }
  }

  /// Classifies the exercise from tracked landmark motion, re-evaluated on
  /// every frame so the whole video is continuously reviewed and the name
  /// updates as soon as a different movement pattern is detected. Uses
  /// knee-angle dips for squats, and elbow flexion cycles for curls (upright
  /// torso) or push-ups (horizontal torso).
  void _classifyExercise(List<PoseKeypoint> kps) {
    double? jointAngle(String aName, String bName, String cName) {
      final a = kps.where((k) => k.name == aName).toList();
      final b = kps.where((k) => k.name == bName).toList();
      final c = kps.where((k) => k.name == cName).toList();
      if (a.isEmpty || b.isEmpty || c.isEmpty) return null;
      if (a.first.confidence < 0.3 ||
          b.first.confidence < 0.3 ||
          c.first.confidence < 0.3) {
        return null;
      }
      return _angleBetween(
        Offset(a.first.x, a.first.y),
        Offset(b.first.x, b.first.y),
        Offset(c.first.x, c.first.y),
      );
    }

    // Track deepest knee flexion
    final knee =
        jointAngle('left_hip', 'left_knee', 'left_ankle') ??
        jointAngle('right_hip', 'right_knee', 'right_ankle');
    if (knee != null && knee < _minKneeAngleSeen) {
      _minKneeAngleSeen = knee;
    }

    // Track deepest elbow flexion
    final elbow =
        jointAngle('left_shoulder', 'left_elbow', 'left_wrist') ??
        jointAngle('right_shoulder', 'right_elbow', 'right_wrist');
    if (elbow != null && elbow < _minElbowAngleSeen) {
      _minElbowAngleSeen = elbow;
    }

    // Torso orientation: horizontal body => push-up, upright => curl
    final horizontal = _isTorsoHorizontal(kps);

    // Count elbow flexion cycles (bicep curl or push-up depending on torso)
    if (elbow != null) {
      if (elbow < 90) _armCurled = true;
      if (elbow > 150 && _armCurled) {
        _armCurled = false;
        if (horizontal) {
          _pushupCount++;
        } else {
          _curlCount++;
        }
      }
    }

    // Identification is re-checked at every point in the video: whichever
    // movement signature is currently being performed wins.
    String name = 'Identifying exercise...';
    if (horizontal && _minElbowAngleSeen < 120) {
      name = 'Push-Up';
    } else if (_curlCount > 0 && _squatCount == 0) {
      name = 'Bicep Curl';
    } else if (_squatCount > 0 || _minKneeAngleSeen < 110) {
      name = 'Bodyweight Squat';
    } else if (_curlCount > 0) {
      name = 'Bicep Curl';
    } else if (horizontal) {
      name = 'Push-Up (probable)';
    }

    if (name != _liveExerciseName && mounted) {
      setState(() => _liveExerciseName = name);
    }
  }

  /// True when the shoulder-hip line is roughly horizontal (lying/plank
  /// orientation, as in a push-up).
  bool _isTorsoHorizontal(List<PoseKeypoint> kps) {
    for (final side in ['left', 'right']) {
      final shoulder = kps.where((k) => k.name == '${side}_shoulder').toList();
      final hip = kps.where((k) => k.name == '${side}_hip').toList();
      if (shoulder.isNotEmpty &&
          hip.isNotEmpty &&
          shoulder.first.confidence > 0.4 &&
          hip.first.confidence > 0.4) {
        if ((shoulder.first.y - hip.first.y).abs() < 0.06) return true;
      }
    }
    return false;
  }

  /// Knee angle (hip-knee-ankle) averaged over both legs in degrees.
  double? _computeKneeAngle(List<PoseKeypoint> keypoints) {
    double? angleFor(String side) {
      final hip = keypoints.firstWhere(
        (k) => k.name == '${side}_hip',
        orElse: () => keypoints.first,
      );
      final knee = keypoints.firstWhere(
        (k) => k.name == '${side}_knee',
        orElse: () => keypoints.first,
      );
      final ankle = keypoints.firstWhere(
        (k) => k.name == '${side}_ankle',
        orElse: () => keypoints.first,
      );
      if (hip.name != '${side}_hip' ||
          knee.name != '${side}_knee' ||
          ankle.name != '${side}_ankle') {
        return null;
      }
      if (hip.confidence < 0.3 ||
          knee.confidence < 0.3 ||
          ankle.confidence < 0.3) {
        return null;
      }
      return _angleBetween(
        Offset(hip.x, hip.y),
        Offset(knee.x, knee.y),
        Offset(ankle.x, ankle.y),
      );
    }

    final left = angleFor('left');
    final right = angleFor('right');
    if (left != null && right != null) return (left + right) / 2;
    return left ?? right;
  }

  /// Elbow angle (shoulder-elbow-wrist) averaged over both arms in degrees.
  double? _computeElbowAngle(List<PoseKeypoint> keypoints) {
    double? angleFor(String side) {
      final shoulder = keypoints.firstWhere(
        (k) => k.name == '${side}_shoulder',
        orElse: () => keypoints.first,
      );
      final elbow = keypoints.firstWhere(
        (k) => k.name == '${side}_elbow',
        orElse: () => keypoints.first,
      );
      final wrist = keypoints.firstWhere(
        (k) => k.name == '${side}_wrist',
        orElse: () => keypoints.first,
      );
      if (shoulder.name != '${side}_shoulder' ||
          elbow.name != '${side}_elbow' ||
          wrist.name != '${side}_wrist') {
        return null;
      }
      if (shoulder.confidence < 0.3 ||
          elbow.confidence < 0.3 ||
          wrist.confidence < 0.3) {
        return null;
      }
      return _angleBetween(
        Offset(shoulder.x, shoulder.y),
        Offset(elbow.x, elbow.y),
        Offset(wrist.x, wrist.y),
      );
    }

    final left = angleFor('left');
    final right = angleFor('right');
    if (left != null && right != null) return (left + right) / 2;
    return left ?? right;
  }

  static double _angleBetween(Offset a, Offset b, Offset c) {
    final v1 = a - b;
    final v2 = c - b;
    final denom = (v1.distance * v2.distance);
    if (denom == 0) return 180;
    final cos = (v1.dx * v2.dx + v1.dy * v2.dy) / denom;
    return math.acos(cos.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  /// Counts a squat rep using knee-angle hysteresis (below 110deg = down,
  /// back above 155deg = standing).
  void _updateSquatCounter(double angle) {
    _kneeAngleHistory.add(angle);
    if (_kneeAngleHistory.length > 5) _kneeAngleHistory.removeAt(0);
    final smoothed =
        _kneeAngleHistory.reduce((a, b) => a + b) / _kneeAngleHistory.length;
    _lastKneeAngle = smoothed;

    String? feedback;
    if (smoothed < 110 && !_inSquatDepth) {
      _inSquatDepth = true;
    }
    if (smoothed > 155 && _inSquatDepth) {
      _inSquatDepth = false;
      _squatCount++;
    }

    if (smoothed >= 155) {
      feedback = _inSquatDepth ? 'Standing up' : 'Standing - squat down slowly';
    } else if (smoothed >= 110) {
      feedback = 'Descending - keep going for parallel depth';
    } else {
      feedback = 'Deep squat - drive up through the heels';
    }

    if (mounted) setState(() => _liveFeedback = feedback!);
  }

  void _cycleDemoExercise() {
    _videoPlayerController?.pause();
    _stopVideoFrameTracking();
    WebPoseService.clearVideoSource();
    final demo = _demoExercises[_demoIndex % _demoExercises.length];
    _demoIndex++;
    final kpList = demo['keypoints'] as List<PoseKeypoint>;

    setState(() {
      _selectedMediaFile = null;
      _isVideo = false;
      _error = null;
      _analysisResult = PoseAnalysisResult(
        exerciseName: demo['name'] as String,
        confidence: demo['confidence'] as String,
        description: demo['description'] as String,
        keyPoints: (demo['keyPoints'] as List<String>),
        formTips: (demo['formTips'] as List<String>),
        musclesWorked: demo['muscles'] as String,
        detectedKeypoints: kpList,
        engineUsed: 'ML Kit Biomechanics Engine',
      );
    });
  }

  Future<void> _analyzeCurrentMedia() async {
    // Web video paths are blob URLs with no local File; video analysis is
    // local landmark tracking and does not need the raw bytes.
    if (!_isVideo &&
        _selectedMediaBytes == null &&
        _selectedMediaFile == null) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      PoseAnalysisResult result;
      if (_isVideo) {
        // Don't base64-encode whole videos to the cloud API - that takes
        // minutes on web and is the cause of the endless "analyzing" state.
        // Video exercise ID is derived from live per-frame landmark tracking
        // instead, which starts immediately.
        result = PoseAnalysisResult(
          exerciseName: 'Live Video Exercise',
          confidence: 'Tracking',
          description:
              'Analyzing movement from live per-frame landmark tracking. '
              'The skeleton overlay follows the subject in the video in real time.',
          keyPoints: const [
            'Landmark tracking runs locally on every captured frame',
            'Skeleton re-detects any subject in the stream automatically',
            'Squat reps are counted from live knee-angle analysis',
          ],
          formTips: const [
            'Keep the full body visible in the video for accurate tracking',
            'Ensure good lighting so landmark confidence stays high',
            'Squat below parallel to register a full rep',
          ],
          musclesWorked: 'Primary: Quadriceps, Gluteus Maximus | Secondary: Hamstrings, Core',
          detectedKeypoints: const [],
          engineUsed: kIsWeb
              ? 'MoveNet (TF.js) Real-time Tracking'
              : 'Google ML Kit Real-time Tracking',
        );
      } else if (_selectedMediaBytes != null) {
        result = await PoseAnalysisService.analyzeImageBytes(
          _selectedMediaBytes!,
          mimeType: 'image/jpeg',
        );
      } else {
        result = await PoseAnalysisService.analyzeImage(_selectedMediaFile!);
      }

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _error =
            'Analysis failed: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildInputControls(),
                    if (_isAnalyzing) ...[
                      const SizedBox(height: 24),
                      _buildAnalyzingIndicator(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorCard(),
                    ],
                    if (_selectedMediaFile != null ||
                        _selectedMediaBytes != null ||
                        (_isVideo && _videoPlayerController != null) ||
                        _isLiveTracking) ...[
                      const SizedBox(height: 16),
                      _isLiveTracking
                          ? _buildLiveTrackingPreview()
                          : _buildMediaPreview(),
                      if (_isLiveTracking ||
                          (_isVideo && _videoPlayerController != null)) ...[
                        const SizedBox(height: 14),
                        _buildLiveStatsCard(),
                      ],
                    ],
                    if (_analysisResult != null) ...[
                      const SizedBox(height: 20),
                      _buildResultSection(),
                    ],
                    if (_selectedMediaFile == null &&
                        _selectedMediaBytes == null &&
                        _analysisResult == null &&
                        !_isAnalyzing &&
                        !_isLiveTracking)
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBackToHome,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textSlate,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POSE TRACKING',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textWhite,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Live Camera • Real-time Landmark Tracking',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.orangeBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryOrange,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'ML KIT',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputControls() {
    return Column(
      children: [
        // Primary media action buttons
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.image_outlined,
                label: 'Image',
                subtitle: 'Photo/Gallery',
                onTap: _pickImage,
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: Icons.videocam_outlined,
                label: 'Video',
                subtitle: 'User Movement',
                onTap: _pickVideo,
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                subtitle: 'Snap Live',
                onTap: _takePhoto,
                isPrimary: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Live Squat Tracking button (replaces the bundled test workout video)
        GestureDetector(
          onTap: _isLiveTracking
              ? _stopLiveTrackingSession
              : _startLiveSquatTracking,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF24160E), Color(0xFF141A24)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isLiveTracking
                    ? AppColors.emerald
                    : AppColors.orangeBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isLiveTracking
                        ? AppColors.rose
                        : AppColors.primaryOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLiveTracking ? Icons.stop : Icons.play_arrow,
                    color: Colors.black,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLiveTracking
                            ? 'STOP LIVE TRACKING'
                            : 'LIVE SQUAT TRACKING (PERSON IN FRONT OF CAMERA)',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isLiveTracking
                              ? AppColors.emerald
                              : AppColors.primaryOrange,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Point the camera at yourself and squat - landmarks plot in real time',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textSlate,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return SizedBox(
      height: 92,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          backgroundColor: isPrimary
              ? AppColors.orangeSoft
              : AppColors.cardSurface,
          side: BorderSide(
            color: isPrimary ? AppColors.orangeBorder : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            Text(label),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio:
                  _isVideo &&
                      _videoPlayerController != null &&
                      _videoPlayerController!.value.isInitialized
                  ? _videoPlayerController!.value.aspectRatio
                  : 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isVideo &&
                      _videoPlayerController != null &&
                      _videoPlayerController!.value.isInitialized)
                    RepaintBoundary(
                      key: _videoBoundaryKey,
                      child: VideoPlayer(_videoPlayerController!),
                    )
                  else if (_selectedMediaFile != null)
                    Image.file(_selectedMediaFile!, fit: BoxFit.cover)
                  else if (_selectedMediaBytes != null)
                    Image.memory(_selectedMediaBytes!, fit: BoxFit.cover),

                  // Real-time skeleton overlay: for video streams the landmarks
                  // are re-detected every frame, so the skeleton follows whichever
                  // subject is moving in the video. Falls back to the static
                  // analysis skeleton for images.
                  if (_isVideo && _liveKeypoints.isNotEmpty)
                    CustomPaint(
                      painter: PoseSkeletonPainter(
                        keypoints: _liveKeypoints,
                        lineColor: AppColors.emerald,
                      ),
                    )
                  else if (_analysisResult != null)
                    CustomPaint(
                      painter: PoseSkeletonPainter(
                        keypoints: _analysisResult!.detectedKeypoints,
                      ),
                    ),

                  // Overlay badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.orangeBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isVideo ? Icons.videocam : Icons.photo,
                            color: AppColors.primaryOrange,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isVideo ? 'VIDEO STREAM' : 'IMAGE FRAME',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Replay button shown when the video finishes (no looping)
                  if (_isVideo && _videoEnded)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        child: Center(
                          child: GestureDetector(
                            onTap: _replayVideo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.replay,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'REPLAY VIDEO',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Video play/pause toggle button
                  if (_isVideo &&
                      _videoPlayerController != null &&
                      !_videoEnded)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoPlayerController!.value.isPlaying
                                ? _videoPlayerController!.pause()
                                : _videoPlayerController!.play();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.orangeBorder),
                          ),
                          child: Icon(
                            _videoPlayerController!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: AppColors.primaryOrange,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Video seek slider with time labels
            if (_isVideo &&
                _videoPlayerController != null &&
                _videoPlayerController!.value.isInitialized)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _videoPlayerController!,
                builder: (context, value, _) {
                  final durationMs = value.duration.inMilliseconds;
                  final positionMs = value.position.inMilliseconds.clamp(
                    0,
                    durationMs > 0 ? durationMs : 0,
                  );
                  return Container(
                    color: Colors.black,
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(value.position),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textSlate,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                              activeTrackColor: AppColors.primaryOrange,
                              inactiveTrackColor: AppColors.border,
                              thumbColor: AppColors.primaryOrange,
                            ),
                            child: Slider(
                              value: durationMs > 0
                                  ? positionMs.toDouble()
                                  : 0.0,
                              max: durationMs > 0 ? durationMs.toDouble() : 1.0,
                              onChanged: durationMs > 0
                                  ? (v) {
                                      _videoPlayerController!.seekTo(
                                        Duration(milliseconds: v.round()),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(value.duration),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textSlate,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildLiveTrackingPreview() {
    final controller = _cameraController;
    final initialized = controller != null && controller.value.isInitialized;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: AspectRatio(
          aspectRatio: initialized ? (1 / controller.value.aspectRatio) : 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (initialized) CameraPreview(controller),

              // Real-time landmark skeleton overlay plotted on the person
              if (_liveKeypoints.isNotEmpty)
                CustomPaint(
                  painter: PoseSkeletonPainter(
                    keypoints: _liveKeypoints,
                    lineColor: AppColors.emerald,
                  ),
                ),

              // LIVE badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.rose.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: AppColors.rose, size: 8),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE POSE TRACKING',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.rose,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Landmark count badge
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.emerald.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '${_liveKeypoints.length} LANDMARKS',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              // Real-time coaching feedback
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.orangeBorder),
                  ),
                  child: Text(
                    _liveFeedback,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Label for the rep counter: the identified exercise name + " COUNTER",
  /// e.g. "BICEP CURL COUNTER" instead of a hardcoded "SQUATS COUNTED".
  String get _counterLabel {
    if (_liveExerciseName == 'Identifying exercise...') {
      return 'EXERCISE COUNTER';
    }
    return '${_liveExerciseName.toUpperCase()} COUNTER';
  }

  /// Rep count for the exercise currently being identified.
  int get _identifiedRepCount {
    switch (_liveExerciseName) {
      case 'Bicep Curl':
        return _curlCount;
      case 'Push-Up':
      case 'Push-Up (probable)':
        return _pushupCount;
      default:
        return _squatCount;
    }
  }

  Widget _buildLiveStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _counterLabel,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSlate,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_identifiedRepCount',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'reps',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 52, color: AppColors.border),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KNEE ANGLE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSlate,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_lastKneeAngle.round()}°',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryOrange,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 52, color: AppColors.border),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ELBOW ANGLE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSlate,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_lastElbowAngle.round()}°',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.rose,
                    height: 1,
                  ),
                ),
                Text(
                  _videoTrackStatus ?? 'Streaming landmarks in real time',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: _videoTrackStatus != null
                        ? AppColors.amber
                        : AppColors.textMuted,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingIndicator() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orangeBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking movements & identifying exercise...',
                  style: GoogleFonts.inter(
                    color: AppColors.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Running ML Kit pose estimation model',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1AF43F5E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x4DF43F5E)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.rose, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.inter(color: AppColors.rose, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final result = _analysisResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live identification banner (from per-frame landmark tracking)
        if (_isVideo) ...[
          _buildLiveIdentificationBanner(),
          const SizedBox(height: 14),
        ],

        // Exercise identification card
        _buildExerciseCard(result),
        const SizedBox(height: 14),

        // Standalone skeleton visualization if no media file selected
        if (_selectedMediaFile == null &&
            result.detectedKeypoints.isNotEmpty) ...[
          _buildSkeletonVisualization(result),
          const SizedBox(height: 14),
        ],

        // Key Biomechanical Observations
        _buildSection(
          title: 'Pose & Movement Analysis',
          icon: Icons.accessibility_new,
          children: result.keyPoints
              .map((kp) => _buildBulletItem(kp, AppColors.amber))
              .toList(),
        ),
        const SizedBox(height: 14),

        // Form Coaching Tips
        _buildSection(
          title: 'Coaching & Correction Cues',
          icon: Icons.tips_and_updates_outlined,
          children: result.formTips
              .map((tip) => _buildBulletItem(tip, AppColors.emerald))
              .toList(),
        ),
        const SizedBox(height: 14),

        // Muscles worked
        _buildMusclesCard(result.musclesWorked),
      ],
    );
  }

  Widget _buildLiveIdentificationBanner() {
    final identified = _liveExerciseName != 'Identifying exercise...';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: identified
            ? AppColors.emerald.withValues(alpha: 0.12)
            : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: identified
              ? AppColors.emerald.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            identified ? Icons.check_circle_outline : Icons.radar,
            color: identified ? AppColors.emerald : AppColors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IDENTIFIED FROM LIVE TRACKING',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _liveExerciseName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: identified ? AppColors.emerald : AppColors.textSlate,
                  ),
                ),
                if (_identifiedRepCount > 0)
                  Text(
                    '$_identifiedRepCount rep${_identifiedRepCount == 1 ? '' : 's'} counted',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSlate,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'Deepest knee bend: ${_minKneeAngleSeen.round()}° • elbow: ${_minElbowAngleSeen.round()}°',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(PoseAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.orangeSoft, AppColors.orangeFade],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sports_gymnastics,
                color: AppColors.primaryOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'IDENTIFIED EXERCISE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryOrange,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  result.confidence,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.exerciseName,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textWhite,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSlate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.bolt, color: AppColors.primaryOrange, size: 14),
              const SizedBox(width: 4),
              Text(
                'Engine: ${result.engineUsed}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonVisualization(PoseAnalysisResult result) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.accessibility_new,
                  color: AppColors.primaryOrange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '3D SKELETAL LANDMARKS',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSlate,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 9 / 14,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                painter: PoseSkeletonPainter(
                  keypoints: result.detectedKeypoints,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Center(
              child: Text(
                'Visualizing ${result.detectedKeypoints.length} landmark coordinates mapped in real time',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryOrange, size: 16),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSlate,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text, Color bulletColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 10),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textLight,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusclesCard(String muscles) {
    final parts = muscles.split('|').map((s) => s.trim()).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fitness_center,
                color: AppColors.primaryOrange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'TARGET MUSCULATURE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSlate,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...parts.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                p,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textLight,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.orangeBorder, width: 2),
            ),
            child: Icon(
              Icons.accessibility_new,
              color: AppColors.primaryOrange,
              size: 36,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Pose Tracking & Exercise ID',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a workout image or video, or start\n"Live Squat Tracking" to point the camera at\nyourself and see landmarks plot in real time.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _cycleDemoExercise,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.orangeBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    color: AppColors.primaryOrange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Preview Demo Skeletal Models',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureChip(Icons.center_focus_strong, 'Google ML Kit'),
              _buildFeatureChip(Icons.video_collection, 'Video & Image'),
              _buildFeatureChip(Icons.sports_gymnastics, 'Exercise ID'),
              _buildFeatureChip(Icons.auto_graph, 'Joint Biomechanics'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, color: AppColors.primaryOrange, size: 14),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
