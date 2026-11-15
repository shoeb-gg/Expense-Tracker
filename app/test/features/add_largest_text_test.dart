import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/add_support.dart';
import '../support/shots.dart';

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

    testWidgets('largest text: Edit expense shows in full, with a pocket pill', (tester) async {
      final db = await openAdd(
        tester,
        settings: largest,
        pockets: true,
        route: Routes.editExpense(doctorVisitId),
      );
      showsInFull(tester, find.text('Edit expense'));
      showsInFull(tester, find.text('Cancel'));
      showsInFull(tester, find.text('Personal'));
      final title = tester.getRect(find.text('Edit expense'));
      expect(title.left, greaterThanOrEqualTo(tester.getRect(cancel).right));
      expect(title.right, lessThanOrEqualTo(tester.getRect(pocketPill('Personal')).left));
      await closeApp(tester, db);
    });

    testWidgets('largest text: short pocket names show in full', (tester) async {
      final db = await sampleDatabase(tester);
      await addSamplePockets(tester, db);
      await tester.runAsync(() => PocketsRepo(db).add(name: 'Test trip', emoji: '\u{1F9F3}'));
      await pumpApp(tester, db: db, location: Routes.add(), settings: largest);

      showsInFull(tester, find.text('Personal'));
      var current = 'Personal';
      for (final name in ['Test trip', 'Business', 'Personal']) {
        await tap(tester, pocketPill(current));
        await tap(tester, find.text(name).last);
        current = name;
        showsInFull(tester, find.text(name));
        final pill = tester.getRect(pocketPill(name));
        expect(pill.right, 344, reason: name);
        expect(pill.left, greaterThanOrEqualTo(180), reason: name);
        expect(
          tester.getRect(find.text('Add expense')).right,
          lessThanOrEqualTo(pill.left),
          reason: name,
        );
        showsInFull(tester, find.text('Add expense'));
        showsInFull(tester, find.text('Cancel'));
      }
      await closeApp(tester, db);
    });

    testWidgets('largest text: a long pocket name ellipsizes and breaks nothing', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await tester.runAsync(
        () => PocketsRepo(db).add(name: 'The Smiths family holiday', emoji: '\u{1F3D6}'),
      );
      await pumpApp(tester, db: db, location: Routes.add(), settings: largest);
      await tap(tester, pocketPill('Personal'));
      await tap(tester, find.text('The Smiths family holiday').last);
      final pill = tester.getRect(pocketPill('The Smiths family holiday'));
      expect(pill.right, 344);
      expect(pill.width, lessThanOrEqualTo(140));
      expect(paragraph(tester, find.text('The Smiths family holiday')).didExceedMaxLines, isTrue);
      showsInFull(tester, find.text('Add expense'));
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
