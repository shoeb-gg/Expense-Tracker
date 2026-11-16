import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/text_cut.dart';

/// Settings and its choice sheets at the default and the largest text size,
/// with the real font (the row widths need it): nothing is cut off with "…"
/// or clipped, and nothing moves at the default size.
void main() {
  setUpAll(loadShotFonts);

  final largest = AppSettings(textScale: textScaleSteps.last);

  /// Opens Settings on a view tall enough to build every row.
  Future<AppDatabase> openSettings(WidgetTester tester, {AppSettings? settings}) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.settings, settings: settings ?? const AppSettings());
    await boardHeight(tester, 2400);
    return db;
  }

  RenderParagraph paragraphOf(WidgetTester tester, Finder text) =>
      tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)).first,
      );

  /// Right edge of the laid-out text, and its line count.
  ({double right, int lines}) layoutOf(RenderParagraph p) {
    final length = p.text.toPlainText().length;
    final boxes = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length));
    if (boxes.isEmpty) return (right: 0, lines: 0);
    return (
      right: boxes.map((b) => b.right).reduce((a, b) => a > b ? a : b),
      lines: {for (final b in boxes) b.top.round()}.length,
    );
  }

  /// The text is whole: not ended with "…", not clipped at the side.
  bool isCut(RenderParagraph p) => p.didExceedMaxLines || layoutOf(p).right > p.size.width + 0.5;

  /// Every Text under [within] that is cut off.
  List<String> cutTexts(WidgetTester tester, Finder within) => [
    for (final element in find.descendant(of: within, matching: find.byType(Text)).evaluate())
      if (isCut(paragraphOf(tester, find.byWidget(element.widget)))) (element.widget as Text).data ?? '?',
  ];

  Future<void> openSheet(WidgetTester tester, String row) async {
    await revealRow(tester, noteText(row));
    await tester.tap(noteText(row));
    await settle(tester);
  }

  const toggles = [
    ('Monthly total on Home', 'The big number at the top of Home'),
    ('Privacy hide', 'Mask the total until you tap the eye'),
    ('Calendar button', 'Shortcut to the calendar on Home'),
    ('Amounts in calendar days', 'Show each day’s total in its cell'),
  ];

  group('at the default size nothing moves', () {
    testWidgets('the toggle rows: texts and switches keep their places', (tester) async {
      final db = await openSettings(tester);
      // The Theme row (68 px) is the first row of Appearance.
      const titleTops = [571.0, 639.0, 707.0, 775.0];
      for (var i = 0; i < toggles.length; i++) {
        final (title, sub) = toggles[i];
        final t = tester.getRect(noteText(title));
        final s = tester.getRect(noteText(sub));
        expect(t.left, 32, reason: title);
        expect(t.top, titleTops[i], reason: title);
        expect(s.top, titleTops[i] + 22, reason: sub);
        expect(s.height, 16, reason: '$sub stays on one line');
      }
      // Each switch sits at the right edge, centred on its row.
      final switches = tester.widgetList<AppSwitch>(find.byType(AppSwitch)).toList();
      for (var i = 0; i < toggles.length; i++) {
        final r = tester.getRect(find.byWidget(switches[i]));
        expect(r.left, 280);
        expect(r.right, 328);
        expect(r.center.dy, titleTops[i] + 19, reason: toggles[i].$1);
      }
      await closeApp(tester, db);
    });

    testWidgets('Show decimals sits where Thousands separator did', (tester) async {
      final db = await openSettings(tester);
      // Measured before the change: the same 56 px row, and the Calculator
      // keys row below it did not move.
      Rect row(String title) => tester.getRect(find.widgetWithText(ListRow, title));
      expect(row('Number format'), const Rect.fromLTRB(16, 1200, 344, 1256));
      expect(row('Show decimals'), const Rect.fromLTRB(16, 1256, 344, 1312));
      expect(row('Calculator keys').top, 1312);
      expect(tester.getRect(find.text('Show decimals')).top, 1274);
      expect(tester.getRect(find.text('Calculator keys')).top, 1330);
      expect(tester.widgetList<ListRow>(find.byType(ListRow)), hasLength(16));
      expect(find.text('Thousands separator'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('the other rows keep their places', (tester) async {
      final db = await openSettings(tester);
      expect(tester.getRect(find.text('Manage pockets')).top, 959);
      expect(tester.getRect(noteText('Add, edit, delete')).top, 981);
      expect(tester.getRect(find.text('Manage categories')).top, 1087);
      expect(tester.getRect(noteText('Add, edit, delete, reorder')).top, 1109);
      expect(tester.getRect(find.text('Export')).top, 1443);
      expect(tester.getRect(find.text('Automatic backup')).top, 1579);
      expect(tester.getRect(noteText('Phone and Google Drive')).top, 1601);
      expect(tester.getRect(find.text('Delete all data')).top, 1715);
      expect(tester.getRect(noteText('This can’t be undone')).top, 1737);
      expect(cutTexts(tester, find.byType(Scaffold)), isEmpty);
      await closeApp(tester, db);
    });
  });

  group('at the largest size every row shows in full', () {
    testWidgets('no text on Settings is cut off', (tester) async {
      final db = await openSettings(tester, settings: largest);
      expect(cutTexts(tester, find.byType(Scaffold)), isEmpty);
      await closeApp(tester, db);
    });

    testWidgets('the two long subtitles wrap, and the switch stays centred', (tester) async {
      final db = await openSettings(tester, settings: largest);
      for (final (title, sub) in toggles) {
        final t = tester.getRect(noteText(title));
        final s = tester.getRect(noteText(sub));
        final p = paragraphOf(tester, noteText(sub));
        expect(isCut(p), isFalse, reason: sub);
        if (title == 'Monthly total on Home' || title == 'Privacy hide') {
          expect(layoutOf(p).lines, greaterThanOrEqualTo(2), reason: '$sub wraps');
        }
        // The switch is at the right edge and centred on the text block.
        final row = tester
            .widgetList<AppSwitch>(find.byType(AppSwitch))
            .map((w) => tester.getRect(find.byWidget(w)))
            .firstWhere((r) => (r.center.dy - (t.top + s.bottom) / 2).abs() < 1);
        expect(row.right, 328, reason: title);
        expect(row.size, const Size(48, 28), reason: title);
        // The text ends before the switch.
        expect(s.right, lessThanOrEqualTo(row.left), reason: sub);
        expect(t.right, lessThanOrEqualTo(row.left), reason: title);
      }
      await closeApp(tester, db);
    });

    testWidgets('a wrapped row grows: its text keeps clear of the lines around it', (
      tester,
    ) async {
      final db = await openSettings(tester, settings: largest);
      final rows = [
        for (final (title, sub) in toggles)
          (tester.getRect(noteText(title)), tester.getRect(noteText(sub))),
      ];
      for (var i = 0; i < rows.length - 1; i++) {
        final (_, sub) = rows[i];
        final (nextTitle, _) = rows[i + 1];
        // At least 20 px between a row's text and the next row's (the
        // hairline lies in the middle).
        expect(nextTitle.top - sub.bottom, greaterThanOrEqualTo(20), reason: 'row $i');
      }
      await closeApp(tester, db);
    });

    testWidgets('Manage categories and Automatic backup show in full', (tester) async {
      final db = await openSettings(tester, settings: largest);
      for (final text in [
        'Manage categories',
        'Add, edit, delete, reorder',
        'Phone and Google Drive',
      ]) {
        expect(isCut(paragraphOf(tester, noteText(text))), isFalse, reason: text);
      }
      // The tiles and the "Coming later" pill keep to the right edge.
      expect(tester.getRect(find.text('Coming later')).right, lessThanOrEqualTo(328));
      expect(tester.getRect(find.text('+13')).right, lessThanOrEqualTo(328));
      await closeApp(tester, db);
    });
  });

  group('the choice sheets', () {
    for (final big in [false, true]) {
      final size = big ? 'largest' : 'default';
      for (final row in ['Number format', 'First day of the week', 'Calculator keys']) {
        testWidgets('$row: nothing is cut off ($size text)', (tester) async {
          final db = await sampleDatabase(tester);
          await pumpApp(
            tester,
            db: db,
            location: Routes.settings,
            settings: big ? largest : const AppSettings(),
          );
          await openSheet(tester, row);
          expect(find.byType(AppSheet), findsOneWidget);
          expect(cutTexts(tester, find.byType(AppSheet)), isEmpty);
          await closeApp(tester, db);
        });
      }
    }

    testWidgets('Calculator keys: "Plus and minus" shows whole at the largest size', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.settings, settings: largest);
      await openSheet(tester, 'Calculator keys');
      final label = find.descendant(of: find.byType(AppSheet), matching: find.text('Plus and minus'));
      expect(isCut(paragraphOf(tester, label)), isFalse);
      // The row is as wide as the sheet allows, and the tick stays inside.
      expect(tester.getRect(label).right, lessThanOrEqualTo(360 - 16 - 16));
      await closeApp(tester, db);
    });

    testWidgets('Calculator keys at the default size: the rows are still 56 px', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.settings);
      await openSheet(tester, 'Calculator keys');
      final rows = find.byType(OptionRow);
      expect(rows, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        expect(tester.getSize(rows.at(i)).height, 56);
      }
      await closeApp(tester, db);
    });
  });
}
