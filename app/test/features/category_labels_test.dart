import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
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

    testWidgets('largest text: both lines of a name are scaled alike', (tester) async {
      final db = await openAdd(tester, settings: largest);
      final tiles = find.byType(CategoryTile);
      double scaleOf(WidgetTester tester, Text t) {
        final finder = find.byWidget(t);
        final natural = tester.renderObject<RenderParagraph>(finder).size.width;
        return tester.getRect(finder).width / natural;
      }

      var twoLines = 0;
      for (var i = 0; i < tiles.evaluate().length; i++) {
        final name = tester.widget<CategoryTile>(tiles.at(i)).category.name;
        final lines = labelLines(tester, tiles.at(i));
        if (lines.length < 2) continue;
        twoLines++;
        final first = scaleOf(tester, lines.first);
        for (final t in lines.skip(1)) {
          expect(scaleOf(tester, t), closeTo(first, 0.005), reason: '"${t.data}" in $name');
        }
      }
      expect(twoLines, greaterThan(0));

      // "Online Subscriptions": "Subscriptions" is the wide line and sets the
      // scale; "Online" follows it instead of staying full size.
      final cell = tester.getRect(find.text('Subscriptions')).width;
      final subs = tester.widget<Text>(find.text('Subscriptions'));
      final online = tester.widget<Text>(find.text('Online'));
      final scale = scaleOf(tester, subs);
      expect(scale, lessThan(0.9), reason: 'it does not fit at full size');
      expect(scale, closeTo(0.7827, 0.01), reason: 'the scale the widest line needs');
      expect(scaleOf(tester, online), closeTo(scale, 0.005));
      expect(cell, lessThanOrEqualTo(tester.getRect(find.byType(CategoryTile).at(12)).width));
      // The scaled lines stay level with their neighbour's text.
      expect(
        tester.getRect(find.text('Online')).center.dy,
        closeTo(tester.getRect(find.text('Gifts')).center.dy, 0.5),
      );
      await closeApp(tester, db);
    });

    testWidgets('largest text: a name too long for two lines scales its lines alike too', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await tester.runAsync(
        () => CategoriesRepo(db).add(
          name: 'Subscriptions and other recurring stuff',
          emoji: '\u{1F4C5}',
          color: 0xFF336699,
        ),
      );
      await pumpApp(tester, db: db, location: Routes.add(), settings: largest);
      final tile = find.byWidgetPredicate(
        (w) => w is CategoryTile && w.category.name == 'Subscriptions and other recurring stuff',
      );
      expect(tile, findsOneWidget);
      final lines = labelLines(tester, tile);
      expect(lines.length, 2);
      double scaleOf(Text t) {
        final finder = find.byWidget(t);
        return tester.getRect(finder).width / tester.renderObject<RenderParagraph>(finder).size.width;
      }

      // The first line is the wide word, the second ends in "...": both take
      // the scale the wide word needs.
      expect(lines.first.data, 'Subscriptions');
      final scale = scaleOf(lines.first);
      expect(scale, lessThan(0.9));
      expect(scaleOf(lines.last), closeTo(scale, 0.005));
      expect(tester.takeException(), isNull);
      await closeApp(tester, db);
    });

    testWidgets('largest text: a single-line label scales as it did', (tester) async {
      final db = await openAdd(tester, settings: largest);
      double scaleOf(String name) {
        final finder = find.text(name);
        final natural = tester.renderObject<RenderParagraph>(finder).size.width;
        return tester.getRect(finder).width / natural;
      }

      expect(scaleOf('Transportation'), closeTo(0.7414, 0.005));
      expect(scaleOf('Miscellaneous'), closeTo(0.7623, 0.005));
      // Short names and short words are not scaled at all.
      for (final name in ['Groceries', 'Snacks', 'Shopping', 'Phone', 'Gifts', 'House', 'Rent']) {
        expect(scaleOf(name), closeTo(1, 0.005), reason: name);
      }
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
