import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/charts/chart_parts.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/text_fit.dart';

/// The summary card of Charts ("Total spent | Daily average", and the chip
/// under them) on the 360 x 791 phone at every text size, with the real
/// fonts: every text shows in full, and nothing paints outside the card or
/// its 16 px padding.
void main() {
  setUpAll(loadShotFonts);

  /// The card the total sits in: Charts' first card under the tabs.
  Finder summaryCard() =>
      find.ancestor(of: find.text('Total spent'), matching: find.byType(ChartCard));

  Future<void> expectWhole(
    WidgetTester tester, {
    required String averageLabel,
    required String total,
    required String average,
    required String chip,
  }) async {
    final card = tester.getRect(summaryCard());
    final inner = Rect.fromLTRB(card.left + 16, card.top, card.right - 16, card.bottom);
    for (final shown in ['Total spent', averageLabel, total, average, chip]) {
      // The total and the average may be the same figure (one day of data).
      final matches = find.descendant(of: summaryCard(), matching: find.text(shown));
      expect(matches, findsWidgets, reason: shown);
      for (var i = 0; i < matches.evaluate().length; i++) {
        final finder = matches.at(i);
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(cutReason(paragraph), isNull, reason: '"$shown" is cut');
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(inner.left - 0.5), reason: shown);
        expect(rect.right, lessThanOrEqualTo(inner.right + 0.5), reason: shown);
      }
    }
    // The chip itself (the text sits in it) stays inside the padding too.
    final chipBox = tester.getRect(
      find
          .ancestor(
            of: find.descendant(of: summaryCard(), matching: find.text(chip)),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(chipBox.right, lessThanOrEqualTo(inner.right + 0.5), reason: 'the chip');
    expect(cutTexts(tester, within: summaryCard()), isEmpty);
    expect(textsOutside(tester, summaryCard(), card), isEmpty);
    expect(tester.takeException(), isNull);
  }

  for (final (stepIndex, scale) in textScaleSteps.indexed) {
    final size = stepIndex == textScaleSteps.length - 1
        ? 'largest text'
        : 'text size ${stepIndex + 1} of ${textScaleSteps.length}';

    testWidgets('Charts summary, $size, the mockup data: Month, Year and Week show in full', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: AppSettings(textScale: scale),
      );
      await boardHeight(tester, 791);
      await expectWhole(
        tester,
        averageLabel: 'Daily average',
        total: '34,555',
        average: '1,920',
        chip: '2% more than Sep 1–18',
      );
      await tester.tap(find.text('Year'));
      await settle(tester);
      await expectWhole(
        tester,
        averageLabel: 'Monthly average',
        total: '493,610',
        average: '51,006',
        chip: '3% more than the same period in 2025',
      );
      await tester.tap(find.text('Week'));
      await settle(tester);
      await expectWhole(
        tester,
        averageLabel: 'Daily average',
        total: '1,180',
        average: '1,180',
        chip: '195% more than the week before',
      );
      await closeApp(tester, db);
    });

    testWidgets('Charts summary, $size, big figures: Month shows in full', (tester) async {
      final db = await bigSpendDatabase(
        tester,
        spent: 1234567,
        spentCents: 89,
        before: 617284,
        monthly: 1234567,
      );
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: AppSettings(textScale: scale),
      );
      await boardHeight(tester, 791);
      await expectWhole(
        tester,
        averageLabel: 'Daily average',
        total: '1,234,567.89',
        average: '68,587',
        chip: '100% more than Sep 1–18',
      );
      // The total shrank to its room; the average still sits on its baseline.
      double baseline(String text) {
        final finder = find.descendant(of: summaryCard(), matching: find.text(text));
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
          maxLines: 1,
        )..layout();
        final fromTop = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        painter.dispose();
        // As drawn: a text that was drawn smaller has its baseline scaled too.
        return MatrixUtils.transformPoint(paragraph.getTransformTo(null), Offset(0, fromTop)).dy;
      }

      expect(baseline('1,234,567.89'), closeTo(baseline('68,587'), 0.5));
      await closeApp(tester, db);
    });
  }
}
