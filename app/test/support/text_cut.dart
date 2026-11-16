import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether any text that matches [text] is cut: ended with an ellipsis, or
/// clipped at the side. Every match is looked at; at least one must exist.
bool isCut(WidgetTester tester, Finder text) {
  final count = text.evaluate().length;
  expect(count, greaterThan(0), reason: 'nothing found for $text');
  for (var i = 0; i < count; i++) {
    final p = tester.renderObject<RenderParagraph>(
      find.descendant(of: text.at(i), matching: find.byType(RichText)).first,
    );
    if (p.didExceedMaxLines) return true;
    // The space that ends a wrapped line hangs over the edge; only the
    // letters count.
    final plain = p.text.toPlainText();
    for (var c = 0; c < plain.length; c++) {
      if (plain[c].trim().isEmpty) continue;
      final boxes = p.getBoxesForSelection(TextSelection(baseOffset: c, extentOffset: c + 1));
      if (boxes.any((b) => b.right > p.size.width + 0.5)) return true;
    }
  }
  return false;
}

/// The text widget whose text is [text], whether or not its words are joined
/// by no-break spaces (U+00A0) and break marks (U+200B) for display.
Finder noteText(String text) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final shown = w.data ?? w.textSpan?.toPlainText() ?? '';
  return shown.replaceAll(' ', ' ').replaceAll('​', '') == text;
});

/// The words on the last line of the one text widget [text] finds. A
/// no-break space counts as the gap it looks like, so two joined words are
/// still two words.
List<String> lastLineWords(WidgetTester tester, Finder text) {
  expect(text, findsOneWidget, reason: '$text');
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
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
