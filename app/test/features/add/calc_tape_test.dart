import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/add/keypad_panel.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/add_support.dart';
import '../../support/shots.dart';
import '../../support/text_cut.dart';

/// While calculating on the keypad, each number shows in its own pill under
/// the category and the total ("120", "+ 45", "+ 300"), big enough to read
/// at a glance (the user, 2026-11-20: the old grey line was far too small).
void main() {
  setUpAll(loadShotFonts);

  final panel = find.byKey(const ValueKey('keypad'));
  final tape = find.byType(CalcTape);

  /// The text of the pill that reads [text] ("+ 45").
  Finder label(String text) => find.descendant(of: tape, matching: find.text(text));

  /// The pill that reads [text].
  Finder pill(String text) => find.ancestor(of: label(text), matching: find.byType(Container)).first;

  Future<void> keys(WidgetTester tester, String typed) async {
    for (final k in typed.split(' ')) {
      await tester.tap(find.descendant(of: panel, matching: find.text(k)).last);
      await tester.pump();
    }
    await settle(tester);
  }

  Future<AppDatabase> openKeypad(WidgetTester tester, {double scale = 1.0}) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add(), settings: AppSettings(textScale: scale));
    await tester.tap(find.text('Snacks').first);
    await settle(tester);
    return db;
  }

  testWidgets('each number in its own pill, the total alone above them', (tester) async {
    final db = await openKeypad(tester);
    await keys(tester, '1 2 0');
    expect(tape, findsNothing, reason: 'a plain number needs no pills');

    await keys(tester, '+ 4 5 + 3 0 0');
    expect(label('120'), findsOneWidget);
    expect(label('+ 45'), findsOneWidget);
    expect(label('+ 300'), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('465')), findsOneWidget);
    // Read at a glance: 16 px and bold, not the old 12.5 px grey line.
    final p = tester.renderObject<RenderParagraph>(
      find.descendant(of: label('+ 45'), matching: find.byType(RichText)).first,
    );
    expect(p.text.style!.fontSize, 16);
    expect(p.text.style!.fontWeight, FontWeight.w700);
    // Under the total, inside the panel.
    final total = tester.getRect(find.descendant(of: panel, matching: find.text('465')));
    expect(tester.getRect(tape).top, greaterThan(total.bottom));
    expect(tester.getRect(tape).right, closeTo(tester.getRect(panel).right - 16, 0.5));

    // A trailing operator waits in its own pill.
    await keys(tester, '+');
    expect(label('+'), findsOneWidget);
    // "=" works it out: the pills go.
    await keys(tester, '5 =');
    expect(tape, findsNothing);
    expect(find.descendant(of: panel, matching: find.text('470')), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('a long sum: the category is not cut, the newest number shows, '
      'and the first ones are a swipe away', (tester) async {
    final db = await openKeypad(tester);
    await keys(tester, '1 2 0 + 4 5 + 3 0 0 + 8 0 + 1 2 5 0 − 2 0 0 + 9 9');
    expect(isCut(tester, find.descendant(of: panel, matching: find.text('Snacks'))), isFalse);
    final edge = tester.getRect(panel).right - 16;
    expect(tester.getRect(pill('+ 99')).right, closeTo(edge, 0.5));
    expect(tester.getRect(pill('+ 99')).left, greaterThan(tester.getRect(panel).left));
    // The first number is out of view to the left.
    final first = label('120');
    expect(first.evaluate().isEmpty || tester.getRect(first).right < tester.getRect(panel).left + 16, isTrue);

    // Swipe left to right: the first number comes into view.
    await tester.drag(tape, const Offset(600, 0));
    await settle(tester);
    expect(tester.getRect(pill('120')).left, greaterThanOrEqualTo(tester.getRect(panel).left + 16 - 0.5));
    // The next key brings the newest back.
    await keys(tester, '1');
    expect(tester.getRect(pill('+ 991')).right, closeTo(edge, 0.5));
    await closeApp(tester, db);
  });

  testWidgets('no result says so at the end of the row', (tester) async {
    final db = await openKeypad(tester);
    // Below zero has no result.
    await keys(tester, '5 − 1 0');
    expect(label('5'), findsOneWidget);
    expect(label('− 10'), findsOneWidget);
    expect(find.descendant(of: tape, matching: find.text('no result')), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the taller panel still lets the whole grid scroll into view', (tester) async {
    final db = await openKeypad(tester);
    await keys(tester, '1 2 0 + 4 5');
    // A drag on the grid, above the panel.
    await tester.dragFrom(const Offset(180, 200), const Offset(0, -2000));
    await settle(tester);
    final manage = tester.getRect(find.text('Manage'));
    expect(manage.bottom, lessThanOrEqualTo(tester.getRect(panel).top));
    await closeApp(tester, db);
  });

  testWidgets('typing a title while calculating keeps the header visible', (tester) async {
    final db = await openKeypad(tester);
    await keys(tester, '1 2 0 + 4 5');
    showSoftKeyboard(tester, height: 360);
    await tester.tap(find.byType(EditableText).first);
    await settle(tester);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(panel).dy, greaterThanOrEqualTo(88));
    expect(label('+ 45').hitTestable(), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('largest text: the pills grow with the text and nothing is cut', (tester) async {
    final db = await openKeypad(tester, scale: textScaleSteps.last);
    await keys(tester, '1 2 0 + 4 5');
    expect(tester.takeException(), isNull);
    expect(isCut(tester, label('+ 45')), isFalse);
    final text = tester.getRect(label('+ 45'));
    final box = tester.getRect(pill('+ 45'));
    expect(text.top, greaterThanOrEqualTo(box.top));
    expect(text.bottom, lessThanOrEqualTo(box.bottom));
    await closeApp(tester, db);
  });
}
