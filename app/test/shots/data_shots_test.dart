@Tags(['shots'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/board.dart';
import '../support/import_files.dart';
import '../support/shots.dart';
import '../support/text_cut.dart';

List<Override> picking(String name, Uint8List bytes) => [
  importFilePickerProvider.overrideWithValue(
    () async => (name: name, bytes: bytes),
  ),
  exportSharerProvider.overrideWithValue((File file, String mime) async {}),
];

void main() {
  setUpAll(loadShotFonts);

  testWidgets('export (board Export)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.export);
    expect(find.text('33 expenses'), findsOneWidget);
    expect(find.text('Export 33 expenses'), findsOneWidget);
    await takeShot(tester, 'data_export');
    await tester.tap(find.text('CSV (.csv)'));
    await tester.tap(find.text('Everything'));
    await settle(tester);
    expect(find.text('Export 1,266 expenses'), findsOneWidget);
    await takeShot(tester, 'data_export_everything_csv');
    await closeApp(tester, db);
  });

  testWidgets('import step 1 (board Import: step 1)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.importStart);
    await takeShot(tester, 'data_import_1');
    await closeApp(tester, db);
  });

  testWidgets('import step 1: a file that cannot be used', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      overrides: picking('receipt.pdf', Uint8List(4)),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    expect(find.text("Can't use this file"), findsOneWidget);
    // "Choose another" gets the room it needs beside Cancel.
    final cancel = tester.getRect(find.widgetWithText(Pressable, 'Cancel'));
    final again = tester.getRect(
      find.widgetWithText(Pressable, 'Choose another'),
    );
    expect(again.top, cancel.top);
    expect(again.width, greaterThan(cancel.width));
    await takeShot(tester, 'data_import_bad_file');
    await closeApp(tester, db);
  });

  testWidgets('import step 1: a file that cannot be used, largest text', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: AppSettings(textScale: textScaleSteps.last),
      overrides: picking('receipt.pdf', Uint8List(4)),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    expect(find.text("Can't use this file"), findsOneWidget);
    // Too wide to share a row: stacked, action on top, nothing clipped.
    final cancel = tester.getRect(find.widgetWithText(Pressable, 'Cancel'));
    final again = tester.getRect(
      find.widgetWithText(Pressable, 'Choose another'),
    );
    expect(cancel.top, greaterThan(again.bottom));
    for (final label in ['Cancel', 'Choose another']) {
      expect(
        tester.renderObject<RenderParagraph>(find.text(label)).didExceedMaxLines,
        isFalse,
      );
    }
    await takeShot(tester, 'data_import_bad_file_largest');
    await closeApp(tester, db);
  });

  testWidgets('import step 2 (board Import: step 2)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      overrides: picking('expenses-2025.csv', step2File()),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    expect(find.text('4 of 4 found'), findsOneWidget);
    expect(
      noteText('05/03/2025 is read as March 5, 2025'),
      findsOneWidget,
    );
    await takeShot(tester, 'data_import_2');
    await closeApp(tester, db);
  });

  testWidgets('import step 2: amount column not found', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      overrides: picking('shops.csv', noAmountFile()),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    expect(find.text('Choose a column'), findsOneWidget);
    await takeShot(tester, 'data_import_2_missing');
    await closeApp(tester, db);
  });

  testWidgets('import step 3 (board Import: step 3), then Home with Undo', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    final file = await tester.runAsync(() => step3File(db));
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      overrides: picking('expenses-2025.csv', file!),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await boardHeight(tester, 900);
    expect(find.text('298 expenses'), findsOneWidget);
    expect(find.text('412,560'), findsOneWidget);
    expect(find.text('Mar 2 to Dec 30, 2025'), findsOneWidget);
    expect(find.text('11 already in the app'), findsOneWidget);
    expect(noteText('Rows 14, 87, 203 · no date or amount'), findsOneWidget);
    expect(noteText('Pets and Travel will be created'), findsOneWidget);
    await takeShot(tester, 'data_import_3');

    await tester.tap(find.text('Import 298 expenses'));
    await settle(tester);
    expect(find.text('298 expenses added'), findsOneWidget);
    await takeShot(tester, 'data_import_done');
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });

  // The same screens at the largest text size, on a tall board so the whole
  // screen shows: every text is whole there (see import_largest_text_test).
  final largest = AppSettings(textScale: textScaleSteps.last);

  testWidgets('export, largest text', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.export, settings: largest);
    await boardHeight(tester, 1700);
    await takeShot(tester, 'data_export_largest');
    await closeApp(tester, db);
  });

  testWidgets('import step 1, largest text', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.importStart, settings: largest);
    await boardHeight(tester, 1700);
    await takeShot(tester, 'data_import_1_largest');
    await closeApp(tester, db);
  });

  testWidgets('import step 2, largest text', (tester) async {
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
    await takeShot(tester, 'data_import_2_largest');
    await closeApp(tester, db);
  });

  testWidgets('import step 2: amount column not found, largest text', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: largest,
      overrides: picking('shops.csv', noAmountFile()),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await boardHeight(tester, 1700);
    await takeShot(tester, 'data_import_2_missing_largest');
    await closeApp(tester, db);
  });

  testWidgets('import step 3, largest text', (tester) async {
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
    await takeShot(tester, 'data_import_3_largest');
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });

  testWidgets('import step 2 and export, largest text, a long pocket name', (tester) async {
    final db = await sampleDatabase(tester);
    final id = await tester.runAsync(
      () => PocketsRepo(db).add(name: 'Wedding planning', emoji: '\u{1F4BC}'),
    );
    final settings = AppSettings(textScale: textScaleSteps.last, currentPocketId: id);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: settings,
      overrides: picking('expenses-2025.csv', step2File()),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await takeShot(tester, 'data_import_2_long_pocket_largest');
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go(Routes.export);
    await settle(tester);
    await takeShot(tester, 'data_export_long_pocket_largest');
    await closeApp(tester, db);
  });

  testWidgets('import step 3, largest text, thousands of rows', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: largest,
      overrides: picking('bank.csv', longFile(5000)),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settleFor(tester, rounds: 40);
    await boardHeight(tester, 1700);
    await takeShot(tester, 'data_import_3_long_largest');
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });
}
