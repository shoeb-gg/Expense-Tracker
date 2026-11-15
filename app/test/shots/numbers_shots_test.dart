@Tags(['shots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/features/charts/chart_parts.dart';
import 'package:spill_the_bills/features/reports/reports_screen.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/shots.dart';
import '../support/test_db.dart';

/// Screens of the "numbers" fixes: the monthly average, the inline Details
/// of a selected Charts row, and labels that used to be cut off. Each is
/// drawn at the default text size and at the largest.
void main() {
  setUpAll(loadShotFonts);

  final sizes = <String, AppSettings>{
    'default': const AppSettings(),
    'large': AppSettings(textScale: textScaleSteps.last),
  };

  Future<int> categoryId(WidgetTester tester, AppDatabase db, String name) async {
    final rows = await tester.runAsync(
      () => (db.select(db.categories)..where((c) => c.name.equals(name))).get(),
    );
    return rows!.single.id;
  }

  for (final entry in sizes.entries) {
    final size = entry.key;
    final settings = entry.value;

    testWidgets('numbers: charts, a selected row (ring scrolled away), $size',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: settings,
      );
      // Selected near the top: the ring and the row's Details both show.
      await tester.ensureVisible(find.text('Groceries'));
      await tester.pump();
      await tester.tap(find.text('Groceries'));
      await settle(tester);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 3000),
      );
      await settle(tester);
      await takeShot(tester, 'numbers_charts_selected_top_$size');

      // Scrolled to the list: only the row's Details is in view.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -3000),
      );
      await settle(tester);
      await tester.tap(find.text('Health').last);
      await settle(tester);
      expect(find.byType(DetailsPill), findsNWidgets(2));
      await takeShot(tester, 'numbers_charts_selected_list_$size');
      await closeApp(tester, db);
    });

    for (final name in ['Online Subscriptions', 'Transportation', 'Groceries']) {
      testWidgets('numbers: category summary, $name, $size', (tester) async {
        final db = await sampleDatabase(tester);
        final id = await categoryId(tester, db, name);
        await pumpApp(
          tester,
          db: db,
          location: Routes.category(
            id,
            from: dayOf(2026, 10, 1),
            to: dayOf(2026, 10, 31),
          ),
          settings: settings,
        );
        final slug = name.toLowerCase().replaceAll(' ', '_');
        await takeShot(tester, 'numbers_category_${slug}_$size');
        await closeApp(tester, db);
      });
    }

    testWidgets('numbers: category, year, first expense this month, $size',
        (tester) async {
      final db = openTestDatabase();
      await tester.runAsync(() async {
        await ExpensesRepo(db, clock: Clock.fixed(mockupNow)).add(
          pocketId: 1,
          categoryId: 1,
          amount: 39000,
          day: dayOf(2026, 10, 5),
        );
      });
      await pumpApp(
        tester,
        db: db,
        location: Routes.category(
          1,
          from: yearStart(2026),
          to: yearEnd(2026),
        ),
        settings: settings,
      );
      await takeShot(tester, 'numbers_category_year_na_$size');
      await closeApp(tester, db);
    });

    testWidgets('numbers: charts year, first expense this month, $size',
        (tester) async {
      final db = openTestDatabase();
      await tester.runAsync(() async {
        final repo = ExpensesRepo(db, clock: Clock.fixed(mockupNow));
        await repo.add(
          pocketId: 1,
          categoryId: 1,
          amount: 39000,
          day: dayOf(2026, 10, 5),
        );
      });
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: settings,
      );
      await tester.tap(find.text('Year'));
      await settle(tester);
      await takeShot(tester, 'numbers_charts_year_na_categories_$size');
      await tester.tap(find.text('Over time'));
      await settle(tester);
      await takeShot(tester, 'numbers_charts_year_na_overtime_$size');
      await closeApp(tester, db);
    });

    for (final (label, day) in [
      ('november', dayOf(2026, 11, 16)),
      ('september', dayOf(2026, 9, 16)),
    ]) {
      testWidgets('numbers: reports, month by month in $label, $size',
          (tester) async {
        final db = await sampleDatabase(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.reports,
          settings: settings,
          overrides: [todayProvider.overrideWithValue(day)],
        );
        final list = find.byType(Scrollable).first;
        await tester.drag(list, const Offset(0, -4000));
        await settle(tester);
        expect(find.byType(ReportsScreen), findsOneWidget);
        await takeShot(tester, 'numbers_reports_${label}_$size');
        await closeApp(tester, db);
      });
    }
  }
}
