import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/budgets_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/home/home_list.dart';
import 'package:spill_the_bills/state/budgets.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/budget_ring.dart';

import '../../support/add_support.dart';
import '../../support/shots.dart';

/// Home's expense rows wear the same budget ring as the category tiles of Add
/// and Edit expense: on the category's emoji, for the month Home shows, in
/// the pocket Home shows, and only for categories with a budget.

const int _groceries = 1;
const int _snacks = 2;
const int _health = 10;

/// The first row on Home of an expense in [category].
Finder _rowOf(int category) =>
    find.byWidgetPredicate((w) => w is HomeExpenseRow && w.expense.categoryId == category).first;

/// The ring on [row], or null when it has none.
BudgetRingPainter? _ringOn(WidgetTester tester, Finder row) {
  final paints = find.descendant(
    of: row,
    matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is BudgetRingPainter),
  );
  if (paints.evaluate().isEmpty) return null;
  return tester.widget<CustomPaint>(paints).foregroundPainter! as BudgetRingPainter;
}

Future<void> _budget(WidgetTester tester, AppDatabase db, int pocket, int category, int amount) async {
  await tester.runAsync(() => BudgetsRepo(db).set(pocket, category, amount * 100));
}

void main() {
  testWidgets('a category with a budget wears its ring; one without does not', (tester) async {
    final db = await sampleDatabase(tester);
    // Health: 1,180 spent in October, over a budget of 1,000.
    await _budget(tester, db, 1, _health, 1000);
    await pumpApp(tester, db: db);
    final row = _rowOf(_health);
    final ring = _ringOn(tester, row);
    expect(ring, isNotNull);
    expect(ring!.progress, closeTo(1.18, 0.001));
    expect(ring.color, budgetColor(tester.element(row).colors, BudgetLevel.over));
    expect(ring.radius, 14, reason: 'the row tile is 44 px with 14 px corners');
    expect(_ringOn(tester, _rowOf(_snacks)), isNull);

    // Held: the lifted copy of the row wears the same ring.
    await tester.longPress(row);
    await settle(tester);
    final rows = find.byWidgetPredicate((w) => w is HomeExpenseRow && w.expense.categoryId == _health);
    expect(rows, findsNWidgets(2));
    expect(_ringOn(tester, rows.last)?.progress, closeTo(1.18, 0.001));
    await closeApp(tester, db);
  });

  testWidgets('the ring is for the month Home shows', (tester) async {
    final db = await sampleDatabase(tester);
    // Groceries: 6,540 in October, under a budget of 10,000.
    await _budget(tester, db, 1, _groceries, 10000);
    await pumpApp(tester, db: db);
    final october = tester.widget<HomeExpenseRow>(_rowOf(_groceries));
    expect(october.budget, const BudgetUse(spent: 654000, budget: 1000000));
    final ring = _ringOn(tester, _rowOf(_groceries))!;
    expect(ring.color, budgetColor(tester.element(_rowOf(_groceries)).colors, BudgetLevel.ok));

    // September's groceries are measured against September's spending.
    await tester.dragFrom(const Offset(30, 420), const Offset(300, 0));
    await settle(tester);
    final september = tester.widget<HomeExpenseRow>(_rowOf(_groceries));
    expect(dateOfDay(september.expense.day).month, 9);
    expect(september.budget, isNotNull);
    expect(september.budget!.spent, isNot(654000));
    await closeApp(tester, db);
  });

  testWidgets("another pocket's budget does not show", (tester) async {
    final db = await sampleDatabase(tester);
    final pockets = await addSamplePockets(tester, db);
    await _budget(tester, db, pockets.business, _health, 1000);
    await pumpApp(tester, db: db);
    expect(_ringOn(tester, _rowOf(_health)), isNull);
    await closeApp(tester, db);
  });
}
