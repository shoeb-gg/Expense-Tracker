import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/add/category_grid.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/shots.dart';

/// The category grid of Add expense at the default and the largest text
/// size, with the real font (the labels' widths need it).
void main() {
  setUpAll(loadShotFonts);

  final largest = AppSettings(textScale: textScaleSteps.last);

  Future<AppDatabase> openAdd(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add(), settings: settings);
    return db;
  }

  /// How many lines the paragraph is laid out in.
  int lineCount(RenderParagraph p) {
    final length = p.text.toPlainText().length;
    final boxes = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length));
    return {for (final b in boxes) b.top.round()}.length;
  }

  group('category labels', () {
    /// The label lines of one tile: every Text but the emoji.
    List<Text> labelLines(WidgetTester tester, Finder tile) {
      final emoji = tester.widget<CategoryTile>(tile).category.emoji;
      final texts = tester.widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text)));
      return [
        for (final t in texts)
          if (t.data != emoji) t,
      ];
    }

    testWidgets('largest text: breaks only between words, scales a wide word down', (tester) async {
      final db = await openAdd(tester, settings: largest);
      final tiles = find.byType(CategoryTile);
      expect(tiles, findsWidgets);
      for (var i = 0; i < tiles.evaluate().length; i++) {
        final tile = tiles.at(i);
        final name = tester.widget<CategoryTile>(tile).category.name;
        final lines = labelLines(tester, tile);
        expect(lines, isNotEmpty, reason: name);
        expect(lines.length, lessThanOrEqualTo(2), reason: name);
        // Whole words, in order.
        expect([for (final t in lines) t.data].join(' '), name);
        for (final t in lines) {
          final p = tester.renderObject<RenderParagraph>(find.byWidget(t));
          expect(lineCount(p), 1, reason: '"${t.data}" broke inside a word');
          expect(p.didExceedMaxLines, isFalse, reason: '"${t.data}" was cut');
          // And inside its cell, scaled down when it was too wide.
          final cell = tester.getRect(tile);
          final ink = tester.getRect(find.byWidget(t));
          expect(ink.left, greaterThanOrEqualTo(cell.left), reason: name);
          expect(ink.right, lessThanOrEqualTo(cell.right), reason: name);
        }
      }
      // The words that broke before: "Transportation", "Subscriptions",
      // "Miscellaneous" are each on one line.
      expect(find.text('Transportation'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Subscriptions'), findsOneWidget);
      expect(find.text('Miscellaneous'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('largest text: neighbouring labels keep a gap', (tester) async {
      final db = await openAdd(tester, settings: largest);
      final tiles = find.byType(CategoryTile);
      final count = tiles.evaluate().length;
      // The union of a tile's label lines.
      Rect ink(int i) {
        final lines = labelLines(tester, tiles.at(i));
        return lines
            .map((t) => tester.getRect(find.byWidget(t)))
            .reduce((a, b) => a.expandToInclude(b));
      }

      for (var i = 0; i + 1 < count; i++) {
        final here = tester.getRect(tiles.at(i));
        final next = tester.getRect(tiles.at(i + 1));
        if (next.left <= here.left) continue; // a new row
        final gap = ink(i + 1).left - ink(i).right;
        expect(gap, greaterThanOrEqualTo(6), reason: 'tile $i and ${i + 1}');
      }
      await closeApp(tester, db);
    });

    testWidgets('default text: no label is scaled or moved', (tester) async {
      final db = await openAdd(tester);
      final tiles = find.byType(CategoryTile);
      for (var i = 0; i < tiles.evaluate().length; i++) {
        final name = tester.widget<CategoryTile>(tiles.at(i)).category.name;
        for (final t in labelLines(tester, tiles.at(i))) {
          final finder = find.byWidget(t);
          final natural = tester.renderObject<RenderParagraph>(finder).size;
          final drawn = tester.getRect(finder).size;
          expect(drawn.width, closeTo(natural.width, 0.01), reason: '"${t.data}" in $name');
          expect(drawn.height, closeTo(natural.height, 0.01), reason: '"${t.data}" in $name');
        }
        // Every tile is the 84 px cell it always was.
        expect(tester.getSize(tiles.at(i)).height, 84, reason: name);
      }
      // "Online Subscriptions" is the one two-line name.
      expect(
        [for (final t in labelLines(tester, tiles.at(12))) t.data].join('|'),
        anyOf('Online|Subscriptions', 'Online Subscriptions'),
      );
      await closeApp(tester, db);
    });
  });
}
