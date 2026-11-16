import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/features/charts/chart_parts.dart';
import 'package:spill_the_bills/features/charts/ring_chart.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/text_fit.dart';

/// The legend under the Top days ring ("1 Sun, Oct 4 / 6,540 ...", "+12 12
/// other days") on the 360 x 791 phone at every text size, with the real
/// fonts: every name and amount shows in full, inside its entry, and nothing
/// paints outside the card.
void main() {
  setUpAll(loadShotFonts);

  /// The card with the ring and the legend.
  Finder ringCard() =>
      find.ancestor(of: find.byType(RingChart), matching: find.byType(ChartCard)).first;

  /// Opens Top days and checks every text of the card: whole, and within the
  /// card (the legend reaches 8 px into its padding, no further).
  Future<void> expectLegendWhole(WidgetTester tester) async {
    await tester.tap(find.text('Top days'));
    await settle(tester);
    expect(find.textContaining('other days'), findsOneWidget);
    expect(cutTexts(tester, within: ringCard()), isEmpty);
    final card = tester.getRect(ringCard());
    expect(textsOutside(tester, ringCard(), card), isEmpty);
    // Each legend text stays inside the 8 px padding of its entry.
    for (final entry in find
        .descendant(of: ringCard(), matching: find.byType(Pressable))
        .evaluate()) {
      final box = tester.getRect(find.byWidget(entry.widget));
      expect(
        textsOutside(
          tester,
          find.byWidget(entry.widget),
          Rect.fromLTRB(box.left, box.top, box.right - 8, box.bottom),
        ),
        isEmpty,
        reason: 'an entry of the legend',
      );
    }
    expect(tester.takeException(), isNull);
  }

  for (final (stepIndex, scale) in textScaleSteps.indexed) {
    final size = stepIndex == textScaleSteps.length - 1
        ? 'largest text'
        : 'text size ${stepIndex + 1} of ${textScaleSteps.length}';

    testWidgets('Top days legend, $size, the mockup data: every entry shows '
        'in full', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: AppSettings(textScale: scale),
      );
      await boardHeight(tester, 791);
      await expectLegendWhole(tester);
      await closeApp(tester, db);
    });

    for (final style in NumberStyle.values) {
      testWidgets('Top days legend, $size, ${style.name} style, a big day: '
          'every entry shows in full', (tester) async {
        final db = await sampleWithBigTotal(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.charts,
          settings: AppSettings(textScale: scale, numberStyle: style),
        );
        await boardHeight(tester, 791);
        await expectLegendWhole(tester);
        await closeApp(tester, db);
      });
    }
  }
}
