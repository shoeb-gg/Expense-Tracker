import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/board.dart';
import '../support/import_files.dart';
import '../support/shots.dart';
import '../support/text_cut.dart';

/// At the largest text size the quiet texts of the app (subtitles, notes,
/// hints) never end on a lone word on the real screens.
void main() {
  setUpAll(loadShotFonts);

  final largest = AppSettings(textScale: textScaleSteps.last);

  List<Override> picking(String name, Uint8List bytes) => [
    importFilePickerProvider.overrideWithValue(() async => (name: name, bytes: bytes)),
  ];

  void expectWholeEnding(WidgetTester tester, List<String> texts) {
    for (final text in texts) {
      final words = lastLineWords(tester, noteText(text));
      expect(words.length, greaterThanOrEqualTo(2), reason: '"$text": last line $words');
    }
  }

  testWidgets('Export: the file types', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.export, settings: largest);
    await boardHeight(tester, 2400);
    expectWholeEnding(tester, [
      'Opens in Excel and Google Sheets',
      'Plain text, opens in almost any app',
    ]);
    await closeApp(tester, db);
  });

  testWidgets('Settings: the row subtitles and the text size note', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.settings, settings: largest);
    await boardHeight(tester, 2600);
    expectWholeEnding(tester, [
      'The big number at the top of Home',
      'Mask the total until you tap the eye',
      'Shortcut to the calendar on Home',
      'Add, edit, delete, reorder',
      'Phone and Google Drive',
      'Preview. The whole app uses this size.',
    ]);
    await closeApp(tester, db);
  });

  testWidgets('Import step 1: the steps and what the file needs', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.importStart, settings: largest);
    await boardHeight(tester, 2400);
    expectWholeEnding(tester, [
      'From your phone or a cloud drive',
      'Blank ones go to Miscellaneous',
    ]);
    await closeApp(tester, db);
  });

  testWidgets('Import step 2: how dates are read', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: largest,
      overrides: picking('expenses-2025.csv', step2File()),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await boardHeight(tester, 2400);
    final line = find.byWidgetPredicate(
      (w) => w is Text && (w.textSpan?.toPlainText() ?? '').contains('is read as'),
    );
    final words = lastLineWords(tester, line);
    expect(words.length, greaterThanOrEqualTo(2), reason: 'last line $words');
    await closeApp(tester, db);
  });

  testWidgets('Import step 3: the hint under the button', (tester) async {
    final db = await sampleDatabase(tester);
    final file = await tester.runAsync(() => step3File(db));
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: largest,
      overrides: picking('expenses-2025.csv', file!),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await boardHeight(tester, 2400);
    expectWholeEnding(tester, ['Adds to your expenses. Nothing is replaced.']);
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });

  testWidgets('Charts: the hint under the pie', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts, settings: largest);
    await boardHeight(tester, 2400);
    expectWholeEnding(tester, ['Tap a slice or a category below to see its share.']);
    await closeApp(tester, db);
  });

  testWidgets('Add expense: the fixed hint on the empty card', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add(), settings: largest);
    await boardHeight(tester, 1700);
    expectWholeEnding(tester, ['Tap one above, or just type below']);
    await closeApp(tester, db);
  });

  testWidgets('Add expense: the line with the typed word is left as typed', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add(), settings: largest);
    await boardHeight(tester, 1700);
    await tester.enterText(find.byType(EditableText).last, 'coffee');
    await settle(tester);
    // Plain spaces: nothing the user typed is joined.
    expect(find.text('Like “coffee 120”'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('New pocket: the note under the form', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.newPocket, settings: largest);
    await boardHeight(tester, 1700);
    expectWholeEnding(tester, [
      'A new pocket starts empty. Your categories and settings are already in it.',
    ]);
    await closeApp(tester, db);
  });
}
