import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/pose_history_models.dart';
import 'package:workout_app/screens/pose_tracking_screen.dart';
import 'package:workout_app/services/live_tracking_history_service.dart';
import 'package:workout_app/services/local_store.dart';

void main() {
  testWidgets('Pose tracking screen smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: PoseTrackingScreen(onBackToHome: () {})),
    );
    await tester.pump();

    expect(find.text('POSE TRACKING'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(
      find.text('LIVE SQUAT TRACKING (PERSON IN FRONT OF CAMERA)'),
      findsOneWidget,
    );
    expect(find.text('Live Tracking'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.byKey(const Key('save-live-tracking')), findsOneWidget);
  });

  testWidgets('live tracking history shows saved sessions', (tester) async {
    await LocalStore.instance.resetForTesting();
    await LiveTrackingHistoryStore.save(
      LiveTrackingSession(
        id: 'history-1',
        startedAt: DateTime(2026, 11, 23, 9),
        endedAt: DateTime(2026, 11, 23, 9, 2),
        exerciseName: 'Bodyweight Squat',
        repCount: 15,
        squatCount: 15,
        curlCount: 0,
        pushupCount: 0,
        kneeAngle: 90,
        elbowAngle: 170,
        minKneeAngle: 80,
        minElbowAngle: null,
        feedback: 'Deep squat',
        engine: 'ML Kit',
        cameraName: null,
        keypoints: const [],
      ),
    );

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: PoseTrackingScreen(onBackToHome: () {})),
    );
    await tester.pump();
    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('LIVE TRACKING HISTORY'), findsOneWidget);
    expect(find.text('Bodyweight Squat'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.byTooltip('Clear all'), findsOneWidget);
  });

  testWidgets('history shows a video-only session with no tracking message', (
    tester,
  ) async {
    await LocalStore.instance.resetForTesting();
    await LiveTrackingHistoryStore.save(
      LiveTrackingSession(
        id: 'video-only',
        startedAt: DateTime(2026, 11, 23, 10),
        endedAt: DateTime(2026, 11, 23, 10, 1),
        exerciseName: 'No live tracking',
        repCount: 0,
        squatCount: 0,
        curlCount: 0,
        pushupCount: 0,
        kneeAngle: null,
        elbowAngle: null,
        minKneeAngle: null,
        minElbowAngle: null,
        feedback: 'No live tracking happened. The captured camera video is saved below.',
        engine: 'MoveNet (TF.js)',
        cameraName: 'Webcam',
        keypoints: const [],
        videoBase64: 'ZmFrZSB2aWRlbyBieXRlcw==',
        videoMimeType: 'video/webm',
      ),
    );

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: PoseTrackingScreen(onBackToHome: () {})),
    );
    await tester.pump();
    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('NO LIVE TRACKING HAPPENED'), findsOneWidget);
    expect(
      find.text(
        'No live tracking happened. The captured camera video is saved below.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('session-video-video-only')), findsOneWidget);
  });
}
