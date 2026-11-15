@Tags(['shots'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/features/charts/range_popups.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/shots.dart';

/// The time-navigation screens: the "back to now" pill on Home, Calendar,
/// Charts and the three pop-ups, the pinned Calendar grid, future periods
/// and the Home month chip, at the default and at the largest text size.
void main() {
  setUpAll(loadShotFonts);

  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.dragFrom(Offset(dx > 0 ? 30 : 330, 420), Offset(dx, 0));
    await settle(tester);
  }

  for (final big in [false, true]) {
    final tag = big ? 'big' : 'std';
    final settings = AppSettings(textScale: big ? textScaleSteps.last : 1.0);

    testWidgets('home: this month (no pill) and September (pill) $tag',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, settings: settings);
      expect(find.byType(Pill), findsNothing);
      await takeShot(tester, 'time_home_now_$tag');
      await swipe(tester, 300);
      expect(find.byType(Pill), findsOneWidget);
      await takeShot(tester, 'time_home_back_$tag');
      await swipe(tester, -300);
      await swipe(tester, -300);
      await swipe(tester, -300);
      await takeShot(tester, 'time_home_future_$tag');
      await closeApp(tester, db);
    });

    testWidgets('calendar: this month, September, and Aug 2026 $tag',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.calendar(),
        settings: settings,
      );
      expect(find.byType(Pill), findsNothing);
      await takeShot(tester, 'time_calendar_now_$tag');
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await settle(tester);
      expect(find.byType(Pill), findsOneWidget);
      await takeShot(tester, 'time_calendar_back_$tag');
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.bySemanticsLabel('Next month'));
        await settle(tester);
      }
      await takeShot(tester, 'time_calendar_future_$tag');
      await closeApp(tester, db);

      final db2 = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db2,
        location: Routes.calendar(day: dayOf(2026, 8, 12)),
        settings: settings,
      );
      await takeShot(tester, 'time_calendar_aug_$tag');
      await closeApp(tester, db2);
    });

    testWidgets('charts: off the current period and in the future $tag',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: settings,
      );
      await takeShot(tester, 'time_charts_now_$tag');
      await swipe(tester, 300);
      await takeShot(tester, 'time_charts_month_back_$tag');
      await swipe(tester, -300);
      await swipe(tester, -300);
      await swipe(tester, -300);
      await takeShot(tester, 'time_charts_month_future_$tag');
      await tester.tap(find.text('Over time'));
      await settle(tester);
      await takeShot(tester, 'time_charts_month_future_columns_$tag');

      await tester.tap(find.text('Week'));
      await settle(tester);
      await swipe(tester, 300);
      await takeShot(tester, 'time_charts_week_back_$tag');

      await tester.tap(find.text('Year'));
      await settle(tester);
      await swipe(tester, -300);
      await swipe(tester, -300);
      await takeShot(tester, 'time_charts_year_future_$tag');
      await closeApp(tester, db);
    });

    testWidgets('pop-ups: date, month and year $tag', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, settings: settings);
      final ctx = tester.element(find.byType(Scaffold).first);

      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 9, 3)));
      await settle(tester);
      await takeShot(tester, 'time_pop_date_$tag');
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      unawaited(showMonthPicker(ctx, year: 2025, month: 3));
      await settle(tester);
      await takeShot(tester, 'time_pop_month_$tag');
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      unawaited(showYearPicker(ctx, year: 2031));
      await settle(tester);
      await takeShot(tester, 'time_pop_year_$tag');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await closeApp(tester, db);
    });
  }
}
