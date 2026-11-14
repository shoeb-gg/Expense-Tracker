@Tags(['shots'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/home/home_list.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/features/home/home_state.dart';
import 'package:spill_the_bills/features/home/pocket_button.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/pocket_samples.dart';
import '../support/shots.dart';

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(HomeScreen, skipOffstage: false)),
);

void main() {
  setUpAll(loadShotFonts);

  // PocketHome board.
  testWidgets('Home, October in Personal', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await takeShot(tester, 'home_default');
    await closeApp(tester, db);
  });

  // PocketHome with the eye toggled (state {"hidden": true}).
  testWidgets('Home, total masked by privacy hide', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      settings: const AppSettings(privacyMask: true),
    );
    await takeShot(tester, 'home_masked');
    await closeApp(tester, db);
  });

  // PocketHome scrolled to the end: the "See September" button.
  testWidgets('Home, end of the list', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    final list = find.descendant(
      of: find.byType(HomeMonthList),
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 8; i++) {
      await tester.drag(list, const Offset(0, -2000));
      await settle(tester);
    }
    expect(find.text('See September'), findsOneWidget);
    await takeShot(tester, 'home_end');
    await closeApp(tester, db);
  });

  // PocketSwitch board: "Your pockets" open over Home.
  testWidgets('Home, pocket switch open', (tester) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(() => addMockupPockets(db));
    await pumpApp(tester, db: db);
    await tester.tap(find.byType(PocketButton));
    await settle(tester);
    await takeShot(tester, 'home_switch');
    await closeApp(tester, db);
  });

  // PocketSwitch with Business in use.
  testWidgets('Home, pocket switch with Business in use', (tester) async {
    final db = await sampleDatabase(tester);
    final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
    await pumpApp(
      tester,
      db: db,
      settings: AppSettings(currentPocketId: ids.business),
    );
    await takeShot(tester, 'home_business');
    await tester.tap(find.byType(PocketButton));
    await settle(tester);
    await takeShot(tester, 'home_switch_business');
    await closeApp(tester, db);
  });

  // PopMonth board (drawn over Home).
  testWidgets('Home, month pop-up', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await tester.tap(find.bySemanticsLabel('Choose month, October 2026'));
    await settle(tester);
    await takeShot(tester, 'home_month_pop');
    await closeApp(tester, db);
  });

  // NewQuickMenu board: holding the Today row.
  testWidgets('Home, hold an expense', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await tester.longPress(find.text('Doctor visit'));
    await settle(tester);
    await takeShot(tester, 'home_quick_menu');
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await takeShot(tester, 'home_delete_expense');
    await closeApp(tester, db);
  });

  // Not drawn: a month with nothing in it (November, after today).
  testWidgets('Home, empty month', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    _container(
      tester,
    ).read(homeMonthProvider.notifier).show((year: 2026, month: 11));
    await settle(tester);
    await takeShot(tester, 'home_empty_month');
    await closeApp(tester, db);
  });

  // Not drawn: a brand-new pocket.
  testWidgets('Home, new empty pocket', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    final container = _container(tester);
    final id = (await tester.runAsync(
      () =>
          container.read(pocketsRepoProvider).add(name: 'Savings', emoji: '💰'),
    ))!;
    await container.read(dataActionsProvider).switchPocket(id);
    await settle(tester);
    await takeShot(tester, 'home_new_pocket');
    await closeApp(tester, db);
  });

  // Not drawn: "Monthly total on Home" off.
  testWidgets('Home, monthly total off', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      settings: const AppSettings(showMonthlyTotal: false),
    );
    await takeShot(tester, 'home_total_off');
    await closeApp(tester, db);
  });

  // Not drawn: the calendar button off.
  testWidgets('Home, calendar button off', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      settings: const AppSettings(showCalendarButton: false),
    );
    await takeShot(tester, 'home_no_calendar');
    await closeApp(tester, db);
  });

  // September after a left-to-right swipe.
  testWidgets('Home, previous month after a swipe', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await tester.dragFrom(const Offset(30, 420), const Offset(300, 0));
    await settle(tester);
    expect(find.text('Spent in September'), findsOneWidget);
    await takeShot(tester, 'home_september');
    await closeApp(tester, db);
  });
}
