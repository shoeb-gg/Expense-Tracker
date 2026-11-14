import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/features/add/add_screen.dart';
import 'package:spill_the_bills/features/expense/details_screen.dart';
import 'package:spill_the_bills/features/expense/photo_screen.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/add_support.dart';
import '../support/shots.dart';

const int gifts = 14;
const int health = 10;

void main() {
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  Future<Expense?> load(WidgetTester tester, AppDatabase db, int id) =>
      tester.runAsync<Expense?>(() => ExpensesRepo(db).get(id));

  testWidgets('Details: category, amount, title, date, photo, month link', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await attachReceipt(tester, db);
    await pushRoute(tester, Routes.expense(doctorVisitId));
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('1,180'), findsOneWidget);
    expect(find.text('Doctor visit'), findsOneWidget);
    expect(find.text('Sunday, October 18, 2026'), findsOneWidget);
    expect(find.textContaining('Added Oct 18, 2026 at '), findsOneWidget);
    expect(find.text('Receipt, tap to view'), findsOneWidget);
    // "in October" is held together by a no-break space.
    expect(find.text('See all Health in October'), findsOneWidget);

    await tap(tester, find.text('Receipt, tap to view'));
    expect(find.byType(PhotoScreen), findsOneWidget);
    expect(find.text('Receipt'), findsOneWidget);
    await tap(tester, find.bySemanticsLabel('Close'));
    expect(find.byType(PhotoScreen), findsNothing);
    await closeAppWithFiles(tester, db);
  });

  testWidgets('Delete asks first, then Undo brings the expense and its photo back', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    final photo = await attachReceipt(tester, db);
    final folder = await tester.runAsync(() => appPhotoStore(tester).folder());
    await pushRoute(tester, Routes.expense(doctorVisitId));

    // Cancel keeps it.
    await tap(tester, find.text('Delete'));
    expect(find.text('Delete this expense?'), findsOneWidget);
    expect(find.text('Doctor visit · 1,180'), findsOneWidget);
    // The board's second line, worded for the Undo that follows.
    expect(find.text('You can undo this right after.'), findsOneWidget);
    await tap(tester, find.text('Cancel'));
    expect(await load(tester, db, doctorVisitId), isNotNull);

    await tap(tester, find.text('Delete'));
    await tap(tester, find.text('Delete').last);
    expect(await load(tester, db, doctorVisitId), isNull);
    expect(find.byType(ExpenseDetailsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Expense deleted'), findsOneWidget);
    // The photo stays on the phone so Undo can bring it back.
    expect(File('${folder!.path}/$photo').existsSync(), isTrue);

    await tap(tester, find.text('Undo'));
    await settle(tester);
    final back = await load(tester, db, doctorVisitId);
    expect(back, isNotNull);
    expect(back!.photoPath, photo);
    expect(back.amount, 118000);
    expect(find.text('Expense deleted'), findsNothing);
    await tester.pump(const Duration(seconds: 7));
    await closeAppWithFiles(tester, db);
  });

  testWidgets('Edit: prefilled; amount, category and date change on Save', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await pushRoute(tester, Routes.expense(doctorVisitId));
    await tap(tester, find.text('Edit'));
    expect(find.byType(AddScreen), findsOneWidget);
    expect(find.text('Edit expense'), findsOneWidget);
    expect(find.text('1,180'), findsOneWidget);
    expect(find.text('Doctor visit'), findsWidgets);

    // Backspace twice and a zero: 1180 -> 11 -> 110.
    await tap(tester, find.bySemanticsLabel('Delete'));
    await tap(tester, find.bySemanticsLabel('Delete'));
    await tap(tester, find.text('0').last);
    expect(find.text('110'), findsOneWidget);

    // The chip does not clear the category on Edit.
    await tap(tester, find.bySemanticsLabel('Category: Health'));
    expect(find.text('Save'), findsOneWidget);

    await tap(tester, find.text('Gifts'));
    await tap(tester, find.text('Today'));
    await tap(tester, find.text('12'));
    await tap(tester, find.text('Confirm'));
    expect(find.text('Oct 12'), findsOneWidget);
    await tap(tester, find.text('Save'));

    final edited = await load(tester, db, doctorVisitId);
    expect(edited!.amount, 11000);
    expect(edited.categoryId, gifts);
    expect(edited.day, 20744 - 6);
    expect(edited.note, 'Doctor visit');
    // Back on Details, which shows the change.
    expect(find.byType(ExpenseDetailsScreen), findsOneWidget);
    expect(find.text('110'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Edit: removing the photo deletes its file on Save', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    final photo = await attachReceipt(tester, db);
    final folder = await tester.runAsync(() => appPhotoStore(tester).folder());
    await pushRoute(tester, Routes.editExpense(doctorVisitId));
    await settleImages(tester);
    await tester.tap(find.bySemanticsLabel('Receipt photo attached, tap to view or replace'));
    await settleImages(tester);
    await tap(tester, find.text('Remove photo'));
    // Not saved yet: the file is still there.
    expect(File('${folder!.path}/$photo').existsSync(), isTrue);
    await tap(tester, find.text('Save'));
    await settleImages(tester);
    final edited = await load(tester, db, doctorVisitId);
    expect(edited!.photoPath, isNull);
    expect(File('${folder.path}/$photo').existsSync(), isFalse);
    await closeAppWithFiles(tester, db);
  });

  testWidgets('Edit: move to another pocket on Save, then Undo', (tester) async {
    final db = await sampleDatabase(tester);
    final pockets = await addSamplePockets(tester, db);
    await pumpApp(tester, db: db);
    await pushRoute(tester, Routes.editExpense(doctorVisitId));
    expect(find.text('Personal'), findsOneWidget);

    await tap(tester, find.text('Personal'));
    expect(find.text('Move to another pocket'), findsOneWidget);
    expect(find.text('Now in this pocket'), findsOneWidget);
    await tap(tester, find.text('Business'));
    // Nothing moves until Save.
    expect((await load(tester, db, doctorVisitId))!.pocketId, 1);
    expect(find.text('Business'), findsOneWidget);

    await tap(tester, find.text('Save'));
    expect((await load(tester, db, doctorVisitId))!.pocketId, pockets.business);
    expect(find.text('Moved to Business'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tap(tester, find.text('Undo'));
    await settle(tester);
    expect((await load(tester, db, doctorVisitId))!.pocketId, 1);
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });

  testWidgets('a bad link shows a gone state, not an error', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.expense(-1));
    // The app's one "not found" card.
    expect(find.byType(NotFoundCard), findsOneWidget);
    expect(find.text('Expense not found'), findsOneWidget);
    expect(find.text('It may have been deleted.'), findsOneWidget);
    await pushRoute(tester, Routes.editExpense(424242));
    expect(find.text('Expense not found'), findsWidgets);
    expect(find.byType(NotFoundCard), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
    await pushRoute(tester, Routes.expensePhoto(424242));
    expect(find.text('Photo not found'), findsOneWidget);
    expect(find.text('Expense not found'), findsWidgets);
    expect(appContainer(tester).read(todayProvider), 20744);
    await closeApp(tester, db);
  });
}
