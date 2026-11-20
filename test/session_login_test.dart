import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/main.dart';
import 'package:workout_app/services/api_key_service.dart';
import 'package:workout_app/services/local_store.dart';
import 'package:workout_app/state/session_state.dart';
import 'package:workout_app/state/workout_state.dart';
import 'package:workout_app/theme/theme_controller.dart';

void main() {
  setUp(() async {
    await LocalStore.instance.resetForTesting();
    await ApiKeyStore.instance.resetForTesting();
    SessionState.resetForTesting();
    ThemeController.mode.value = ThemeMode.dark;
    ThemeController.seed.value = ThemeController.palettes.first.seed;
    ThemeController.paletteName.value = ThemeController.palettes.first.name;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const WorkoutTrackingApp());
    await tester.pumpAndSettle();
    expect(find.text('Choose your session'), findsOneWidget);
  }

  testWidgets('guest can sign in but can only leave via sign out', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your session'), findsNothing);
    expect(find.text('Exercise Catalog'), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsOneWidget);
    expect(SessionState.isSignedIn, isTrue);
    expect(SessionState.kind.value, SessionKind.guest);
    expect(WorkoutState.instance.savedWorkouts, isNotEmpty);
    expect(WorkoutState.instance.exerciseLogs, isNotEmpty);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your session'), findsOneWidget);
    expect(find.byTooltip('Delete saved session'), findsOneWidget);
    expect(find.text('Guest session'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue as guest'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Continue as new user'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('session must be deleted before a new user can sign in', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete saved session'));
    await tester.pumpAndSettle();
    expect(find.text('Delete saved session?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(SessionState.hasSession, isFalse);
    expect(find.byTooltip('Delete saved session'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue as guest'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Continue as new user'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Continue as new user'));
    await tester.pumpAndSettle();

    expect(SessionState.kind.value, SessionKind.newUser);
    expect(find.text('Exercise Catalog'), findsOneWidget);
    expect(WorkoutState.instance.savedWorkouts, isEmpty);
    expect(WorkoutState.instance.exerciseLogs, isEmpty);
    expect(WorkoutState.instance.currentWorkout.name, isEmpty);
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets('new user follows the same sign-out and delete rule', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Continue as new user'));
    await tester.pumpAndSettle();

    expect(SessionState.kind.value, SessionKind.newUser);
    expect(WorkoutState.instance.savedWorkouts, isEmpty);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete saved session'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Continue as new user'),
          )
          .onPressed,
      isNull,
    );
  });
}
