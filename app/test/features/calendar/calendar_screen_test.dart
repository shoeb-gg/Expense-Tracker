import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/features/add/add_screen.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/shots.dart';

/// Drags across the month grid. `by.dx > 0`: finger left to right;
/// `by.dy > 0`: finger top to bottom.
Future<void> _swipe(WidgetTester tester, Offset by) async {
  await tester.dragFrom(const Offset(180, 300), by);
  await settle(tester);
}

void main() {
  testWidgets('opens on this month with today chosen', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar());
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('34,555 spent'), findsOneWidget);
    // Only the day card says "Today": the pill is for when you have moved.
    expect(find.text('Today'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to today'), findsNothing);
    expect(find.text('Doctor visit'), findsOneWidget);
    expect(find.text('Health · 10:18 AM'), findsOneWidget);
    expect(find.text('Add expense on Oct 18'), findsOneWidget);
    expect(find.text('15K'), findsOneWidget);
    expect(find.text('1.7K'), findsOneWidget);
    expect(find.text('835'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('horizontal swipes: left to right shows the previous month, '
      'right to left the next', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar());
    await _swipe(tester, const Offset(200, 0));
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('45,220 spent'), findsOneWidget);
    // Another month opens on its 1st.
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('September 1'), findsOneWidget);
    await _swipe(tester, const Offset(200, 0));
    expect(find.text('August 2026'), findsOneWidget);
    await _swipe(tester, const Offset(-200, 0));
    expect(find.text('September 2026'), findsOneWidget);
    await _swipe(tester, const Offset(-200, 0));
    expect(find.text('October 2026'), findsOneWidget);
    // This month is not the last one: the future is endless too.
    await _swipe(tester, const Offset(-200, 0));
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('0 spent'), findsOneWidget);
    await _swipe(tester, const Offset(-200, 0));
    expect(find.text('December 2026'), findsOneWidget);
    await _swipe(tester, const Offset(-200, 0));
    expect(find.text('January 2027'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('vertical swipes: top to bottom shows the previous month, '
      'bottom to top the next', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar());
    await _swipe(tester, const Offset(0, 150));
    expect(find.text('September 2026'), findsOneWidget);
    await _swipe(tester, const Offset(0, 150));
    expect(find.text('August 2026'), findsOneWidget);
    await _swipe(tester, const Offset(0, -150));
    expect(find.text('September 2026'), findsOneWidget);
    await _swipe(tester, const Offset(0, -150));
    expect(find.text('October 2026'), findsOneWidget);
    await _swipe(tester, const Offset(0, -150));
    expect(find.text('November 2026'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the first month with expenses is not the earliest',
      (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2025, 1, 10)),
    );
    expect(find.text('January 2025'), findsOneWidget);
    expect(find.text('January 10, 2025'), findsOneWidget);
    // Before the first month with expenses: swipes and arrows keep going.
    await _swipe(tester, const Offset(200, 0));
    expect(find.text('December 2024'), findsOneWidget);
    expect(find.text('0 spent'), findsOneWidget);
    expect(find.text('December 1, 2024'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Previous month'));
    await settle(tester);
    expect(find.text('November 2024'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next month'));
    await settle(tester);
    expect(find.text('December 2024'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('this month has no last month: the next arrow goes on',
      (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar());
    await tester.tap(find.bySemanticsLabel('Next month'));
    await settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
    // A month still to come: its days cannot be chosen, the 1st shows.
    expect(find.text('November 1'), findsOneWidget);
    expect(find.text('Nothing spent on this day.'), findsOneWidget);
    await tester.tap(find.text('20'));
    await settle(tester);
    expect(find.text('November 1'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the month pop-up honours a month before the first expense',
      (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar());
    await tester.tap(find.text('October 2026'));
    await settle(tester);
    expect(find.text('Month to show'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Previous year'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Previous year'));
    await settle(tester);
    await tester.tap(find.text('Mar'));
    await settle(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    // The first expense is in January 2025; March 2024 still opens.
    expect(find.text('March 2024'), findsOneWidget);
    expect(find.text('March 1, 2024'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the month pop-up honours a month still to come',
      (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar());
    await tester.tap(find.text('October 2026'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Next year'));
    await settle(tester);
    await tester.tap(find.text('Feb'));
    await settle(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(find.text('February 2027'), findsOneWidget);
    expect(find.text('February 1, 2027'), findsOneWidget);
    await closeApp(tester, db);
  });

  group('scrolling', () {
    // The largest text size and a six-week month (Aug 2026): the most the
    // pinned part can take of a 360 x 780 screen.
    final big = AppSettings(textScale: textScaleSteps.last);
    final aug = Routes.calendar(day: dayOf(2026, 8, 31));

    ScrollableState page(WidgetTester tester) => tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          ),
        );

    testWidgets('a drag below the grid scrolls the page; the month bar, '
        'weekdays and grid stay put', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: aug, settings: big);
      final bar = tester.getTopLeft(find.text('August 2026')).dy;
      final weekdays = tester.getTopLeft(find.text('Sun')).dy;
      final grid = tester.getTopLeft(find.text('31').first).dy;
      expect(page(tester).position.pixels, 0);

      await tester.dragFrom(
        tester.getCenter(find.text('Less')),
        const Offset(0, -150),
      );
      await settle(tester);
      expect(page(tester).position.pixels, greaterThan(0));
      expect(tester.getTopLeft(find.text('August 2026')).dy, bar);
      expect(tester.getTopLeft(find.text('Sun')).dy, weekdays);
      expect(tester.getTopLeft(find.text('31').first).dy, grid);
      expect(find.text('August 2026'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('a vertical swipe on the grid changes the month and does '
        'not scroll the page', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: aug, settings: big);
      final grid = tester.getCenter(find.text('15'));
      await tester.dragFrom(grid, const Offset(0, 120));
      await settle(tester);
      expect(find.text('July 2026'), findsOneWidget);
      expect(page(tester).position.pixels, 0);
      await tester.dragFrom(grid, const Offset(0, -120));
      await settle(tester);
      expect(find.text('August 2026'), findsOneWidget);
      expect(page(tester).position.pixels, 0);
      await closeApp(tester, db);
    });

    testWidgets('the day card keeps room under the grid', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: aug, settings: big);
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      final legend = tester.getRect(find.text('Less'));
      final header = tester.getRect(find.text('Monday'));
      debugPrint('viewport $viewport legend $legend header $header');
      expect(legend.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(header.bottom, lessThanOrEqualTo(viewport.bottom));
      await closeApp(tester, db);
    });
  });

  testWidgets('tapping a day shows its card; a swipe never picks a day',
      (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar());
    await tester.tap(find.text('12'));
    await settle(tester);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('October 12'), findsOneWidget);
    expect(find.text('October bill'), findsOneWidget);
    expect(find.text('Add expense on Oct 12'), findsOneWidget);

    // Days still to come cannot be chosen.
    await tester.tap(find.text('25'));
    await settle(tester);
    expect(find.text('October 12'), findsOneWidget);

    // A swipe that ends on a day changes the month only.
    await tester.dragFrom(tester.getCenter(find.text('9')), const Offset(0, 80));
    await settle(tester);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('September 1'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('?day= chooses that day; an empty day says so', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2026, 10, 9)),
    );
    expect(find.text('October 9'), findsOneWidget);
    expect(find.text('Friday'), findsOneWidget);
    expect(find.text('Nothing spent on this day.'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Add expense opens Add for the chosen day', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2026, 10, 13)),
    );
    await tester.ensureVisible(find.text('Add expense on Oct 13'));
    await tester.tap(find.text('Add expense on Oct 13'));
    await settle(tester);
    expect(
      tester.widget<AddScreen>(find.byType(AddScreen)).day,
      dayOf(2026, 10, 13),
    );
    await closeApp(tester, db);
  });

  testWidgets('Today and the month pop-up', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar());
    await tester.tap(find.text('October 2026'));
    await settle(tester);
    expect(find.text('Month to show'), findsOneWidget);
    await tester.tap(find.text('Mar'));
    await settle(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(find.text('March 2026'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back to today'));
    await settle(tester);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Doctor visit'), findsOneWidget);
    await closeApp(tester, db);
  });

  group('back to today', () {
    Finder pill() => find.bySemanticsLabel('Back to today');

    bool forward(WidgetTester tester) =>
        tester.widget<SlideSwitcher>(find.byType(SlideSwitcher)).forward;

    testWidgets('shows once the view has moved, and fades away on return',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.calendar());
      expect(pill(), findsNothing);
      expect(find.byType(NowPill), findsOneWidget);

      await _swipe(tester, const Offset(200, 0));
      expect(find.text('September 2026'), findsOneWidget);
      expect(pill(), findsOneWidget);
      await _swipe(tester, const Offset(-200, 0));
      expect(find.text('October 2026'), findsOneWidget);
      // Back in October by hand: it opens on today, so the pill is gone.
      expect(pill(), findsNothing);
      await _swipe(tester, const Offset(-200, 0));
      expect(find.text('November 2026'), findsOneWidget);
      expect(pill(), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('a tap shows this month and chooses today', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.calendar());
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.bySemanticsLabel('Previous month'));
        await settle(tester);
      }
      expect(find.text('May 2026'), findsOneWidget);
      await tester.tap(pill());
      await tester.pump();
      expect(forward(tester), isTrue, reason: 'from the past: slide forward');
      await settle(tester);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Add expense on Oct 18'), findsOneWidget);
      expect(find.text('Doctor visit'), findsOneWidget);
      expect(pill(), findsNothing);

      for (var i = 0; i < 7; i++) {
        await tester.tap(find.bySemanticsLabel('Next month'));
        await settle(tester);
      }
      expect(find.text('May 2027'), findsOneWidget);
      await tester.tap(pill());
      await tester.pump();
      expect(forward(tester), isFalse, reason: 'from the future: slide back');
      await settle(tester);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Add expense on Oct 18'), findsOneWidget);
      expect(pill(), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('in this month it also brings back today after another day',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.calendar());
      await tester.tap(find.text('12'));
      await settle(tester);
      expect(find.text('Add expense on Oct 12'), findsOneWidget);
      expect(pill(), findsOneWidget);
      await tester.tap(pill());
      await settle(tester);
      expect(find.text('Add expense on Oct 18'), findsOneWidget);
      expect(pill(), findsNothing);
      await closeApp(tester, db);
    });
  });

  testWidgets('amounts can be turned off; weeks can start on Monday',
      (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(),
      settings: const AppSettings(
        calendarAmounts: false,
        firstDayOfWeek: FirstDayOfWeek.monday,
      ),
    );
    expect(find.text('15K'), findsNothing);
    expect(find.text('K = thousand'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Mon')).dx,
      lessThan(tester.getTopLeft(find.text('Sun')).dx),
    );
    // Oct 1, 2026 is a Thursday: the fourth column when weeks start Monday.
    final mon = tester.getCenter(find.text('Mon')).dx;
    final thu = tester.getCenter(find.text('Thu')).dx;
    expect((tester.getCenter(find.text('1')).dx - thu).abs(), lessThan(1));
    expect(thu, greaterThan(mon));
    await closeApp(tester, db);
  });
}
