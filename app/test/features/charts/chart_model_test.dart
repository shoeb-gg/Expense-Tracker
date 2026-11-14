import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/calendar/calendar_data.dart';
import 'package:spill_the_bills/features/charts/chart_data.dart';
import 'package:spill_the_bills/features/charts/chart_model.dart';
import 'package:spill_the_bills/features/charts/column_chart.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/sample_data.dart';
import '../../support/test_db.dart';

/// Aggregation of the sample data (TODAY = 18 Oct 2026), checked against the
/// numbers the mockup boards show.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late SpendIndex index;
  const fmt = AmountFormat();
  final today = dayOf(2026, 10, 18);
  const monday = FirstDayOfWeek.monday;

  setUpAll(() async {
    db = openTestDatabase();
    await fillSampleData(db);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(Clock.fixed(mockupNow)),
      ],
    );
    final sub = container.listen(spendIndexProvider(1), (_, _) {});
    index = await container.read(spendIndexProvider(1).future);
    sub.close();
  });

  tearDownAll(() async {
    container.dispose();
    await db.close();
  });

  String whole(double minor) => fmt.formatWhole(minor.round());

  group('SpendIndex (sums from the database)', () {
    test('October total is 34,555 and Oct 18 is 1,180', () {
      expect(index.sum(dayOf(2026, 10, 1), today), 3455500);
      expect(index.dayTotal(today), 118000);
      expect(index.dayTotal(dayOf(2026, 10, 17)), 13500);
      expect(index.dayTotal(dayOf(2026, 10, 1)), 1509000);
      expect(index.dayTotal(dayOf(2026, 10, 9)), 0);
      expect(index.dayTotal(dayOf(2026, 10, 19)), 0);
    });

    test('first and last day, empty and reversed ranges', () {
      expect(index.firstDay, dayOf(2025, 1, 1));
      expect(index.lastDay, today);
      expect(index.sum(today, today - 1), 0);
      expect(SpendIndex.empty.sum(0, 99999), 0);
      expect(SpendIndex.empty.firstDay, isNull);
    });

    test('day totals of a month have only days with spending', () {
      final days = index.dayTotals(dayOf(2026, 10, 1), dayOf(2026, 10, 31));
      expect(days.length, 17);
      expect(days.values.fold<int>(0, (s, v) => s + v), 3455500);
      expect(days.containsKey(dayOf(2026, 10, 9)), isFalse);
    });

    test('categories in October, biggest first, with shares', () {
      final cats = index.byCategory(dayOf(2026, 10, 1), today);
      expect([for (final c in cats) c.categoryId], [5, 1, 2, 6, 7, 3, 14, 10, 8, 11, 13]);
      expect([for (final c in cats) c.amount ~/ 100], [
        15000, 6540, 2770, 2470, 1500, 1210, 1200, 1180, 1000, 1000, 685, //
      ]);
      final total = index.sum(dayOf(2026, 10, 1), today);
      expect(
        [for (final c in cats) shareText(c.amount, total, fmt)],
        ['43.4%', '18.9%', '8.0%', '7.1%', '4.3%', '3.5%', '3.5%', '3.4%',
          '2.9%', '2.9%', '2.0%'],
      );
    });

    test('top days of October', () {
      final days = index.topDays(dayOf(2026, 10, 1), today);
      expect(days.take(5).toList(), [
        (day: dayOf(2026, 10, 1), amount: 1509000),
        (day: dayOf(2026, 10, 2), amount: 310500),
        (day: dayOf(2026, 10, 16), amount: 265000),
        (day: dayOf(2026, 10, 12), amount: 258000),
        (day: dayOf(2026, 10, 6), amount: 223000),
      ]);
      final rest = days.skip(5);
      expect(rest.length, 12);
      expect(rest.fold<int>(0, (s, d) => s + d.amount), 890000);
    });
  });

  group('periods', () {
    test('week, month and year ranges and tab labels', () {
      final w = weekPeriod(today, monday, 0);
      expect(w.from, dayOf(2026, 10, 12));
      expect(w.to, today);
      expect(periodTabLabel(w), 'This week');
      expect(periodTabLabel(weekPeriod(today, monday, 1)), 'Last week');
      expect(
        periodTabLabel(weekPeriod(today, monday, 2)),
        'Sep 28 – Oct 4',
      );
      // Weeks follow the setting: Sunday-first puts Oct 18 at the start.
      expect(weekPeriod(today, FirstDayOfWeek.sunday, 0).from, today);

      expect(periodTabLabel(monthPeriod(today, 0)), 'This month');
      expect(periodTabLabel(monthPeriod(today, 1)), 'Last month');
      expect(periodTabLabel(monthPeriod(today, 2)), 'Aug 2026');
      expect(periodTabLabel(yearPeriod(today, 0)), 'This year');
      expect(periodTabLabel(yearPeriod(today, 1)), '2025');
      expect(
        periodTabLabel(customPeriod(today - 29, today)),
        'Sep 19 – Oct 18',
      );
    });

    test('tab offsets keep the quick tabs and show older periods first', () {
      expect(tabOffsets(PeriodKind.month, 0), [2, 1, 0]);
      expect(tabOffsets(PeriodKind.month, 1), [2, 1, 0]);
      expect(tabOffsets(PeriodKind.month, 5), [5, 1, 0]);
      expect(tabOffsets(PeriodKind.year, 0), [1, 0]);
      expect(tabOffsets(PeriodKind.year, 3), [3, 0]);
      expect(tabOffsets(PeriodKind.custom, 0), [0]);
    });

    test('offset of a day', () {
      expect(
        offsetOfDay(PeriodKind.month, dayOf(2025, 1, 1),
            today: today, first: monday),
        21,
      );
      expect(
        offsetOfDay(PeriodKind.week, dayOf(2026, 10, 5),
            today: today, first: monday),
        1,
      );
      expect(
        offsetOfDay(PeriodKind.year, dayOf(2025, 6, 1),
            today: today, first: monday),
        1,
      );
    });
  });

  group('summaries (total, average, more/less)', () {
    void check(
      ChartPeriod p, {
      required String total,
      required String average,
      required String label,
      required String? delta,
    }) {
      final s = summaryOf(p, today, index);
      expect(fmt.format(s.total), total, reason: '$p total');
      expect(whole(s.average), average, reason: '$p average');
      expect(s.averageLabel, label);
      expect(s.delta?.text, delta, reason: '$p delta');
    }

    test('months', () {
      check(monthPeriod(today, 0),
          total: '34,555',
          average: '1,920',
          label: 'Daily average',
          delta: '2% more than Sep 1–18');
      check(monthPeriod(today, 1),
          total: '45,220',
          average: '1,507',
          label: 'Daily average',
          delta: '14% less than August');
      check(monthPeriod(today, 2),
          total: '52,475',
          average: '1,693',
          label: 'Daily average',
          delta: '1% more than July');
      expect(summaryOf(monthPeriod(today, 0), today, index).delta!.trend,
          Trend.up);
      expect(summaryOf(monthPeriod(today, 1), today, index).delta!.trend,
          Trend.down);
    });

    test('weeks (Monday first, as on the board)', () {
      check(weekPeriod(today, monday, 0),
          total: '8,250',
          average: '1,179',
          label: 'Daily average',
          delta: '25% more than the week before');
      check(weekPeriod(today, monday, 1),
          total: '6,620',
          average: '946',
          label: 'Daily average',
          delta: '71% less than the week before');
      check(weekPeriod(today, monday, 2),
          total: '22,805',
          average: '3,258',
          label: 'Daily average',
          delta: '224% more than the week before');
    });

    test('years: the monthly average counts full months only', () {
      check(yearPeriod(today, 0),
          total: '493,610',
          average: '51,006',
          label: 'Monthly average',
          delta: '3% more than the same period in 2025');
      check(yearPeriod(today, 1),
          total: '596,750',
          average: '49,729',
          label: 'Monthly average',
          delta: null);
    });

    test('custom range: the last 30 days', () {
      check(customPeriod(today - 29, today),
          total: '46,040',
          average: '1,535',
          label: 'Daily average',
          delta: '10% more than the 30 days before');
    });

    test('a period with nothing spent and one still to come', () {
      final empty = summaryOf(monthPeriod(today, 30), today, index);
      expect(empty.total, 0);
      expect(empty.average, 0);
      expect(empty.delta, isNull);
      final future = summaryOf(customPeriod(today + 1, today + 5), today, index);
      expect(future.total, 0);
      expect(future.delta, isNull);
    });

    test('about the same', () {
      expect(deltaOf(10040, (previous: 10000, label: 'June')),
          const Delta(Trend.flat, 'About the same as June'));
      expect(deltaOf(100, (previous: 0, label: 'June')), isNull);
    });
  });

  group('columns', () {
    test('this month: 31 days, 18 so far, ticks every 7 days', () {
      final points = periodColumns(monthPeriod(today, 0), today, index);
      expect(points.length, 31);
      expect(points.where((p) => p.value != null).length, 18);
      expect(points.first.value, 1509000);
      expect([for (final p in points) if (p.tick.isNotEmpty) p.tick],
          ['1', '8', '15', '22', '29']);
      expect(points[6].tipLabel, 'Wed, Oct 7');
      expect(points[6].value, 124000);
    });

    test('this year: October in progress, November and December to come', () {
      final points = periodColumns(yearPeriod(today, 0), today, index);
      expect(points.length, 12);
      expect(points[9].partial, isTrue);
      expect(points[9].value, 3455500);
      expect(points[9].tipLabel, 'Oct 2026, so far');
      expect(points[10].value, isNull);
      expect(points[2].value, 5433000);
      expect([for (final p in points) if (p.tick.isNotEmpty) p.tick],
          ['Feb', 'Apr', 'Jun', 'Aug', 'Oct', 'Dec']);
      final last = periodColumns(yearPeriod(today, 1), today, index);
      expect([for (final p in last) if (p.tick.isNotEmpty) p.tick],
          ['Jan', 'Mar', 'May', 'Jul', 'Sep', 'Nov']);
      expect(last[6].tipLabel, 'July 2025');
    });

    test('week ticks are weekday names; custom ticks name the month', () {
      final week = periodColumns(weekPeriod(today, monday, 0), today, index);
      expect([for (final p in week) p.tick],
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
      final custom =
          periodColumns(customPeriod(today - 29, today), today, index);
      expect([for (final p in custom) if (p.tick.isNotEmpty) p.tick],
          ['Sep 19', '26', 'Oct 3', '10', '17']);
    });

    test('axis scale', () {
      expect(ChartScale.fit(15090).top, 20000);
      expect(ChartScale.fit(15090).step, 5000);
      expect(ChartScale.fit(2650).top, 4000);
      expect(ChartScale.fit(54330).top, 80000);
      expect(ChartScale.fit(2120).top, 3000);
      expect(ChartScale.fit(0).top, 1000);
      const s = ChartScale(20000, 5000);
      expect(s.label(5000, fmt), '5K');
      expect(const ChartScale(10000, 2500).label(2500, fmt), '2.5K');
      expect(const ChartScale(3000, 1000).label(1000, fmt), '1,000');
    });
  });

  group('calendar', () {
    test('heat steps of October are the quartiles of spending days', () {
      final totals =
          index.dayTotals(dayOf(2026, 10, 1), dayOf(2026, 10, 18)).values;
      final s = heatSteps(totals);
      expect(s, (t1: 36500, t2: 118000, t3: 223000));
      expect(heatLevel(0, s), 0);
      expect(heatLevel(36500, s), 1);
      expect(heatLevel(118000, s), 2);
      expect(heatLevel(223000, s), 3);
      expect(heatLevel(1509000, s), 4);
      expect(heatSteps(const []), (t1: 0, t2: 0, t3: 0));
    });

    test('month grid follows the first day of the week', () {
      final sun = monthCells(2026, 10, FirstDayOfWeek.sunday);
      expect(sun.take(4), everyElement(isNull));
      expect(sun[4], dayOf(2026, 10, 1));
      expect(sun.length, 4 + 31);
      final mon = monthCells(2026, 10, FirstDayOfWeek.monday);
      expect(mon[3], dayOf(2026, 10, 1));
      final sat = monthCells(2026, 10, FirstDayOfWeek.saturday);
      expect(sat[5], dayOf(2026, 10, 1));
      expect(monthCells(2026, 8, FirstDayOfWeek.sunday).length, 6 + 31);
    });

    test('default day and short amounts', () {
      expect(defaultDay(2026, 10, today), today);
      expect(defaultDay(2026, 9, today), dayOf(2026, 9, 30));
      expect(fmt.short(1509000), '15K');
      expect(fmt.short(166500), '1.7K');
      expect(fmt.short(83500), '835');
    });
  });
}
