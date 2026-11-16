import 'package:flutter/material.dart';

import '../theme/symbols.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'buttons.dart';
import 'headers.dart' show titleWidth;

/// The "back to now" pill: a small accent [Pill] with a calendar icon that
/// takes you back to the current period ("This month", "Today", "This year").
///
/// Show it with [visible] true while the view is off the current period. It
/// fades and scales in over 200 ms and fades out again when [visible] turns
/// false; once gone it takes no room and is not in the tree, so it never
/// shifts anything. While it fades out it can no longer be tapped and screen
/// readers skip it.
///
/// [semanticLabel] is what a screen reader says ("Back to this month").
/// The pill is 32 px high; place it in free space, e.g. at the right of a
/// screen header, or hang it over a card's edge with [NowPillOverCard].
class NowPill extends StatefulWidget {
  const NowPill({
    super.key,
    required this.visible,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.ringColor,
  });

  final bool visible;

  /// The short text on the pill: "This month", "Today".
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  /// A [ringWidth] ring of this colour around the pill, to set it apart from
  /// a fill of its own colour behind it (Home's turquoise month card). The
  /// ring is outside the pill's 32 px.
  final Color? ringColor;

  /// Width of the [ringColor] ring.
  static const double ringWidth = 2;

  /// How long the pill takes to appear and to go.
  static const Duration duration = Duration(milliseconds: 200);

  /// The pill's height.
  static const double height = 32;

  /// The width a pill that says [label] takes at the current text size: its
  /// 14 px of padding each side, the 16 px icon, 6 px, and the label (the
  /// pill is an accent [Pill], so the label is w800). A screen header uses it
  /// to keep its own text clear of the pill, whether or not it is showing.
  static double widthFor(BuildContext context, String label) =>
      14 +
      16 +
      6 +
      titleWidth(
        context,
        label,
        AppText.pill.copyWith(fontWeight: FontWeight.w800),
      ) +
      14;

  @override
  State<NowPill> createState() => _NowPillState();
}

class _NowPillState extends State<NowPill> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NowPill.duration,
    value: widget.visible ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.8,
    end: 1,
  ).animate(_curve);

  // The words stay as they were while the pill fades out, even when the
  // screen has already moved on to another period ("This week" going away
  // while the Month tab opens).
  late String _label = widget.label;
  late String _semanticLabel = widget.semanticLabel;

  @override
  void didUpdateWidget(NowPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _label = widget.label;
      _semanticLabel = widget.semanticLabel;
    }
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _ring(Widget pill) {
    final ring = widget.ringColor;
    if (ring == null) return pill;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ring,
        borderRadius: BorderRadius.circular(
          NowPill.height / 2 + NowPill.ringWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NowPill.ringWidth),
        child: pill,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // The last tick of the fade-out reports value 0 before the status
        // flips to dismissed, so the value is what to look at.
        if (!widget.visible && _controller.value == 0) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          ignoring: !widget.visible,
          child: ExcludeSemantics(
            excluding: !widget.visible,
            child: FadeTransition(
              opacity: _curve,
              child: ScaleTransition(
                scale: _scale,
                child: _ring(
                  Semantics(
                    button: true,
                    label: _semanticLabel,
                    onTap: widget.onTap,
                    excludeSemantics: true,
                    child: Pill(
                      label: _label,
                      onTap: widget.onTap,
                      tone: PillTone.accent,
                      height: NowPill.height,
                      leading: Icon(
                        Symbols.calendar_month_rounded,
                        size: 16,
                        color: c.onFill,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A pop-up card with a [NowPill] hanging over the right end of its top
/// edge, mostly above the card, clear of the heading under it.
///
/// The card keeps its place: the room the pill needs is added above and
/// below it in equal measure, so the pop-up stays centred as before.
class NowPillOverCard extends StatelessWidget {
  const NowPillOverCard({super.key, required this.pill, required this.child});

  /// The room above (and, to keep the card centred, below) the card.
  static const double hang = 26;

  final NowPill pill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: hang),
          child: child,
        ),
        Positioned(top: hang - NowPill.height / 2 - 6, right: 16, child: pill),
      ],
    );
  }
}
