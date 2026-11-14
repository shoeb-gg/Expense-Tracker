@Tags(['shots'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/shots.dart';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('shell: Home tab with the bottom bar', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    expect(find.text('Spent in October'), findsOneWidget);
    expect(find.text('34,555'), findsOneWidget);
    await takeShot(tester, 'shell_home');

    await tester.tap(find.text('Settings'));
    await settle(tester);
    await takeShot(tester, 'shell_settings');
    await closeApp(tester, db);
  });

  testWidgets('date pop-up (PopDate default: Oct 12 chosen, today 18)',
      (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    final ctx = tester.element(find.byType(HomeScreen));
    unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
    await settle(tester);
    expect(find.text('Mon, Oct 12, 2026'), findsOneWidget);
    await takeShot(tester, 'pop_date');
    await closeApp(tester, db);
  });

  testWidgets('month pop-up and year view (PopMonth, PopYear)',
      (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    final ctx = tester.element(find.byType(HomeScreen));
    unawaited(showMonthPicker(ctx, year: 2026, month: 10));
    await settle(tester);
    await takeShot(tester, 'pop_month');

    await tester.tap(find.text('2026').last);
    await settle(tester);
    expect(find.text('2018 – 2029'), findsOneWidget);
    await takeShot(tester, 'pop_year');
    await closeApp(tester, db);
  });

  testWidgets('option sheet (PopWeekStart) and delete-all dialog',
      (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    final ctx = tester.element(find.byType(HomeScreen));
    unawaited(
      showOptionSheet<FirstDayOfWeek>(
        ctx,
        title: 'First day of the week',
        message: 'Used by the calendar and the weekly chart.',
        current: FirstDayOfWeek.sunday,
        options: [
          for (final d in FirstDayOfWeek.values) SheetOption(value: d, label: d.label),
        ],
      ),
    );
    await settle(tester);
    await takeShot(tester, 'pop_week_start');
    await tester.tap(find.text('Sunday').last);
    await settle(tester);

    unawaited(
      showAppDialog(
        ctx,
        title: 'Delete all data?',
        boldLine: 'All expenses, categories and photos',
        quietLine: "This can't be undone.",
        extra: DialogLinkRow(
          label: 'Save a copy first',
          actionLabel: 'Export',
          onTap: () {},
        ),
        tickLabel: 'Yes, erase everything',
        actionLabel: 'Delete all',
        destructive: true,
      ),
    );
    await settle(tester);
    await takeShot(tester, 'pop_delete_all');
    await tester.tap(find.text('Yes, erase everything'));
    await settle(tester);
    await takeShot(tester, 'pop_delete_all_ticked');
    await closeApp(tester, db);
  });
}
