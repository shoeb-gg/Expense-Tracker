// The card band: a title with a note on the right ("What happens" and
// "1,000 rows in the file"). The real font, the 328 px card of a 360 px screen.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/shots.dart' show loadShotFonts;

void main() {
  setUpAll(loadShotFonts);

  /// A band at text scale [scale] in a card 328 px wide.
  Future<void> pumpBand(
    WidgetTester tester, {
    required double scale,
    required String title,
    required String note,
  }) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Mood.aqua),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: BandCard(title: title, trailingText: note),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The text shows whole: not ended with "...".
  bool whole(WidgetTester tester, String text) =>
      !tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

  final largest = textScaleSteps.last;

  testWidgets('at the default size the note sits on the title line', (tester) async {
    await pumpBand(tester, scale: 1, title: 'What happens', note: '312 rows in the file');
    final title = tester.getRect(find.text('What happens'));
    final note = tester.getRect(find.text('312 rows in the file'));
    expect(whole(tester, 'What happens'), isTrue);
    expect(note.right, 16 + 328 - 16);
    expect(note.bottom, closeTo(title.bottom - 4, 4));
    expect(tester.getSize(find.byType(BandCard)).height, 48);
  });

  for (final note in ['312 rows in the file', '1,000 rows in the file', '5,000 rows in the file']) {
    testWidgets('largest text: "$note" and the title both show in full', (tester) async {
      await pumpBand(tester, scale: largest, title: 'What happens', note: note);
      expect(whole(tester, 'What happens'), isTrue, reason: 'title');
      expect(whole(tester, note), isTrue, reason: 'note');
      // The note wraps to a second line beside the title; the band holds it.
      expect(tester.getSize(find.byType(BandCard)).height, 48);
      final noteBox = tester.getRect(find.text(note));
      final card = tester.getRect(find.byType(BandCard));
      expect(noteBox.right, card.right - 16);
      expect(noteBox.top, greaterThanOrEqualTo(card.top));
      expect(noteBox.bottom, lessThanOrEqualTo(card.top + 48));
    });
  }
}
