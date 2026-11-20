import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'theme_controller.dart';

/// Semantic colour roles used by the custom UI.
///
/// Every role is derived from the *current* seeded Material 3 [ColorScheme],
/// so changing the Auto palette updates the custom screens together with the
/// global theme, and both light and dark modes stay harmonious.
class AppColors {
  static ColorScheme get _scheme => AppTheme.colorScheme(
    ThemeController.isDark ? Brightness.dark : Brightness.light,
  );

  static bool get _isDark => ThemeController.isDark;

  /// The original brand seed, kept as a stable reference.
  static const Color seed = Color(0xFFFF6B00);

  // Surfaces (Material 3 tonal surface roles)
  static Color get background => _scheme.surface;
  static Color get surface => _scheme.surface;
  static Color get cardSurface => _scheme.surfaceContainer;
  static Color get surfaceLow => _scheme.surfaceContainerLow;
  static Color get surfaceHigh => _scheme.surfaceContainerHighest;
  static Color get cardInset => _scheme.surfaceContainerHigh;
  static Color get border => _scheme.outlineVariant;

  // Brand (primary) roles, derived from the active seed
  static Color get primaryOrange => _scheme.primary;
  static Color get orangeDark => _scheme.primaryContainer;
  static Color get orangeSoft =>
      _scheme.primary.withValues(alpha: _isDark ? 0.20 : 0.10);
  static Color get orangeBorder => _scheme.primary.withValues(alpha: 0.4);
  static Color get orangeFade =>
      _scheme.primary.withValues(alpha: _isDark ? 0.04 : 0.05);
  static Color get onPrimary => _scheme.onPrimary;

  // Text (on-surface roles)
  static Color get textWhite => _scheme.onSurface;
  static Color get textLight => _scheme.onSurface;
  static Color get textSlate => _scheme.onSurfaceVariant;
  static Color get textMuted =>
      _scheme.onSurfaceVariant.withValues(alpha: 0.78);

  // Status / chart accents (secondary + tertiary + error keep them on-palette)
  static Color get emerald => _scheme.tertiary;
  static Color get amber => _scheme.secondary;
  static Color get rose => _scheme.error;
}
