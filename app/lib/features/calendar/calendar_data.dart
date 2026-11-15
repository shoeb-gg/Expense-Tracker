import '../../core/days.dart';

/// The heat thresholds of a month: the quartiles of its spending days.
typedef HeatSteps = ({int t1, int t2, int t3});

/// Quartiles of the days that have spending (minor units), as the mockup
/// computes them: sorted values at 25%, 50% and 75% of the way, rounded
/// down to an index.
HeatSteps heatSteps(Iterable<int> dayTotals) {
  final vals = [
    for (final v in dayTotals)
      if (v > 0) v,
  ]..sort();
  int q(double p) => vals.isEmpty ? 0 : vals[(p * (vals.length - 1)).floor()];
  return (t1: q(0.25), t2: q(0.5), t3: q(0.75));
}

/// Brightness step of a day: 0 for no spending, then 1 to 4 by quarter.
int heatLevel(int value, HeatSteps s) {
  if (value <= 0) return 0;
  if (value <= s.t1) return 1;
  if (value <= s.t2) return 2;
  if (value <= s.t3) return 3;
  return 4;
}

/// The cells of a month grid, week by week: null for the blanks before the
/// 1st (weeks start on [first]), then every day of the month.
List<int?> monthCells(int year, int month, FirstDayOfWeek first) {
  final s = monthStart(year, month);
  final lead = (weekdayOfDay(s) - first.weekday + 7) % 7;
  return [
    for (var i = 0; i < lead; i++) null,
    for (var d = s; d <= monthEnd(year, month); d++) d,
  ];
}

/// The day chosen when a month opens: today in the current month, else the
/// month's 1st (an earlier month and a later one alike).
int defaultDay(int year, int month, int today) {
  final s = monthStart(year, month);
  return today >= s && today <= monthEnd(year, month) ? today : s;
}

/// A month as one number (year * 12 + month - 1), for limits and keys.
int monthKey(int year, int month) => year * 12 + month - 1;
