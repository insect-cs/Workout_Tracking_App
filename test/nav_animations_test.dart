import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/theme/nav_animations.dart';
import 'package:workout_app/theme/nav_icon_art.dart';

void main() {
  test('Home chimney rises upward then disappears', () {
    expect(chimneyRise(0), 0);
    expect(chimneyRise(0.5), lessThan(0));
    expect(chimneyRise(1), closeTo(0, 1e-9));
    expect(chimneyOpacity(0), closeTo(0, 1e-9));
    expect(chimneyOpacity(0.45), greaterThan(0.9));
    expect(chimneyOpacity(1), 0);
  });

  test('Plan calendar performs a full page turn', () {
    expect(calendarFlipAngle(0), 0);
    expect(calendarFlipAngle(0.25), closeTo(1.5708, 0.001));
    expect(calendarFlipAngle(1), closeTo(2 * 3.14159, 0.01));
  });

  test('Calories flame sways and stretches repeatedly', () {
    final samples = List.generate(9, (i) => flameSway(i / 8));
    var signChanges = 0;
    for (var i = 1; i < samples.length; i++) {
      if (samples[i] * samples[i - 1] < 0) signChanges++;
    }
    expect(signChanges, greaterThanOrEqualTo(2));
    expect(flameStretch(1 / 12), greaterThan(1));
    expect(flameStretch(1), closeTo(1, 1e-9));
  });

  test('Generate stars fade out then reappear one by one', () {
    // At the midpoint all outer stars are hidden.
    for (var i = 0; i < 4; i++) {
      expect(starOpacity(0.4, i), 0, reason: 'star $i');
    }
    // They come back in index order.
    expect(starOpacity(0.5, 0), greaterThan(0));
    expect(starOpacity(0.5, 3), 0);
    expect(starOpacity(0.95, 3), greaterThan(0.9));
    expect(starOpacity(0, 0), 1);
    expect(starOpacity(1, 3), 1);
  });

  test('Saved bookmark goes up then returns from below', () {
    expect(bookmarkOffset(0), 0);
    expect(bookmarkOffset(0.16), lessThan(0));
    expect(bookmarkOffset(0.6), greaterThan(0));
    expect(bookmarkOffset(1), closeTo(0, 1e-9));
  });

  test('Logger hand starts at 12 and comes back to 12', () {
    expect(stopwatchHandAngle(0), closeTo(0, 1e-9));
    expect(stopwatchHandAngle(0.5).abs(), greaterThan(4));
    expect(stopwatchHandAngle(1), closeTo(0, 1e-9));
  });

  test('Pose hand swings sideways and returns to rest', () {
    final rest = poseHandAngle(0);
    expect(rest, greaterThan(0.5));
    expect(poseHandAngle(0.5), closeTo(0, 1e-9));
    expect(poseHandAngle(1), closeTo(rest, 1e-9));
  });

  test('animations repaint when progress or colour changes', () {
    const first = NavIconArtPainter(
      animation: NavIconAnimation.homeHop,
      progress: 0.2,
      color: Colors.red,
    );
    const same = NavIconArtPainter(
      animation: NavIconAnimation.homeHop,
      progress: 0.2,
      color: Colors.red,
    );
    const moved = NavIconArtPainter(
      animation: NavIconAnimation.homeHop,
      progress: 0.4,
      color: Colors.red,
    );
    const recoloured = NavIconArtPainter(
      animation: NavIconAnimation.homeHop,
      progress: 0.2,
      color: Colors.blue,
    );

    expect(first.shouldRepaint(same), isFalse);
    expect(first.shouldRepaint(moved), isTrue);
    expect(first.shouldRepaint(recoloured), isTrue);
  });

  test('every destination has a distinct motion duration', () {
    final durations = NavIconAnimation.values.map(navIconDuration).toSet();
    expect(durations.length, NavIconAnimation.values.length);
    for (final duration in durations) {
      expect(duration.inMilliseconds, greaterThanOrEqualTo(600));
      expect(duration.inMilliseconds, lessThanOrEqualTo(1200));
    }
  });

  testWidgets('press events replay only their own icon', (tester) async {
    final events = ValueNotifier<NavPressEvent>(const NavPressEvent(-1, 0));
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            AnimatedNavIcon(
              index: 0,
              animation: NavIconAnimation.homeHop,
              pressEvent: events,
            ),
            AnimatedNavIcon(
              index: 2,
              animation: NavIconAnimation.calorieFlicker,
              pressEvent: events,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    events.value = const NavPressEvent(2, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // A mismatched event must be ignored and matching events are safe to fire
    // repeatedly (sequence number forces a new event object).
    events.value = const NavPressEvent(9, 2);
    await tester.pumpAndSettle();
    events.value = const NavPressEvent(2, 3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    events.dispose();
  });
}
