import 'package:flutter/material.dart';

/// A seed colour that is known to generate a balanced Material 3 scheme in
/// both light and dark mode. The Auto palette button cycles through these.
class PaletteOption {
  final String name;
  final Color seed;

  const PaletteOption(this.name, this.seed);
}

/// Global theme state used by the whole app.
///
/// The Home screen toggles [mode] and cycles [seed]; [WorkoutTrackingApp]
/// listens to both and rebuilds with the matching seeded Material 3 theme.
abstract final class ThemeController {
  static const List<PaletteOption> palettes = [
    PaletteOption('Sunset Orange', Color(0xFFFF6B00)),
    PaletteOption('Ocean Blue', Color(0xFF0061A4)),
    PaletteOption('Forest Teal', Color(0xFF006C51)),
    PaletteOption('Violet', Color(0xFF6750A4)),
    PaletteOption('Crimson', Color(0xFF9C4146)),
    PaletteOption('Olive Green', Color(0xFF3F6212)),
  ];

  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.dark,
  );

  static final ValueNotifier<Color> seed = ValueNotifier<Color>(
    palettes.first.seed,
  );

  static final ValueNotifier<String> paletteName = ValueNotifier<String>(
    palettes.first.name,
  );

  static bool get isDark => mode.value == ThemeMode.dark;

  static void toggle() {
    mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  /// Chooses the next automatically harmonised palette. Every entry is a
  /// Material 3 seed, so the generated light and dark schemes stay balanced.
  static String chooseNextPalette() {
    final index = palettes.indexWhere((option) => option.seed == seed.value);
    final next = palettes[(index + 1) % palettes.length];
    seed.value = next.seed;
    paletteName.value = next.name;
    return next.name;
  }
}
