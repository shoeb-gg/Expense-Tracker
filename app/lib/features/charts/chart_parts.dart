import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'ring_chart.dart';

/// Text styles shared by the Charts and Category screens (mockup sizes).
abstract final class ChartText {
  /// "Total spent", "Daily average": 12.5/16 w500 text3.
  static TextStyle label(AppColors c) => AppText.sub.copyWith(color: c.text3);

  /// The big total: 32/40 w800 -0.6.
  static final TextStyle total = AppText.heroNumber.copyWith(
    height: 40 / 32,
    letterSpacing: -0.6,
    fontFeatures: const <FontFeature>[],
  );

  /// The average and entries next to the total: 18/24 w700.
  static final TextStyle stat = AppText.bodyStrong.copyWith(
    fontSize: 18,
    height: 24 / 18,
  );

  /// "Daily spending": 14/20 w800.
  static final TextStyle chartTitle =
      AppText.bodyStrong.copyWith(fontWeight: FontWeight.w800);

  /// "Dashed line = average 363": 12/16 w500 text3, tabular.
  static TextStyle key(AppColors c) =>
      AppText.tabular(AppText.caption.copyWith(color: c.text3));

  /// The hint under a chart: 12/16 w500 text3.
  static TextStyle hint(AppColors c) => AppText.caption.copyWith(color: c.text3);

  /// A share or percentage in a list: 12.5/16 w600 text2, tabular.
  static TextStyle share(AppColors c) =>
      AppText.tabular(AppText.overline.copyWith(color: c.text2));
}

/// The hint under a column chart that has nothing to show yet.
String emptyColumnsHint({required bool byMonth}) => byMonth
    ? 'Each month you spend in gets a column.'
    : 'Each day you spend gets a column.';

/// A surface card with the mockup's 20 px radius.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => CardEdge(
        radius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// The heading of a column-chart card: "Daily spending" over the key line.
class ChartHeading extends StatelessWidget {
  const ChartHeading({super.key, required this.title, required this.keyLine});

  final String title;
  final String keyLine;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ChartText.chartTitle),
          const SizedBox(height: 2),
          Text(keyLine, style: ChartText.key(c)),
        ],
      ),
    );
  }
}

/// A list row's comparison bar: a 6 px track with a fill of [fraction]
/// (at least 6 px wide).
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth * fraction.clamp(0.0, 1.0))
              .clamp(6.0, box.maxWidth)
              .toDouble();
          return Container(
            height: 6,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: context.colors.track,
              borderRadius: BorderRadius.circular(3),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: w,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        },
      );
}

/// The "Details" pill (opens the category drill-down): in the ring centre,
/// and on the selected row of the ranked list.
class DetailsPill extends StatelessWidget {
  const DetailsPill({
    super.key,
    required this.onTap,
    this.semanticLabel = 'Details',
  });

  final VoidCallback onTap;

  /// What a screen reader says ("Details of Health" on a row, where the
  /// ring centre has its own plain "Details").
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Its own semantics node, so a screen reader can reach it on a row that
    // is itself a button, and says one label for it.
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: semanticLabel,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(12),
        button: false,
        child: SizedBox(
          height: 24,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Details',
                  style: AppText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
                Icon(Symbols.chevron_right_rounded, size: 16, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring centre: a title, the amount and a line under it, plus an
/// optional Details pill.
///
/// It sits in the box in the middle of the ring ([RingChart] centres it).
/// Each of the three lines is as wide as the hole of the ring is at that
/// height (the chord of the inner circle at the line's far edge, and no wider
/// than the box). A line that needs more, a big amount or large text, is drawn
/// in a smaller font until it fits, never cut. The title (a category's name)
/// shrinks to 75% of its size at most: a name that needs less stays at 75% and
/// ends in "..." on its one line. A line that fits is a plain text where it
/// always was; the lines keep their places whatever their size.
class RingCenter extends StatelessWidget {
  const RingCenter({
    super.key,
    required this.title,
    required this.value,
    required this.sub,
    this.onDetails,
  });

  final String title;
  final String value;
  final String sub;
  final VoidCallback? onDetails;

  /// Space between the three lines.
  static const double _gap = 2;

  /// The smallest the title is drawn, as a share of its size.
  static const double _titleFloor = 0.75;

  /// Space between the lines and the Details pill, and the pill's height.
  static const double _pillGap = 6;
  static const double _pillHeight = 24;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final titleStyle = AppText.overline.copyWith(color: c.text2);
    final valueStyle = AppText.heroNumber.copyWith(
      fontSize: 24,
      height: 30 / 24,
      letterSpacing: -0.4,
      fontFeatures: const <FontFeature>[],
    );
    final subStyle = AppText.caption.copyWith(color: c.text3);
    final heights = [
      for (final style in [titleStyle, valueStyle, subStyle])
        titleHeight(context, style),
    ];
    final hasPill = onDetails != null;

    return LayoutBuilder(
      builder: (context, box) {
        // Where the lines sit: the column is centred in the box, and the
        // middle of the box is the middle of the ring.
        final total = heights.fold<double>(0, (a, h) => a + h) +
            2 * _gap +
            (hasPill ? _pillGap + _pillHeight : 0);
        final middle = box.maxHeight / 2;
        var top = (box.maxHeight - total) / 2;
        final rooms = <double>[];
        for (final h in heights) {
          rooms.add(math.min(_holeWidth(top - middle, top + h - middle), box.maxWidth));
          top += h + _gap;
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _line(
                    title,
                    titleStyle,
                    heights[0],
                    rooms[0],
                    TextAlign.center,
                    _titleFloor,
                  ),
                  const SizedBox(height: _gap),
                  _line(value, valueStyle, heights[1], rooms[1], TextAlign.start, 0),
                  const SizedBox(height: _gap),
                  _line(sub, subStyle, heights[2], rooms[2], TextAlign.start, 0),
                ],
              ),
            ),
            if (hasPill) ...[
              const SizedBox(height: _pillGap),
              DetailsPill(onTap: onDetails!),
            ],
          ],
        );
      },
    );
  }

  /// One line in a slot of its own height, [room] wide at most. The slot
  /// keeps the line where it is when the text inside it is drawn smaller.
  /// [align] is how each line was aligned before it fitted itself: it makes
  /// no difference to where a plain text is, but keeps its pixels the same.
  static Widget _line(
    String text,
    TextStyle style,
    double height,
    double room,
    TextAlign align,
    double minScale,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: room),
      child: SizedBox(
        height: height,
        child: Center(
          child: FitTitle(
            text,
            style: style,
            resizeFont: true,
            textAlign: align,
            minScale: minScale,
          ),
        ),
      ),
    );
  }

  /// The widest a line between [from] and [to] (px below the middle of the
  /// ring, negative above) can be and still have its corners in the hole: the
  /// chord of the inner circle at the edge that is further from the middle.
  static double _holeWidth(double from, double to) {
    final far = math.max(from.abs(), to.abs());
    const radius = RingChart.inner;
    if (far >= radius) return 0;
    return 2 * math.sqrt(radius * radius - far * far);
  }
}

/// The text shown in a card body when there is nothing to list.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: AppText.body.copyWith(color: context.colors.text3),
        ),
      );
}
