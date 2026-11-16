import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/data/data_parts.dart' show NewBadge;
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/board.dart';
import '../../support/import_files.dart';
import '../../support/shots.dart';
import '../../support/text_cut.dart';

/// The Import steps and Export use the kit's list row like Settings does: at
/// the largest text size every text wraps to more lines instead of ending in
/// "…" or being clipped at the side.
void main() {
  setUpAll(loadShotFonts);

  final largest = AppSettings(textScale: textScaleSteps.last);

  List<Override> picking(String name, Uint8List bytes) => [
    importFilePickerProvider.overrideWithValue(() async => (name: name, bytes: bytes)),
    exportSharerProvider.overrideWithValue((File file, String mime) async {}),
  ];

  /// Opens step 2 (or, with [next], step 3) on [file] at the largest size.
  Future<AppDatabase> openStep(
    WidgetTester tester,
    String name,
    Uint8List? file, {
    bool next = false,
  }) async {
    final db = await sampleDatabase(tester);
    final bytes = file ?? (await tester.runAsync(() => step3File(db)))!;
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: largest,
      overrides: picking(name, bytes),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    if (next) {
      await tester.tap(find.text('Next'));
      await settle(tester);
    }
    await boardHeight(tester, 1700);
    return db;
  }

  testWidgets('step 1: the steps and what the file needs show in full', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.importStart, settings: largest);
    await boardHeight(tester, 1700);
    for (final text in [
      'From your phone or a cloud drive',
      'Confirm which column is which',
      'See what will be added before it is saved',
      'In every row',
      'Blank ones go to Miscellaneous',
      'A file exported from this app works as it is.',
    ]) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await closeApp(tester, db);
  });

  testWidgets('step 2: the file name shows in full', (tester) async {
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
    await boardHeight(tester, 1700);
    expect(isCut(tester, noteText('expenses-2025.csv')), isFalse);
    await closeApp(tester, db);
  });

  testWidgets('step 2: the column heading shows in full', (tester) async {
    final db = await openStep(tester, 'expenses-2025.csv', step2File());
    for (final text in ['In the app', 'Column in your file', 'Date', 'e.g. 05/03/2025']) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await closeApp(tester, db);
  });

  testWidgets('step 2: what is missing or left out shows in full', (tester) async {
    final db = await openStep(tester, 'shops.csv', noAmountFile());
    for (final text in [
      'Not found in the file',
      'Choose a column',
      'All go to Miscellaneous',
      'Left blank',
      'None',
    ]) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await closeApp(tester, db);
  });

  testWidgets('step 2: a file with only date and amount shows in full', (tester) async {
    final db = await openStep(tester, 'plain.csv', dateAndAmountFile());
    for (final text in ['All go to Miscellaneous', 'Left blank', 'None']) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await closeApp(tester, db);
  });

  testWidgets('step 2: an empty column shows in full', (tester) async {
    final db = await openStep(tester, 'notes.csv', emptyNoteFile());
    expect(isCut(tester, find.text('Empty in this file')), isFalse);
    await closeApp(tester, db);
  });

  testWidgets('step 3: what happens shows in full', (tester) async {
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
    await boardHeight(tester, 1700);
    for (final text in [
      'Will be added',
      'Skipped, so nothing is counted twice',
      'Rows 14, 87, 203 · no date or amount',
      'Pets and Travel will be created',
    ]) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });

  testWidgets('step 3: a first look shows each row in full, amounts on the right', (
    tester,
  ) async {
    final db = await openStep(tester, 'expenses-2025.csv', null, next: true);
    final shown = <String>[
      'Weekly bazaar', 'Groceries', '· Mar 2, 2025',
      'Bus pass', 'Transportation', '· Mar 3, 2025',
      'Cat food', 'Pets', '· Mar 3, 2025',
    ];
    for (final text in shown) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    // The three rows sit one under the other and the amounts line up on the
    // right edge of the card, each beside its own row.
    final amounts = ['2,450', '600', '890'].map((a) => tester.getRect(noteText(a))).toList();
    final titles = ['Weekly bazaar', 'Bus pass', 'Cat food']
        .map((t) => tester.getRect(noteText(t)))
        .toList();
    for (var i = 0; i < 3; i++) {
      expect(amounts[i].right, closeTo(amounts[0].right, 0.5));
      expect(amounts[i].center.dy, closeTo(titles[i].bottom + 1, 30));
      if (i > 0) expect(titles[i].top, greaterThan(titles[i - 1].bottom));
    }
    // The "New" badge stays as wide as its word when the row wraps.
    expect(tester.getSize(find.byType(NewBadge)).width, lessThan(60));
    final card = tester.getRect(
      find.ancestor(of: find.text('A first look'), matching: find.byType(ClipRRect)).first,
    );
    expect(amounts[0].right, closeTo(card.right - 16, 0.5));
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });

  testWidgets('export: the file types and their notes show in full', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.export, settings: largest);
    await boardHeight(tester, 1700);
    for (final text in [
      'Excel (.xlsx)',
      'Opens in Excel and Google Sheets',
      'CSV (.csv)',
      'Plain text, opens in almost any app',
      'One row per expense. Photos are left out.',
      'This month',
      'This year',
      'Everything',
      'Oct 1, 2026',
      'Oct 18, 2026',
      'Next, you choose where to save or share it.',
    ]) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await closeApp(tester, db);
  });

  /// A pocket with the longest name the header shows in full, in use.
  Future<AppSettings> longPocketSettings(WidgetTester tester, AppDatabase db) async {
    final id = await tester.runAsync(
      () => PocketsRepo(db).add(name: 'Wedding planning', emoji: '\u{1F4BC}'),
    );
    return AppSettings(textScale: textScaleSteps.last, currentPocketId: id);
  }

  testWidgets('steps 1 to 3: the header is whole with a long pocket name', (tester) async {
    final db = await sampleDatabase(tester);
    final settings = await longPocketSettings(tester, db);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: settings,
      overrides: picking('expenses-2025.csv', step2File()),
    );
    expect(isCut(tester, find.text('Step 1 of 3 · \u{1F4BC} Wedding planning')), isFalse);
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    expect(isCut(tester, find.text('Step 2 of 3 · \u{1F4BC} Wedding planning')), isFalse);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(isCut(tester, find.text('Step 3 of 3 · \u{1F4BC} Wedding planning')), isFalse);
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });

  testWidgets('step 3: nothing to import shows in full', (tester) async {
    final db = await openStep(tester, 'later.csv', unreadableFile(), next: true);
    for (final text in [
      'Nothing to add',
      '2 rows can’t be read',
      'Rows 2, 3 · no date or amount',
      'Nothing new in this file',
      'Nothing to import',
      'Go back to check the columns, or choose another file.',
    ]) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });

  testWidgets('export: everything as CSV, and a pocket with nothing to export', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.export, settings: largest);
    await boardHeight(tester, 1700);
    await tester.tap(find.text('Everything'));
    await settle(tester);
    for (final text in ['Which expenses', '1,266 expenses', 'Export 1,266 expenses']) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await closeApp(tester, db);

    final empty = await sampleDatabase(tester);
    final settings = await longPocketSettings(tester, empty);
    await pumpApp(tester, db: empty, location: Routes.export, settings: settings);
    await boardHeight(tester, 1700);
    for (final text in [
      '\u{1F4BC} Wedding planning',
      'Nothing to export',
      'No expenses in these dates. Try other dates.',
    ]) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await closeApp(tester, empty);
  });

  testWidgets('step 3: a long file does not cut "What happens"', (tester) async {
    final db = await openStep(tester, 'bank.csv', longFile(5000), next: true);
    await settleFor(tester, rounds: 40);
    for (final text in ['What happens', '5,000 rows in the file', 'A first look']) {
      expect(isCut(tester, noteText(text)), isFalse, reason: text);
    }
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });
}
