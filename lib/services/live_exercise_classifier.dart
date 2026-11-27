import 'dart:math' as math;

import 'pose_analysis_service.dart';

/// Broad muscle-group family used for the live identification banner.
enum LiveExerciseCategory {
  neck('NECK'),
  shoulders('SHOULDERS'),
  back('BACK'),
  biceps('BICEPS'),
  triceps('TRICEPS'),
  chest('CHEST'),
  legs('LEGS'),
  core('CORE'),
  unknown('ANALYSING');

  const LiveExerciseCategory(this.label);
  final String label;
}

/// Specific movement currently being performed, with its family.
enum LiveExerciseKind {
  neckStretch('Neck Stretch', LiveExerciseCategory.neck),
  shoulderPress('Shoulder Press', LiveExerciseCategory.shoulders),
  lateralRaise('Lateral Raise', LiveExerciseCategory.shoulders),
  bentOverRow('Bent-Over Row', LiveExerciseCategory.back),
  bicepCurl('Bicep Curl', LiveExerciseCategory.biceps),
  tricepExtension('Overhead Tricep Extension', LiveExerciseCategory.triceps),
  pushUp('Push-Up', LiveExerciseCategory.chest),
  squat('Bodyweight Squat', LiveExerciseCategory.legs),
  lunge('Reverse Lunge', LiveExerciseCategory.legs),
  crunch('Crunch', LiveExerciseCategory.core),
  plank('Plank', LiveExerciseCategory.core),
  unknown('Identifying exercise...', LiveExerciseCategory.unknown);

  const LiveExerciseKind(this.name, this.category);
  final String name;
  final LiveExerciseCategory category;
}

/// Snapshot returned after every classified frame.
class LiveExerciseReading {
  const LiveExerciseReading({
    required this.kind,
    required this.category,
    required this.repCount,
    required this.feedback,
    required this.kneeAngle,
    required this.elbowAngle,
    required this.hipAngle,
  });

  final LiveExerciseKind kind;
  final LiveExerciseCategory category;
  final int repCount;
  final String feedback;
  final double? kneeAngle;
  final double? elbowAngle;
  final double? hipAngle;
}

/// Geometric features extracted once per frame from the detector keypoints.
class _PoseFeatures {
  const _PoseFeatures({
    required this.knee,
    required this.elbow,
    required this.hip,
    required this.knees,
    required this.elbows,
    required this.hipAngles,
    required this.hipY,
    required this.shoulderY,
    required this.headY,
    required this.shoulderMidX,
    required this.hipMidX,
    required this.horizontal,
    required this.armAboveHead,
    required this.wideArms,
    required this.wristsNearHips,
    required this.neckTilted,
    required this.asymmetricKnees,
    required this.wristY,
    required this.armsRelaxed,
  });

  final double? knee;
  final double? elbow;
  final double? hip;
  final List<double> knees;
  final List<double> elbows;
  final List<double> hipAngles;
  final double? hipY;
  final double? shoulderY;
  final double? headY;
  final double? shoulderMidX;
  final double? hipMidX;
  final bool horizontal;
  final bool armAboveHead;
  final bool wideArms;
  final bool wristsNearHips;
  final bool neckTilted;
  final bool asymmetricKnees;
  final double? wristY;
  final bool armsRelaxed;
}

/// Feature extraction and rep counting from raw detector keypoints.
///
/// All angles are computed in the detector's upright frame. Rotation does not
/// change joint angles, so this works for the 270° Android stream, other lenses
/// and replay. Only the exercise that owns a movement is counted, so bending
/// the knees during a curl cannot inflate the squat counter.
class LiveExerciseClassifier {
  LiveExerciseClassifier({this.minConfidence = 0.12, DateTime Function()? now})
    : _clock = now ?? DateTime.now;

  final DateTime Function() _clock;
  final double minConfidence;

  static const Duration _holdDuration = Duration(milliseconds: 250);
  static const Duration _recentRepWindow = Duration(seconds: 4);
  static const Duration _activityWindow = Duration(seconds: 5);
  static const Duration _neutralReset = Duration(seconds: 2);

  /// A squat must start from a standing reference. Without it, a seated or
  /// slightly bent pose in an arbitrary video frame becomes a false positive.
  double? _standingHipY;

  final Map<LiveExerciseKind, int> _reps = {
    for (final kind in LiveExerciseKind.values)
      if (kind != LiveExerciseKind.unknown) kind: 0,
  };

  LiveExerciseKind? _activeKind;
  LiveExerciseKind _lastIdentifiedKind = LiveExerciseKind.unknown;
  DateTime? _downSince;
  DateTime? _neutralSince;
  DateTime? _lastRepAt;
  DateTime? _lastActivityAt;
  bool _isDown = false;

  void reset() {
    for (final kind in _reps.keys.toList()) {
      _reps[kind] = 0;
    }
    _standingHipY = null;
    disarm();
    _activeKind = null;
    _lastIdentifiedKind = LiveExerciseKind.unknown;
    _lastRepAt = null;
    _lastActivityAt = null;
  }

  /// Clears held-position state without throwing away reps already counted.
  /// Called when a frame has no subject so a brief disappearance cannot finish
  /// a rep when the person returns.
  void disarm() {
    _downSince = null;
    _neutralSince = null;
    _isDown = false;
  }

  int countFor(LiveExerciseKind kind) => _reps[kind] ?? 0;

  /// Classifies one detector frame and returns the current reading.
  LiveExerciseReading update(List<PoseKeypoint> keypoints, [DateTime? at]) {
    final now = at ?? _clock();
    final features = _extract(keypoints);

    _learnStandingReference(features);

    var candidate = _geometryKind(features, now);

    // Keep a movement through its opposite phase, even when that posture also
    // resembles another exercise (for example a shoulder press lowered into a
    // curl-like position). Only do this while the movement is still recent.
    final active = _activeKind;
    var preservePhase = false;
    if (active != null && _isRecent(_lastActivityAt, now, _activityWindow)) {
      final finishingRep = _isDown && _isExtended(active, features);
      final holdingDown =
          _isDownPosition(active, features) &&
          (candidate == null ||
              candidate == active ||
              _isTransientFor(active, candidate));
      if (finishingRep || holdingDown) {
        candidate = active;
        preservePhase = true;
      }
    }

    if (candidate != active && !preservePhase) {
      _activeKind = candidate;
      _downSince = null;
      _isDown = false;
    }

    if (candidate == null) {
      _neutralSince ??= now;
      if (now.difference(_neutralSince!).compareTo(_neutralReset) >= 0) {
        _activeKind = null;
      }
    } else {
      _lastIdentifiedKind = candidate;
      _lastActivityAt = now;
      _neutralSince = null;
    }

    // Holds such as plank and neck stretch never complete reps.
    final countsReps =
        candidate != null &&
        candidate != LiveExerciseKind.plank &&
        candidate != LiveExerciseKind.neckStretch;
    if (countsReps) {
      if (_isDownPosition(candidate, features)) {
        _downSince ??= now;
        if (now.difference(_downSince!).inMilliseconds >=
            _holdDuration.inMilliseconds) {
          _isDown = true;
        }
      } else if (_isDown) {
        _registerRep(candidate, now);
        _downSince = null;
        _isDown = false;
      }
    } else {
      _downSince = null;
      _isDown = false;
    }

    // Keep the last identified movement visible while the person rests, so the
    // counter and category do not disappear from the live UI or saved session.
    final kind = _activeKind ?? _lastIdentifiedKind;
    return LiveExerciseReading(
      kind: kind,
      category: kind.category,
      repCount: countFor(kind),
      feedback: _feedbackFor(kind, features),
      kneeAngle: features.knee,
      elbowAngle: features.elbow,
      hipAngle: features.hip,
    );
  }

  void _learnStandingReference(_PoseFeatures f) {
    if (f.horizontal ||
        f.hipY == null ||
        f.knees.length != 2 ||
        !f.knees.every((angle) => angle > 160)) {
      return;
    }
    _standingHipY = _standingHipY == null
        ? f.hipY
        : math.min(_standingHipY!, f.hipY!);
  }

  void _registerRep(LiveExerciseKind kind, DateTime now) {
    _reps[kind] = (_reps[kind] ?? 0) + 1;
    _lastIdentifiedKind = kind;
    _lastRepAt = now;
  }

  bool _isRecent(DateTime? at, DateTime now, Duration window) =>
      at != null && now.difference(at).compareTo(window) < 0;

  /// A lowered press or raise can briefly look like a curl. Do not let that
  /// steal the phase of the movement that is already in progress.
  bool _isTransientFor(LiveExerciseKind active, LiveExerciseKind candidate) =>
      candidate == LiveExerciseKind.bicepCurl &&
      (active == LiveExerciseKind.shoulderPress ||
          active == LiveExerciseKind.lateralRaise ||
          active == LiveExerciseKind.tricepExtension);

  LiveExerciseKind? _geometryKind(_PoseFeatures f, DateTime now) {
    if (f.horizontal) {
      if (f.wristsNearHips && f.elbow != null && f.elbow! < 135) {
        return LiveExerciseKind.bentOverRow;
      }
      if (f.hip != null && f.hip! < 120) return LiveExerciseKind.crunch;
      if (f.elbow != null && f.elbow! < 135) return LiveExerciseKind.pushUp;
      if (_isRecent(_lastRepAt, now, _recentRepWindow)) {
        return LiveExerciseKind.pushUp;
      }
      return LiveExerciseKind.plank;
    }

    // Neck and overhead patterns are checked before elbow flexion so an
    // overhead tricep extension is never reported as a bicep curl.
    if (f.neckTilted && f.armsRelaxed) return LiveExerciseKind.neckStretch;

    if (f.armAboveHead && f.elbow != null) {
      if (f.elbow! < 140) return LiveExerciseKind.tricepExtension;
      if (f.elbow! > 145) return LiveExerciseKind.shoulderPress;
    }

    if (f.wideArms && f.elbow != null && f.elbow! > 145) {
      return LiveExerciseKind.lateralRaise;
    }

    if (f.elbow != null && f.elbow! < 110) return LiveExerciseKind.bicepCurl;

    if (_isSquatShape(f)) return LiveExerciseKind.squat;

    if (f.asymmetricKnees && _hipDropped(f, 0.03)) {
      return LiveExerciseKind.lunge;
    }
    return null;
  }

  /// Squat detection is deliberately strict: both knees bend together, the
  /// torso folds at the hips, the shoulders stay over the hips, and the hips
  /// must actually drop below a standing reference learned earlier in the
  /// session. This rejects sitting, stepping and camera jitter in video.
  bool _isSquatShape(_PoseFeatures f) {
    if (_standingHipY == null || f.knees.length != 2) return false;
    if (!f.knees.every((angle) => angle < 125)) return false;
    if (f.hipAngles.isEmpty || f.hipAngles.any((angle) => angle > 165)) {
      return false;
    }
    if (f.shoulderMidX == null ||
        f.hipMidX == null ||
        (f.shoulderMidX! - f.hipMidX!).abs() > 0.14) {
      return false;
    }
    return _hipDropped(f, 0.04);
  }

  bool _hipDropped(_PoseFeatures f, double minimumDrop) =>
      _standingHipY != null &&
      f.hipY != null &&
      f.hipY! > _standingHipY! + minimumDrop;

  bool _isDownPosition(LiveExerciseKind kind, _PoseFeatures f) {
    switch (kind) {
      case LiveExerciseKind.squat:
        return f.knees.length == 2 && f.knees.every((angle) => angle < 100);
      case LiveExerciseKind.lunge:
        return f.knees.any((angle) => angle < 95);
      case LiveExerciseKind.bicepCurl:
        return f.elbow != null && f.elbow! < 80;
      case LiveExerciseKind.tricepExtension:
        return f.armAboveHead && f.elbow != null && f.elbow! < 135;
      case LiveExerciseKind.shoulderPress:
        return f.wristY != null &&
            f.headY != null &&
            f.elbow != null &&
            f.wristY! > f.headY! + 0.02 &&
            f.elbow! < 140;
      case LiveExerciseKind.lateralRaise:
        return !f.wideArms &&
            f.wristY != null &&
            f.shoulderY != null &&
            f.wristY! > f.shoulderY! + 0.08;
      case LiveExerciseKind.bentOverRow:
        return f.wristsNearHips && f.elbow != null && f.elbow! < 110;
      case LiveExerciseKind.pushUp:
        return f.elbow != null && f.elbow! < 90;
      case LiveExerciseKind.crunch:
        return f.hip != null && f.hip! < 95;
      case LiveExerciseKind.plank:
      case LiveExerciseKind.neckStretch:
      case LiveExerciseKind.unknown:
        return false;
    }
  }

  bool _isExtended(LiveExerciseKind kind, _PoseFeatures f) {
    switch (kind) {
      case LiveExerciseKind.squat:
        return f.knees.length == 2 && f.knees.every((angle) => angle > 155);
      case LiveExerciseKind.lunge:
        return f.knees.length == 2 && f.knees.every((angle) => angle > 155);
      case LiveExerciseKind.bicepCurl:
        return f.elbow != null && f.elbow! > 150;
      case LiveExerciseKind.tricepExtension:
        return f.armAboveHead && f.elbow != null && f.elbow! > 150;
      case LiveExerciseKind.shoulderPress:
        return f.wristY != null &&
            f.headY != null &&
            f.elbow != null &&
            f.wristY! < f.headY! + 0.02 &&
            f.elbow! > 145;
      case LiveExerciseKind.lateralRaise:
        return f.wideArms && (f.elbow == null || f.elbow! > 145);
      case LiveExerciseKind.bentOverRow:
        return !f.wristsNearHips && (f.elbow == null || f.elbow! > 145);
      case LiveExerciseKind.pushUp:
        return f.elbow != null && f.elbow! > 150;
      case LiveExerciseKind.crunch:
        return f.hip != null && f.hip! > 145;
      case LiveExerciseKind.plank:
      case LiveExerciseKind.neckStretch:
      case LiveExerciseKind.unknown:
        return false;
    }
  }

  String _feedbackFor(LiveExerciseKind kind, _PoseFeatures f) {
    switch (kind) {
      case LiveExerciseKind.neckStretch:
        return 'Keep shoulders level and tilt gently - no jerking';
      case LiveExerciseKind.shoulderPress:
        return 'Press overhead without shrugging, then lower slowly';
      case LiveExerciseKind.lateralRaise:
        return 'Raise to shoulder height with soft elbows';
      case LiveExerciseKind.bentOverRow:
        return 'Pull elbows toward the hips and squeeze the back';
      case LiveExerciseKind.bicepCurl:
        return f.elbow != null && f.elbow! < 80
            ? 'Squeeze the curl at the top, then lower slowly'
            : 'Keep elbows close and curl up';
      case LiveExerciseKind.tricepExtension:
        return 'Keep upper arms still and extend overhead';
      case LiveExerciseKind.pushUp:
        return f.elbow != null && f.elbow! < 90
            ? 'Press the floor away and keep a straight body line'
            : 'Lower under control - body straight';
      case LiveExerciseKind.squat:
        if (f.knees.isEmpty) return 'Step back so both legs are visible';
        if (f.knees.every((angle) => angle < 100)) {
          return 'Deep squat - drive up through the heels';
        }
        if (f.knees.any((angle) => angle < 140)) {
          return 'Descending - keep going for parallel depth';
        }
        return 'Standing - squat down slowly';
      case LiveExerciseKind.lunge:
        return 'Step back, drop the rear knee and keep the torso tall';
      case LiveExerciseKind.crunch:
        return f.hip != null && f.hip! < 95
            ? 'Exhale and lift the shoulders, then lower slowly'
            : 'Lie back and fold at the hips to start a crunch';
      case LiveExerciseKind.plank:
        return 'Hold a straight line from shoulders to ankles';
      case LiveExerciseKind.unknown:
        return 'Stand in frame and start moving';
    }
  }

  _PoseFeatures _extract(List<PoseKeypoint> keypoints) {
    final kneeLeft = _angleFor(
      keypoints,
      'left_hip',
      'left_knee',
      'left_ankle',
    );
    final kneeRight = _angleFor(
      keypoints,
      'right_hip',
      'right_knee',
      'right_ankle',
    );
    final elbowLeft = _angleFor(
      keypoints,
      'left_shoulder',
      'left_elbow',
      'left_wrist',
    );
    final elbowRight = _angleFor(
      keypoints,
      'right_shoulder',
      'right_elbow',
      'right_wrist',
    );
    final hipLeft = _angleFor(
      keypoints,
      'left_shoulder',
      'left_hip',
      'left_knee',
    );
    final hipRight = _angleFor(
      keypoints,
      'right_shoulder',
      'right_hip',
      'right_knee',
    );

    final knees = <double>[?kneeLeft, ?kneeRight];
    final elbows = <double>[?elbowLeft, ?elbowRight];
    final hipAngles = <double>[?hipLeft, ?hipRight];

    final leftHip = _point(keypoints, 'left_hip');
    final rightHip = _point(keypoints, 'right_hip');
    final leftShoulder = _point(keypoints, 'left_shoulder');
    final rightShoulder = _point(keypoints, 'right_shoulder');
    final head = _point(keypoints, 'head');
    final leftWrist = _point(keypoints, 'left_wrist');
    final rightWrist = _point(keypoints, 'right_wrist');

    final hipY = _midOrSingle(leftHip?.y, rightHip?.y);
    final shoulderY = _midOrSingle(leftShoulder?.y, rightShoulder?.y);
    final shoulderMidX = _midOrSingle(leftShoulder?.x, rightShoulder?.x);
    final hipMidX = _midOrSingle(leftHip?.x, rightHip?.x);

    final wrists = <PoseKeypoint>[?leftWrist, ?rightWrist];
    final wristY = wrists.isEmpty
        ? null
        : wrists.map((w) => w.y).reduce(math.min);

    final armAboveHead =
        head != null &&
        wristY != null &&
        shoulderY != null &&
        wristY < head.y + 0.03 &&
        wrists.every((w) => w.y < shoulderY);

    final wideArms =
        shoulderMidX != null &&
        shoulderY != null &&
        wrists.length == 2 &&
        wrists.every(
          (w) =>
              (w.x - shoulderMidX).abs() > 0.16 &&
              (w.y - shoulderY).abs() < 0.13,
        );

    final wristsNearHips =
        (leftWrist != null &&
            leftHip != null &&
            _distance(leftWrist, leftHip) < 0.18) ||
        (rightWrist != null &&
            rightHip != null &&
            _distance(rightWrist, rightHip) < 0.18);

    final neckTilted =
        head != null &&
        shoulderMidX != null &&
        hipMidX != null &&
        leftShoulder != null &&
        rightShoulder != null &&
        (head.x - shoulderMidX).abs() > 0.07 &&
        (leftShoulder.y - rightShoulder.y).abs() < 0.07 &&
        (shoulderMidX - hipMidX).abs() < 0.10;

    final asymmetricKnees =
        kneeLeft != null &&
        kneeRight != null &&
        ((kneeLeft < 100 && kneeRight > 155) ||
            (kneeRight < 100 && kneeLeft > 155));

    final armsRelaxed =
        !armAboveHead &&
        !wideArms &&
        (elbows.isEmpty || elbows.every((angle) => angle > 145));

    return _PoseFeatures(
      knee: _smallest(knees),
      elbow: _smallest(elbows),
      hip: _smallest(hipAngles),
      knees: knees,
      elbows: elbows,
      hipAngles: hipAngles,
      hipY: hipY,
      shoulderY: shoulderY,
      headY: head?.y,
      shoulderMidX: shoulderMidX,
      hipMidX: hipMidX,
      horizontal: _torsoHorizontal(keypoints),
      armAboveHead: armAboveHead,
      wideArms: wideArms,
      wristsNearHips: wristsNearHips,
      neckTilted: neckTilted,
      asymmetricKnees: asymmetricKnees,
      wristY: wristY,
      armsRelaxed: armsRelaxed,
    );
  }

  double? _smallest(List<double> values) =>
      values.isEmpty ? null : values.reduce(math.min);

  double? _midOrSingle(double? a, double? b) {
    if (a != null && b != null) return (a + b) / 2;
    return a ?? b;
  }

  double _distance(PoseKeypoint a, PoseKeypoint b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  double? _angleFor(
    List<PoseKeypoint> keypoints,
    String aName,
    String bName,
    String cName,
  ) {
    final a = _point(keypoints, aName);
    final b = _point(keypoints, bName);
    final c = _point(keypoints, cName);
    if (a == null || b == null || c == null) return null;
    final v1x = a.x - b.x;
    final v1y = a.y - b.y;
    final v2x = c.x - b.x;
    final v2y = c.y - b.y;
    final denominator =
        math.sqrt(v1x * v1x + v1y * v1y) * math.sqrt(v2x * v2x + v2y * v2y);
    if (denominator == 0) return null;
    final cosine = (v1x * v2x + v1y * v2y) / denominator;
    return math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  PoseKeypoint? _point(List<PoseKeypoint> keypoints, String name) {
    for (final point in keypoints) {
      if (point.name == name && point.confidence >= minConfidence) {
        return point;
      }
    }
    return null;
  }

  bool _torsoHorizontal(List<PoseKeypoint> keypoints) {
    for (final side in ['left', 'right']) {
      final shoulder = _point(keypoints, '${side}_shoulder');
      final hip = _point(keypoints, '${side}_hip');
      if (shoulder != null &&
          hip != null &&
          (shoulder.y - hip.y).abs() < 0.09 &&
          (shoulder.x - hip.x).abs() > 0.05) {
        return true;
      }
    }
    return false;
  }
}
