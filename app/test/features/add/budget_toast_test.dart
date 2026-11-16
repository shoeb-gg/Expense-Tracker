import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/budgets_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/add/add_screen.dart';
import 'package:spill_the_bills/features/add/budget_alert.dart';
import 'package:spill_the_bills/features/add/category_grid.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/budgets.dart';
import 'package:spill_the_bills/theme/symbols.dart';

import '../../support/shots.dart';
import '../../support/test_db.dart';

/// Seeded default category ids.
const int snacks = 2;
const int groceries = 1;

/// 18 Oct 2026, the pinned test day.
const int today = 20744;

void main() {
  late AppDatabase db;
  late int pocket;

  Future<void> setUpDb(WidgetTester tester, {int? budget, int spent = 0, int category = snacks}) async {
    db = openTestDatabase();
    await tester.runAsync(() async {
      pocket = (await PocketsRepo(db).defaultPocket()).id;
      if (budget != null) await BudgetsRepo(db).set(pocket, category, budget);
      if (spent > 0) {
        await ExpensesRepo(db).add(pocketId: pocket, categoryId: category, amount: spent, day: today - 3);
      }
    });
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> keys(WidgetTester tester, String typed) async {
    for (final k in typed.split(' ')) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await settle(tester);
  }

  /// Opens Add expense, picks [category] and saves [amount] on the keypad.
  Future<void> addOnKeypad(WidgetTester tester, String category, String amount) async {
    await pumpApp(tester, db: db, location: Routes.add());
    await tap(tester, find.text(category).first);
    await keys(tester, amount.split('').join(' '));
    await tap(tester, find.text('Save'));
  }

  /// Lets the toast time out, then closes the app.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await closeApp(tester, db);
  }

  testWidgets('going over: a red toast says by how much', (tester) async {
    await setUpDb(tester, budget: 500000, spent: 480000);
    await addOnKeypad(tester, 'Snacks', '800');
    expect(find.byType(AddScreen), findsNothing);
    expect(find.text('Snacks is 600 over budget'), findsOneWidget);
    expect(find.text('5,600 of 5,000 spent this month'), findsOneWidget);
    expect(find.byIcon(Symbols.error_rounded), findsOneWidget);
    await finish(tester);
  });

  testWidgets('passing 90%: a yellow toast with the share and what is left', (tester) async {
    await setUpDb(tester, budget: 500000, spent: 400000);
    await addOnKeypad(tester, 'Snacks', '600');
    expect(find.text('Snacks has used 92% of its budget'), findsOneWidget);
    expect(find.text('4,600 of 5,000 spent this month · 400 left'), findsOneWidget);
    expect(find.byIcon(Symbols.trending_up_rounded), findsOneWidget);
    await finish(tester);
  });

  testWidgets('already past 90%: no toast for another small one', (tester) async {
    await setUpDb(tester, budget: 500000, spent: 460000);
    await addOnKeypad(tester, 'Snacks', '100');
    expect(find.byType(BudgetAlertMark), findsNothing);
    expect(find.textContaining('budget'), findsNothing);
    await finish(tester);
  });

  testWidgets('no budget: no toast', (tester) async {
    await setUpDb(tester, budget: 500000, spent: 490000);
    await addOnKeypad(tester, 'Groceries', '99999');
    expect(find.byType(BudgetAlertMark), findsNothing);
    await finish(tester);
  });

  testWidgets('type to add tells too', (tester) async {
    await setUpDb(tester, budget: 500000, spent: 480000);
    await pumpApp(tester, db: db, location: Routes.add());
    await tester.enterText(find.byType(EditableText).last, 'snacks 800');
    await settle(tester);
    await tap(tester, find.text('Add').last);
    expect(find.text('Snacks is 600 over budget'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('editing an expense up past the budget tells too', (tester) async {
    await setUpDb(tester, budget: 500000, spent: 300000);
    final id = await tester.runAsync(
      () => ExpensesRepo(db).add(pocketId: pocket, categoryId: snacks, amount: 10000, day: today),
    );
    await pumpApp(tester, db: db, location: Routes.editExpense(id!));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Symbols.backspace_rounded));
      await tester.pump();
    }
    await keys(tester, '2 5 0 0');
    await tap(tester, find.text('Save'));
    expect(find.text('Snacks is 500 over budget'), findsOneWidget);
    expect(find.text('5,500 of 5,000 spent this month'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the ring on Add expense shows the real spending', (tester) async {
    await setUpDb(tester, budget: 500000, spent: 460000);
    await pumpApp(tester, db: db, location: Routes.add());
    final tile = tester.widget<CategoryTile>(
      find.ancestor(of: find.text('Snacks').first, matching: find.byType(CategoryTile)),
    );
    expect(tile.budget, const BudgetUse(spent: 460000, budget: 500000));
    final groceriesTile = tester.widget<CategoryTile>(
      find.ancestor(of: find.text('Groceries').first, matching: find.byType(CategoryTile)),
    );
    expect(groceriesTile.budget, isNull);
    await closeApp(tester, db);
  });
}
