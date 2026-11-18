import 'package:flutter/material.dart';

/// Global theme mode used by the whole app.
///
/// The Home screen toggle calls [toggle]; [WorkoutTrackingApp] listens to
/// [mode] and rebuilds with the matching Material 3 light/dark theme.
abstract final class ThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.dark,
  );

  static bool get isDark => mode.value == ThemeMode.dark;

  static void toggle() {
    mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}
