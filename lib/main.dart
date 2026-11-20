import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'services/api_key_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load securely stored AI keys before the first frame so every feature sees
  // the same active key/endpoint.
  await ApiKeyStore.instance.ensureLoaded();
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
      // together with the Material 3 theme.
      home: MainShell(
        key: ValueKey('${themeMode}_${ThemeController.seed.value}'),
      ),
    );
  }
}
