import 'dart:async';

import 'package:flutter/material.dart';

import '../services/local_store.dart';

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
  static const String _storeKey = 'workout_app.theme.v1';

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

  static bool _listening = false;
  static bool _suppressPersist = false;

  static bool get isDark => mode.value == ThemeMode.dark;

  /// Restores the saved theme and starts persisting future changes.
  static Future<void> ensureLoaded() async {
    await LocalStore.instance.ensureLoaded();
    final saved = LocalStore.instance.readMap(_storeKey);
    if (saved != null) {
      mode.value = ThemeMode.values.firstWhere(
        (value) => value.name == saved['mode'],
        orElse: () => ThemeMode.dark,
      );
      final seedValue = (saved['seed'] as num?)?.toInt();
      if (seedValue != null) {
        final match = palettes.where(
          (option) => option.seed.toARGB32() == seedValue,
        );
        if (match.isNotEmpty) {
          seed.value = match.first.seed;
          paletteName.value =
              (saved['paletteName'] as String?)?.isNotEmpty == true
              ? saved['paletteName'] as String
              : match.first.name;
        }
      }
    }
    if (_listening) return;
    _listening = true;
    mode.addListener(_persist);
    seed.addListener(_persist);
    paletteName.addListener(_persist);
  }

  /// Restores the active session's palette without leaking the previous
  /// session's values into the new namespace while notifiers are changing.
  static Future<void> reload() async {
    _suppressPersist = true;
    mode.value = ThemeMode.dark;
    seed.value = palettes.first.seed;
    paletteName.value = palettes.first.name;
    try {
      await ensureLoaded();
    } finally {
      _suppressPersist = false;
    }
  }

  static void _persist() {
    if (_suppressPersist) return;
    unawaited(
      LocalStore.instance.write(_storeKey, {
        'mode': mode.value.name,
        'seed': seed.value.toARGB32(),
        'paletteName': paletteName.value,
      }),
    );
  }

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
