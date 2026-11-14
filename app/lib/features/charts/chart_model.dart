import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import 'chart_data.dart';

/// The Week / Month / Year / Custom switch of the Charts screen.
enum PeriodKind {
  week('Week'),
  month('Month'),
  year('Year'),
  custom('Custom');

  const PeriodKind(this.label);

  /// Text on the switch.
  final String label;
}

/// The three chart buttons.
enum ChartView {
  categories('Categories'),
  topDays('Top days'),
  overTime('Over time');

  const ChartView(this.label);

  /// Text on the button.
  final String label;
}

/// A period shown by Charts: an inclusive day range. [offset] counts periods
/// back from the current one (0 = this week/month/year).
@immutable
class ChartPeriod {
  const ChartPeriod({
    required this.kind,
    required this.from,
    required this.to,
    this.offset = 0,
  });

  final PeriodKind kind;
  final int from;
  final int to;
  final int offset;

  /// Number of days in the period.
  int get length => to - from + 1;

  /// True for the year view: one column per month, averages per month.
  bool get byMonth => kind == PeriodKind.year;

  /// The last day that has happened (the period end, or today).
  int lastPast(int today) => math.min(to, today);

  @override
  bool operator ==(Object other) =>
      other is ChartPeriod &&
      other.kind == kind &&
      other.from == from &&
      other.to == to &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(kind, from, to, offset);

  @override
  String toString() => 'ChartPeriod($kind, $from-$to, offset $offset)';
}

/// The week [offset] weeks before the one holding [today].
ChartPeriod weekPeriod(int today, FirstDayOfWeek first, int offset) {
  final s = weekStart(today, first) - 7 * offset;
  return ChartPeriod(kind: PeriodKind.week, from: s, to: s + 6, offset: offset);
}

/// The month [offset] months before the one holding [today].
ChartPeriod monthPeriod(int today, int offset) {
  final ym = yearMonthOfDay(today);
  final t = addMonths(ym.year, ym.month, -offset);
  return ChartPeriod(
    kind: PeriodKind.month,
    from: monthStart(t.year, t.month),
    to: monthEnd(t.year, t.month),
    offset: offset,
  );
}

/// The year [offset] years before the one holding [today].
ChartPeriod yearPeriod(int today, int offset) {
  final y = yearOfDay(today) - offset;
  return ChartPeriod(
    kind: PeriodKind.year,
    from: yearStart(y),
    to: yearEnd(y),
    offset: offset,
  );
}

/// A custom range.
ChartPeriod customPeriod(int from, int to) =>
    ChartPeriod(kind: PeriodKind.custom, from: from, to: to);

/// The default custom range: the last 30 days, ending today.
({int from, int to}) defaultCustomRange(int today) =>
    (from: today - 29, to: today);

/// The period of [kind] that is [offset] periods back from today.
ChartPeriod periodAt(
  PeriodKind kind,
  int offset, {
  required int today,
  required FirstDayOfWeek first,
  required ({int from, int to}) custom,
}) =>
    switch (kind) {
      PeriodKind.week => weekPeriod(today, first, offset),
      PeriodKind.month => monthPeriod(today, offset),
      PeriodKind.year => yearPeriod(today, offset),
      PeriodKind.custom => customPeriod(custom.from, custom.to),
    };

/// How many periods of [kind] [day] lies before the current one (0 for the
/// current period; negative for a later one).
int offsetOfDay(
  PeriodKind kind,
  int day, {
  required int today,
  required FirstDayOfWeek first,
}) {
  switch (kind) {
    case PeriodKind.week:
      return (weekStart(today, first) - weekStart(day, first)) ~/ 7;
    case PeriodKind.month:
      final a = yearMonthOfDay(today);
      final b = yearMonthOfDay(day);
      return (a.year * 12 + a.month) - (b.year * 12 + b.month);
    case PeriodKind.year:
      return yearOfDay(today) - yearOfDay(day);
    case PeriodKind.custom:
      return 0;
  }
}

/// Number of period tabs for [kind]: "Aug 2026, Last month, This month";
/// "2025, This year"; the custom range alone.
int tabCount(PeriodKind kind) => switch (kind) {
      PeriodKind.week || PeriodKind.month => 3,
      PeriodKind.year => 2,
      PeriodKind.custom => 1,
    };

/// The offsets the tabs show, left to right, while [selected] is chosen. The
/// first tab shows the chosen period once it is older than the quick tabs.
List<int> tabOffsets(PeriodKind kind, int selected) {
  final n = tabCount(kind);
  if (n == 1) return const [0];
  final quick = n - 1; // offsets 0 .. quick-1 have their own tabs
  final browse = math.max(quick, selected);
  return [browse, for (var o = quick - 1; o >= 0; o--) o];
}

/// The label of a period tab.
String periodTabLabel(ChartPeriod p) {
  switch (p.kind) {
    case PeriodKind.week:
      if (p.offset == 0) return 'This week';
      if (p.offset == 1) return 'Last week';
      return dayRangeLabel(p.from, p.to);
    case PeriodKind.month:
      if (p.offset == 0) return 'This month';
      if (p.offset == 1) return 'Last month';
      return shortMonthYear(yearOfDay(p.from), monthOfDay(p.from));
    case PeriodKind.year:
      if (p.offset == 0) return 'This year';
      return '${yearOfDay(p.from)}';
    case PeriodKind.custom:
      return dayRangeLabel(p.from, p.to);
  }
}

/// Which way spending went compared with the period before.
enum Trend { up, down, flat }

/// The more/less note under the total.
@immutable
class Delta {
  const Delta(this.trend, this.text);

  final Trend trend;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is Delta && other.trend == trend && other.text == text;

  @override
  int get hashCode => Object.hash(trend, text);

  @override
  String toString() => 'Delta($trend, $text)';
}

/// What a period is compared with: the total of the comparable earlier span
/// and how the note names it ("Sep 1–18", "the week before").
typedef Comparison = ({int previous, String label});

/// The comparable earlier span of [p] (null when nothing has happened yet).
Comparison? comparisonOf(ChartPeriod p, int today, SpendIndex index) {
  final s = p.from;
  final eEff = p.lastPast(today);
  if (eEff < s) return null;
  final len = eEff - s;
  switch (p.kind) {
    case PeriodKind.week:
      return (previous: index.sum(s - 7, s - 7 + len), label: 'the week before');
    case PeriodKind.custom:
      final days = p.length;
      return (
        previous: index.sum(s - days, s - days + len),
        label: days == 1 ? 'the day before' : 'the $days days before',
      );
    case PeriodKind.month:
      final ym = yearMonthOfDay(s);
      final pm = addMonths(ym.year, ym.month, -1);
      final ps = monthStart(pm.year, pm.month);
      final pe = monthEnd(pm.year, pm.month);
      if (eEff < p.to) {
        final n = math.min(len + 1, daysInMonth(pm.year, pm.month));
        return (
          previous: index.sum(ps, math.min(pe, ps + len)),
          label: '${monthShortName(pm.month)} 1–$n',
        );
      }
      return (previous: index.sum(ps, pe), label: monthName(pm.month));
    case PeriodKind.year:
      final y = yearOfDay(s);
      if (eEff < p.to) {
        final m = monthOfDay(eEff);
        final end = math.min(
          dayOf(y - 1, m, dayOfMonth(eEff)),
          monthEnd(y - 1, m),
        );
        return (
          previous: index.sum(yearStart(y - 1), end),
          label: 'the same period in ${y - 1}',
        );
      }
      return (
        previous: index.sum(yearStart(y - 1), yearEnd(y - 1)),
        label: '${y - 1}',
      );
  }
}

/// The more/less note (null: "Nothing earlier to compare with").
Delta? deltaOf(int total, Comparison? cmp) {
  if (cmp == null || cmp.previous <= 0) return null;
  final pct = (total - cmp.previous) / cmp.previous * 100;
  final abs = pct.abs().round();
  if (abs == 0) return Delta(Trend.flat, 'About the same as ${cmp.label}');
  final less = pct < 0;
  return Delta(
    less ? Trend.down : Trend.up,
    '$abs% ${less ? 'less' : 'more'} than ${cmp.label}',
  );
}

/// Text shown when there is nothing earlier to compare with.
const String nothingToCompare = 'Nothing earlier to compare with';

/// Average spending of a period in minor units: per day so far, or (year
/// view) per full month, leaving out a month in progress like Reports does.
double periodAverage(ChartPeriod p, int today, SpendIndex index) {
  final eEff = p.lastPast(today);
  if (eEff < p.from) return 0;
  final total = index.sum(p.from, eEff);
  if (!p.byMonth) return total / (eEff - p.from + 1);
  if (eEff < p.to) {
    final fullMonths = monthOfDay(eEff) - 1;
    if (fullMonths == 0) return total.toDouble();
    return index.sum(p.from, monthStartOfDay(eEff) - 1) / fullMonths;
  }
  return total / 12;
}

/// The summary card of a period.
@immutable
class PeriodSummary {
  const PeriodSummary({
    required this.total,
    required this.average,
    required this.averageLabel,
    required this.delta,
  });

  /// Total spent so far, minor units.
  final int total;

  /// Average in minor units (see [periodAverage]).
  final double average;

  /// "Daily average" or "Monthly average".
  final String averageLabel;

  /// The more/less note; null when there is nothing earlier.
  final Delta? delta;
}

/// The summary of [p].
PeriodSummary summaryOf(ChartPeriod p, int today, SpendIndex index) {
  final total = index.sum(p.from, p.lastPast(today));
  return PeriodSummary(
    total: total,
    average: periodAverage(p, today, index),
    averageLabel: p.byMonth ? 'Monthly average' : 'Daily average',
    delta: deltaOf(total, comparisonOf(p, today, index)),
  );
}

/// Rounds a minor-unit amount to whole units and back (for averages).
int roundToWhole(double minor) => (minor / 100).round() * 100;

/// "43.4%": the share of [part] in [total] with one decimal.
String shareText(int part, int total, AmountFormat fmt) {
  final pct = part / (total == 0 ? 1 : total) * 100;
  return '${pct.toStringAsFixed(1).replaceAll('.', fmt.decimalMark)}%';
}

/// "11 categories", "1 category".
String categoryCount(int n) => n == 1 ? '1 category' : '$n categories';

/// "12 other days", "1 other day".
String otherDays(int n) => n == 1 ? '1 other day' : '$n other days';

/// One column of an "Over time" chart.
@immutable
class ColumnPoint {
  const ColumnPoint({
    required this.value,
    required this.tick,
    required this.tipLabel,
    this.partial = false,
  });

  /// Spending in minor units; null for a day or month still to come.
  final int? value;

  /// Label under the column ('' = none).
  final String tick;

  /// First line of the pinned label ("Wed, Oct 7", "July 2025").
  final String tipLabel;

  /// A month in progress (drawn hollow, "so far").
  final bool partial;
}

/// Width of the plot the columns share (both charts are 296 px wide).
const double columnPlotWidth = 254;

/// How the day columns are labelled.
enum DayTicks { weekdays, monthDays, range }

/// One column per day from [from] to [to]. Days after [today] are still to
/// come.
List<ColumnPoint> dayColumns(
  int from,
  int to,
  int today,
  DayTicks ticks,
  int Function(int day) valueOf,
) {
  final n = to - from + 1;
  final pitch = columnPlotWidth / n;
  final stride = 7 * math.max(1, (44 / (7 * pitch)).ceil());
  int? lastMonth;
  return [
    for (var i = 0; i < n; i++)
      () {
        final d = from + i;
        var tick = '';
        switch (ticks) {
          case DayTicks.weekdays:
            tick = weekdayShortName(d);
          case DayTicks.monthDays:
            if (i % 7 == 0) tick = '${dayOfMonth(d)}';
          case DayTicks.range:
            if (i % stride == 0) {
              final m = monthOfDay(d);
              tick = lastMonth == m
                  ? '${dayOfMonth(d)}'
                  : '${monthShortName(m)} ${dayOfMonth(d)}';
              lastMonth = m;
            }
        }
        return ColumnPoint(
          value: d > today ? null : valueOf(d),
          tick: tick,
          tipLabel: weekdayMonthDay(d),
        );
      }(),
  ];
}

/// One column per month of [year]. The month holding [today] is partial and
/// later months are still to come. Every second month is labelled.
List<ColumnPoint> monthColumns(
  int year,
  int today,
  int Function(int from, int to) sumOf,
) {
  final parity = year == yearOfDay(today) ? (monthOfDay(today) - 1) % 2 : 0;
  return [
    for (var m = 1; m <= 12; m++)
      () {
        final s = monthStart(year, m);
        final e = monthEnd(year, m);
        final future = s > today;
        final partial = !future && e > today;
        return ColumnPoint(
          value: future ? null : sumOf(s, math.min(e, today)),
          tick: (m - 1) % 2 == parity ? monthShortName(m) : '',
          tipLabel:
              partial ? '${shortMonthYear(year, m)}, so far' : monthYear(year, m),
          partial: partial,
        );
      }(),
  ];
}

/// The columns of the Charts "Over time" view.
List<ColumnPoint> periodColumns(ChartPeriod p, int today, SpendIndex index) {
  if (p.byMonth) return monthColumns(yearOfDay(p.from), today, index.sum);
  final ticks = switch (p.kind) {
    PeriodKind.week => DayTicks.weekdays,
    PeriodKind.month => DayTicks.monthDays,
    _ => DayTicks.range,
  };
  return dayColumns(p.from, p.to, today, ticks, index.dayTotal);
}
