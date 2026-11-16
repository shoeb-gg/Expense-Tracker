import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/board.dart';
import '../../support/shots.dart';

/// The centred notes at the foot of Import step 1 and of Export never leave
/// one word alone on their last line, even at the largest text size.
void main() {
  setUpAll(loadShotFonts);

  final largest = AppSettings(textScale: textScaleSteps.last);

  /// The words on the last line of the note [text] (a no-break space does
  /// not join two words here: it counts as the gap it looks like).
  List<String> lastLine(WidgetTester tester, String text) {
    final finder = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').replaceAll('\u00A0', ' ') == text,
    );
    expect(finder, findsOneWidget, reason: text);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)).first,
    );
    final plain = paragraph.text.toPlainText();
    // Each letter's line is where its box sits; the last line is the lowest.
    final tops = <int, double>{};
    for (var i = 0; i < plain.length; i++) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isNotEmpty && plain[i].trim().isNotEmpty) tops[i] = boxes.first.top;
    }
    final lowest = tops.values.reduce((a, b) => a > b ? a : b);
    final line = StringBuffer();
    for (var i = 0; i < plain.length; i++) {
      final top = tops[i];
      if (top != null && top == lowest) line.write(plain[i]);
      if (top == null && line.isNotEmpty) line.write(' ');
    }
    return line.toString().trim().split(RegExp(r'\s+'));
  }

  testWidgets('Import step 1: the note does not end on a lone word', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.importStart, settings: largest);
    await boardHeight(tester, 1700);
    final words = lastLine(tester, 'A file exported from this app works as it is.');
    expect(words.length, greaterThanOrEqualTo(2), reason: 'last line: $words');
    await closeApp(tester, db);
  });

  testWidgets('Export: the note does not end on a lone word', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.export, settings: largest);
    await boardHeight(tester, 1700);
    final words = lastLine(tester, 'One row per expense. Photos are left out.');
    expect(words.length, greaterThanOrEqualTo(2), reason: 'last line: $words');
    await closeApp(tester, db);
  });
}
