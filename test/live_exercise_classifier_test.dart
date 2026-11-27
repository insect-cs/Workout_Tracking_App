import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/services/live_exercise_classifier.dart';
import 'package:workout_app/services/pose_analysis_service.dart';

PoseKeypoint kp(String name, double x, double y) =>
    PoseKeypoint(name: name, x: x, y: y, confidence: 0.9);

List<PoseKeypoint> upright({double kneeAngle = 180, double elbowAngle = 180}) {
  final bentKnee = kneeAngle < 130;
  final bentElbow = elbowAngle < 100;
  return [
    kp('head', 0.50, 0.10),
    kp('left_shoulder', 0.42, 0.25),
    kp('right_shoulder', 0.58, 0.25),
    kp('left_elbow', bentElbow ? 0.36 : 0.38, bentElbow ? 0.45 : 0.40),
    kp('right_elbow', bentElbow ? 0.64 : 0.62, bentElbow ? 0.45 : 0.40),
    kp('left_wrist', bentElbow ? 0.48 : 0.36, bentElbow ? 0.38 : 0.62),
    kp('right_wrist', bentElbow ? 0.52 : 0.64, bentElbow ? 0.38 : 0.62),
    kp('left_hip', 0.44, bentKnee ? 0.60 : 0.55),
    kp('right_hip', 0.56, bentKnee ? 0.60 : 0.55),
    kp('left_knee', bentKnee ? 0.30 : 0.43, bentKnee ? 0.75 : 0.75),
    kp('right_knee', bentKnee ? 0.70 : 0.57, bentKnee ? 0.75 : 0.75),
    kp('left_ankle', 0.43, 0.92),
    kp('right_ankle', 0.57, 0.92),
  ];
}

List<PoseKeypoint> horizontalBody({required bool bentElbows}) {
  return [
    kp('head', 0.15, 0.45),
    kp('left_shoulder', 0.25, 0.45),
    kp('right_shoulder', 0.32, 0.45),
    kp('left_elbow', 0.20, bentElbows ? 0.60 : 0.45),
    kp('right_elbow', 0.36, bentElbows ? 0.60 : 0.45),
    kp('left_wrist', bentElbows ? 0.30 : 0.14, bentElbows ? 0.55 : 0.45),
    kp('right_wrist', bentElbows ? 0.26 : 0.46, bentElbows ? 0.55 : 0.45),
    kp('left_hip', 0.55, 0.45),
    kp('right_hip', 0.62, 0.45),
    kp('left_knee', 0.75, 0.45),
    kp('right_knee', 0.80, 0.45),
    kp('left_ankle', 0.90, 0.45),
    kp('right_ankle', 0.94, 0.45),
  ];
}

List<PoseKeypoint> tiltedNeck() => [
  kp('head', 0.62, 0.10),
  ...upright().skip(1),
];

List<PoseKeypoint> overheadPress({required bool raised}) {
  if (!raised) return upright(elbowAngle: 45);
  return [
    kp('head', 0.50, 0.12),
    kp('left_shoulder', 0.42, 0.28),
    kp('right_shoulder', 0.58, 0.28),
    kp('left_elbow', 0.44, 0.18),
    kp('right_elbow', 0.56, 0.18),
    kp('left_wrist', 0.46, 0.05),
    kp('right_wrist', 0.54, 0.05),
    kp('left_hip', 0.44, 0.58),
    kp('right_hip', 0.56, 0.58),
    kp('left_knee', 0.43, 0.78),
    kp('right_knee', 0.57, 0.78),
    kp('left_ankle', 0.43, 0.92),
    kp('right_ankle', 0.57, 0.92),
  ];
}

List<PoseKeypoint> raisedArms() {
  return [
    kp('head', 0.50, 0.12),
    kp('left_shoulder', 0.42, 0.28),
    kp('right_shoulder', 0.58, 0.28),
    kp('left_elbow', 0.25, 0.27),
    kp('right_elbow', 0.75, 0.27),
    kp('left_wrist', 0.10, 0.27),
    kp('right_wrist', 0.90, 0.27),
    kp('left_hip', 0.44, 0.58),
    kp('right_hip', 0.56, 0.58),
    kp('left_knee', 0.43, 0.78),
    kp('right_knee', 0.57, 0.78),
    kp('left_ankle', 0.43, 0.92),
    kp('right_ankle', 0.57, 0.92),
  ];
}

List<PoseKeypoint> overheadTricep({required bool extended}) => [
  kp('head', 0.50, 0.14),
  kp('left_shoulder', 0.42, 0.30),
  kp('right_shoulder', 0.58, 0.30),
  kp('left_elbow', 0.44, 0.18),
  kp('right_elbow', 0.56, 0.18),
  kp('left_wrist', extended ? 0.44 : 0.58, extended ? 0.05 : 0.10),
  kp('right_wrist', extended ? 0.56 : 0.42, extended ? 0.05 : 0.10),
  ...upright().skip(7),
];

List<PoseKeypoint> rowPose({required bool pulled}) => [
  kp('head', 0.15, 0.45),
  kp('left_shoulder', 0.25, 0.45),
  kp('right_shoulder', 0.32, 0.45),
  kp('left_elbow', pulled ? 0.45 : 0.18, pulled ? 0.58 : 0.52),
  kp('right_elbow', pulled ? 0.52 : 0.25, pulled ? 0.58 : 0.52),
  kp('left_wrist', pulled ? 0.55 : 0.10, pulled ? 0.50 : 0.55),
  kp('right_wrist', pulled ? 0.62 : 0.17, pulled ? 0.50 : 0.55),
  kp('left_hip', 0.55, 0.45),
  kp('right_hip', 0.62, 0.45),
  kp('left_knee', 0.75, 0.45),
  kp('right_knee', 0.80, 0.45),
  kp('left_ankle', 0.90, 0.45),
  kp('right_ankle', 0.94, 0.45),
];

List<PoseKeypoint> lungePose() => [
  kp('head', 0.50, 0.12),
  kp('left_shoulder', 0.42, 0.25),
  kp('right_shoulder', 0.58, 0.25),
  kp('left_elbow', 0.38, 0.40),
  kp('right_elbow', 0.62, 0.40),
  kp('left_wrist', 0.36, 0.62),
  kp('right_wrist', 0.64, 0.62),
  kp('left_hip', 0.42, 0.60),
  kp('right_hip', 0.56, 0.60),
  kp('left_knee', 0.32, 0.72),
  kp('right_knee', 0.56, 0.76),
  kp('left_ankle', 0.48, 0.85),
  kp('right_ankle', 0.56, 0.92),
];

void main() {
  group('live exercise classifier', () {
    test('squat reps are legs and need a held deep position', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 10);

      var reading = classifier.update(upright(), start);
      expect(reading.kind, LiveExerciseKind.unknown);
      expect(reading.category, LiveExerciseCategory.unknown);

      reading = classifier.update(
        upright(kneeAngle: 95),
        start.add(const Duration(milliseconds: 80)),
      );
      expect(classifier.countFor(LiveExerciseKind.squat), 0);

      classifier.update(
        upright(kneeAngle: 95),
        start.add(const Duration(milliseconds: 400)),
      );
      reading = classifier.update(
        upright(),
        start.add(const Duration(milliseconds: 650)),
      );
      expect(reading.kind, LiveExerciseKind.squat);
      expect(reading.category, LiveExerciseCategory.legs);
      expect(reading.repCount, 1);
    });

    test('bent knees without a standing reference do not create a squat', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 10, 5);
      final reading = classifier.update(
        upright(kneeAngle: 95),
        start.add(const Duration(milliseconds: 500)),
      );
      expect(reading.kind, LiveExerciseKind.unknown);
      expect(classifier.countFor(LiveExerciseKind.squat), 0);
    });

    test('bicep curl reps are biceps', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 11);
      classifier.update(upright(elbowAngle: 45), start);
      classifier.update(
        upright(elbowAngle: 45),
        start.add(const Duration(milliseconds: 300)),
      );
      final reading = classifier.update(
        upright(elbowAngle: 180),
        start.add(const Duration(milliseconds: 600)),
      );
      expect(reading.kind, LiveExerciseKind.bicepCurl);
      expect(reading.category, LiveExerciseCategory.biceps);
      expect(reading.repCount, 1);
    });

    test('bent knees during a curl do not inflate the squat counter', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 11, 30);
      classifier.update(upright(), start);
      classifier.update(upright(elbowAngle: 45, kneeAngle: 95), start);
      classifier.update(
        upright(elbowAngle: 45, kneeAngle: 95),
        start.add(const Duration(milliseconds: 300)),
      );
      classifier.update(
        upright(elbowAngle: 180, kneeAngle: 95),
        start.add(const Duration(milliseconds: 600)),
      );
      expect(classifier.countFor(LiveExerciseKind.bicepCurl), 1);
      expect(classifier.countFor(LiveExerciseKind.squat), 0);
    });

    test('a lateral head tilt with relaxed arms is a neck hold', () {
      final classifier = LiveExerciseClassifier();
      final reading = classifier.update(
        tiltedNeck(),
        DateTime(2026, 11, 27, 11, 45),
      );
      expect(reading.kind, LiveExerciseKind.neckStretch);
      expect(reading.category, LiveExerciseCategory.neck);
      expect(reading.repCount, 0);
    });

    test('overhead presses are shoulder reps', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 12);
      classifier.update(overheadPress(raised: true), start);
      classifier.update(
        overheadPress(raised: false),
        start.add(const Duration(milliseconds: 300)),
      );
      classifier.update(
        overheadPress(raised: false),
        start.add(const Duration(milliseconds: 550)),
      );
      final reading = classifier.update(
        overheadPress(raised: true),
        start.add(const Duration(milliseconds: 800)),
      );
      expect(reading.kind, LiveExerciseKind.shoulderPress);
      expect(reading.category, LiveExerciseCategory.shoulders);
      expect(reading.repCount, 1);
    });

    test('wide arms at shoulder height are lateral raises', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 12, 10);
      classifier.update(raisedArms(), start);
      classifier.update(
        upright(),
        start.add(const Duration(milliseconds: 300)),
      );
      classifier.update(
        upright(),
        start.add(const Duration(milliseconds: 550)),
      );
      final reading = classifier.update(
        raisedArms(),
        start.add(const Duration(milliseconds: 800)),
      );
      expect(reading.kind, LiveExerciseKind.lateralRaise);
      expect(reading.category, LiveExerciseCategory.shoulders);
      expect(reading.repCount, 1);
    });

    test('bent arms overhead are tricep extensions', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 12, 20);
      classifier.update(overheadTricep(extended: false), start);
      classifier.update(
        overheadTricep(extended: false),
        start.add(const Duration(milliseconds: 300)),
      );
      final reading = classifier.update(
        overheadTricep(extended: true),
        start.add(const Duration(milliseconds: 600)),
      );
      expect(reading.kind, LiveExerciseKind.tricepExtension);
      expect(reading.category, LiveExerciseCategory.triceps);
      expect(reading.repCount, 1);
    });

    test('pulling the elbows back on a horizontal torso is a back row', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 12, 40);
      classifier.update(rowPose(pulled: true), start);
      classifier.update(
        rowPose(pulled: true),
        start.add(const Duration(milliseconds: 300)),
      );
      final reading = classifier.update(
        rowPose(pulled: false),
        start.add(const Duration(milliseconds: 600)),
      );
      expect(reading.kind, LiveExerciseKind.bentOverRow);
      expect(reading.category, LiveExerciseCategory.back);
      expect(reading.repCount, 1);
    });

    test('horizontal torso with elbow cycles is a push-up', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 13);

      classifier.update(horizontalBody(bentElbows: true), start);
      classifier.update(
        horizontalBody(bentElbows: true),
        start.add(const Duration(milliseconds: 300)),
      );
      final reading = classifier.update(
        horizontalBody(bentElbows: false),
        start.add(const Duration(milliseconds: 600)),
      );
      expect(reading.kind, LiveExerciseKind.pushUp);
      expect(reading.category, LiveExerciseCategory.chest);
      expect(reading.repCount, 1);
    });

    test('reverse lunge reps are legs and need one bent knee', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 13, 15);
      classifier.update(upright(), start);
      classifier.update(
        lungePose(),
        start.add(const Duration(milliseconds: 300)),
      );
      classifier.update(
        lungePose(),
        start.add(const Duration(milliseconds: 600)),
      );
      final reading = classifier.update(
        upright(),
        start.add(const Duration(milliseconds: 900)),
      );
      expect(reading.kind, LiveExerciseKind.lunge);
      expect(reading.category, LiveExerciseCategory.legs);
      expect(reading.repCount, 1);
    });

    test('a held straight body line is a core plank with no reps', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 13, 30);
      final plank = horizontalBody(bentElbows: false);

      final reading = classifier.update(
        plank,
        start.add(const Duration(milliseconds: 1200)),
      );
      expect(reading.kind, LiveExerciseKind.plank);
      expect(reading.category, LiveExerciseCategory.core);
      expect(reading.repCount, 0);
    });

    test('hip flexion on a horizontal torso is a core crunch', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 14);
      final folded = [
        kp('left_shoulder', 0.25, 0.45),
        kp('right_shoulder', 0.32, 0.45),
        kp('left_hip', 0.55, 0.45),
        kp('right_hip', 0.62, 0.45),
        kp('left_knee', 0.50, 0.25),
        kp('right_knee', 0.62, 0.25),
      ];
      final extended = List<PoseKeypoint>.from(folded);
      extended[4] = kp('left_knee', 0.75, 0.50);
      extended[5] = kp('right_knee', 0.82, 0.50);

      classifier.update(folded, start);
      classifier.update(folded, start.add(const Duration(milliseconds: 300)));
      final reading = classifier.update(
        extended,
        start.add(const Duration(milliseconds: 600)),
      );
      expect(reading.kind, LiveExerciseKind.crunch);
      expect(reading.category, LiveExerciseCategory.core);
      expect(reading.repCount, 1);
    });

    test('disarm on a missed frame never completes a rep', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 14, 30);
      classifier.update(upright(), start);
      classifier.update(upright(kneeAngle: 45), start);
      classifier.update(
        upright(kneeAngle: 45),
        start.add(const Duration(milliseconds: 300)),
      );
      classifier.disarm();
      final reading = classifier.update(
        upright(),
        start.add(const Duration(milliseconds: 600)),
      );
      expect(classifier.countFor(LiveExerciseKind.squat), 0);
      expect(reading.repCount, 0);
    });

    test('last exercise and its counter stay visible while resting', () {
      final classifier = LiveExerciseClassifier();
      final start = DateTime(2026, 11, 27, 15);
      classifier.update(upright(), start);
      classifier.update(upright(kneeAngle: 45), start);
      classifier.update(
        upright(kneeAngle: 45),
        start.add(const Duration(milliseconds: 300)),
      );
      classifier.update(
        upright(),
        start.add(const Duration(milliseconds: 600)),
      );
      final reading = classifier.update(
        upright(),
        start.add(const Duration(seconds: 4)),
      );
      expect(reading.kind, LiveExerciseKind.squat);
      expect(reading.category, LiveExerciseCategory.legs);
      expect(reading.repCount, 1);
    });
  });
}
