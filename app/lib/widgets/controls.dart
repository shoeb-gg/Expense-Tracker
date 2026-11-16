import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// One segment of an [AppSegmented].
class Segment<T> {
  const Segment(this.value, this.label);

  final T value;
  final String label;
}

enum SegmentedSize {
  /// 40 px track (padding 4, radius 14, gap 4), 32 px segments (radius 10),
  /// 13.5/20 labels. Charts time range, Export, Import, Custom range.
  regular,

  /// 36 px track (padding 3, radius 12, gap 2), 30 px segments (radius 9),
  /// 12.5/16 labels. Settings Theme, Reports year, Category sort.
  compact,
}

/// Segmented control: the selected segment is solid `accent` with
/// `onAccent` w800 text; the others are transparent with `text2` w600.
///
/// [trackColor] is one step away from the container: `surface` on a
/// `surface2` band or the page, `bg` on a `surface` card (default `surface`).
/// [segmentWidth] null stretches the segments to fill the width; a number
/// gives fixed-width segments (e.g. 64 for Settings Theme).
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.size = SegmentedSize.regular,
    this.trackColor,
    this.segmentWidth,
    this.fontSize,
    this.tabular = false,
  });

  final List<Segment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final SegmentedSize size;
  final Color? trackColor;
  final double? segmentWidth;

  /// Overrides the label size (Reports year uses 13).
  final double? fontSize;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final regular = size == SegmentedSize.regular;
    final trackH = regular ? 40.0 : 36.0;
    final pad = regular ? 4.0 : 3.0;
    final gap = regular ? 4.0 : 2.0;
    final segH = regular ? 32.0 : 30.0;
    final segR = regular ? 10.0 : 9.0;
    final base = regular ? AppText.segment : AppText.segmentSmall;
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final on = s.value == value;
      var style = base.copyWith(
        color: on ? c.onAccent : c.text2,
        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
        fontSize: fontSize,
      );
      if (tabular) style = AppText.tabular(style);
      final seg = SizedBox(
        height: segH,
        width: segmentWidth,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: on ? c.accent : c.accent.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(segR),
          ),
          child: Pressable(
            onTap: () => onChanged(s.value),
            selected: on,
            borderRadius: BorderRadius.circular(segR),
            // A label wider than the segment less 6 px each side (the bold
            // one of the chosen segment, in large text) scales down a little
            // instead of touching the edges.
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(s.label, maxLines: 1, softWrap: false, style: style),
                ),
              ),
            ),
          ),
        ),
      );
      if (i > 0) children.add(SizedBox(width: gap));
      children.add(segmentWidth == null ? Expanded(child: seg) : seg);
    }
    return Container(
      height: trackH,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: trackColor ?? c.surface,
        borderRadius: BorderRadius.circular(regular ? 14 : 12),
      ),
      child: Row(
        mainAxisSize: segmentWidth == null ? MainAxisSize.max : MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// The 48 x 28 switch of Settings. On: accent track, onAccent knob at
/// x 23. Off: mix(text3, surface, 0.4) track, white knob at x 3.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const duration = Duration(milliseconds: 150);
    return Semantics(
      toggled: value,
      label: semanticLabel,
      enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: duration,
          width: 48,
          height: 28,
          decoration: BoxDecoration(
            color: value ? c.accent : c.switchOff,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOut,
                top: 3,
                left: value ? 23 : 3,
                child: AnimatedContainer(
                  duration: duration,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? c.onAccent : c.thumb,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
