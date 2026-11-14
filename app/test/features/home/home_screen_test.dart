import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/home/home_list.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/features/home/home_state.dart';
import 'package:spill_the_bills/features/home/pocket_button.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/pocket_samples.dart';
import '../../support/shots.dart';

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(HomeScreen, skipOffstage: false)),
);

String _location(WidgetTester tester) =>
    _container(tester).read(routerProvider).state.uri.toString();

/// A finger moving across the day list by [dx] (positive = left to right).
Future<void> _swipe(WidgetTester tester, double dx) async {
  final start = Offset(dx > 0 ? 30 : 330, 420);
  await tester.dragFrom(start, Offset(dx, 0));
  await settle(tester);
}

Finder _listScrollable() => find.descendant(
  of: find.byType(HomeMonthList),
  matching: find.byType(Scrollable),
);

/// Drags the day list until its end is on screen.
Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.drag(_listScrollable(), const Offset(0, -2000));
    await settle(tester);
  }
}

void main() {
  testWidgets('shows the month total and the days of October', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    expect(find.text('Spent in October'), findsOneWidget);
    expect(find.text('34,555'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Doctor visit'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    // Oct 17 has no title: the category stands alone.
    expect(find.text('Snacks'), findsWidgets);
    expect(find.text('Chips & soda'), findsNothing);
    await closeApp(tester, db);
  });

  group('swipe', () {
    testWidgets('finger left to right shows the previous month', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      await _swipe(tester, 300);
      expect(find.text('Spent in September'), findsOneWidget);
      expect(find.text('45,220'), findsOneWidget);
      await _swipe(tester, 300);
      expect(find.text('Spent in August'), findsOneWidget);
      expect(find.text('52,475'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('finger right to left shows the next month', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      await _swipe(tester, 300);
      expect(find.text('Spent in September'), findsOneWidget);
      await _swipe(tester, -300);
      expect(find.text('Spent in October'), findsOneWidget);
      await _swipe(tester, -300);
      expect(find.text('Spent in November'), findsOneWidget);
      expect(find.text('Nothing spent in November'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('a vertical move scrolls and keeps the month', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      await tester.dragFrom(const Offset(180, 600), const Offset(0, -300));
      await settle(tester);
      await tester.dragFrom(const Offset(180, 300), const Offset(0, 300));
      await settle(tester);
      expect(find.text('Spent in October'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('a short move is not a swipe', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      // Starts in the gap above the first day card, so no row is tapped.
      await tester.dragFrom(const Offset(100, 162), const Offset(16, 0));
      await settle(tester);
      expect(find.text('Spent in October'), findsOneWidget);
      await closeApp(tester, db);
    });
  });

  testWidgets('the month chip opens the month pop-up', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await tester.tap(find.bySemanticsLabel('Choose month, October 2026'));
    await settle(tester);
    expect(find.text('Month to show'), findsOneWidget);
    await tester.tap(find.text('Mar'));
    await settle(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(find.text('Spent in March'), findsOneWidget);
    expect(find.text('54,330'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('"See September" at the end of the list goes back a month', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await _scrollToEnd(tester);
    expect(find.text('See September'), findsOneWidget);
    await tester.tap(find.text('See September'));
    await settle(tester);
    expect(find.text('Spent in September'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the first month with expenses has no "See" button', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    _container(
      tester,
    ).read(homeMonthProvider.notifier).show((year: 2025, month: 1));
    await settle(tester);
    expect(find.text('Spent in January'), findsOneWidget);
    await _scrollToEnd(tester);
    final position = tester.state<ScrollableState>(_listScrollable()).position;
    expect(position.pixels, position.maxScrollExtent);
    expect(find.textContaining('See '), findsNothing);
    await closeApp(tester, db);
  });

  group('privacy and settings', () {
    testWidgets('privacy hide masks the total until the eye is tapped', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        settings: const AppSettings(privacyMask: true),
      );
      expect(find.text(maskedAmount), findsOneWidget);
      expect(find.text('34,555'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Show total'));
      await settle(tester);
      expect(find.text('34,555'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Hide total'));
      await settle(tester);
      expect(find.text(maskedAmount), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('without privacy hide the eye still hides it for now', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      expect(find.text('34,555'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Hide total'));
      await settle(tester);
      expect(find.text(maskedAmount), findsOneWidget);
      expect(_container(tester).read(settingsProvider).privacyMask, isFalse);
      await closeApp(tester, db);
    });

    testWidgets('monthly total off shows the count and no eye', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        settings: const AppSettings(showMonthlyTotal: false),
      );
      expect(find.text('34,555'), findsNothing);
      expect(find.text('Expenses in October'), findsOneWidget);
      expect(find.text('33'), findsOneWidget);
      expect(find.bySemanticsLabel('Hide total'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('the calendar button follows its setting', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      expect(find.bySemanticsLabel('Calendar'), findsOneWidget);
      await _container(
        tester,
      ).read(settingsProvider.notifier).setShowCalendarButton(false);
      await settle(tester);
      expect(find.bySemanticsLabel('Calendar'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('the calendar button opens the calendar', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      await tester.tap(find.bySemanticsLabel('Calendar'));
      await settle(tester);
      expect(_location(tester), Routes.calendar());
      await closeApp(tester, db);
    });
  });

  group('rows', () {
    Future<Expense> doctorVisit(AppDatabase db, WidgetTester tester) async {
      final rows = await tester.runAsync(
        () => (db.select(
          db.expenses,
        )..where((e) => e.day.equals(dayOf(2026, 10, 18)))).get(),
      );
      return rows!.single;
    }

    testWidgets('tapping a row opens its details', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      final e = await doctorVisit(db, tester);
      await tester.tap(find.text('Doctor visit'));
      await settle(tester);
      expect(_location(tester), Routes.expense(e.id));
      await closeApp(tester, db);
    });

    testWidgets('holding a row opens Edit, Delete, Details', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      final e = await doctorVisit(db, tester);
      await tester.longPress(find.text('Doctor visit'));
      await settle(tester);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await settle(tester);
      expect(_location(tester), Routes.editExpense(e.id));
      await closeApp(tester, db);
    });

    testWidgets('Delete in the menu asks first, removes it, and can undo', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      await tester.longPress(find.text('Doctor visit'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      // The same dialog as Details: no "can't be undone", there is Undo.
      expect(find.text('Delete this expense?'), findsOneWidget);
      expect(find.text('Doctor visit · 1,180'), findsOneWidget);
      expect(find.text("This can't be undone."), findsNothing);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Doctor visit'), findsOneWidget);

      await tester.longPress(find.text('Doctor visit'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(find.text('Doctor visit'), findsNothing);
      expect(find.text('33,375'), findsOneWidget);
      expect(find.text('Expense deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Expense deleted'), findsNothing);
      expect(find.text('Doctor visit'), findsOneWidget);
      expect(find.text('34,555'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('the Undo toast goes away by itself', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      await tester.longPress(find.text('Doctor visit'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(find.text('Expense deleted'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await settle(tester);
      expect(find.text('Expense deleted'), findsNothing);
      expect(find.text('Doctor visit'), findsNothing);
      await closeApp(tester, db);
    });
  });

  group('pocket switch', () {
    testWidgets('switching pocket changes everything on Home', (tester) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await pumpApp(tester, db: db);
      await tester.tap(find.byType(PocketButton));
      await settle(tester);
      expect(find.text('Your pockets'), findsOneWidget);
      expect(find.text('34,555 this month'), findsOneWidget);
      expect(find.text('18,240 this month'), findsOneWidget);
      expect(find.text('6,300 this month'), findsOneWidget);
      expect(find.text('In use'), findsOneWidget);

      await tester.tap(find.text('Business'));
      await settle(tester);
      expect(find.text('Your pockets'), findsNothing);
      expect(_container(tester).read(currentPocketIdProvider), ids.business);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('18,240'), findsOneWidget);
      expect(find.text('Office chairs'), findsOneWidget);
      expect(find.text('Doctor visit'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('the switch shows with a single pocket too', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      expect(find.byType(PocketButton), findsOneWidget);
      await tester.tap(find.byType(PocketButton));
      await settle(tester);
      expect(find.text('Your pockets'), findsOneWidget);
      expect(find.text('Add pocket'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('"Add pocket" and "Manage" open the pocket screens', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      await tester.tap(find.byType(PocketButton));
      await settle(tester);
      await tester.tap(find.text('Add pocket'));
      await settle(tester);
      expect(_location(tester), Routes.newPocket);
      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.byType(PocketButton));
      await settle(tester);
      await tester.tap(find.text('Manage'));
      await settle(tester);
      expect(_location(tester), Routes.pockets);
      await closeApp(tester, db);
    });

    testWidgets('a pocket with no expenses shows the empty card', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      final container = _container(tester);
      final id = (await tester.runAsync(
        () => container
            .read(pocketsRepoProvider)
            .add(name: 'Savings', emoji: '💰'),
      ))!;
      await container.read(dataActionsProvider).switchPocket(id);
      await settle(tester);
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Nothing in Savings yet'), findsOneWidget);
      expect(find.text('Tap + to add its first expense.'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await closeApp(tester, db);
    });
  });

  testWidgets('Add expense can jump Home to a month', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    _container(
      tester,
    ).read(homeMonthProvider.notifier).showDay(dayOf(2026, 7, 4));
    await settle(tester);
    expect(find.text('Spent in July'), findsOneWidget);
    expect(find.text('51,885'), findsOneWidget);
    await closeApp(tester, db);
  });
}
