import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/import_files.dart';
import '../../support/shots.dart';

/// The category drill-down's header (emoji, name, month button) and the
/// "By amount | By date" segment, and every other segmented control, at the
/// default and the largest text size, with the real font.
void main() {
  setUpAll(loadShotFonts);

  final largest = AppSettings(textScale: textScaleSteps.last);

  RenderParagraph paragraphOf(WidgetTester tester, Finder text) =>
      tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)).first,
      );

  /// The drawn width of a text over its natural width: 1 unless scaled down.
  double scaleOf(WidgetTester tester, Finder text) =>
      tester.getRect(text).width / paragraphOf(tester, text).size.width;

  Future<List<String>> categoryNames(WidgetTester tester, AppDatabase db) async {
    final rows = await tester.runAsync(() => db.select(db.categories).get());
    return [for (final c in rows!) c.name];
  }

  Future<void> openCategory(
    WidgetTester tester,
    AppDatabase db,
    String name,
    AppSettings settings,
  ) async {
    final rows = await tester.runAsync(
      () => (db.select(db.categories)..where((c) => c.name.equals(name))).get(),
    );
    await pumpApp(
      tester,
      db: db,
      location: Routes.category(
        rows!.single.id,
        from: dayOf(2026, 10, 1),
        to: dayOf(2026, 10, 31),
      ),
      settings: settings,
    );
  }

  /// The header's name: the first match (the rows below may repeat it).
  Finder title(String name) => find.text(name).first;

  /// The month button of the header.
  Finder monthButton() =>
      find.ancestor(of: find.text('Oct 2026'), matching: find.byType(Pressable)).first;

  for (final big in [false, true]) {
    final size = big ? 'largest' : 'default';
    final settings = big ? largest : const AppSettings();

    testWidgets('header: every default category shows its whole name ($size text)', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      for (final name in await categoryNames(tester, db)) {
        await openCategory(tester, db, name, settings);
        final t = title(name);
        expect(
          paragraphOf(tester, t).didExceedMaxLines,
          isFalse,
          reason: '$name was cut with "..."',
        );
        // Scaled down at most to 0.65 ("Online Subscriptions" needs 0.68).
        expect(scaleOf(tester, t), inInclusiveRange(0.65, 1.0), reason: name);
        // Between the back button and the month button, never over them.
        final rect = tester.getRect(t);
        expect(rect.left, greaterThanOrEqualTo(16 + 40 + 12), reason: name);
        expect(rect.right, lessThanOrEqualTo(tester.getRect(monthButton()).left - 12), reason: name);
        expect(tester.takeException(), isNull, reason: name);
      }
      await closeApp(tester, db);
    });
  }

  testWidgets('header, default text: names that fit stay exactly where they were', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await openCategory(tester, db, 'Groceries', const AppSettings());
    expect(tester.getRect(title('Groceries')).left, closeTo(127.0, 0.1));
    expect(tester.getRect(title('Groceries')).right, closeTo(207.4, 0.1));
    expect(tester.getRect(title('Groceries')).top, 18);
    expect(scaleOf(tester, title('Groceries')), closeTo(1, 0.001));
    await openCategory(tester, db, 'Miscellaneous', const AppSettings());
    expect(tester.getRect(title('Miscellaneous')).left, closeTo(109.1, 0.1));
    expect(tester.getRect(title('Miscellaneous')).right, closeTo(225.3, 0.1));
    expect(scaleOf(tester, title('Miscellaneous')), closeTo(1, 0.001));
    await closeApp(tester, db);
  });

  testWidgets('header, largest text: a name needing less than 0.65 ends in "..."', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(
      () => CategoriesRepo(db).add(
        name: 'The Smiths family holiday supplies',
        emoji: '\u{1F3D6}',
        color: 0xFF336699,
      ),
    );
    await openCategory(tester, db, 'The Smiths family holiday supplies', largest);
    final t = title('The Smiths family holiday supplies');
    expect(paragraphOf(tester, t).didExceedMaxLines, isTrue);
    expect(scaleOf(tester, t), closeTo(0.65, 0.01), reason: 'scaled to 0.65, then cut');
    expect(tester.getRect(t).right, lessThanOrEqualTo(tester.getRect(monthButton()).left - 12));
    expect(tester.getRect(t).left, greaterThanOrEqualTo(16 + 40 + 12));
    expect(tester.takeException(), isNull);
    await closeApp(tester, db);
  });

  /// How far the text of every segment is from the edges of its segment.
  List<({String label, double left, double right})> segmentGaps(WidgetTester tester) {
    final gaps = <({String label, double left, double right})>[];
    final controls = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().startsWith('AppSegmented'),
    );
    for (final control in controls.evaluate()) {
      final scope = find.byWidget(control.widget);
      for (final text in find.descendant(of: scope, matching: find.byType(Text)).evaluate()) {
        final label = text.widget as Text;
        final segment = find
            .ancestor(of: find.byWidget(label), matching: find.byType(Pressable))
            .first;
        final t = tester.getRect(find.byWidget(label));
        final s = tester.getRect(segment);
        gaps.add((label: label.data ?? '?', left: t.left - s.left, right: s.right - t.right));
      }
    }
    return gaps;
  }

  void expectRoom(WidgetTester tester, {double least = 4}) {
    final gaps = segmentGaps(tester);
    expect(gaps, isNotEmpty);
    for (final g in gaps) {
      expect(g.left, greaterThanOrEqualTo(least), reason: '"${g.label}" touches the left edge');
      expect(g.right, greaterThanOrEqualTo(least), reason: '"${g.label}" touches the right edge');
    }
  }

  group('"By amount | By date"', () {
    testWidgets('default text: the labels sit where they always did', (tester) async {
      final db = await sampleDatabase(tester);
      await openCategory(tester, db, 'Groceries', const AppSettings());
      final amount = tester.getRect(find.text('By amount'));
      final segment = tester.getRect(
        find.ancestor(of: find.text('By amount'), matching: find.byType(Pressable)).first,
      );
      expect(segment.width, 84);
      // Centred, at its natural size.
      expect(amount.center.dx, closeTo(segment.center.dx, 0.01));
      expect(scaleOf(tester, find.text('By amount')), closeTo(1, 0.001));
      expect(amount.width, closeTo(65.7, 0.1));
      expect(amount.left, closeTo(164.2, 0.1));
      expectRoom(tester, least: 8);
      await closeApp(tester, db);
    });

    testWidgets('largest text: the label has room on both sides, selected or not', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await openCategory(tester, db, 'Groceries', largest);
      expectRoom(tester);
      // The other way round: By date chosen, By amount unselected.
      await tester.tap(find.text('By date'));
      await settle(tester);
      expectRoom(tester);
      // One line, whole words, at most a little smaller.
      for (final label in ['By amount', 'By date']) {
        final p = paragraphOf(tester, find.text(label));
        expect(p.didExceedMaxLines, isFalse, reason: label);
        expect(scaleOf(tester, find.text(label)), inInclusiveRange(0.7, 1.0), reason: label);
      }
      await closeApp(tester, db);
    });
  });

  group('every segmented control keeps its labels off the edges at the largest size', () {
    testWidgets('Charts: Week | Month | Year | Custom', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts, settings: largest);
      expectRoom(tester);
      for (final kind in ['Week', 'Year']) {
        await tester.tap(find.text(kind));
        await settle(tester);
        expectRoom(tester);
      }
      await closeApp(tester, db);
    });

    testWidgets('the custom range pop-up: quick choices', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.charts, settings: largest);
      await tester.tap(find.text('Custom'));
      await settle(tester);
      expect(find.text('30 days'), findsOneWidget);
      expectRoom(tester);
      await closeApp(tester, db);
    });

    testWidgets('Export: which expenses', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.export, settings: largest);
      expectRoom(tester);
      await closeApp(tester, db);
    });

    testWidgets('Import: how dates are written', (tester) async {
      final db = await sampleDatabase(tester);
      final List<Override> picking = [
        importFilePickerProvider.overrideWithValue(
          () async => (name: 'expenses-2025.csv', bytes: step2File()),
        ),
        exportSharerProvider.overrideWithValue((File file, String mime) async {}),
      ];
      await pumpApp(
        tester,
        db: db,
        location: Routes.importStart,
        settings: largest,
        overrides: picking,
      );
      await tester.tap(find.text('Choose a file').last);
      await settle(tester);
      expect(find.text('Day first'), findsOneWidget);
      expectRoom(tester);
      await closeApp(tester, db);
    });

    testWidgets('Reports: the year switch', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.reports, settings: largest);
      expect(find.text('2026'), findsWidgets);
      expectRoom(tester);
      await closeApp(tester, db);
    });
  });

  group('at the default size no segmented control moves', () {
    for (final (name, route) in [
      ('Charts', Routes.charts),
      ('Export', Routes.export),
      ('Reports', Routes.reports),
    ]) {
      testWidgets('$name: every label is centred in its segment, at its natural size', (
        tester,
      ) async {
        final db = await sampleDatabase(tester);
        await pumpApp(tester, db: db, location: route);
        final controls = find.byWidgetPredicate(
          (w) => w.runtimeType.toString().startsWith('AppSegmented'),
        );
        expect(controls, findsWidgets);
        for (final control in controls.evaluate()) {
          final scope = find.byWidget(control.widget);
          for (final text in find.descendant(of: scope, matching: find.byType(Text)).evaluate()) {
            final label = find.byWidget(text.widget);
            final segment = find.ancestor(of: label, matching: find.byType(Pressable)).first;
            expect(
              tester.getRect(label).center.dx,
              closeTo(tester.getRect(segment).center.dx, 0.01),
            );
            expect(scaleOf(tester, label), closeTo(1, 0.001), reason: (text.widget as Text).data);
          }
        }
        await closeApp(tester, db);
      });
    }
  });
}
