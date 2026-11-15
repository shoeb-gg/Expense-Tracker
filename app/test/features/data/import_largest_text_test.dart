import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/board.dart';
import '../../support/import_files.dart';
import '../../support/shots.dart';

/// The Import steps use the kit's list row like Settings does: at the largest
/// text size its title and subtitle wrap instead of ending in "…".
void main() {
  setUpAll(loadShotFonts);

  final largest = AppSettings(textScale: textScaleSteps.last);

  List<Override> picking(String name, Uint8List bytes) => [
    importFilePickerProvider.overrideWithValue(() async => (name: name, bytes: bytes)),
    exportSharerProvider.overrideWithValue((File file, String mime) async {}),
  ];

  /// The text is whole: not ended with "…", not clipped at the side.
  bool isCut(WidgetTester tester, Finder text) {
    final p = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)).first,
    );
    final length = p.text.toPlainText().length;
    final boxes = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length));
    final right = boxes.map((b) => b.right).fold<double>(0, (a, b) => a > b ? a : b);
    return p.didExceedMaxLines || right > p.size.width + 0.5;
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
    ]) {
      expect(isCut(tester, find.text(text)), isFalse, reason: text);
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
    expect(isCut(tester, find.text('expenses-2025.csv')), isFalse);
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
      expect(isCut(tester, find.text(text)), isFalse, reason: text);
    }
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db);
  });
}
