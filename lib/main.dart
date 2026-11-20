import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_key_service.dart';
import 'services/local_store.dart';
import 'state/diet_state.dart';
import 'state/session_state.dart';
import 'state/workout_state.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // All fonts used by the app are bundled in assets/fonts. Never let the
  // google_fonts package download from fonts.gstatic.com at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  await LocalStore.instance.ensureLoaded();
  await SessionState.ensureLoaded();
  await ApiKeyStore.instance.ensureLoaded();

  // A signed-out or brand-new device stays on the login gate; no user data is
  // loaded until a profile is selected.
  if (SessionState.isSignedIn) {
    await Future.wait([
      WorkoutState.instance.reload(
        withDemoData: SessionState.kind.value == SessionKind.guest,
      ),
      DietState.instance.reload(),
      ThemeController.reload(),
    ]);
  }
  runApp(const WorkoutTrackingApp());
}

class WorkoutTrackingApp extends StatefulWidget {
  const WorkoutTrackingApp({super.key});

  @override
  State<WorkoutTrackingApp> createState() => _WorkoutTrackingAppState();
}

class _WorkoutTrackingAppState extends State<WorkoutTrackingApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.mode.addListener(_handleThemeChanged);
    ThemeController.seed.addListener(_handleThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.mode.removeListener(_handleThemeChanged);
    ThemeController.seed.removeListener(_handleThemeChanged);
    super.dispose();
  }

  void _handleThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ThemeController.mode.value;

    return MaterialApp(
      title: 'Workout Tracking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Forces a full subtree rebuild so every custom AppColors role switches
      // together with the Material 3 theme. Switching the signed-in value
      // replaces the root widget, so there is no back route into the login
      // screen until the user signs out from Home.
      home: ValueListenableBuilder<bool>(
        valueListenable: SessionState.signedIn,
        builder: (context, signedIn, _) {
          final themeKey = ValueKey(
            '${themeMode}_${ThemeController.seed.value}_'
            '${SessionState.kind.value?.name ?? 'none'}',
          );
          return signedIn
              ? MainShell(key: themeKey)
              : LoginScreen(key: themeKey);
        },
      ),
    );
  }
}
