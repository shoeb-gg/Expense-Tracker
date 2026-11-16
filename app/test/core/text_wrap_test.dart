import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/text_wrap.dart';

void main() {
  group('keepLastWordsTogether', () {
    test('joins the last two words with a no-break space', () {
      expect(
        keepLastWordsTogether('A file exported from this app works as it is.'),
        'A file exported from this app works as it\u00A0is.',
      );
      expect(keepLastWordsTogether('One two three'), 'One two\u00A0three');
    });

    test('the wording stays the same', () {
      const text = 'One row per expense. Photos are left out.';
      expect(keepLastWordsTogether(text).replaceAll('\u00A0', ' '), text);
    });

    test('one word, an empty text and a text with a trailing space', () {
      expect(keepLastWordsTogether('Hello'), 'Hello');
      expect(keepLastWordsTogether(''), '');
      expect(keepLastWordsTogether('   '), '   ');
      expect(keepLastWordsTogether('Hello world '), 'Hello\u00A0world ');
    });
  });
}
