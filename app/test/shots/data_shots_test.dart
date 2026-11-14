@Tags(['shots'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/router.dart';

import '../support/board.dart';
import '../support/import_files.dart';
import '../support/shots.dart';

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
    await takeShot(tester, 'data_import_bad_file');
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
      find.text('05/03/2025 is read as March 5, 2025', findRichText: true),
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
    expect(find.text('Rows 14, 87, 203 · no date or amount'), findsOneWidget);
    expect(find.text('Pets and Travel will be created'), findsOneWidget);
    await takeShot(tester, 'data_import_3');

    await tester.tap(find.text('Import 298 expenses'));
    await settle(tester);
    expect(find.text('298 expenses added'), findsOneWidget);
    await takeShot(tester, 'data_import_done');
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });
}
