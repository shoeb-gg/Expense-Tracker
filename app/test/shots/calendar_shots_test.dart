@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/settings.dart';

import '../support/shots.dart';
import '../support/test_db.dart';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('calendar: October, today chosen', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar());
    expect(find.text('34,555 spent'), findsOneWidget);
    await takeShot(tester, 'calendar_default');
    await closeApp(tester, db);
  });

  testWidgets('calendar: a six-week month and an empty day', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2026, 8, 31)),
    );
    await takeShot(tester, 'calendar_aug2026');
    await closeApp(tester, db);
  });

  testWidgets('calendar: a day with nothing spent', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2026, 10, 9)),
    );
    await takeShot(tester, 'calendar_oct9_empty');
    await closeApp(tester, db);
  });

  testWidgets('calendar: the first month (previous arrow off)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2025, 1, 31)),
    );
    await takeShot(tester, 'calendar_jan2025');
    await closeApp(tester, db);
  });

  testWidgets('calendar: amounts off, weeks from Monday', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2026, 10, 12)),
      settings: const AppSettings(
        calendarAmounts: false,
        firstDayOfWeek: FirstDayOfWeek.monday,
      ),
    );
    await takeShot(tester, 'calendar_no_amounts_monday');
    await closeApp(tester, db);
  });

  testWidgets('calendar: a pocket with no expenses', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.calendar());
    await takeShot(tester, 'calendar_empty');
    await closeApp(tester, db);
  });
}
