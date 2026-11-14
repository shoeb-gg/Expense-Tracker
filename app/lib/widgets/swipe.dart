import 'package:flutter/material.dart';

/// A swipe found by [SwipeArea].
class SwipeEvent {
  const SwipeEvent({required this.next, required this.axis});

  /// True: show the NEXT month/year (finger moved right-to-left or
  /// bottom-to-top). False: show the PREVIOUS one (finger moved
  /// left-to-right or top-to-bottom).
  final bool next;

  /// The axis the finger mostly moved along (for the slide animation).
  final Axis axis;
}

/// Turns a drag across [child] into previous/next, the rule of BUILD_LIST
/// "Swipe to change the month": dragging the finger left-to-right or
/// top-to-bottom pulls the PREVIOUS one into view (it comes in from the left
/// or from above); right-to-left or bottom-to-top pulls the NEXT one in.
/// A move shorter than [threshold] (24 px) is not a swipe.
///
/// A swipe never also picks a day: taps inside check
/// [SwipeArea.swipedRecently] (true when the gesture that just ended was a
/// swipe, until the next finger down). Flutter's tap recogniser also gives up
/// once the finger moves more than 18 px.
class SwipeArea extends StatefulWidget {
  const SwipeArea({
    super.key,
    required this.child,
    required this.onSwipe,
    this.threshold = 24,
  });

  final Widget child;
  final ValueChanged<SwipeEvent> onSwipe;
  final double threshold;

  /// Whether the gesture that just ended in the nearest [SwipeArea] above
  /// [context] was a swipe (ignore the tap it would otherwise make).
  static bool swipedRecently(BuildContext context) =>
      context.findAncestorStateOfType<_SwipeAreaState>()?._swiped ?? false;

  @override
  State<SwipeArea> createState() => _SwipeAreaState();
}

class _SwipeAreaState extends State<SwipeArea> {
  Offset? _down;
  int? _pointer;
  bool _swiped = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        _down = e.position;
        _swiped = false;
      },
      onPointerCancel: (e) {
        if (e.pointer != _pointer) return;
        _pointer = null;
        _down = null;
      },
      onPointerUp: (e) {
        if (e.pointer != _pointer) return;
        final start = _down;
        _pointer = null;
        _down = null;
        if (start == null) return;
        final dx = e.position.dx - start.dx;
        final dy = e.position.dy - start.dy;
        final horizontal = dx.abs() > dy.abs();
        final far = horizontal ? dx : dy;
        if (far.abs() < widget.threshold) return;
        _swiped = true;
        widget.onSwipe(
          SwipeEvent(
            next: far < 0,
            axis: horizontal ? Axis.horizontal : Axis.vertical,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Slides between pages when [pageKey] changes: the new page comes in from
/// the right/below when [forward], from the left/above otherwise, along
/// [axis]. Clips to its own box.
class SlideSwitcher extends StatelessWidget {
  const SlideSwitcher({
    super.key,
    required this.pageKey,
    required this.forward,
    required this.child,
    this.axis = Axis.horizontal,
    this.duration = const Duration(milliseconds: 220),
  });

  final Object pageKey;
  final bool forward;
  final Axis axis;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey<Object>(pageKey);
    final sign = forward ? 1.0 : -1.0;
    final enterFrom = axis == Axis.horizontal
        ? Offset(0.3 * sign, 0)
        : Offset(0, 0.3 * sign);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == key;
          final begin = incoming ? enterFrom : -enterFrom;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: begin, end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: key, child: child),
      ),
    );
  }
}
