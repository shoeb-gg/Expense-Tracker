import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'reports_logic.dart';
import 'reports_screen.dart';

/// Card 2, "Year at a glance": the year switch, the selected month with
/// its change from the month before, the column chart and its key.
class YearCard extends ConsumerWidget {
  const YearCard({
    super.key,
    required this.years,
    required this.year,
    required this.months,
    required this.selected,
    required this.previous,
    required this.onYear,
    required this.onMonth,
  });

  final List<int> years;
  final int year;
  final List<MonthCell> months;
  final int selected;
  final int? Function(MonthCell) previous;
  final ValueChanged<int> onYear;
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final sel = months[selected - 1];
    final avg = fullMonthAverage(months);
    final delta = sel.partial ? null : deltaOf(sel.value, previous(sel));
    final prevName = monthName(selected == 1 ? 12 : selected - 1);
    final caption = AppText.caption.copyWith(color: c.text3);
    return BandCard(
      title: 'Year at a glance',
      bandHeight: BandCard.tallBand,
      trailing: _YearSwitch(years: years, year: year, onYear: onYear),
      bodyPadding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 46,
            child: LayoutBuilder(
              builder: (context, box) {
                final label =
                    '${monthName(selected)} $year${sel.partial ? ' (so far)' : ''}';
                final labelStyle = AppText.sub.copyWith(color: c.text3);
                final value = fmt.formatWhole(sel.value);
                String? pill;
                if (delta != null) {
                  final short = delta.trend == Trend.flat
                      ? 'Same'
                      : '${delta.percent}% ${delta.trend == Trend.down ? 'less' : 'more'}';
                  final long = delta.trend == Trend.flat
                      ? 'Same as $prevName'
                      : '$short than $prevName';
                  // Like the board, the pill keeps its full copy and the
                  // month label wraps ("December / 2025"). Only when even
                  // the amount (or one word of the label) cannot sit beside
                  // it (a huge amount, the largest text size) does the pill
                  // drop "than November".
                  final scaler = MediaQuery.textScalerOf(context);
                  final left = [
                    for (final word in label.split(' '))
                      _textWidth(word, labelStyle, scaler),
                    _textWidth(value, ReportText.big, scaler),
                  ].reduce((a, b) => a > b ? a : b);
                  final pillStyle = _DeltaPill.style(c, delta);
                  final need =
                      left +
                      8 +
                      _DeltaPill.chrome +
                      _textWidth(long, pillStyle, scaler);
                  pill = need <= box.maxWidth ? long : short;
                }
                // A two-line label makes the block taller than the 46 px
                // row; as on the board it stays centred and overflows the
                // row evenly into the card's padding and the gap below.
                return OverflowBox(
                  maxHeight: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, maxLines: 2, style: labelStyle),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              maxLines: 1,
                              softWrap: false,
                              style: ReportText.big,
                            ),
                          ],
                        ),
                      ),
                      if (delta != null && pill != null) ...[
                        const SizedBox(width: 8),
                        _DeltaPill(delta: delta, text: pill),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          YearChart(
            year: year,
            months: months,
            selected: selected,
            average: avg,
            onMonth: onMonth,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avg == null
                      ? 'No full month yet in $year'
                      : 'Dashed line = $year monthly average ${fmt.formatWhole(avg)}',
                  style: AppText.tabular(caption),
                ),
                if (months.any((m) => m.partial && m.value > 0)) ...[
                  const SizedBox(height: 4),
                  Text('Hollow column = month in progress', style: caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta, required this.text});

  final Delta delta;
  final String text;

  /// Width of everything but the text: padding 8 + 12, icon 18, gap 6.
  static const double chrome = 8 + 18 + 6 + 12;

  static TextStyle style(AppColors c, Delta delta) => AppText.sub.copyWith(
    fontWeight: FontWeight.w700,
    color: trendColor(c, delta.trend),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = trendColor(c, delta.trend);
    return Container(
      height: 28,
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon(delta.trend), size: 18, color: color),
          const SizedBox(width: 6),
          Text(text, maxLines: 1, style: style(c, delta)),
        ],
      ),
    );
  }
}

double _textWidth(String text, TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final w = painter.width;
  painter.dispose();
  return w;
}

/// The year switch: segments for up to three years, otherwise a button
/// that opens a list of years.
class _YearSwitch extends StatelessWidget {
  const _YearSwitch({
    required this.years,
    required this.year,
    required this.onYear,
  });

  final List<int> years;
  final int year;
  final ValueChanged<int> onYear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (years.length <= 3) {
      return AppSegmented<int>(
        size: SegmentedSize.compact,
        fontSize: 13,
        tabular: true,
        segmentWidth: years.length <= 2 ? 60 : 48,
        segments: [for (final y in years) Segment(y, '$y')],
        value: year,
        onChanged: onYear,
      );
    }
    return SizedBox(
      height: 36,
      child: Pressable(
        semanticLabel: 'Year $year. Tap to change',
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: edgeBorder(c),
        shadows: liftShadows(c),
        onTap: () async {
          final picked = await showOptionSheet<int>(
            context,
            title: 'Year to show',
            options: [
              for (final y in years.reversed)
                SheetOption(value: y, label: '$y', tabular: true),
            ],
            current: year,
          );
          if (picked != null) onYear(picked);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$year',
                style: AppText.tabular(
                  AppText.segmentSmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Symbols.expand_more_rounded, size: 20, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 296 x 186 column chart: 12 columns, gridlines with right-aligned
/// values, a dashed line for the average of the full months.
class YearChart extends ConsumerWidget {
  const YearChart({
    super.key,
    required this.year,
    required this.months,
    required this.selected,
    required this.average,
    required this.onMonth,
  });

  final int year;
  final List<MonthCell> months;
  final int selected;
  final int? average;
  final ValueChanged<int> onMonth;

  static const double height = 186;
  static const double padL = 34;
  static const double padR = 8;
  static const double padT = 20;
  static const double plotH = 140;
  static const double inset = 4;
  static const double barW = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    var maxV = 0.0;
    for (final m in months) {
      if (m.shown && m.value / 100 > maxV) maxV = m.value / 100;
    }
    // With nothing spent, the same placeholder scale as Charts' empty
    // "Over time" chart (0, 250, 500, 750, 1,000).
    final AxisScale scale = maxV > 0
        ? axisScale(maxV)
        : (step: 250, top: 1000);
    final compact = scale.top >= 10000;
    String tick(double v) {
      if (v == 0) return '0';
      if (compact) return compactAxisLabel(v, fmt);
      return fmt.group(v.round());
    }

    double y(double whole) => padT + plotH - whole / scale.top * plotH;
    final ticks = <double>[
      for (var v = 0.0; v <= scale.top + 1e-9; v += scale.step) v,
    ];
    // The average line stops where the month in progress (or the first
    // month still to come) begins.
    final open = months.indexWhere((m) => m.partial || m.future);
    final avgWhole = average == null ? null : average! / 100;
    final semantics = [
      for (final m in months)
        if (m.shown)
          '${monthShortName(m.month)} ${fmt.formatWhole(m.value)}${m.partial ? ' so far' : ''}',
    ].join(', ');
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final plotW = w - padL - padR;
        final slot = plotW / 12;
        return Semantics(
          label:
              'Column chart of monthly spending in $year. $semantics.'
              '${average == null ? '' : ' Average full month ${fmt.formatWhole(average!)}.'}',
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(
                      ticks: [for (final t in ticks) y(t)],
                      left: padL,
                      right: w,
                      line: c.line,
                      avgY: avgWhole == null || avgWhole == 0
                          ? null
                          : y(avgWhole),
                      avgEnd: open < 0 ? w : padL + inset + open * slot,
                      avgColor: c.text2,
                    ),
                  ),
                ),
                for (final t in ticks)
                  Positioned(
                    left: 0,
                    width: 28,
                    top: y(t) - 7,
                    // A value wider than the 28 px (1500K) scales down to it.
                    child: ExcludeSemantics(
                      child: FitTitle(
                        tick(t),
                        textAlign: TextAlign.right,
                        style: AppText.tabular(
                          AppText.caption.copyWith(
                            fontSize: 10.5,
                            height: 14 / 10.5,
                            color: c.text3,
                          ),
                        ),
                      ),
                    ),
                  ),
                for (final m in months)
                  Positioned(
                    left: padL + inset + (m.month - 1) * slot,
                    top: 0,
                    width: slot,
                    height: height,
                    child: _Column(
                      cell: m,
                      selected: m.month == selected,
                      barHeight: m.future
                          ? 3
                          : m.value == 0
                          ? 0
                          : (m.value / 100 / scale.top * plotH).clamp(2, plotH),
                      onTap: m.shown ? () => onMonth(m.month) : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.cell,
    required this.selected,
    required this.barHeight,
    required this.onTap,
  });

  final MonthCell cell;
  final bool selected;
  final double barHeight;
  final VoidCallback? onTap;

  static const String letters = 'JFMAMJJASOND';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final BoxDecoration bar;
    if (cell.future) {
      bar = BoxDecoration(
        color: c.stub,
        borderRadius: BorderRadius.circular(1.5),
      );
    } else if (cell.partial) {
      bar = BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        border: Border.all(color: selected ? c.accent : c.barSoft, width: 1.5),
      );
    } else {
      bar = BoxDecoration(
        color: selected ? c.accent : c.barSoft,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      );
    }
    final letterColor = selected
        ? c.onAccent
        : cell.shown
        ? c.text3
        : c.dim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: onTap != null,
        selected: selected,
        label: cell.future
            ? '${monthName(cell.month)} ${cell.year}, no data yet'
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (barHeight > 0)
              Positioned(
                bottom: 26,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: YearChart.barW,
                    height: barHeight,
                    decoration: bar,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 3,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  decoration: BoxDecoration(
                    color: selected ? c.accent : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Align(
                    widthFactor: 1,
                    child: Text(
                      letters[cell.month - 1],
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                        fontSize: 10.5,
                        height: 16 / 10.5,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: letterColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.ticks,
    required this.left,
    required this.right,
    required this.line,
    required this.avgY,
    required this.avgEnd,
    required this.avgColor,
  });

  final List<double> ticks;
  final double left;
  final double right;
  final Color line;
  final double? avgY;
  final double avgEnd;
  final Color avgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (final t in ticks) {
      final y = t.roundToDouble() + 0.5;
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
    }
    final a = avgY;
    if (a != null) {
      final paint = Paint()
        ..color = avgColor
        ..strokeWidth = 1.5;
      final y = a.roundToDouble() + 0.5;
      for (var x = left; x < avgEnd; x += 9) {
        final end = x + 5 < avgEnd ? x + 5 : avgEnd;
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.ticks.length != ticks.length ||
      old.avgY != avgY ||
      old.avgEnd != avgEnd ||
      old.line != line ||
      old.avgColor != avgColor ||
      old.right != right ||
      (old.ticks.isNotEmpty &&
          ticks.isNotEmpty &&
          old.ticks.first != ticks.first);
}
