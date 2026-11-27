import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/main.dart';
import 'package:workout_app/services/api_key_service.dart';
import 'package:workout_app/screens/login_screen.dart';
import 'package:workout_app/services/local_store.dart';
import 'package:workout_app/services/update_service.dart';
import 'package:workout_app/state/session_state.dart';
import 'package:workout_app/state/workout_state.dart';
import 'package:workout_app/theme/app_colors.dart';
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

  /// Selects the new-user card, then finishes the name-entry page.
  Future<void> createNewUser(
    WidgetTester tester, {
    String name = 'Alex',
  }) async {
    await tester.tap(find.text('Continue as new user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue as new user'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('name-field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name-field')), name);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('name-next')));
    await tester.pumpAndSettle();
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

  testWidgets('a saved session can be resumed without creating a new one', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resume-session')), findsOneWidget);
    expect(SessionState.hasSession, isTrue);
    expect(SessionState.isSignedIn, isFalse);
    expect(SessionState.canSignIn, isFalse);

    await tester.tap(find.byKey(const Key('resume-session')));
    await tester.pumpAndSettle();

    expect(SessionState.isSignedIn, isTrue);
    expect(SessionState.kind.value, SessionKind.guest);
    expect(find.text('Exercise Catalog'), findsOneWidget);
    expect(find.text('Choose your session'), findsNothing);
    // Restoring never creates a second profile.
    expect(SessionState.canSignIn, isFalse);
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

    await createNewUser(tester);

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
    await createNewUser(tester);

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

  testWidgets('welcome cards select via wheel, swipe, keys and tap', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('session-dots')), findsNothing);
    bool highlighted(int index) {
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(Key('session-option-$index')),
      );
      final side = button.style?.side?.resolve(const <WidgetState>{});
      return side?.color == AppColors.primaryOrange;
    }

    expect(highlighted(0), isTrue);
    expect(highlighted(1), isFalse);
    expect(
      tester.widget<Text>(find.text('Continue as guest')).style?.color,
      AppColors.textWhite,
    );

    // Mouse wheel down highlights the next card.
    await tester.handlePointerEventRecord([
      PointerEventRecord(Duration.zero, [
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          device: 1,
          position: tester.getCenter(find.byKey(const Key('session-selector'))),
          scrollDelta: const Offset(0, 120),
        ),
      ]),
    ]);
    await tester.pumpAndSettle();
    expect(highlighted(0), isFalse);
    expect(highlighted(1), isTrue);

    // Arrow up highlights the previous card.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(highlighted(0), isTrue);
    expect(highlighted(1), isFalse);

    // Swipe up highlights the next card.
    await tester.drag(
      find.byKey(const Key('session-selector')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(highlighted(1), isTrue);

    // Tapping an unhighlighted card selects it without signing in.
    await tester.tap(find.byKey(const Key('session-option-0')));
    await tester.pumpAndSettle();
    expect(highlighted(0), isTrue);
    expect(SessionState.isSignedIn, isFalse);

    // Tapping the highlighted card confirms it.
    await tester.tap(find.byKey(const Key('session-option-0')));
    await tester.pumpAndSettle();
    expect(SessionState.kind.value, SessionKind.guest);
    expect(SessionState.isSignedIn, isTrue);
  });

  testWidgets('Enter confirms the highlighted session card', (tester) async {
    await pumpApp(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('name-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('name-field')), 'Taylor');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('name-next')));
    await tester.pumpAndSettle();

    expect(SessionState.kind.value, SessionKind.newUser);
    expect(SessionState.isSignedIn, isTrue);
  });

  testWidgets('new user name updates welcome text and appears on Home', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Continue as new user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue as new user'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('welcome-name')), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('name-next'))).onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('name-field')), 'Sam');
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Sam'), findsOneWidget);
    expect(SessionState.isSignedIn, isFalse);

    await tester.tap(find.byKey(const Key('name-next')));
    await tester.pumpAndSettle();

    expect(SessionState.kind.value, SessionKind.newUser);
    expect(SessionState.name, 'Sam');
    expect(find.text('WELCOME BACK, SAM'), findsOneWidget);
  });

  testWidgets('check for updates button shows the GitHub release', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          updateChecker: () async => const AppUpdate(
            latestVersion: '3.0.0',
            releaseName: 'Big release',
            releaseNotes: 'Faster app',
            releaseUrl: 'https://github.com/x/releases',
            apkUrl: null,
            isNewer: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('check-for-updates'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(
      find.text(
        'Version 3.0.0 is available. You have ${UpdateService.currentVersion}.',
      ),
      findsOneWidget,
    );
    expect(find.text('Big release'), findsOneWidget);
    expect(find.text('Faster app'), findsOneWidget);
    expect(find.byKey(const Key('update-open')), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('check for updates reports the current version', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          updateChecker: () async => const AppUpdate(
            latestVersion: '1.0.0',
            releaseName: '',
            releaseNotes: '',
            releaseUrl: 'https://github.com/x/releases',
            apkUrl: null,
            isNewer: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('check-for-updates')));
    await tester.pumpAndSettle();

    expect(find.text('You’re up to date'), findsOneWidget);
    expect(find.byKey(const Key('update-open')), findsNothing);
  });
}
