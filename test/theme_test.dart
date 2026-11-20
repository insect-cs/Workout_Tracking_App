import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/screens/home_screen.dart';
import 'package:workout_app/services/local_store.dart';
import 'package:workout_app/state/workout_state.dart';
import 'package:workout_app/theme/app_theme.dart';
import 'package:workout_app/theme/theme_controller.dart';

double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) * 2.4;
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final light = l1 > l2 ? l1 : l2;
  final dark = l1 > l2 ? l2 : l1;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  setUp(() async {
    await LocalStore.instance.resetForTesting();
    ThemeController.mode.value = ThemeMode.dark;
    ThemeController.seed.value = ThemeController.palettes.first.seed;
    ThemeController.paletteName.value = ThemeController.palettes.first.name;
  });

  test('auto palette cycles through every curated scheme', () {
    final names = ThemeController.palettes.map((p) => p.name).toList();
    for (final name in names) {
      expect(ThemeController.paletteName.value, name);
      ThemeController.chooseNextPalette();
    }
    // Wraps back to the start.
    expect(ThemeController.paletteName.value, names.first);
    expect(ThemeController.seed.value, ThemeController.palettes.first.seed);
  });

  test('every palette blends with both light and dark mode', () {
    for (final brightness in Brightness.values) {
      for (final palette in ThemeController.palettes) {
        ThemeController.seed.value = palette.seed;
        final scheme = AppTheme.colorScheme(brightness);

        expect(scheme.brightness, brightness, reason: palette.name);
        expect(
          _contrast(scheme.onSurface, scheme.surface),
          greaterThan(4.5),
          reason: '${palette.name} $brightness onSurface/surface',
        );
        expect(
          _contrast(scheme.onPrimary, scheme.primary),
          greaterThan(2.5),
          reason: '${palette.name} $brightness onPrimary/primary',
        );
        expect(
          _contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThan(2.5),
          reason: '${palette.name} $brightness nav label/indicator',
        );
        expect(
          scheme.primary,
          isNot(scheme.surface),
          reason: '${palette.name} $brightness primary/surface',
        );
      }
    }
  });

  testWidgets('the Home palette button changes the active scheme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: HomeScreen(
          state: WorkoutState(),
          onTabChange: (_) {},
          onNavigateToInput: (_) {},
          onOpenDiet: () {},
          onOpenKeys: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = ThemeController.paletteName.value;
    expect(find.byTooltip('Auto color scheme'), findsOneWidget);

    await tester.tap(find.byTooltip('Auto color scheme'));
    await tester.pumpAndSettle();

    expect(ThemeController.paletteName.value, isNot(before));
    expect(
      find.text('Palette: ${ThemeController.paletteName.value}'),
      findsOneWidget,
    );
  });
}
