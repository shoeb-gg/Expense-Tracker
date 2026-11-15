import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/charts/category_screen.dart';
import 'package:spill_the_bills/features/charts/charts_screen.dart';
import 'package:spill_the_bills/features/charts/column_chart.dart';
import 'package:spill_the_bills/features/charts/range_popups.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/shots.dart';

AppSettings _settings(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(ChartsScreen)),
    ).read(settingsProvider);

/// Drags across the middle of the screen. `by.dx > 0`: the finger moves
/// from left to right.
Future<void> _swipe(WidgetTester tester, Offset by) async {
  await tester.dragFrom(const Offset(180, 420), by);
  await settle(tester);
}

/// Scrolls [f] to the middle of the screen and taps it.
Future<void> _tapRow(WidgetTester tester, Finder f) async {
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

/// The total of the summary card ("34,555" also shows in the ring).
Finder _total(String text) => find.text(text);

void main() {
  group('Charts', () {
    testWidgets('finger left to right shows the previous period, right to '
        'left the next one', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      expect(_total('34,555'), findsWidgets);

      await _swipe(tester, const Offset(200, 0));
      expect(_total('45,220'), findsWidgets, reason: 'Last month');
      await _swipe(tester, const Offset(200, 0));
      expect(_total('52,475'), findsWidgets, reason: 'Aug 2026');
      await _swipe(tester, const Offset(200, 0));
      expect(find.text('Jul 2026'), findsOneWidget);
      expect(find.text('Aug 2026'), findsNothing);

      await _swipe(tester, const Offset(-200, 0));
      expect(find.text('Aug 2026'), findsOneWidget);
      expect(_total('52,475'), findsWidgets);
      await _swipe(tester, const Offset(-200, 0));
      await _swipe(tester, const Offset(-200, 0));
      expect(_total('34,555'), findsWidgets, reason: 'This month');

      // A vertical drag scrolls; it does not change the period.
      await _swipe(tester, const Offset(0, 200));
      await _swipe(tester, const Offset(0, -200));
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Last month'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('swipes never stop: past the first expense and into the '
        'future', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      await tester.tap(find.text('Year'));
      await settle(tester);
      expect(_total('493,610'), findsWidgets);
      await _swipe(tester, const Offset(200, 0));
      expect(_total('596,750'), findsWidgets, reason: '2025');
      await _swipe(tester, const Offset(200, 0));
      expect(find.text('2024'), findsOneWidget, reason: 'before the data');
      expect(_total('596,750'), findsNothing);
      await _swipe(tester, const Offset(200, 0));
      expect(find.text('2023'), findsOneWidget);

      // Forward again: this year, then the years still to come.
      for (var i = 0; i < 3; i++) {
        await _swipe(tester, const Offset(-200, 0));
      }
      expect(find.text('This year'), findsOneWidget);
      expect(_total('493,610'), findsWidgets);
      await _swipe(tester, const Offset(-200, 0));
      expect(find.text('2027'), findsOneWidget);
      // The tab, and the pill that goes back to it.
      expect(find.text('This year'), findsNWidgets(2));
      expect(_total('493,610'), findsNothing);
      await _swipe(tester, const Offset(-200, 0));
      expect(find.text('2028'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('months and weeks go on into the future', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      await _swipe(tester, const Offset(-200, 0));
      expect(find.text('Nov 2026'), findsOneWidget);
      expect(find.text('This month'), findsNWidgets(2), reason: 'tab and pill');
      expect(find.text('Last month'), findsOneWidget);
      expect(find.text('Nothing spent in this period.'), findsOneWidget);
      await _swipe(tester, const Offset(-200, 0));
      expect(find.text('Dec 2026'), findsOneWidget);
      await _swipe(tester, const Offset(200, 0));
      await _swipe(tester, const Offset(200, 0));
      expect(_total('34,555'), findsWidgets, reason: 'back on this month');
      expect(find.text('Nov 2026'), findsNothing);

      await tester.tap(find.text('Week'));
      await settle(tester);
      await _swipe(tester, const Offset(-200, 0));
      expect(find.text('Oct 25 – Oct 31'), findsOneWidget);
      expect(find.text('This week'), findsNWidgets(2), reason: 'tab and pill');
      await closeApp(tester, db);
    });

    testWidgets('a future week, month or year shows every chart empty, '
        'never an error or an odd number', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      for (final kind in ['Week', 'Month', 'Year']) {
        await tester.tap(find.text(kind));
        await settle(tester);
        for (var i = 0; i < 3; i++) {
          await _swipe(tester, const Offset(-200, 0));
        }
        for (final (view, empty) in [
          ('Categories', 'Nothing spent'),
          ('Top days', 'Nothing spent'),
          ('Over time', 'Nothing spent in this period.'),
        ]) {
          await tester.tap(find.text(view));
          await settle(tester);
          expect(tester.takeException(), isNull, reason: '$kind, $view');
          expect(find.textContaining('NaN'), findsNothing);
          expect(find.textContaining('Infinity'), findsNothing);
          expect(find.text(empty), findsWidgets, reason: '$kind, $view');
        }
      }
      await closeApp(tester, db);
    });

    testWidgets('tabs choose a period; the chosen tab opens the month pop-up',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      await tester.tap(find.text('Last month'));
      await settle(tester);
      expect(_total('45,220'), findsWidgets);

      await tester.tap(find.text('Last month'));
      await settle(tester);
      expect(find.text('Month to show'), findsOneWidget);
      await tester.tap(find.text('Jun'));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(find.text('Jun 2026'), findsOneWidget);
      expect(find.text('Last month'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('weeks follow the first day of the week', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: const AppSettings(firstDayOfWeek: FirstDayOfWeek.monday),
      );
      await tester.tap(find.text('Week'));
      await settle(tester);
      expect(_total('8,250'), findsWidgets, reason: 'Oct 12 - Oct 18');
      expect(find.text('Sep 28 – Oct 4'), findsOneWidget);
      await closeApp(tester, db);

      final db2 = await sampleDatabase(tester);
      await pumpApp(tester, db: db2, location: Routes.charts);
      await tester.tap(find.text('Week'));
      await settle(tester);
      // Sunday first: this week is Oct 18 - Oct 24 and only Oct 18 is past.
      expect(find.text('1,180'), findsWidgets);
      await closeApp(tester, db2);
    });

    testWidgets('Custom opens the range pop-up; Charts switch only after '
        'Confirm and remember the range', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      await tester.tap(find.text('Custom'));
      await settle(tester);
      expect(find.text('Charts will show these 30 days.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('This month'), findsOneWidget);
      expect(_settings(tester).lastCustomRange, isNull);

      await tester.tap(find.text('Custom'));
      await settle(tester);
      await tester.tap(find.text('7 days'));
      await settle(tester);
      expect(find.text('Charts will show these 7 days.'), findsOneWidget);
      expect(find.text('Oct 12, 2026'), findsOneWidget);
      expect(find.text('Today, Oct 18'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(find.text('Oct 12 – Oct 18'), findsOneWidget);
      expect(
        _settings(tester).lastCustomRange,
        (from: dayOf(2026, 10, 12), to: dayOf(2026, 10, 18)),
      );
      expect(_total('8,250'), findsWidgets);

      // The tab reopens the pop-up on the last range.
      await tester.tap(find.text('Oct 12 – Oct 18'));
      await settle(tester);
      expect(find.text('Charts will show these 7 days.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await closeApp(tester, db);
    });

    testWidgets('To earlier than From switches Confirm off', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      DayRange? result = (from: 0, to: 0);
      unawaited(
        showCustomRange(
          tester.element(find.byType(ChartsScreen)),
          initial: (from: dayOf(2026, 10, 13), to: dayOf(2026, 10, 10)),
        ).then((r) => result = r),
      );
      await settle(tester);
      expect(find.text("To can't be earlier than From."), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(find.text("To can't be earlier than From."), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(result, isNull);
      await closeApp(tester, db);
    });

    testWidgets('a category row selects its slice; Details opens the '
        'drill-down with the range', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      await _tapRow(tester, find.text('Groceries'));
      expect(find.text('18.9% of total'), findsOneWidget);
      // The name also shows in the ring centre; the row is the last one.
      await _tapRow(tester, find.text('Groceries').last);
      expect(find.text('18.9% of total'), findsNothing);

      // A category in the slate rest: the centre shows it too.
      await _tapRow(tester, find.text('Health'));
      expect(find.text('3.4% of total'), findsOneWidget);

      await _tapRow(tester, find.text('Details'));
      final screen = tester.widget<CategoryScreen>(find.byType(CategoryScreen));
      expect(screen.categoryId, 10);
      expect(screen.from, dayOf(2026, 10, 1));
      expect(screen.to, dayOf(2026, 10, 31));
      expect(find.text('1,180'), findsWidgets);
      await closeApp(tester, db);
    });

    testWidgets('Top days: tapping a legend entry selects its slice',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      await tester.tap(find.text('Top days'));
      await settle(tester);
      expect(find.text('Top 5 days'), findsOneWidget);
      expect(find.text('25,655'), findsOneWidget);
      await _tapRow(tester, find.text('Fri, Oct 16'));
      expect(find.text('7.7% of total'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('Over time: tap pins a column, tap again clears; a drag '
        'along the columns does not change the period', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      await tester.tap(find.text('Over time'));
      await settle(tester);
      final chart = tester.getTopLeft(find.byType(ColumnChart));
      Offset column(int i) => chart + Offset(38 + 254 / 31 * (i + 0.5), 150);

      await tester.tapAt(column(6));
      await settle(tester);
      expect(find.text('Wed, Oct 7'), findsOneWidget);
      expect(find.text('1,240'), findsOneWidget);
      expect(find.text('Peak 15,090'), findsNothing);
      await tester.tapAt(column(6));
      await settle(tester);
      expect(find.text('Wed, Oct 7'), findsNothing);
      expect(find.text('Peak 15,090'), findsOneWidget);

      // Days still to come cannot be pinned.
      await tester.tapAt(column(25));
      await settle(tester);
      expect(find.text('Mon, Oct 26'), findsNothing);

      await tester.dragFrom(column(2), const Offset(60, 0));
      await settle(tester);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('34,555'), findsOneWidget);
      expect(find.text('Sat, Oct 10'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('the chosen year tab opens the year pop-up', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);
      await tester.tap(find.text('Year'));
      await settle(tester);
      await tester.tap(find.text('This year'));
      await settle(tester);
      expect(find.text('Year to show'), findsOneWidget);
      await tester.tap(find.text('2025').last);
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(_total('596,750'), findsWidgets);
      await closeApp(tester, db);
    });

    testWidgets('the pop-ups pick any week, month or year, past or future',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts);

      // Month: March 2027 is still to come.
      await tester.tap(find.text('This month'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Next year'));
      await settle(tester);
      await tester.tap(find.text('Mar'));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(find.text('Mar 2027'), findsOneWidget);
      expect(find.text('Nothing spent in this period.'), findsOneWidget);

      // March 2024 is before the first expense.
      await tester.tap(find.text('Mar 2027'));
      await settle(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.bySemanticsLabel('Previous year'));
        await settle(tester);
      }
      await tester.tap(find.text('Mar'));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(find.text('Mar 2024'), findsOneWidget);

      // Week: the week of Nov 11, 2026.
      await tester.tap(find.text('Week'));
      await settle(tester);
      await tester.tap(find.text('This week'));
      await settle(tester);
      expect(find.text('Week to show'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Wednesday, November 11'));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(find.text('Nov 8 – Nov 14'), findsOneWidget);

      // Year: 2028.
      await tester.tap(find.text('Year'));
      await settle(tester);
      await tester.tap(find.text('This year'));
      await settle(tester);
      await tester.tap(find.text('2028'));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(find.text('2028'), findsOneWidget);
      expect(find.text('This year'), findsNWidgets(2), reason: 'tab and pill');
      await closeApp(tester, db);
    });

    group('back to now', () {
      Finder pill(String what) => find.bySemanticsLabel('Back to $what');

      bool forward(WidgetTester tester) =>
          tester.widget<SlideSwitcher>(find.byType(SlideSwitcher)).forward;

      testWidgets('Month: off this month it shows, a tap goes back the right '
          'way', (tester) async {
        final db = await sampleDatabase(tester);
        await pumpApp(tester, db: db, location: Routes.charts);
        expect(find.byType(Pill), findsNothing);

        await _swipe(tester, const Offset(200, 0));
        expect(pill('this month'), findsOneWidget);
        await _swipe(tester, const Offset(200, 0));
        await _swipe(tester, const Offset(200, 0));
        expect(find.text('Jul 2026'), findsOneWidget);
        await tester.tap(pill('this month'));
        await tester.pump();
        expect(forward(tester), isTrue, reason: 'from the past');
        await settle(tester);
        expect(_total('34,555'), findsWidgets);
        expect(find.text('Jul 2026'), findsNothing);
        expect(find.byType(Pill), findsNothing);

        // By swiping back to this month it goes by itself.
        await _swipe(tester, const Offset(200, 0));
        expect(find.byType(Pill), findsOneWidget);
        await _swipe(tester, const Offset(-200, 0));
        expect(find.byType(Pill), findsNothing);

        // From the future it slides the other way.
        for (var i = 0; i < 3; i++) {
          await _swipe(tester, const Offset(-200, 0));
        }
        expect(find.text('Jan 2027'), findsOneWidget);
        await tester.tap(pill('this month'));
        await tester.pump();
        expect(forward(tester), isFalse, reason: 'from the future');
        await settle(tester);
        expect(_total('34,555'), findsWidgets);
        expect(find.byType(Pill), findsNothing);
        await closeApp(tester, db);
      });

      testWidgets('Week and Year have their own pill and their own period',
          (tester) async {
        final db = await sampleDatabase(tester);
        await pumpApp(tester, db: db, location: Routes.charts);
        // Two months back, then to the other tabs.
        await _swipe(tester, const Offset(200, 0));
        await _swipe(tester, const Offset(200, 0));
        expect(pill('this month'), findsOneWidget);

        await tester.tap(find.text('Week'));
        await settle(tester);
        expect(find.byType(Pill), findsNothing, reason: 'this week');
        await _swipe(tester, const Offset(200, 0));
        expect(pill('this week'), findsOneWidget);
        expect(pill('this month'), findsNothing);
        await tester.tap(pill('this week'));
        await settle(tester);
        expect(find.text('This week'), findsOneWidget);
        expect(find.byType(Pill), findsNothing);

        await tester.tap(find.text('Year'));
        await settle(tester);
        expect(find.byType(Pill), findsNothing, reason: 'this year');
        await _swipe(tester, const Offset(-200, 0));
        expect(find.text('2027'), findsOneWidget);
        expect(pill('this year'), findsOneWidget);
        await tester.tap(pill('this year'));
        await settle(tester);
        expect(_total('493,610'), findsWidgets);
        expect(find.byType(Pill), findsNothing);

        // The month tab still remembers where it was.
        await tester.tap(find.text('Month'));
        await settle(tester);
        expect(find.text('Aug 2026'), findsOneWidget);
        expect(pill('this month'), findsOneWidget);
        await closeApp(tester, db);
      });

      testWidgets('Custom has no pill', (tester) async {
        final db = await sampleDatabase(tester);
        await pumpApp(tester, db: db, location: Routes.charts);
        await _swipe(tester, const Offset(200, 0));
        expect(find.byType(Pill), findsOneWidget);
        await tester.tap(find.text('Custom'));
        await settle(tester);
        await tester.tap(find.text('Confirm'));
        await settle(tester);
        expect(find.text('Sep 19 – Oct 18'), findsOneWidget);
        expect(find.byType(Pill), findsNothing);
        // Swiping does not move a custom range, and no pill appears.
        await _swipe(tester, const Offset(200, 0));
        expect(find.byType(Pill), findsNothing);
        await closeApp(tester, db);
      });
    });

    testWidgets('follows the current pocket', (tester) async {
      final db = await sampleDatabase(tester);
      late int other;
      await tester.runAsync(() async {
        other = await PocketsRepo(db).add(name: 'Trip', emoji: '\u{1F334}');
        await ExpensesRepo(db, clock: Clock.fixed(mockupNow)).add(
          pocketId: other,
          categoryId: 1,
          amount: 77700,
          day: dayOf(2026, 10, 3),
        );
      });
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: AppSettings(currentPocketId: other),
      );
      expect(find.text('777'), findsWidgets);
      expect(find.text('34,555'), findsNothing);
      await closeApp(tester, db);
    });
  });

  group('Category drill-down', () {
    testWidgets('summary, sort by amount or date', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.category(
          1,
          from: dayOf(2026, 10, 1),
          to: dayOf(2026, 10, 31),
        ),
      );
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Oct 2026'), findsOneWidget);
      expect(find.text('6,540'), findsOneWidget);
      expect(find.text('363'), findsOneWidget);
      expect(find.text('Dashed line = average 363'), findsOneWidget);
      expect(find.text('Peak 2,120'), findsOneWidget);

      await tester.ensureVisible(find.text('2,080'));
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('2,120'), lessThan(y('2,080')));
      await tester.tap(find.text('By date'));
      await settle(tester);
      expect(y('2,080'), lessThan(y('2,120')));
      expect(find.text('31.8%'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('the month pill opens the month pop-up', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.category(1));
      expect(find.text('Oct 2026'), findsOneWidget);
      await tester.tap(find.text('Oct 2026'));
      await settle(tester);
      expect(find.text('Month to show'), findsOneWidget);
      await tester.tap(find.text('Sep'));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(find.text('Sep 2026'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('a week range shows weekday columns', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.category(
          2,
          from: dayOf(2026, 10, 11),
          to: dayOf(2026, 10, 17),
        ),
      );
      expect(find.text('Oct 11 – Oct 17'), findsOneWidget);
      expect(find.text('Mon'), findsWidgets);
      await closeApp(tester, db);
    });

    testWidgets('a given pocket is shown, also after choosing another month',
        (tester) async {
      final db = await sampleDatabase(tester);
      late int trip;
      await tester.runAsync(() async {
        trip = await PocketsRepo(db).add(name: 'Trip', emoji: '\u{1F334}');
        final repo = ExpensesRepo(db, clock: Clock.fixed(mockupNow));
        await repo.add(
          pocketId: trip,
          categoryId: 1,
          amount: 77700,
          day: dayOf(2026, 10, 3),
        );
        await repo.add(
          pocketId: trip,
          categoryId: 1,
          amount: 55500,
          day: dayOf(2026, 9, 9),
        );
      });
      // Personal stays the pocket in use.
      await pumpApp(
        tester,
        db: db,
        location: Routes.category(
          1,
          from: dayOf(2026, 10, 1),
          to: dayOf(2026, 10, 31),
          pocket: trip,
        ),
      );
      expect(find.text('777'), findsWidgets);
      expect(find.text('6,540'), findsNothing, reason: 'not Personal');

      await tester.tap(find.text('Oct 2026'));
      await settle(tester);
      await tester.tap(find.text('Sep'));
      await settle(tester);
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(find.text('Sep 2026'), findsOneWidget);
      expect(find.text('555'), findsWidgets);
      expect(find.text('45,220'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('an unknown category says so', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.category(999));
      expect(find.byType(NotFoundCard), findsOneWidget);
      expect(find.text('Category not found'), findsOneWidget);
      expect(find.text('It may have been deleted.'), findsOneWidget);
      await closeApp(tester, db);
    });
  });
}
