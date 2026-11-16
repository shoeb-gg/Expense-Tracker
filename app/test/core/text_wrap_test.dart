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
      expect(keepLastWordsTogether('Hello big world '), 'Hello big world ');
    });

    test('a text of two words stays as it is', () {
      expect(keepLastWordsTogether('Hello world'), 'Hello world');
      expect(keepLastWordsTogether('Hello world '), 'Hello world ');
      expect(keepLastWordsTogether(' Hello world'), ' Hello world');
    });

    test('the last two words join only when they are short enough to share a line', () {
      // 18 characters with the space between: joined.
      expect(
        keepLastWordsTogether('See the abcdefgh ijklmnopq'),
        'See the abcdefgh ijklmnopq',
      );
      // 19 characters: left alone, so two long words can still split.
      expect(
        keepLastWordsTogether('See the abcdefgh ijklmnopqr'),
        'See the abcdefgh ijklmnopqr',
      );
      expect(lastWordsMaxLength, 18);
    });

    test('words already joined stay joined, and nothing is joined twice', () {
      const joined = 'Tap to add an expense';
      expect(keepLastWordsTogether(joined), joined);
      expect(keepLastWordsTogether(keepLastWordsTogether('One two three')), 'One two three');
    });
  });

  group('breakableFileName', () {
    const z = '\u200B';

    test('adds a break mark after _, - and . only', () {
      expect(
        breakableFileName('expenses_export-2026.csv'),
        'expenses_${z}export-${z}2026.${z}csv',
      );
    });

    test('the name itself stays the same', () {
      const name = 'expenses_export_2026_november_final_version.csv';
      expect(breakableFileName(name).replaceAll(z, ''), name);
    });

    test('no mark at the end, before a space or after another mark', () {
      expect(breakableFileName('notes_'), 'notes_');
      expect(breakableFileName('my file_ 2.csv'), 'my file_ 2.${z}csv');
      expect(breakableFileName('a__b'), 'a_${z}_${z}b');
      expect(breakableFileName('plain'), 'plain');
      expect(breakableFileName(''), '');
    });
  });
}
