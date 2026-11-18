import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/screens/pose_tracking_screen.dart';

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
  });
}
