@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/router.dart';

import '../support/add_support.dart';
import '../support/shots.dart';

void main() {
  setUpAll(loadShotFonts);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await settle(tester);
  }

  testWidgets('Expense details with a receipt, and the delete question (NewExpense)', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await attachReceipt(tester, db);
    await pushRoute(tester, Routes.expense(doctorVisitId));
    await settleImages(tester);
    expect(find.text('Sunday, October 18, 2026'), findsOneWidget);
    expect(find.text('See all Health in October'), findsOneWidget);
    await takeShot(tester, 'expense_details');

    await tapText(tester, 'Delete');
    expect(find.text('Delete this expense?'), findsOneWidget);
    await takeShot(tester, 'expense_delete');
    await closeAppWithFiles(tester, db);
  });

  testWidgets('Expense details without a title or photo', (tester) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(() async {
      final repo = ExpensesRepo(db);
      final rent = await repo.get(1);
      await repo.update(rent!.copyWith(note: ''));
    });
    await pumpApp(tester, db: db, location: Routes.expense(1));
    expect(find.text('Title'), findsNothing);
    await takeShot(tester, 'expense_details_plain');
    await closeApp(tester, db);
  });

  testWidgets('Edit expense with a receipt, and its photo sheet (NewEdit, PopPhoto)', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await attachReceipt(tester, db);
    await pushRoute(tester, Routes.editExpense(doctorVisitId));
    await settleImages(tester);
    expect(find.text('1,180'), findsOneWidget);
    await takeShot(tester, 'expense_edit');

    await tester.tap(find.bySemanticsLabel('Receipt photo attached, tap to view or replace'));
    await settleImages(tester);
    expect(find.text('Choose from gallery'), findsOneWidget);
    await takeShot(tester, 'expense_edit_photo_sheet');
    await closeAppWithFiles(tester, db);
  });

  testWidgets('Edit expense with pockets, and the move sheet (PocketEditExpense, PocketMove)', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await addSamplePockets(tester, db);
    await pumpApp(tester, db: db);
    await attachReceipt(tester, db);
    await pushRoute(tester, Routes.editExpense(doctorVisitId));
    await settleImages(tester);
    await takeShot(tester, 'expense_edit_pocket');

    await tapText(tester, 'Personal');
    expect(find.text('Move to another pocket'), findsOneWidget);
    await takeShot(tester, 'expense_edit_pocket_move');
    await closeAppWithFiles(tester, db);
  });

  testWidgets('Receipt photo viewer (NewPhoto)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await attachReceipt(tester, db);
    await pushRoute(tester, Routes.expensePhoto(doctorVisitId));
    await settleImages(tester);
    expect(find.text('Pinch to zoom'), findsOneWidget);
    await takeShot(tester, 'expense_photo');
    await closeAppWithFiles(tester, db);
  });

  testWidgets('Missing photo file, and an expense that is gone', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    final name = await attachReceipt(tester, db);
    final store = appPhotoStore(tester);
    await tester.runAsync(() => store.delete(name));
    await pushRoute(tester, Routes.expensePhoto(doctorVisitId));
    await settleImages(tester);
    expect(find.text('Photo not found'), findsOneWidget);
    await takeShot(tester, 'expense_photo_missing');

    await tester.tap(find.byIcon(Symbols.close_rounded));
    await settle(tester);
    await pushRoute(tester, Routes.expense(99999));
    expect(find.text('Expense not found'), findsOneWidget);
    await takeShot(tester, 'expense_gone');
    await closeAppWithFiles(tester, db);
  });
}
