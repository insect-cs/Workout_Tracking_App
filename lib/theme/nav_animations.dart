import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'nav_icon_art.dart';

/// Semantic animations for the seven navigation icons. Each destination gets
/// its own drawn glyph and motion instead of a shared generic icon.
enum NavIconAnimation {
  homeHop,
  planFlip,
  calorieFlicker,
  generateSparkle,
  savedDrop,
  loggerTick,
  poseWiggle,
}

Duration navIconDuration(NavIconAnimation animation) {
  switch (animation) {
    case NavIconAnimation.homeHop:
      return const Duration(milliseconds: 900);
    case NavIconAnimation.planFlip:
      return const Duration(milliseconds: 700);
    case NavIconAnimation.calorieFlicker:
      return const Duration(milliseconds: 820);
    case NavIconAnimation.generateSparkle:
      return const Duration(milliseconds: 980);
    case NavIconAnimation.savedDrop:
      return const Duration(milliseconds: 780);
    case NavIconAnimation.loggerTick:
      return const Duration(milliseconds: 860);
    case NavIconAnimation.poseWiggle:
      return const Duration(milliseconds: 840);
  }
}

/// A press event carries the tapped index plus a sequence number, so tapping
/// the same tab twice always fires the animation again.
class NavPressEvent {
  const NavPressEvent(this.index, this.sequence);

  final int index;
  final int sequence;
}

/// Wraps one navigation glyph and replays its own animation whenever its tab
/// is pressed.
class AnimatedNavIcon extends StatefulWidget {
  const AnimatedNavIcon({
    super.key,
    required this.index,
    required this.animation,
    required this.pressEvent,
    this.selected = false,
  });

  final int index;
  final NavIconAnimation animation;
  final ValueListenable<NavPressEvent> pressEvent;
  final bool selected;

  @override
  State<AnimatedNavIcon> createState() => _AnimatedNavIconState();
}

class _AnimatedNavIconState extends State<AnimatedNavIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: navIconDuration(widget.animation),
    );
    widget.pressEvent.addListener(_handlePress);
  }

  @override
  void didUpdateWidget(covariant AnimatedNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressEvent != widget.pressEvent) {
      oldWidget.pressEvent.removeListener(_handlePress);
      widget.pressEvent.addListener(_handlePress);
    }
    if (oldWidget.animation != widget.animation) {
      _controller.duration = navIconDuration(widget.animation);
    }
  }

  @override
  void dispose() {
    widget.pressEvent.removeListener(_handlePress);
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() {
    if (widget.pressEvent.value.index != widget.index) return;
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final color = widget.selected
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant;
        return SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: NavIconArtPainter(
              animation: widget.animation,
              progress: _controller.value,
              color: color,
            ),
          ),
        );
      },
    );
  }
}
