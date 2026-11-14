import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/features/add/add_screen.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/settings.dart';

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
    expect(find.text('Today'), findsNWidgets(2)); // button and card
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
    // Another month opens on its last day.
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('September 30'), findsOneWidget);
    await _swipe(tester, const Offset(200, 0));
    expect(find.text('August 2026'), findsOneWidget);
    await _swipe(tester, const Offset(-200, 0));
    expect(find.text('September 2026'), findsOneWidget);
    await _swipe(tester, const Offset(-200, 0));
    expect(find.text('October 2026'), findsOneWidget);
    // This month is the last one.
    await _swipe(tester, const Offset(-200, 0));
    expect(find.text('October 2026'), findsOneWidget);
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
    await _swipe(tester, const Offset(0, -150));
    expect(find.text('October 2026'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the first month with expenses is the earliest', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2025, 1, 10)),
    );
    expect(find.text('January 2025'), findsOneWidget);
    expect(find.text('January 10, 2025'), findsOneWidget);
    await _swipe(tester, const Offset(200, 0));
    expect(find.text('January 2025'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Previous month'));
    await settle(tester);
    expect(find.text('January 2025'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next month'));
    await settle(tester);
    expect(find.text('February 2025'), findsOneWidget);
    await closeApp(tester, db);
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
    expect(find.text('September 30'), findsOneWidget);
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
    await tester.tap(find.text('Today').first);
    await settle(tester);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Doctor visit'), findsOneWidget);
    await closeApp(tester, db);
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
