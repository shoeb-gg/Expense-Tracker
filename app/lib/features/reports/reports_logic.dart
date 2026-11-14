import '../../core/days.dart';
import '../../state/providers.dart';

/// Whether spending went up, down, or stayed (rounded to whole percent).
enum Trend { up, down, flat }

/// A comparison: [percent] is the rounded size of the change.
typedef Delta = ({int percent, Trend trend});

/// Change from [prev] to [value]; null when there is nothing to compare
/// with (no spending before).
Delta? deltaOf(int value, int? prev) {
  if (prev == null || prev <= 0) return null;
  final pct = (value - prev) / prev * 100;
  final abs = pct.abs().round();
  return (
    percent: abs,
    trend: abs == 0 ? Trend.flat : (pct < 0 ? Trend.down : Trend.up),
  );
}

/// One month of the year chart and the month-by-month table.
class MonthCell {
  const MonthCell({
    required this.year,
    required this.month,
    required this.future,
    required this.partial,
    required this.beforeData,
    required this.value,
  });

  final int year;
  final int month;

  /// Starts after today ("still to come").
  final bool future;

  /// In progress (today is in it, and it is not its last day).
  final bool partial;

  /// Before the pocket's first expense: drawn empty, not averaged, not
  /// listed in the table.
  final bool beforeData;

  /// Minor units; 0 for future months.
  final int value;

  /// Can be selected and listed.
  bool get shown => !future && !beforeData;

  /// Counts towards the monthly average.
  bool get full => shown && !partial;
}

/// The twelve months of [year] for the chart.
List<MonthCell> monthsOfYear({
  required int year,
  required Map<(int, int), int> totals,
  required int today,
  required int? firstDay,
}) {
  final firstMonth = firstDay == null ? null : monthStartOfDay(firstDay);
  return [
    for (var m = 1; m <= 12; m++)
      MonthCell(
        year: year,
        month: m,
        future: monthStart(year, m) > today,
        partial: monthStart(year, m) <= today && monthEnd(year, m) > today,
        beforeData: firstMonth == null || monthStart(year, m) < firstMonth,
        value: totals[(year, m)] ?? 0,
      ),
  ];
}

/// Mean of the full months (minor units), or null when there are none.
int? fullMonthAverage(Iterable<MonthCell> months) {
  final full = months.where((m) => m.full).toList();
  if (full.isEmpty) return null;
  return (full.fold<int>(0, (s, m) => s + m.value) / full.length).round();
}

/// The value scale of the year chart, in whole units: ticks 0, step, ...
/// top (about three steps, using 1, 2, 2.5 or 5 times a power of ten).
typedef AxisScale = ({double step, double top});

AxisScale axisScale(double maxWhole) {
  final max = maxWhole < 3 ? 3.0 : maxWhole;
  final rough = max / 3;
  var mag = 1.0;
  while (mag * 10 <= rough) {
    mag *= 10;
  }
  final f = rough / mag;
  final step =
      (f <= 1
          ? 1
          : f <= 2
          ? 2
          : f <= 2.5
          ? 2.5
          : f <= 5
          ? 5
          : 10) *
      mag;
  final top = (max / step).ceil() * step;
  return (step: step, top: top);
}

/// Totals keyed by (year, month).
Map<(int, int), int> totalsByMonth(List<MonthTotal> totals) => {
  for (final t in totals) (t.year, t.month): t.total,
};

/// The "vs Sep 1–18" window: the same days of the month before, cut at the
/// end of that month.
({int from, int to, int days}) previousSameDays(int today) {
  final ym = yearMonthOfDay(today);
  final days = dayOfMonth(today);
  final prev = addMonths(ym.year, ym.month, -1);
  final n = days < daysInMonth(prev.year, prev.month)
      ? days
      : daysInMonth(prev.year, prev.month);
  final from = monthStart(prev.year, prev.month);
  return (from: from, to: from + n - 1, days: n);
}
