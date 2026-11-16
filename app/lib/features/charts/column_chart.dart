import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'chart_model.dart';

/// Colours of the columns: the highlighted one (peak or pinned), the others
/// while nothing is pinned, and the others while a column is pinned.
@immutable
class ColumnColors {
  const ColumnColors({required this.hi, required this.soft, required this.dim});

  final Color hi;
  final Color soft;
  final Color dim;
}

/// The value axis of a column chart, in whole units.
@immutable
class ChartScale {
  const ChartScale(this.top, this.step);

  /// Value at the top grid line.
  final double top;

  /// Distance between grid lines.
  final double step;

  /// A rounded scale for a largest value of [maxValue] (whole units), the
  /// mockup's rule: about four steps of 1, 2, 2.5, 5 or 10 times a power of
  /// ten, with one step more when the tallest column would touch the top.
  factory ChartScale.fit(double maxValue) {
    if (maxValue <= 0) return const ChartScale(1000, 250);
    final maxV = math.max(1.0, maxValue);
    final rough = maxV / 4;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final f = rough / mag;
    final step = (f <= 1
            ? 1
            : f <= 2
                ? 2
                : f <= 2.5
                    ? 2.5
                    : f <= 5
                        ? 5
                        : 10) *
        mag;
    var top = (maxV / step).ceil() * step;
    if (maxV > top * 0.86) top += step;
    return ChartScale(top, step);
  }

  /// The grid values from 0 to [top].
  List<double> get ticks => [
        for (var i = 0; i * step <= top + 0.001; i++) i * step,
      ];

  /// Axis label of [v]: "1,000"; "5K" once the top reaches 10,000; "1M" and
  /// "1.5M" from a million up (so a label stays four or five characters).
  String label(double v, AmountFormat fmt) {
    if (v == 0) return '0';
    if (top >= 10000) {
      if (v >= 1000000) return '${_trim(v / 1000000, 2, fmt)}M';
      return '${_trim(v / 1000, 1, fmt)}K';
    }
    if (v == v.roundToDouble()) return fmt.formatWhole((v * 100).round());
    return fmt.format((v * 100).round());
  }

  /// [x] with at most [decimals] decimals, none when it is whole: "5", "2.5",
  /// "1.25".
  static String _trim(double x, int decimals, AmountFormat fmt) {
    if (x == x.roundToDouble()) return '${x.round()}';
    var text = x.toStringAsFixed(decimals);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text.replaceAll('.', fmt.decimalMark);
  }
}

/// The column chart of Charts ("Over time") and of the category drill-down:
/// one column per day or month, the peak labelled, a dashed average line,
/// faint marks for days still to come and a hollow month in progress. Tapping
/// a column pins its date and amount; tapping it again clears it; dragging
/// moves the label along the columns.
class ColumnChart extends ConsumerWidget {
  const ColumnChart({
    super.key,
    required this.points,
    required this.average,
    required this.colors,
    required this.pinned,
    required this.onPin,
    this.padTop = 24,
    this.plotHeight = 170,
    this.onPointerDown,
    this.semanticLabel,
  });

  /// Charts "Over time": 296 x 222.
  static const double chartsPadTop = 24;
  static const double chartsPlotHeight = 170;

  /// Category drill-down: 296 x 188.
  static const double categoryPadTop = 12;
  static const double categoryPlotHeight = 148;

  static const double width = 296;

  /// The column of the axis labels, left of the plot.
  static const double axisWidth = 28;
  static const double padLeft = 34;
  static const double inset = 4;

  final List<ColumnPoint> points;

  /// Average in minor units (the dashed line); 0 hides the line.
  final double average;
  final ColumnColors colors;

  /// Index of the pinned column, or null.
  final int? pinned;
  final ValueChanged<int?> onPin;
  final double padTop;
  final double plotHeight;

  /// Called when a finger touches the chart (Charts uses it to keep a drag
  /// along the columns from also changing the period).
  final PointerDownEventListener? onPointerDown;
  final String? semanticLabel;

  /// Height of the whole chart box.
  double get height => padTop + plotHeight + 28;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final fmt = ref.watch(amountFormatProvider);
    final n = points.length;
    final pitch = columnPlotWidth / n;
    final bw = math.max(
      math.min(4.0, pitch * 0.75),
      math.min(22.0, (pitch * 0.7).roundToDouble()),
    );
    final radius = bw >= 8 ? 4.0 : bw / 2;
    double x(int i) => padLeft + inset + pitch * (i + 0.5);

    final values = [
      for (final p in points)
        if (p.value != null) p.value! / 100,
    ];
    final maxValue = values.isEmpty ? 0.0 : values.reduce(math.max);
    final scale = ChartScale.fit(maxValue);
    double y(double v) => padTop + plotHeight - v / scale.top * plotHeight;

    int? peak;
    for (var i = 0; i < n; i++) {
      final v = points[i].value;
      if (v != null && v > 0 && (peak == null || v > points[peak].value!)) {
        peak = i;
      }
    }
    final hi = pinned ?? peak;
    final firstFuture = points.indexWhere((p) => p.value == null);
    final avg = average / 100;
    final showAvg = avg > 0 && maxValue > 0;

    final tick = AppText.tabular(
      AppText.caption.copyWith(
        fontSize: 10.5,
        height: 14 / 10.5,
        color: c.text3,
      ),
    );
    final peakStyle = AppText.caption.copyWith(
      fontSize: 11.5,
      height: 14 / 11.5,
      fontWeight: FontWeight.w700,
      color: c.text,
    );

    // The axis labels share the 28 px column left of the plot, right
    // aligned. A label that does not fit it (large text, "1,000", "1500K")
    // makes all of them smaller by the same factor, so they stay alike.
    final axisTexts = [for (final v in scale.ticks) scale.label(v, fmt)];
    var axisFit = 1.0;
    for (final text in axisTexts) {
      final natural = titleWidth(context, text, tick);
      // Half a pixel of rounding is not "too wide": it is invisible.
      if (natural > axisWidth + 0.5) {
        axisFit = math.min(axisFit, (axisWidth - 0.5) / natural);
      }
    }
    final axisLine = titleHeight(context, tick);
    Widget axisLabel(double v) {
      final text = scale.label(v, fmt);
      if (axisFit == 1) {
        return Positioned(
          left: 0,
          top: y(v) - 7,
          width: axisWidth,
          child: Text(
            text,
            style: tick,
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        );
      }
      // Smaller, in a slot the height of the normal label so it keeps its
      // middle on the grid line.
      return Positioned(
        left: 0,
        top: y(v) - 7,
        width: axisWidth,
        height: axisLine,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            text,
            style: tick,
            textScaler: TextScaler.linear(
              MediaQuery.textScalerOf(context).scale(1) * axisFit,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      );
    }

    final groups = <BarChartGroupData>[
      for (var i = 0; i < n; i++) _group(i, scale, bw, radius, hi, c),
    ];

    final children = <Widget>[
      Positioned.fill(
        child: CustomPaint(
          painter: _GridPainter(
            lines: [for (final v in scale.ticks) y(v).roundToDouble() + 0.5],
            left: padLeft,
            right: width,
            color: c.line,
          ),
        ),
      ),
      // The dashed average runs behind the columns, as on the boards.
      if (showAvg)
        Positioned.fill(
          child: CustomPaint(
            painter: _DashPainter(
              y: y(avg).roundToDouble() + 0.5,
              left: padLeft,
              right: firstFuture > 0 ? x(firstFuture) - pitch / 2 : width,
              color: c.text2,
            ),
          ),
        ),
      Positioned(
        left: padLeft + inset,
        top: padTop,
        width: columnPlotWidth,
        height: plotHeight,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: 0,
            maxY: scale.top,
            groupsSpace: 0,
            barGroups: groups,
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
          ),
          duration: const Duration(milliseconds: 150),
        ),
      ),
      for (final v in scale.ticks) axisLabel(v),
      for (var i = 0; i < n; i++)
        if (points[i].tick.isNotEmpty)
          Positioned(
            left: x(i) - 20,
            top: padTop + plotHeight + 8,
            width: 40,
            child: Text(
              points[i].tick,
              style: tick,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
    ];

    // "Still to come" over the faint marks.
    if (firstFuture >= 0) {
      final left = x(firstFuture) - bw / 2;
      final w = x(n - 1) + bw / 2 - left;
      if (w >= 70) {
        var top = padTop + plotHeight - 21;
        final avgY = y(avg);
        if (showAvg && (avgY - (top + 7)).abs() < 12) top = avgY - 22;
        children.add(
          _label(
            left: left,
            top: top,
            width: w,
            align: TextAlign.center,
            text: 'Still to come',
            style: tick.copyWith(fontFeatures: const []),
            fill: c.surface,
          ),
        );
      }
    }

    // "so far" beside a month in progress.
    final partial = points.indexWhere((p) => p.partial);
    if (partial >= 0 &&
        points[partial].value != null &&
        pinned != partial &&
        !(pinned == null && partial == peak)) {
      final v = points[partial].value! / 100;
      final last = partial == n - 1;
      children.add(
        Positioned(
          left: last ? x(partial) - 20 : x(partial) + bw / 2 + 4,
          top: last ? y(v) - 17 : y(v) - 2,
          width: 40,
          child: Text(
            'so far',
            style: tick.copyWith(fontFeatures: const []),
            textAlign: last ? TextAlign.center : TextAlign.left,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      );
    }

    // "Peak 15,090" over the tallest column (hidden while one is pinned).
    // A figure too wide for the usual 120 px ("Peak 1,237,672.89" at large
    // text) gets the room it needs, kept inside the chart.
    if (pinned == null && peak != null) {
      final px = x(peak);
      final top = y(points[peak].value! / 100) - 18;
      final text = 'Peak ${fmt.format(points[peak].value!)}';
      final natural = titleWidth(context, text, peakStyle);
      final wide = natural + 1 > 120;
      final room = wide ? math.min(natural + 1, width) : 120.0;
      var left = px - room / 2;
      var align = TextAlign.center;
      if (px - 44 < padLeft) {
        left = px - bw / 2;
        align = TextAlign.left;
      } else if (px + 44 > width) {
        left = px + bw / 2 - room;
        align = TextAlign.right;
      }
      if (wide) left = left.clamp(0.0, width - room).toDouble();
      children.add(
        _label(
          left: left,
          top: top,
          width: room,
          align: align,
          text: text,
          style: peakStyle,
          fill: c.surface,
        ),
      );
    }

    // The pinned label.
    if (pinned != null && pinned! < n && points[pinned!].value != null) {
      final p = points[pinned!];
      final hx = x(pinned!);
      final hy = y(p.value! / 100);
      var left = (hx - 60).clamp(padLeft, width - 120).toDouble();
      var top = hy - 52;
      if (top < 0) {
        top = 0;
        left = hx + bw / 2 + 8;
        if (left + 120 > width) left = hx - bw / 2 - 8 - 120;
      }
      children.add(
        Positioned(
          left: left,
          top: top,
          width: 120,
          height: 44,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.tip,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  cssShadow(y: 6, blur: 16, color: c.shadowSm),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p.tipLabel,
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      height: 14 / 11,
                      fontWeight: FontWeight.w600,
                      color: c.text2,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                  Text(
                    fmt.format(p.value!),
                    style: AppText.bodyStrong.copyWith(
                      height: 18 / 14,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    int? indexAt(double dx) {
      final i = (dx / pitch).floor();
      if (i < 0 || i >= n || points[i].value == null) return null;
      return i;
    }

    children.add(
      Positioned(
        left: padLeft + inset,
        top: 0,
        width: columnPlotWidth,
        height: padTop + plotHeight + 4,
        child: Listener(
          onPointerDown: onPointerDown,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final i = indexAt(d.localPosition.dx);
              if (i == null) return;
              onPin(pinned == i ? null : i);
            },
            onHorizontalDragStart: (d) {
              final i = indexAt(d.localPosition.dx);
              if (i != null && i != pinned) onPin(i);
            },
            onHorizontalDragUpdate: (d) {
              final i = indexAt(d.localPosition.dx);
              if (i != null && i != pinned) onPin(i);
            },
          ),
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }

  BarChartGroupData _group(
    int i,
    ChartScale scale,
    double bw,
    double radius,
    int? hi,
    AppColors c,
  ) {
    final p = points[i];
    final unit = scale.top / plotHeight; // value of one pixel
    final BarChartRodData rod;
    if (p.value == null) {
      rod = BarChartRodData(
        toY: 3 * unit,
        width: bw,
        color: c.stub,
        borderRadius: BorderRadius.circular(1.5),
      );
    } else if (p.value == 0) {
      rod = BarChartRodData(toY: 0, width: bw, color: const Color(0x00000000));
    } else {
      final tone = i == hi
          ? colors.hi
          : pinned != null
              ? colors.dim
              : colors.soft;
      final v = math.max(p.value! / 100, 2 * unit);
      // Like CSS, corners never round more than the column is tall, so a
      // tiny amount is a flat 2 px pill rather than a bump.
      final r = math.min(radius, v / unit);
      final top = BorderRadius.vertical(top: Radius.circular(r));
      // The hollow column's outline is drawn inside its box, which sits on
      // the base line.
      rod = p.partial
          ? BarChartRodData(
              fromY: 0.75 * unit,
              toY: v - 0.75 * unit,
              width: bw - 1.5,
              color: const Color(0x00000000),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(math.max(0, r - 0.75)),
              ),
              borderSide: BorderSide(color: tone, width: 1.5),
            )
          : BarChartRodData(
              toY: v,
              width: bw,
              color: tone,
              borderRadius: top,
            );
    }
    return BarChartGroupData(x: i, barRods: [rod]);
  }

  Widget _label({
    required double left,
    required double top,
    required double width,
    required TextAlign align,
    required String text,
    required TextStyle style,
    required Color fill,
  }) {
    final alignment = switch (align) {
      TextAlign.left => Alignment.centerLeft,
      TextAlign.right => Alignment.centerRight,
      _ => Alignment.center,
    };
    return Positioned(
      left: left - 4,
      top: top,
      width: width + 8,
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(text, style: style, maxLines: 1, softWrap: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.lines,
    required this.left,
    required this.right,
    required this.color,
  });

  final List<double> lines;
  final double left;
  final double right;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final y in lines) {
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.color != color ||
      old.left != left ||
      old.right != right ||
      !_sameList(old.lines, lines);
}

class _DashPainter extends CustomPainter {
  _DashPainter({
    required this.y,
    required this.left,
    required this.right,
    required this.color,
  });

  final double y;
  final double left;
  final double right;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (var x = left; x < right; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, right), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.y != y || old.left != left || old.right != right || old.color != color;
}

bool _sameList(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
