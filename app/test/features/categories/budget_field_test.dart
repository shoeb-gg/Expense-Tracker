import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/categories/category_form_screen.dart';
import 'package:spill_the_bills/router.dart';

import '../../support/shots.dart';

/// The category form's budget field (phone test 2026-11-17).
void main() {
  setUpAll(loadShotFonts);

  Future<void> typeBudget(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText).at(1), text);
    await settle(tester);
  }

  testWidgets('a budget stops at 9 digits, like an expense', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.newCategory);
    await tester.enterText(find.byType(EditableText).first, 'Trips');
    await typeBudget(tester, '999999999.99');
    expect(find.textContaining('at most 9 digits'), findsNothing);
    await typeBudget(tester, '1000000000');
    expect(find.text('A budget has at most 9 digits.'), findsOneWidget);
    await typeBudget(tester, '999999999999999');
    expect(find.text('A budget has at most 9 digits.'), findsOneWidget);
    await closeApp(tester, db);
  });

  test('a long pocket name in the note: no full stop after "…"', () {
    Pocket pocket(String name) => Pocket(
      id: 2,
      name: name,
      emoji: '💼',
      sortOrder: 1,
      isDefault: false,
      createdAt: DateTime(2026),
    );
    expect(budgetNote(pocket('Business')), 'Only for 💼 Business. Each pocket has its own budgets.');
    final long = budgetNote(pocket('A very long pocket name here'));
    expect(long, isNot(contains('….')));
    expect(long, endsWith('Each pocket has its own budgets.'));
    expect(budgetNote(null), 'The same amount every month. Leave it empty for no budget.');
  });
}
