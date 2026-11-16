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
