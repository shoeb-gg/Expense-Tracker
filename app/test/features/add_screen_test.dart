import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/learned_words_repo.dart';
import 'package:spill_the_bills/features/add/add_events.dart';
import 'package:spill_the_bills/features/add/add_screen.dart';
import 'package:spill_the_bills/features/add/photo_picker.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/add_support.dart';
import '../support/receipt_photo.dart';
import '../support/shots.dart';
import '../support/test_db.dart';

const int snacks = 2;
const int gifts = 14;

/// 18 Oct 2026, the pinned test day.
const int today = 20744;

void main() {
  Future<AppDatabase> emptyDb(WidgetTester tester) async {
    final db = openTestDatabase();
    // Open (and seed) it in real async.
    await tester.runAsync(() => db.customSelect('SELECT 1').get());
    return db;
  }

  Future<List<Expense>> allExpenses(WidgetTester tester, AppDatabase db) async {
    final rows = await tester.runAsync(() => db.select(db.expenses).get());
    return rows!;
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

  Future<void> typeInBar(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText).last, text);
    await settle(tester);
  }

  /// Opens Add expense from Home's plus button.
  Future<void> openAdd(WidgetTester tester) async {
    await tap(tester, find.bySemanticsLabel('Add expense'));
    expect(find.byType(AddScreen), findsOneWidget);
  }

  testWidgets('opens with nothing chosen; the keypad calculates and saves', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db);
    await openAdd(tester);
    expect(find.text('Select a category'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await tap(tester, find.text('Snacks'));
    expect(find.text('Save'), findsOneWidget);
    await keys(tester, '1 2 0 + 3 0');
    expect(find.text('120 + 30'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await keys(tester, '=');
    expect(find.text('120 + 30'), findsNothing);
    expect(find.text('150'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'Coffee');
    await tap(tester, find.text('Save'));

    final rows = await allExpenses(tester, db);
    expect(rows, hasLength(1));
    expect(rows.single.amount, 15000);
    expect(rows.single.categoryId, snacks);
    expect(rows.single.note, 'Coffee');
    expect(rows.single.day, today);
    expect(rows.single.pocketId, 1);
    expect(find.byType(AddScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    final saved = appContainer(tester).read(lastSavedExpenseProvider);
    expect(saved?.id, rows.single.id);
    expect(saved?.day, today);
    await closeApp(tester, db);
  });

  testWidgets('four keys: × before +, divide by zero gives no result', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.add(),
      settings: const AppSettings(calcKeys: CalcKeys.allFour),
    );
    await tap(tester, find.text('Groceries'));
    expect(find.text('×'), findsOneWidget);
    expect(find.text('÷'), findsOneWidget);
    await keys(tester, '2 + 3 × 4');
    expect(find.text('14'), findsOneWidget);

    await keys(tester, '= ÷ 0');
    expect(find.textContaining('no result'), findsOneWidget);
    // "=" is greyed out and does nothing; there is no Save to tap.
    await keys(tester, '=');
    expect(find.textContaining('no result'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await tap(tester, find.bySemanticsLabel('Delete'));
    await keys(tester, '2 =');
    await tap(tester, find.text('Save'));
    final rows = await allExpenses(tester, db);
    expect(rows.single.amount, 700);
    expect(find.byType(AddScreen), findsNothing);

    // Plus and minus only: no × or ÷ keys.
    await tester.runAsync(
      () => appContainer(tester).read(settingsProvider.notifier).setCalcKeys(CalcKeys.plusMinus),
    );
    await settle(tester);
    await pushRoute(tester, Routes.add());
    await tap(tester, find.text('Groceries'));
    expect(find.text('×'), findsNothing);
    expect(find.text('+'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the same tile again goes back to the opening state; the chip too', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    await tap(tester, find.text('Snacks'));
    expect(find.text('Save'), findsOneWidget);
    await tap(tester, find.text('Snacks').first);
    expect(find.text('Select a category'), findsOneWidget);

    await tap(tester, find.text('Gym'));
    await tap(tester, find.bySemanticsLabel('Category: Gym'));
    expect(find.text('Select a category'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('typing bar: Add grows in and the camera slides over', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    final camera = find.bySemanticsLabel('Take a receipt photo');
    final add = find.widgetWithText(Pressable, 'Add');
    final start = tester.getRect(camera).left;
    expect(add, findsNothing);

    // The first letter: Add grows in over a few frames instead of the
    // camera jumping.
    await tester.enterText(find.byType(EditableText).last, 'c');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getRect(camera).left;
    expect(mid, lessThan(start));
    await settle(tester);
    final end = tester.getRect(camera).left;
    expect(mid, greaterThan(end));
    // Settled, it is the decided layout: the 40 px Add pill at the end of
    // the bar, 10 px after the camera, at full size.
    final pill = tester.getRect(add);
    expect(pill.height, 40);
    expect(pill.center.dy, tester.getRect(camera).center.dy);
    expect(pill.left - tester.getRect(camera).right, 10);
    expect(pill.right, start + 40);

    // Clearing the bar takes Add out the same way.
    await tester.enterText(find.byType(EditableText).last, '');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final back = tester.getRect(camera).left;
    expect(back, greaterThan(end));
    expect(back, lessThan(start));
    await settle(tester);
    expect(tester.getRect(camera).left, start);
    expect(add, findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('type to add: a new word, picked by hand, is learned', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db);
    await openAdd(tester);

    await typeInBar(tester, 'saree');
    expect(find.text('Now add the amount'), findsOneWidget);
    expect(find.text('Like “saree 120”'), findsOneWidget);

    await typeInBar(tester, 'saree 1200');
    expect(find.text('No category'), findsOneWidget);
    expect(find.text('Select a category above'), findsOneWidget);
    expect(find.text('So the app knows where “saree” goes'), findsOneWidget);
    expect(find.text('Saree · Today'), findsOneWidget);

    // The grey Add cannot save; it points at the grid instead.
    await tap(tester, find.text('Add'));
    expect(await allExpenses(tester, db), isEmpty);

    await tap(tester, find.text('Gifts'));
    expect(find.text('Select a category above'), findsNothing);
    expect(find.text('Next time, “saree” goes to Gifts.'), findsOneWidget);

    await tap(tester, find.text('Add'));
    final rows = await allExpenses(tester, db);
    expect(rows, hasLength(1));
    expect(rows.single.amount, 120000);
    expect(rows.single.categoryId, gifts);
    expect(rows.single.note, 'Saree');
    final learned = await tester.runAsync(() => LearnedWordsRepo(db).lookup(['saree']));
    expect(learned, {'saree': gifts});
    expect(find.byType(HomeScreen), findsOneWidget);

    // Next time the word goes to Gifts on its own.
    await openAdd(tester);
    await typeInBar(tester, 'saree 50');
    expect(find.text('No category'), findsNothing);
    expect(find.text('Next time, “saree” goes to Gifts.'), findsNothing);
    await tap(tester, find.text('Add'));
    final again = await allExpenses(tester, db);
    expect(again, hasLength(2));
    expect(again.last.categoryId, gifts);
    expect(again.last.amount, 5000);
    await closeApp(tester, db);
  });

  testWidgets('type to add: a category name matches and adds at once', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    await typeInBar(tester, 'snacks 555');
    expect(find.text('Select a category above'), findsNothing);
    await tap(tester, find.text('Add'));
    final rows = await allExpenses(tester, db);
    expect(rows.single.categoryId, snacks);
    expect(rows.single.amount, 55500);
    expect(rows.single.note, '');
    final learned = await tester.runAsync(() => LearnedWordsRepo(db).lookup(['snacks']));
    expect(learned, isEmpty);
    await closeApp(tester, db);
  });

  testWidgets('a word without an amount, then a tile: the keypad keeps the words', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    await typeInBar(tester, 'lunch with Sam');
    await tap(tester, find.text('Snacks'));
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Lunch with Sam'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Add expense on a given day, and the date pop-up', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.add(day: today - 3),
    );
    await tap(tester, find.text('Snacks'));
    expect(find.text('Oct 15'), findsOneWidget);
    await tap(tester, find.text('Oct 15'));
    expect(find.text('Date of this expense'), findsOneWidget);
    await tap(tester, find.text('17'));
    await tap(tester, find.text('Confirm'));
    expect(find.text('Yesterday'), findsOneWidget);
    await keys(tester, '9');
    await tap(tester, find.text('Save'));
    final rows = await allExpenses(tester, db);
    expect(rows.single.day, today - 1);
    await closeApp(tester, db);
  });

  testWidgets('/add?day= also dates a typed expense (Calendar "Add expense on")', (
    tester,
  ) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db, location: Routes.add(day: today - 3));
    expect(find.byType(AddScreen), findsOneWidget);
    await typeInBar(tester, 'snacks 50');
    expect(find.text('Oct 15'), findsOneWidget);
    await tap(tester, find.text('Add'));
    final rows = await allExpenses(tester, db);
    expect(rows.single.day, today - 3);
    expect(appContainer(tester).read(lastSavedExpenseProvider)?.day, today - 3);
    await closeApp(tester, db);
  });

  testWidgets('a receipt photo: camera, then removed, then from the gallery', (tester) async {
    final db = await emptyDb(tester);
    final temp = tempFolder('stb_add_test_');
    final source = await tester.runAsync(() => writeReceiptPhoto(temp));
    final picker = FakePhotoPicker(source!.path);
    await pumpApp(
      tester,
      db: db,
      location: Routes.add(),
      overrides: [photoPickerProvider.overrideWithValue(picker)],
    );
    await tap(tester, find.text('Health'));
    await keys(tester, '8 0 0');
    await tester.tap(find.byIcon(Symbols.photo_camera_rounded));
    await settleImages(tester);
    expect(picker.asked, [PhotoSource.camera]);
    final thumb = find.bySemanticsLabel('Receipt photo attached, tap to view or replace');
    expect(thumb, findsOneWidget);
    final folder = await tester.runAsync(() => appPhotoStore(tester).folder());
    List<String> photos() => folder!.listSync().map((f) => f.path).toList();
    expect(photos(), hasLength(1));

    // Remove it: the camera button comes back and the file goes.
    await tester.tap(thumb);
    await settleImages(tester);
    expect(find.text('Remove photo'), findsOneWidget);
    await tap(tester, find.text('Remove photo'));
    await settleImages(tester);
    expect(find.byIcon(Symbols.photo_camera_rounded), findsOneWidget);
    expect(photos(), isEmpty);

    // Backing out of the gallery attaches nothing.
    picker.path = null;
    await tap(tester, find.byIcon(Symbols.image_rounded));
    expect(find.byIcon(Symbols.photo_camera_rounded), findsOneWidget);

    picker.path = source.path;
    await tester.tap(find.byIcon(Symbols.image_rounded));
    await settleImages(tester);
    expect(picker.asked.last, PhotoSource.gallery);
    await tap(tester, find.text('Save'));
    await settleImages(tester);
    final rows = await allExpenses(tester, db);
    expect(rows.single.photoPath, isNotNull);
    expect(File('${folder!.path}/${rows.single.photoPath}').existsSync(), isTrue);
    await closeAppWithFiles(tester, db);
  });

  testWidgets('a picker that fails says so', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.add(),
      overrides: [photoPickerProvider.overrideWithValue(_FailingPicker())],
    );
    await tap(tester, find.text('Health'));
    await tap(tester, find.byIcon(Symbols.photo_camera_rounded));
    expect(find.text("Couldn't open the camera"), findsOneWidget);
    hideToast();
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });

  testWidgets('pockets: the pill shows with two pockets; Add saves in the picked one', (
    tester,
  ) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    expect(find.text('Personal'), findsNothing);
    await closeApp(tester, db);

    final db2 = await emptyDb(tester);
    final pockets = await addSamplePockets(tester, db2);
    await pumpApp(tester, db: db2, location: Routes.add());
    expect(find.text('Personal'), findsOneWidget);
    await tap(tester, find.text('Personal'));
    expect(find.text('Save in another pocket'), findsOneWidget);
    expect(find.text('It will be saved here'), findsOneWidget);
    await tap(tester, find.text('Business'));
    expect(find.text('Save in another pocket'), findsNothing);
    expect(find.text('Business'), findsOneWidget);

    await tap(tester, find.text('Snacks'));
    await keys(tester, '4 5');
    await tap(tester, find.text('Save'));
    final rows = await allExpenses(tester, db2);
    expect(rows.single.pocketId, pockets.business);
    expect(find.text('Saved in Business'), findsOneWidget);
    // The pocket the user is in does not change.
    expect(appContainer(tester).read(currentPocketIdProvider), 1);
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db2);
  });

  testWidgets('Manage opens Categories; Cancel closes without saving', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db);
    await openAdd(tester);
    await tap(tester, find.text('Manage'));
    expect(find.byType(AddScreen).hitTestable(), findsNothing);
    appContainer(tester).read(routerProvider).pop();
    await settle(tester);
    await tap(tester, find.text('Snacks'));
    await keys(tester, '5');
    await tap(tester, find.text('Cancel'));
    expect(find.byType(AddScreen), findsNothing);
    expect(await allExpenses(tester, db), isEmpty);
    await closeApp(tester, db);
  });
}

class _FailingPicker implements PhotoPicker {
  @override
  Future<String?> pick(PhotoSource source) => Future<String?>.error(StateError('no camera'));
}
