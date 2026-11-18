import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/main.dart';

void main() {
  testWidgets('app boots on Home and tab navigation works', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorkoutTrackingApp());
    await tester.pumpAndSettle();

    expect(find.text('Exercise Catalog'), findsOneWidget,
        reason: 'Home screen should render');
    expect(find.byType(NavigationBar), findsOneWidget);

    final tabs = <String, int>{
      'Generate': 1,
      'Saved': 2,
      'Logger': 3,
      'Pose': 4,
      'Home': 0,
    };

    for (final entry in tabs.entries) {
      final label = entry.key;
      final finder = find.widgetWithText(NavigationDestination, label);
      expect(finder, findsOneWidget, reason: 'Missing nav destination $label');
      await tester.tap(finder);
      if (label == 'Pose') {
        // Pose screen has a repeating pulse animation, so pumpAndSettle never
        // completes; a few bounded frames are enough to verify the route.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      } else {
        await tester.pumpAndSettle();
      }

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is NavigationBar && widget.selectedIndex == entry.value,
        ),
        findsOneWidget,
        reason: '$label should be the selected navigation destination',
      );
    }

    expect(find.text('Exercise Catalog'), findsOneWidget,
        reason: 'Home should render after tab round-trip');
  });
}
