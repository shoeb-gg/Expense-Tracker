@Tags(['shots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/features/charts/chart_model.dart';
import 'package:spill_the_bills/features/charts/column_chart.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/settings.dart';

import '../support/shots.dart';
import '../support/test_db.dart';

/// Makes the phone [height] logical px tall (the Charts board is 1606 px, so
/// the whole screen fits in one shot like the mockup render).
Future<void> _tall(WidgetTester tester, double height) async {
  tester.view.physicalSize = Size(720, height * 2);
  await tester.pump();
  await settle(tester);
}

/// Weeks start on Monday on the Charts board.
const _monday = AppSettings(firstDayOfWeek: FirstDayOfWeek.monday);

void main() {
  setUpAll(loadShotFonts);

  testWidgets('charts: month, every view', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts);
    await _tall(tester, 1606);
    expect(find.text('34,555'), findsWidgets);
    await takeShot(tester, 'charts_month_categories');

    await tester.tap(find.text('Top days'));
    await settle(tester);
    await takeShot(tester, 'charts_month_topdays');

    await tester.tap(find.text('Over time'));
    await settle(tester);
    await takeShot(tester, 'charts_month_overtime');

    await tester.tap(find.text('Last month'));
    await settle(tester);
    await takeShot(tester, 'charts_lastmonth_overtime');
    await closeApp(tester, db);
  });

  testWidgets('charts: week and year', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts, settings: _monday);
    await _tall(tester, 1606);
    await tester.tap(find.text('Week'));
    await settle(tester);
    await takeShot(tester, 'charts_week_categories');
    await tester.tap(find.text('Over time'));
    await settle(tester);
    await takeShot(tester, 'charts_week_overtime');

    await tester.tap(find.text('Year'));
    await settle(tester);
    await takeShot(tester, 'charts_year_overtime');
    await tester.tap(find.text('Categories'));
    await settle(tester);
    await takeShot(tester, 'charts_year_categories');
    await tester.tap(find.text('Top days'));
    await settle(tester);
    await takeShot(tester, 'charts_year_topdays');
    await closeApp(tester, db);
  });

  testWidgets('charts: custom range pop-up and custom period', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts);
    await tester.tap(find.text('Custom'));
    await settle(tester);
    await takeShot(tester, 'charts_custom_popup');

    await tester.tap(find.text('7 days'));
    await settle(tester);
    await takeShot(tester, 'charts_custom_popup_7days');

    await tester.tap(find.text('30 days'));
    await settle(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    await _tall(tester, 1606);
    await takeShot(tester, 'charts_custom_categories');
    await closeApp(tester, db);
  });

  testWidgets('charts: a chosen slice and a pinned column', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts);
    await _tall(tester, 1606);
    await tester.tap(find.text('Groceries'));
    await settle(tester);
    await takeShot(tester, 'charts_selected_groceries');

    await tester.tap(find.text('Over time'));
    await settle(tester);
    // Oct 7 (index 6) of the month chart.
    final chart = tester.getTopLeft(find.byType(ColumnChart));
    await tester.tapAt(chart + Offset(38 + 254 / 31 * 6.5, 150));
    await settle(tester);
    await takeShot(tester, 'charts_pinned_oct7');
    await closeApp(tester, db);
  });

  testWidgets('charts: category drill-down', (tester) async {
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
    await _tall(tester, 834);
    expect(find.text('6,540'), findsOneWidget);
    await takeShot(tester, 'charts_category_groceries');
    await tester.tap(find.text('By date'));
    await settle(tester);
    await takeShot(tester, 'charts_category_bydate');
    await closeApp(tester, db);
  });

  testWidgets('charts: 2025 and the year pop-up', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts);
    await tester.tap(find.text('Year'));
    await settle(tester);
    await tester.tap(find.text('2025'));
    await settle(tester);
    expect(find.text(nothingToCompare), findsOneWidget);
    await takeShot(tester, 'charts_year2025_categories');
    // Tapping the chosen tab opens the year pop-up.
    await tester.tap(find.text('2025'));
    await settle(tester);
    await takeShot(tester, 'charts_year_popup');
    await closeApp(tester, db);
  });

  testWidgets('charts: nothing spent (designed here)', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.charts);
    await _tall(tester, 1000);
    await takeShot(tester, 'charts_empty_categories');
    await tester.tap(find.text('Top days'));
    await settle(tester);
    await takeShot(tester, 'charts_empty_topdays');
    await tester.tap(find.text('Over time'));
    await settle(tester);
    await takeShot(tester, 'charts_empty_overtime');
    await closeApp(tester, db);
  });

  testWidgets('charts: one category takes it all (designed here)',
      (tester) async {
    final db = openTestDatabase();
    await tester.runAsync(() async {
      final repo = ExpensesRepo(db, clock: Clock.fixed(mockupNow));
      await repo.add(pocketId: 1, categoryId: 1, amount: 120000, day: 20740);
      await repo.add(pocketId: 1, categoryId: 1, amount: 45050, day: 20744);
    });
    await pumpApp(tester, db: db, location: Routes.charts);
    await _tall(tester, 1000);
    await takeShot(tester, 'charts_single_category');
    await closeApp(tester, db);
  });
}
