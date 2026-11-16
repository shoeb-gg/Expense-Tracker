import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/add_support.dart';
import '../support/shots.dart';
import '../support/test_db.dart';

/// The "Show decimals" switch: off, saved amounts are shown in whole units
/// (half up); what is being typed and the stored amounts stay exact.
void main() {
  final today = dayOf(2026, 10, 18);
  const off = AppSettings(showDecimals: false);

  /// A database with one expense per amount (minor units), all on today.
  /// Returns the db and the id of the first expense.
  Future<(AppDatabase, int)> openWith(
    WidgetTester tester,
    List<int> amounts,
  ) async {
    final db = openTestDatabase();
    final id = await tester.runAsync(() async {
      final pocket = (await PocketsRepo(db).defaultPocket()).id;
      final repo = ExpensesRepo(db);
      var first = 0;
      for (final amount in amounts) {
        final id = await repo.add(
          pocketId: pocket,
          categoryId: 2,
          amount: amount,
          day: today,
          note: 'Coffee',
        );
        if (first == 0) first = id;
      }
      return first;
    });
    return (db, id!);
  }

  Future<void> keys(WidgetTester tester, String typed) async {
    for (final k in typed.split(' ')) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await settle(tester);
  }

  group('saved amounts are rounded when decimals are off', () {
    testWidgets('Home: 840.50 is "841"; with decimals on it is "840.50"', (
      tester,
    ) async {
      final (db, _) = await openWith(tester, [84050]);
      await pumpApp(tester, db: db, settings: off);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('841'), findsWidgets, reason: 'total and row');
      expect(find.text('840.50'), findsNothing);
      expect(find.text('840.5'), findsNothing);
      await closeApp(tester, db);

      final (db2, _) = await openWith(tester, [84050]);
      await pumpApp(tester, db: db2);
      expect(find.text('840.50'), findsWidgets);
      expect(find.text('841'), findsNothing);
      await closeApp(tester, db2);
    });

    testWidgets('Home: 840.25 is "840" and 0.50 is "1"', (tester) async {
      final (db, _) = await openWith(tester, [84025]);
      await pumpApp(tester, db: db, settings: off);
      expect(find.text('840'), findsWidgets);
      expect(find.text('840.25'), findsNothing);
      await closeApp(tester, db);

      final (db2, _) = await openWith(tester, [50]);
      await pumpApp(tester, db: db2, settings: off);
      expect(find.text('1'), findsWidgets);
      expect(find.text('0.50'), findsNothing);
      await closeApp(tester, db2);
    });

    testWidgets('totals are summed from exact amounts, then rounded', (
      tester,
    ) async {
      // 840.40 + 840.40 = 1,680.80: the total is 1,681, the rows are 840.
      final (db, _) = await openWith(tester, [84040, 84040]);
      await pumpApp(tester, db: db, settings: off);
      expect(find.text('1,681'), findsWidgets, reason: 'month and day total');
      expect(find.text('1,680'), findsNothing);
      expect(find.text('840'), findsNWidgets(2), reason: 'the two rows');
      await closeApp(tester, db);
    });

    testWidgets('Expense details', (tester) async {
      final (db, id) = await openWith(tester, [84050]);
      await pumpApp(tester, db: db, settings: off);
      await pushRoute(tester, Routes.expense(id));
      expect(find.text('841'), findsWidgets);
      expect(find.text('840.50'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('Calendar month total and day list', (tester) async {
      final (db, _) = await openWith(tester, [84050]);
      await pumpApp(tester, db: db, location: Routes.calendar(), settings: off);
      expect(find.text('841 spent'), findsOneWidget);
      expect(find.text('841'), findsWidgets, reason: 'day list row');
      expect(find.textContaining('840.50'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('Charts total and category rows', (tester) async {
      final (db, _) = await openWith(tester, [84050]);
      await pumpApp(tester, db: db, location: Routes.charts, settings: off);
      expect(find.text('841'), findsWidgets);
      expect(find.textContaining('840.50'), findsNothing);
      await closeApp(tester, db);
    });
  });

  group('what the user types stays exact', () {
    testWidgets('the keypad shows 840.5 and the sum 840.75 while typing', (
      tester,
    ) async {
      final (db, _) = await openWith(tester, []);
      await pumpApp(tester, db: db, location: Routes.add(), settings: off);
      await tester.tap(find.text('Snacks'));
      await settle(tester);
      await keys(tester, '8 4 0 . 5');
      expect(find.text('840.5'), findsOneWidget);
      expect(find.text('841'), findsNothing);
      await keys(tester, '+ 0 . 2 5');
      expect(find.text('840.5 + 0.25'), findsOneWidget, reason: 'the line');
      expect(find.text('840.75'), findsOneWidget, reason: 'the result');
      expect(find.text('841'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('type to add previews 840.50 and saves exact cents', (
      tester,
    ) async {
      final (db, _) = await openWith(tester, []);
      await pumpApp(tester, db: db, location: Routes.add(), settings: off);
      await tester.enterText(find.byType(EditableText).last, 'saree 840.50');
      await settle(tester);
      expect(find.text('840.50'), findsOneWidget, reason: 'the preview');
      expect(find.text('841'), findsNothing);
      await tester.tap(find.text('Gifts'));
      await settle(tester);
      await tester.tap(find.text('Add'));
      await settle(tester);
      final rows = await tester.runAsync(() => db.select(db.expenses).get());
      expect(rows!.single.amount, 84050, reason: 'stored data stays exact');
      // Home now shows it rounded.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('841'), findsWidgets);
      await closeApp(tester, db);
    });

    testWidgets('Edit expense opens with 840.5 in the keypad', (tester) async {
      final (db, id) = await openWith(tester, [84050]);
      await pumpApp(tester, db: db, settings: off);
      await pushRoute(tester, Routes.editExpense(id));
      expect(find.text('840.5'), findsOneWidget);
      expect(find.text('841'), findsNothing);
      await closeApp(tester, db);
    });
  });
}
