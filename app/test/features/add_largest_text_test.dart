import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/add/category_grid.dart';
import 'package:spill_the_bills/features/add/pocket_parts.dart';
import 'package:spill_the_bills/features/add/quick_area.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/add_support.dart';
import '../support/board.dart';
import '../support/shots.dart';
import '../support/text_cut.dart';

/// Add / Edit expense at the default and the largest text size, with the
/// real font (the boards' widths need it).
void main() {
  setUpAll(loadShotFonts);

  final largest = AppSettings(textScale: textScaleSteps.last);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  /// Opens [route] (Add expense) and returns the database to close at the end.
  Future<AppDatabase> openAdd(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    bool pockets = false,
    String? route,
  }) async {
    final db = await sampleDatabase(tester);
    if (pockets) await addSamplePockets(tester, db);
    await pumpApp(tester, db: db, location: route ?? Routes.add(), settings: settings);
    return db;
  }

  RenderParagraph paragraph(WidgetTester tester, Finder text) =>
      tester.renderObject<RenderParagraph>(text);

  /// How many lines the paragraph is laid out in.
  int lineCount(RenderParagraph p) {
    final length = p.text.toPlainText().length;
    final boxes = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length));
    return {for (final b in boxes) b.top.round()}.length;
  }

  /// The text is whole: not cut with "…" and on one line.
  void showsInFull(WidgetTester tester, Finder text) {
    expect(text, findsOneWidget);
    final p = paragraph(tester, text);
    expect(p.didExceedMaxLines, isFalse, reason: 'ellipsis');
    expect(lineCount(p), 1, reason: 'one line');
  }

  group('the header', () {
    final cancel = find.widgetWithText(Pill, 'Cancel');

    Finder pocketPill(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(Pressable)).first;

    testWidgets('default text: Cancel, the title and the pill stay where they were', (
      tester,
    ) async {
      final db = await openAdd(tester);
      expect(tester.getRect(cancel).left, 16);
      expect(tester.getRect(cancel).right, closeTo(91.7, 0.1));
      expect(tester.getRect(cancel).top, 12);
      expect(tester.getRect(cancel).bottom, 48);
      // The title is centred between the 88 px side columns.
      expect(tester.getRect(find.text('Add expense')).center.dx, closeTo(180, 0.5));
      expect(tester.getRect(find.text('Add expense')).center.dy, closeTo(30, 0.5));
      showsInFull(tester, find.text('Add expense'));
      await closeApp(tester, db);
    });

    testWidgets('default text, with pockets: the pill stays where it was', (tester) async {
      final db = await openAdd(tester, pockets: true);
      final pill = tester.getRect(pocketPill('Personal'));
      expect(pill.right, 344);
      expect(pill.left, closeTo(249.9, 0.1));
      expect(pill.top, 12);
      expect(pill.bottom, 48);
      expect(tester.getRect(cancel).left, 16);
      expect(tester.getRect(cancel).right, closeTo(91.7, 0.1));
      // Centred between the 100 px side columns.
      expect(tester.getRect(find.text('Add expense')).center.dx, closeTo(180, 0.5));
      showsInFull(tester, find.text('Personal'));
      await closeApp(tester, db);
    });

    testWidgets('largest text: Add expense and Cancel show in full', (tester) async {
      final db = await openAdd(tester, settings: largest);
      showsInFull(tester, find.text('Add expense'));
      showsInFull(tester, find.text('Cancel'));
      final title = tester.getRect(find.text('Add expense'));
      expect(title.left, greaterThanOrEqualTo(tester.getRect(cancel).right));
      expect(title.right, lessThanOrEqualTo(344));
      await closeApp(tester, db);
    });

    // The two largest text sizes: the pocket pill shows only its emoji, so
    // the title keeps its size (the user's choice, 2026-11-17). Each pocket
    // starts with its own emoji; tapping the pill lists the names.
    final pill = find.byType(PocketPill);

    for (final scale in textScaleSteps.where((s) => s > 1)) {
      testWidgets('text x${scale.toStringAsFixed(2)}: the pill is only the emoji, the title keeps its size', (
        tester,
      ) async {
        final defaultTitle = await () async {
          final db = await openAdd(tester, pockets: true);
          final h = tester.getRect(find.text('Add expense')).height;
          await closeApp(tester, db);
          return h;
        }();
        final db = await openAdd(tester, settings: AppSettings(textScale: scale), pockets: true);
        expect(find.descendant(of: pill, matching: find.text('Personal')), findsNothing);
        expect(find.descendant(of: pill, matching: find.text('\u{1F45B}')), findsOneWidget);
        final rect = tester.getRect(pill);
        expect(rect.right, 344);
        expect(rect.width, lessThanOrEqualTo(48));
        showsInFull(tester, find.text('Add expense'));
        showsInFull(tester, find.text('Cancel'));
        expect(tester.getRect(find.text('Add expense')).height, greaterThanOrEqualTo(defaultTitle - 0.5));
        await closeApp(tester, db);
      });
    }

    testWidgets('largest text: Edit expense shows in full, with the emoji pill', (tester) async {
      final db = await openAdd(
        tester,
        settings: largest,
        pockets: true,
        route: Routes.editExpense(doctorVisitId),
      );
      showsInFull(tester, find.text('Edit expense'));
      showsInFull(tester, find.text('Cancel'));
      final title = tester.getRect(find.text('Edit expense'));
      expect(title.left, greaterThanOrEqualTo(tester.getRect(cancel).right));
      expect(title.right, lessThanOrEqualTo(tester.getRect(pill).left));
      await closeApp(tester, db);
    });

    testWidgets('largest text: switching pockets swaps the emoji', (tester) async {
      final db = await sampleDatabase(tester);
      await addSamplePockets(tester, db);
      await tester.runAsync(
        () => PocketsRepo(db).add(name: 'The Smiths family holiday', emoji: '\u{1F9F3}'),
      );
      await pumpApp(tester, db: db, location: Routes.add(), settings: largest);
      await tap(tester, pill);
      await tap(tester, find.text('The Smiths family holiday').last);
      expect(find.descendant(of: pill, matching: find.text('\u{1F9F3}')), findsOneWidget);
      expect(find.descendant(of: pill, matching: find.textContaining('Smiths')), findsNothing);
      expect(tester.getRect(pill).width, lessThanOrEqualTo(48));
      showsInFull(tester, find.text('Add expense'));
      await closeApp(tester, db);
    });
  });

  group('the hint card of the opening state', () {
    const hint = 'Tap one above, or just type below';
    final card = find.byType(GuideCard);
    final bar = find.byType(TypingBar);

    /// The text is whole: not cut with "…", not clipped at the side.
    void notCut(WidgetTester tester, Finder text) {
      final p = paragraph(tester, text);
      final length = p.text.toPlainText().length;
      final boxes = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length));
      final right = boxes.map((b) => b.right).fold<double>(0, (a, b) => a > b ? a : b);
      expect(p.didExceedMaxLines, isFalse, reason: 'ellipsis');
      expect(right, lessThanOrEqualTo(p.size.width + 0.5), reason: 'clipped');
    }

    testWidgets('default text: the card stays where it was, on one line', (tester) async {
      final db = await openAdd(tester);
      expect(tester.getRect(card), const Rect.fromLTRB(16, 630, 344, 698));
      expect(tester.getRect(find.text('Select a category')).top, 645);
      final sub = tester.getRect(noteText(hint));
      expect(sub.top, 667);
      expect(sub.height, 16);
      expect(lineCount(paragraph(tester, noteText(hint))), 1);
      expect(tester.getRect(bar), const Rect.fromLTRB(16, 708, 344, 764));
      expect(tester.getSize(find.byKey(const ValueKey('quick'))).height, 162);
      await closeApp(tester, db);
    });

    testWidgets('largest text: the hint shows in full, over two lines', (tester) async {
      final db = await openAdd(tester, settings: largest);
      notCut(tester, noteText(hint));
      expect(lineCount(paragraph(tester, noteText(hint))), 2);
      showsInFull(tester, find.text('Select a category'));
      await closeApp(tester, db);
    });

    testWidgets('largest text: the card grows, nothing overlaps', (tester) async {
      final db = await openAdd(tester, settings: largest);
      final c = tester.getRect(card);
      final sub = tester.getRect(noteText(hint));
      final title = tester.getRect(find.text('Select a category'));
      // The text stays inside the card, below its top padding.
      expect(title.top, greaterThanOrEqualTo(c.top + 12));
      expect(title.bottom, lessThanOrEqualTo(sub.top + 1));
      expect(sub.bottom, lessThanOrEqualTo(c.bottom - 12 + 0.5));
      // The card, the 10 px gap, the bar, the 16 px under it.
      expect(tester.getRect(bar).top, closeTo(c.bottom + 10, 0.5));
      expect(tester.getRect(bar).bottom, 764);
      // And the card is below the header and the grid at the top.
      expect(c.top, greaterThan(tester.getRect(find.text('Cancel')).bottom));
      await closeApp(tester, db);
    });

    testWidgets('largest text: the grid scrolls clear of the taller card', (tester) async {
      final db = await openAdd(tester, settings: largest);
      // A short phone, so the grid has to scroll.
      await boardHeight(tester, 600);
      await tester.drag(find.text('Groceries'), const Offset(0, -2000));
      await settle(tester);
      // The end of the grid (its last row) is above the whole quick area.
      final quickTop = tester.getRect(find.byKey(const ValueKey('quick'))).top;
      expect(tester.getRect(find.byType(CategoryGrid)).bottom, lessThanOrEqualTo(quickTop + 0.5));
      expect(tester.getRect(find.text('Manage')).bottom, lessThanOrEqualTo(tester.getRect(card).top));
      await closeApp(tester, db);
    });

    testWidgets('largest text: "Now add the amount" shows in full too', (tester) async {
      final db = await openAdd(tester, settings: largest);
      await tester.enterText(find.byType(EditableText).last, 'coffee');
      await settle(tester);
      showsInFull(tester, find.text('Now add the amount'));
      notCut(tester, find.textContaining('Like'));
      expect(tester.getRect(bar).top, closeTo(tester.getRect(card).bottom + 10, 0.5));
      await closeApp(tester, db);
    });
  });

  group('SubHeader', () {
    Future<void> pumpHeader(WidgetTester tester, String title, double scale) async {
      tester.view.physicalSize = const Size(720, 1560);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(Mood.aqua),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: SubHeader(title: title)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a long title scales down to fit at the largest text size', (tester) async {
      await pumpHeader(tester, 'Edit expense details', textScaleSteps.last);
      showsInFull(tester, find.text('Edit expense details'));
      final ink = tester.getRect(find.text('Edit expense details'));
      expect(ink.left, greaterThanOrEqualTo(16 + 88));
      expect(ink.right, lessThanOrEqualTo(360 - 16 - 88));
    });

    testWidgets('a short title is left as it is', (tester) async {
      await pumpHeader(tester, 'Pockets', textScaleSteps.last);
      showsInFull(tester, find.text('Pockets'));
      final p = paragraph(tester, find.text('Pockets'));
      expect(tester.getRect(find.text('Pockets')).size, p.size);
      expect(tester.getRect(find.text('Pockets')).center.dx, closeTo(180, 0.5));
    });
  });
}
