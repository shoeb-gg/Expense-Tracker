import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/learned_words_repo.dart';
import 'package:spill_the_bills/features/add/add_events.dart';
import 'package:spill_the_bills/features/add/add_screen.dart';
import 'package:spill_the_bills/features/add/category_grid.dart';
import 'package:spill_the_bills/features/add/photo_picker.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/symbols.dart';
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

  group('typing a title on the keypad', () {
    // 28 px status bar + the 60 px header.
    const headerBottom = 88.0;
    final panel = find.byKey(const ValueKey('keypad'));

    for (final keyboard in [300.0, 360.0]) {
      testWidgets('keeps the header visible with a ${keyboard.round()} px keyboard', (
        tester,
      ) async {
        final db = await emptyDb(tester);
        await pumpApp(tester, db: db, location: Routes.add());
        await tap(tester, find.text('Snacks'));
        await keys(tester, '1 2 0');
        showSoftKeyboard(tester, height: keyboard);
        await tester.tap(find.byType(EditableText).first);
        await settle(tester);

        // Cancel and the title can be tapped, nothing lies over them.
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        expect(find.text('Add expense').hitTestable(), findsOneWidget);
        expect(tester.getTopLeft(panel).dy, greaterThanOrEqualTo(headerBottom));
        // The panel sits right on the keyboard and shows the category and
        // amount row and the title field, not the keys.
        expect(tester.getBottomLeft(panel).dy, 780 - keyboard);
        expect(find.bySemanticsLabel('Category: Snacks'), findsOneWidget);
        expect(find.text('120'), findsOneWidget);
        expect(find.byType(EditableText), findsOneWidget);
        expect(find.text('7'), findsNothing);
        expect(find.text('Save'), findsNothing);
        await closeApp(tester, db);
      });
    }

    testWidgets('the keys come back with the keyboard, and fold away smoothly', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db, location: Routes.add());
      await tap(tester, find.text('Snacks'));
      await keys(tester, '1 2 0');
      final full = tester.getSize(panel).height;
      expect(find.text('7'), findsOneWidget);

      showSoftKeyboard(tester);
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // Part way: the keys are still folding.
      final mid = tester.getSize(panel).height;
      expect(mid, lessThan(full));
      await settle(tester);
      final folded = tester.getSize(panel).height;
      expect(mid, greaterThan(folded));
      expect(folded, lessThan(full - 200));

      // Keyboard down (Done): the keys unfold again.
      hideSoftKeyboard(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getSize(panel).height, greaterThan(folded));
      await settle(tester);
      expect(tester.getSize(panel).height, full);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('the keys stay when the keyboard is down, even with the title focused', (
      tester,
    ) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db, location: Routes.add());
      await tap(tester, find.text('Snacks'));
      await keys(tester, '1 2 0');
      // Back closed the keyboard but the field kept its focus.
      await tester.tap(find.byType(EditableText).first);
      await settle(tester);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('the typing bar of the opening state is not folded', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db, location: Routes.add());
      showSoftKeyboard(tester);
      await tester.tap(find.byType(EditableText).last);
      await settle(tester);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(find.text('Select a category'), findsOneWidget);
      await closeApp(tester, db);
    });
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
    // A screen reader also hears why.
    expect(
      find.bySemanticsLabel('Select a category above. So the app knows where “saree” goes'),
      findsOneWidget,
    );
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

  testWidgets('type to add: "Select a category above" shows above the keyboard', (tester) async {
    final db = await emptyDb(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    showSoftKeyboard(tester);
    await tester.tap(find.byType(EditableText).last);
    await typeInBar(tester, 'saree 1200');

    // The prompt sits inside the bottom area, on the keyboard: nothing to
    // scroll to, nothing lies over it.
    final prompt = find.text('Select a category above');
    expect(prompt, findsOneWidget);
    expect(prompt.hitTestable(), findsOneWidget);
    final quick = tester.getRect(find.byKey(const ValueKey('quick')));
    expect(quick.bottom, 780 - 300);
    expect(tester.getRect(prompt).top, greaterThanOrEqualTo(quick.top));
    expect(tester.getRect(prompt).bottom, lessThanOrEqualTo(quick.bottom));

    // The grid keeps at least two whole rows above it.
    for (var i = 0; i < 8; i++) {
      final tile = tester.getRect(find.byType(CategoryTile).at(i));
      expect(tile.bottom, lessThanOrEqualTo(quick.top), reason: 'tile $i');
    }

    // The grid still scrolls under the bottom area.
    final first = find.text('Groceries');
    final before = tester.getRect(first).top;
    await tester.drag(first, const Offset(0, -120));
    await settle(tester);
    expect(tester.getRect(first).top, lessThan(before));
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
    // An amount is typed, so Cancel asks first.
    await tap(tester, find.text('Cancel'));
    expect(find.text('Discard this expense?'), findsOneWidget);
    await tap(tester, find.text('Discard'));
    expect(find.byType(AddScreen), findsNothing);
    expect(await allExpenses(tester, db), isEmpty);
    await closeApp(tester, db);
  });

  group('leaving with something entered', () {
    const heading = 'Discard this expense?';
    final dialog = find.text(heading);

    testWidgets('Cancel asks first; Keep editing stays, Discard closes', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db);
      await openAdd(tester);
      await tap(tester, find.text('Snacks'));
      await keys(tester, '5');

      await tap(tester, find.text('Cancel'));
      expect(dialog, findsOneWidget);
      expect(find.text('What you entered will be lost.'), findsOneWidget);
      expect(find.text('Keep editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Keep editing: still here, nothing lost.
      await tap(tester, find.text('Keep editing'));
      expect(dialog, findsNothing);
      expect(find.byType(AddScreen), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('5'), findsWidgets);

      // Cancel again, now Discard.
      await tap(tester, find.text('Cancel'));
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Discard'));
      expect(find.byType(AddScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(await allExpenses(tester, db), isEmpty);
      await closeApp(tester, db);
    });

    testWidgets('Cancel on an untouched screen closes at once', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db);
      await openAdd(tester);
      await tap(tester, find.text('Cancel'));
      expect(dialog, findsNothing);
      expect(find.byType(AddScreen), findsNothing);

      // A tile and the same tile again is back to nothing chosen.
      await openAdd(tester);
      await tap(tester, find.text('Snacks'));
      await tap(tester, find.text('Snacks').first);
      await tap(tester, find.text('Cancel'));
      expect(dialog, findsNothing);
      expect(find.byType(AddScreen), findsNothing);

      // Typed words, then cleared again.
      await openAdd(tester);
      await typeInBar(tester, 'coffee 5');
      await typeInBar(tester, '');
      await tap(tester, find.text('Cancel'));
      expect(dialog, findsNothing);
      expect(find.byType(AddScreen), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('a category alone, a typed expense, a title alone each count', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db);

      await openAdd(tester);
      await tap(tester, find.text('Snacks'));
      await tap(tester, find.text('Cancel'));
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Discard'));
      expect(find.byType(AddScreen), findsNothing);

      await openAdd(tester);
      await typeInBar(tester, 'saree 1200');
      await tap(tester, find.text('Cancel'));
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Discard'));
      expect(find.byType(AddScreen), findsNothing);

      // A title, with the category chosen and then taken away again.
      await openAdd(tester);
      await tap(tester, find.text('Snacks'));
      await tester.enterText(find.byType(EditableText).first, 'Coffee');
      await hideKeyboard(tester);
      await tap(tester, find.bySemanticsLabel('Category: Snacks'));
      expect(find.text('Select a category'), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Discard'));
      expect(find.byType(AddScreen), findsNothing);
      expect(await allExpenses(tester, db), isEmpty);
      await closeApp(tester, db);
    });

    testWidgets('the system Back button asks the same way', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db);
      await openAdd(tester);

      // Untouched: Back just closes.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(AddScreen), findsNothing);
      expect(dialog, findsNothing);

      await openAdd(tester);
      await tap(tester, find.text('Snacks'));
      await keys(tester, '5');
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(dialog, findsOneWidget);
      expect(find.byType(AddScreen), findsOneWidget);

      await tap(tester, find.text('Keep editing'));
      expect(dialog, findsNothing);
      expect(find.byType(AddScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Discard'));
      expect(find.byType(AddScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(await allExpenses(tester, db), isEmpty);
      await closeApp(tester, db);
    });

    testWidgets('a title alone turns Back into a question too', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db);
      await openAdd(tester);
      await tap(tester, find.text('Snacks'));
      // The title is typed last, with no screen update of its own after it.
      await tester.enterText(find.byType(EditableText).first, 'Coffee');
      await hideKeyboard(tester);
      await tap(tester, find.bySemanticsLabel('Category: Snacks'));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      await closeApp(tester, db);
    });

    testWidgets('opened as the first screen, Discard goes home', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db, location: Routes.add());
      await tap(tester, find.text('Snacks'));
      await keys(tester, '5');
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Discard'));
      expect(find.byType(AddScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      await closeApp(tester, db);
    });

    /// Whether the soft keyboard would be open: a text field has focus.
    bool aFieldHasFocus(WidgetTester tester) => tester
        .widgetList<EditableText>(find.byType(EditableText))
        .any((field) => field.focusNode.hasFocus);

    /// The phone's steps: the title field is tapped (keyboard up), Back
    /// closes the keyboard but the field keeps its focus.
    Future<void> focusTitleThenCloseKeyboard(WidgetTester tester) async {
      await tap(tester, find.text('Snacks'));
      await keys(tester, '5');
      showSoftKeyboard(tester);
      await tester.tap(find.byType(EditableText).first);
      await settle(tester);
      hideSoftKeyboard(tester);
      await settle(tester);
      expect(aFieldHasFocus(tester), isTrue, reason: 'the title keeps focus after Back');
    }

    testWidgets('Cancel, then Keep editing: the keyboard stays down, the keys show', (
      tester,
    ) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db, location: Routes.add());
      await focusTitleThenCloseKeyboard(tester);

      await tap(tester, find.text('Cancel'));
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      expect(dialog, findsNothing);

      // The screen is as it was before Cancel: no field has focus (so the
      // keyboard does not open again) and the keys are showing.
      expect(aFieldHasFocus(tester), isFalse);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('system Back, then Keep editing: the keyboard stays down too', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db, location: Routes.add());
      await focusTitleThenCloseKeyboard(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      expect(dialog, findsNothing);
      expect(aFieldHasFocus(tester), isFalse);
      expect(find.text('7'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('Cancel with the keyboard still open: Keep editing leaves it closed', (
      tester,
    ) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db, location: Routes.add());
      await tap(tester, find.text('Snacks'));
      await keys(tester, '5');
      showSoftKeyboard(tester);
      await tester.tap(find.byType(EditableText).first);
      await settle(tester);
      expect(aFieldHasFocus(tester), isTrue);

      await tap(tester, find.text('Cancel'));
      expect(dialog, findsOneWidget);
      hideSoftKeyboard(tester);
      await tap(tester, find.text('Keep editing'));
      expect(dialog, findsNothing);
      expect(aFieldHasFocus(tester), isFalse);
      await closeApp(tester, db);
    });

    testWidgets('the typing bar of the opening state is not refocused either', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db, location: Routes.add());
      showSoftKeyboard(tester);
      await tester.tap(find.byType(EditableText).last);
      await settle(tester);
      await typeInBar(tester, 'coffee 5');
      hideSoftKeyboard(tester);
      await settle(tester);
      expect(aFieldHasFocus(tester), isTrue);

      await tap(tester, find.text('Cancel'));
      expect(dialog, findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      expect(aFieldHasFocus(tester), isFalse);
      expect(find.text('coffee 5'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('after Save nothing is asked', (tester) async {
      final db = await emptyDb(tester);
      await pumpApp(tester, db: db);
      await openAdd(tester);
      await tap(tester, find.text('Snacks'));
      await keys(tester, '5');
      await tap(tester, find.text('Save'));
      expect(dialog, findsNothing);
      expect(find.byType(AddScreen), findsNothing);
      expect(await allExpenses(tester, db), hasLength(1));
      await closeApp(tester, db);
    });

    testWidgets('Edit: untouched closes at once, a change asks "Discard changes?"', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      await pushRoute(tester, Routes.editExpense(doctorVisitId));
      expect(find.text('Edit expense'), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(AddScreen), findsNothing);

      // 1,180 -> 118: a change.
      await pushRoute(tester, Routes.editExpense(doctorVisitId));
      await tap(tester, find.bySemanticsLabel('Delete'));
      await tap(tester, find.text('Cancel'));
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('What you entered will be lost.'), findsOneWidget);
      expect(find.text('Keep editing'), findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      expect(find.byType(AddScreen), findsOneWidget);

      // Typing the zero back makes it the original again: not a change.
      await tap(tester, find.text('0').last);
      expect(find.text('1,180'), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(AddScreen), findsNothing);
      final unchanged = await tester.runAsync(() => db.select(db.expenses).get());
      expect(unchanged!.firstWhere((e) => e.id == doctorVisitId).amount, 118000);
      await closeApp(tester, db);
    });

    testWidgets('Edit: a new title, day or category counts; Discard keeps the original', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);

      // Title.
      await pushRoute(tester, Routes.editExpense(doctorVisitId));
      await tester.enterText(find.byType(EditableText).first, 'Doctor visit, follow-up');
      await hideKeyboard(tester);
      await tap(tester, find.text('Cancel'));
      expect(find.text('Discard changes?'), findsOneWidget);
      await tap(tester, find.text('Discard'));
      expect(find.byType(AddScreen), findsNothing);

      // Day.
      await pushRoute(tester, Routes.editExpense(doctorVisitId));
      await tap(tester, find.text('Today'));
      await tap(tester, find.text('12'));
      await tap(tester, find.text('Confirm'));
      await tap(tester, find.text('Cancel'));
      expect(find.text('Discard changes?'), findsOneWidget);
      await tap(tester, find.text('Discard'));
      expect(find.byType(AddScreen), findsNothing);

      // Category, and back to the first one.
      await pushRoute(tester, Routes.editExpense(doctorVisitId));
      await tap(tester, find.text('Gifts'));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      await tap(tester, find.text('Health').first);
      await tap(tester, find.text('Cancel'));
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(AddScreen), findsNothing);

      final rows = await tester.runAsync(() => db.select(db.expenses).get());
      final visit = rows!.firstWhere((e) => e.id == doctorVisitId);
      expect(visit.note, 'Doctor visit');
      expect(visit.amount, 118000);
      await closeApp(tester, db);
    });

    testWidgets('Edit: a new pocket counts', (tester) async {
      final db = await sampleDatabase(tester);
      await addSamplePockets(tester, db);
      await pumpApp(tester, db: db);
      await pushRoute(tester, Routes.editExpense(doctorVisitId));
      await tap(tester, find.text('Personal'));
      await tap(tester, find.text('Business'));
      await tap(tester, find.text('Cancel'));
      expect(find.text('Discard changes?'), findsOneWidget);
      await tap(tester, find.text('Discard'));
      expect(find.byType(AddScreen), findsNothing);
      await closeApp(tester, db);
    });
  });
}

class _FailingPicker implements PhotoPicker {
  @override
  Future<String?> pick(PhotoSource source) => Future<String?>.error(StateError('no camera'));
}
