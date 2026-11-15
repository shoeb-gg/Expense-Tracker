@Tags(['shots'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/learned_words_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/add/photo_picker.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/theme/symbols.dart';

import '../support/add_support.dart';
import '../support/receipt_photo.dart';
import '../support/shots.dart';

/// Category ids of the seeded defaults.
const int snacks = 2;

void main() {
  setUpAll(loadShotFonts);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
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
    await hideKeyboard(tester);
  }

  testWidgets('Add expense: when it opens (NewAdd)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    expect(find.text('Select a category'), findsOneWidget);
    await takeShot(tester, 'add_open');
    await closeApp(tester, db);
  });

  testWidgets('Add expense: keypad (NewAddKeypad) and an expression', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    await tapText(tester, 'Snacks');
    await keys(tester, '1 2 0');
    await tester.enterText(find.byType(EditableText).first, 'Coffee');
    await hideKeyboard(tester);
    expect(find.text('120'), findsOneWidget);
    await takeShot(tester, 'add_keypad');

    await keys(tester, '+ 3 0');
    expect(find.text('150'), findsOneWidget);
    await takeShot(tester, 'add_keypad_expression');
    await closeApp(tester, db);
  });

  testWidgets('Add expense: four calculator keys (NewAddCalc)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.add(),
      settings: const AppSettings(calcKeys: CalcKeys.allFour),
    );
    await tapText(tester, 'Snacks');
    await keys(tester, '1 2 0');
    await tester.enterText(find.byType(EditableText).first, 'Coffee');
    await hideKeyboard(tester);
    await takeShot(tester, 'add_calc');

    await keys(tester, '÷ 0');
    expect(find.textContaining('no result'), findsOneWidget);
    await takeShot(tester, 'add_calc_no_result');
    await closeApp(tester, db);
  });

  testWidgets('Type to add: word, matched, new word, picked (NewAddQuick*)', (tester) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(() => LearnedWordsRepo(db).learn('coffee', snacks));
    await pumpApp(tester, db: db, location: Routes.add());

    await typeInBar(tester, 'coffee');
    expect(find.text('Now add the amount'), findsOneWidget);
    await takeShot(tester, 'add_quick_word');

    await typeInBar(tester, 'coffee 120');
    expect(find.text('Coffee · Today'), findsOneWidget);
    await takeShot(tester, 'add_quick');

    await typeInBar(tester, 'saree 12000');
    expect(find.text('Select a category above'), findsOneWidget);
    await takeShot(tester, 'add_quick_new');

    await tapText(tester, 'Gifts');
    expect(find.text('Next time, “saree” goes to Gifts.'), findsOneWidget);
    await takeShot(tester, 'add_quick_picked');
    await closeApp(tester, db);
  });

  for (final (suffix, settings) in <(String, AppSettings)>[
    ('', const AppSettings()),
    ('_large', AppSettings(textScale: textScaleSteps.last)),
  ]) {
    testWidgets('Keypad: typing a title keeps the header visible$suffix', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.add(), settings: settings);
      await tapText(tester, 'Snacks');
      await keys(tester, '1 2 0');
      showSoftKeyboard(tester, height: 300);
      await tester.tap(find.byType(EditableText).first);
      await tester.enterText(find.byType(EditableText).first, 'Coffee with Sam');
      await takeShot(tester, 'add_title_keyboard$suffix');

      showSoftKeyboard(tester, height: 360);
      await takeShot(tester, 'add_title_keyboard_tall$suffix');

      hideSoftKeyboard(tester);
      await hideKeyboard(tester);
      await takeShot(tester, 'add_title_keys_back$suffix');
      await closeApp(tester, db);
    });
  }

  for (final (suffix, settings) in <(String, AppSettings)>[
    ('', const AppSettings()),
    ('_large', AppSettings(textScale: textScaleSteps.last)),
  ]) {
    testWidgets('Type to add: new word, then a pick, with the keyboard up$suffix', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.add(), settings: settings);
      showSoftKeyboard(tester, height: 300);
      await tester.tap(find.byType(EditableText).last);
      await tester.enterText(find.byType(EditableText).last, '250 for taxi');
      await settle(tester);
      expect(find.text('Select a category above'), findsOneWidget);
      expect(find.text('Taxi · Today'), findsOneWidget);
      await takeShot(tester, 'add_quick_new_keyboard$suffix');

      await tester.tap(find.text('Transportation').first);
      await settle(tester);
      expect(find.text('Next time, “taxi” goes to Transportation.'), findsOneWidget);
      await takeShot(tester, 'add_quick_picked_keyboard$suffix');
      await closeApp(tester, db);
    });
  }

  testWidgets('Add expense: the grid scrolled to its end, largest text', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.add(),
      settings: AppSettings(textScale: textScaleSteps.last),
    );
    await tester.drag(find.text('Groceries'), const Offset(0, -600));
    await settle(tester);
    await takeShot(tester, 'add_open_scrolled_large');
    await closeApp(tester, db);
  });

  testWidgets('Largest text: grid labels and the header (add, pocket pill, edit)', (tester) async {
    final db = await sampleDatabase(tester);
    await addSamplePockets(tester, db);
    await tester.runAsync(() => PocketsRepo(db).add(name: 'Test trip', emoji: '\u{1F9F3}'));
    final largest = AppSettings(textScale: textScaleSteps.last);
    await pumpApp(tester, db: db, location: Routes.add(), settings: largest);
    await takeShot(tester, 'add_open_pockets_large');

    await tapText(tester, 'Personal');
    await tester.tap(find.text('Test trip').last);
    await settle(tester);
    await takeShot(tester, 'add_pocket_test_trip_large');

    await tapText(tester, 'Snacks');
    await takeShot(tester, 'add_keypad_pocket_large');
    await closeApp(tester, db);
  });

  testWidgets('Largest text: Edit expense header', (tester) async {
    final db = await sampleDatabase(tester);
    await addSamplePockets(tester, db);
    await pumpApp(
      tester,
      db: db,
      location: Routes.editExpense(doctorVisitId),
      settings: AppSettings(textScale: textScaleSteps.last),
    );
    await takeShot(tester, 'add_edit_large');
    await closeApp(tester, db);
  });

  testWidgets('Largest text: sub-screen headers', (tester) async {
    final db = await sampleDatabase(tester);
    for (final (name, route) in <(String, String)>[
      ('categories', Routes.categories),
      ('pockets', Routes.pockets),
      ('export', Routes.export),
      ('new_category', Routes.newCategory),
    ]) {
      await pumpApp(
        tester,
        db: db,
        location: route,
        settings: AppSettings(textScale: textScaleSteps.last),
      );
      await takeShot(tester, 'subheader_${name}_large');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    await closeApp(tester, db);
  });

  testWidgets('Pockets: pill and the pick sheet (PocketAddExpense, PocketPick)', (tester) async {
    final db = await sampleDatabase(tester);
    await addSamplePockets(tester, db);
    await pumpApp(tester, db: db, location: Routes.add());
    expect(find.text('Personal'), findsOneWidget);
    await takeShot(tester, 'add_pocket');

    await tapText(tester, 'Personal');
    expect(find.text('Save in another pocket'), findsOneWidget);
    await takeShot(tester, 'add_pocket_pick');
    await closeApp(tester, db);
  });

  testWidgets('Date pop-up over the keypad (PopDate)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    await tapText(tester, 'Snacks');
    await keys(tester, '1 2 0');
    await tapText(tester, 'Today');
    expect(find.text('Date of this expense'), findsOneWidget);
    await tester.tap(find.text('12'));
    await settle(tester);
    await takeShot(tester, 'add_date');
    await tapText(tester, 'Confirm');
    expect(find.text('Oct 12'), findsOneWidget);
    await takeShot(tester, 'add_date_chosen');
    await closeApp(tester, db);
  });

  testWidgets('A receipt photo on Add expense (camera in the title field)', (tester) async {
    final db = await sampleDatabase(tester);
    final temp = tempFolder('stb_add_photo_');
    final source = await tester.runAsync(() => writeReceiptPhoto(temp));
    final picker = FakePhotoPicker(source!.path);
    await pumpApp(
      tester,
      db: db,
      location: Routes.add(),
      overrides: [photoPickerProvider.overrideWithValue(picker)],
    );
    await tapText(tester, 'Snacks');
    await keys(tester, '1 2 0');
    await tester.tap(find.byIcon(Symbols.photo_camera_rounded));
    await settleImages(tester);
    expect(picker.asked, [PhotoSource.camera]);
    await takeShot(tester, 'add_photo');
    await closeAppWithFiles(tester, db);
  });
}
