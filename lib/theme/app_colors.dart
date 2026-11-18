import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// Material 3 (vibrant scheme) tonal palette used across the app.
///
/// Every role resolves against the active [ThemeController] mode, so the
/// custom dark UI and the new light mode keep the same tonal relationships as
/// the global [AppTheme] color scheme.
class AppColors {
  /// Brand seed. Everything else is derived from this orange.
  static const Color seed = Color(0xFFFF6B00);

  // Surfaces (Material 3 tonal surface roles)
  static Color get background => _isDark
      ? const Color(0xFF1D100A) // surface
      : const Color(0xFFFFF8F3);

  static Color get surface => _isDark
      ? const Color(0xFF1D100A)
      : const Color(0xFFFFF8F3);

  static Color get cardSurface => _isDark
      ? const Color(0xFF2B1C15) // surfaceContainer
      : const Color(0xFFFFEDE1);

  static Color get surfaceLow => _isDark
      ? const Color(0xFF241710) // surfaceContainerLow
      : const Color(0xFFFFF1E8);

  static Color get surfaceHigh => _isDark
      ? const Color(0xFF413128) // surfaceContainerHighest
      : const Color(0xFFF3DFD3);

  static Color get cardInset => _isDark
      ? const Color(0xFF1D1F27)
      : const Color(0xFFEDE7F6);

  static Color get border => _isDark
      ? const Color(0xFF53433B) // outlineVariant
      : const Color(0xFFE3C7B7);

  // Primary (orange) roles
  static Color get primaryOrange => _isDark
      ? const Color(0xFFFFB693) // primary
      : const Color(0xFF8C4100);

  static Color get orangeDark => _isDark
      ? const Color(0xFF7A3000) // primaryContainer
      : const Color(0xFFFFDBAF);

  static Color get orangeSoft => _isDark
      ? const Color(0x33FFB693) // primary @ 20%
      : const Color(0x1A8C4100);

  static Color get orangeBorder => _isDark
      ? const Color(0x66FFB693) // primary @ 40%
      : const Color(0x668C4100);

  static Color get orangeFade => _isDark
      ? const Color(0x0AFF6B00)
      : const Color(0x0D8C4100);

  static Color get onPrimary => _isDark
      ? const Color(0xFF561F00)
      : const Color(0xFFFFFFFF);

  // Text (on-surface roles)
  static Color get textWhite => _isDark
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF1D100A);

  static Color get textLight => _isDark
      ? const Color(0xFFF8DDD2) // onSurface
      : const Color(0xFF3B2418);

  static Color get textSlate => _isDark
      ? const Color(0xFFC9B0A4) // onSurfaceVariant
      : const Color(0xFF6E5448);

  static Color get textMuted => _isDark
      ? const Color(0xFF9C8379)
      : const Color(0xFF8C7267);

  // Status / chart accents
  static Color get emerald => _isDark
      ? const Color(0xFF7DDC9A)
      : const Color(0xFF1B6E3C);

  static Color get amber => _isDark
      ? const Color(0xFFFFD887)
      : const Color(0xFF8A5A00);

  static Color get rose => _isDark
      ? const Color(0xFFFFB4AB) // error
      : const Color(0xFFB3261E);

  static bool get _isDark => ThemeController.isDark;
}
