import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/features/charts/chart_parts.dart';
import 'package:spill_the_bills/features/charts/ring_chart.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/text_fit.dart';

/// The ring centre of Charts ("Total", the amount, "11 categories"; or a
/// tapped slice's name, amount and share) on the 360 x 791 phone with the
/// real fonts: every line shows in full (no "...", no line limit hit, no
/// letters past its edge) and inside the ring's hole, at the default and the
/// largest text size, in every number style, with the cents on and off.
void main() {
  setUpAll(loadShotFonts);

  /// Every line of the ring centre, in full and inside the hole of the ring.
  void expectCentreFits(WidgetTester tester, List<String> lines) {
    final centre = find.byType(RingCenter);
    expect(centre, findsOneWidget);
    final middle = tester.getCenter(find.byType(RingChart));
    for (final shown in lines) {
      final match = find.descendant(of: centre, matching: find.text(shown));
      expect(match, findsOneWidget, reason: 'the centre shows "$shown"');
    }
    expect(cutTexts(tester, within: centre), isEmpty);
    // The box of every text (the lines and the Details pill's label) has all
    // four corners inside the ring's inner circle.
    final outside = <String>[];
    for (final element in find
        .descendant(of: centre, matching: find.byType(RichText))
        .evaluate()) {
      final p = element.renderObject;
      if (p is! RenderParagraph) continue;
      final box = MatrixUtils.transformRect(
        p.getTransformTo(null),
        Offset.zero & p.size,
      );
      final far = [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight]
          .map((corner) => (corner - middle).distance)
          .reduce(math.max);
      if (far > RingChart.inner + 0.5) {
        outside.add(
          '"${p.text.toPlainText()}" reaches ${far.toStringAsFixed(1)} px '
          'from the middle of the ring (the hole is ${RingChart.inner} px)',
        );
      }
    }
    expect(outside, isEmpty);
    expect(tester.takeException(), isNull);
  }

  const styles = <NumberStyle, String>{
    NumberStyle.comma: '1,234,567.89',
    NumberStyle.spaceDot: '1 234 567.89',
    NumberStyle.lakh: '12,34,567.89',
    NumberStyle.plain: '1234567.89',
  };

  for (final (stepIndex, scale) in [1.0, textScaleSteps.last].indexed) {
    final size = stepIndex == 0 ? 'default text' : 'largest text';

    for (final MapEntry(key: style, value: total) in styles.entries) {
      testWidgets('ring centre, $size, ${style.name} style: a big total '
          'shows in full inside the hole', (tester) async {
        final db = await sampleWithBigTotal(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.charts,
          settings: AppSettings(textScale: scale, numberStyle: style),
        );
        await boardHeight(tester, 791);
        expectCentreFits(tester, ['Total', total, '11 categories']);
        await closeApp(tester, db);
      });

      testWidgets('ring centre, $size, ${style.name} style: a tapped slice '
          'with the longest name and a big amount shows in full inside the '
          'hole', (tester) async {
        final db = await sampleWithBigCategory(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.charts,
          settings: AppSettings(textScale: scale, numberStyle: style),
        );
        await boardHeight(tester, 791);
        final row = find.text(longestCategoryName);
        await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
        await tester.pump();
        await tester.tap(row);
        await settle(tester);
        expectCentreFits(tester, [longestCategoryName, total, '97.3% of total']);
        await closeApp(tester, db);
      });
    }

    testWidgets('ring centre, $size, Top days: a big total shows in full '
        'inside the hole', (tester) async {
      final db = await sampleWithBigTotal(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: AppSettings(textScale: scale),
      );
      await boardHeight(tester, 791);
      await tester.tap(find.text('Top days'));
      await settle(tester);
      expectCentreFits(tester, ['Top 5 days']);
      await closeApp(tester, db);
    });

    testWidgets('ring centre, $size, cents off: a big total and a tapped '
        'slice show in full inside the hole', (tester) async {
      final db = await sampleWithBigCategory(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: AppSettings(textScale: scale, showDecimals: false),
      );
      await boardHeight(tester, 791);
      expectCentreFits(tester, ['Total', '1,269,123', '12 categories']);
      final row = find.text(longestCategoryName);
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pump();
      await tester.tap(row);
      await settle(tester);
      expectCentreFits(tester, [longestCategoryName, '1,234,568', '97.3% of total']);
      await closeApp(tester, db);
    });
  }
}
