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
///
/// The one exception is a category name: it shrinks to 75% of its font size
/// at most, and a name that needs less ends in "..." on its one line.
void main() {
  setUpAll(loadShotFonts);

  /// The scale a text is drawn at, over the app's text size setting.
  double drawnScale(WidgetTester tester, Finder text, double appScale) {
    final paragraph = tester.renderObject<RenderParagraph>(text);
    return paragraph.textScaler.scale(1) / appScale;
  }

  /// Every line of the ring centre, in full and inside the hole of the ring.
  /// [cutTitle] is a name expected to be shown cut: drawn at 75% of its size
  /// on one line, ended with "...".
  void expectCentreFits(
    WidgetTester tester,
    List<String> lines, {
    required double scale,
    String? cutTitle,
  }) {
    final centre = find.byType(RingCenter);
    expect(centre, findsOneWidget);
    final middle = tester.getCenter(find.byType(RingChart));
    for (final shown in lines) {
      final match = find.descendant(of: centre, matching: find.text(shown));
      expect(match, findsOneWidget, reason: 'the centre shows "$shown"');
    }
    if (cutTitle != null) {
      final title = find.descendant(of: centre, matching: find.text(cutTitle));
      expect(title, findsOneWidget, reason: 'the centre shows "$cutTitle"');
      final paragraph = tester.renderObject<RenderParagraph>(title);
      expect(paragraph.didExceedMaxLines, isTrue, reason: 'the name is cut');
      expect(tester.widget<Text>(title).overflow, TextOverflow.ellipsis);
      expect(tester.widget<Text>(title).maxLines, 1);
      expect(
        drawnScale(tester, title, scale),
        closeTo(0.75, 0.005),
        reason: 'a name too long for 75% stays at 75%',
      );
    }
    expect(
      [
        for (final why in cutTexts(tester, within: centre))
          if (cutTitle == null || !why.startsWith('"$cutTitle"')) why,
      ],
      isEmpty,
    );
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
        expectCentreFits(tester, ['Total', total, '11 categories'], scale: scale);
        await closeApp(tester, db);
      });

      testWidgets('ring centre, $size, ${style.name} style: a tapped slice '
          'with the longest name and a big amount: the name ends in "..." at '
          '75%, the amount shows in full inside the hole', (tester) async {
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
        expectCentreFits(
          tester,
          [total, '97.3% of total'],
          scale: scale,
          cutTitle: longestCategoryName,
        );
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
      expectCentreFits(tester, ['Top 5 days'], scale: scale);
      await closeApp(tester, db);
    });

    testWidgets('ring centre, $size, Online Subscriptions tapped: it shrinks '
        'to its room, to 75% at most', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: AppSettings(textScale: scale),
      );
      await boardHeight(tester, 791);
      final row = find.text('Online Subscriptions');
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pump();
      await tester.tap(row);
      await settle(tester);
      if (scale == 1.0) {
        // Needs 81% of its size: shows in full.
        expectCentreFits(
          tester,
          ['Online Subscriptions', '685', '2.0% of total'],
          scale: scale,
        );
        final title = find.descendant(
          of: find.byType(RingCenter),
          matching: find.text('Online Subscriptions'),
        );
        expect(drawnScale(tester, title, scale), inInclusiveRange(0.75, 0.9));
      } else {
        // Needs half: stays at 75% and ends in "...".
        expectCentreFits(
          tester,
          ['685', '2.0% of total'],
          scale: scale,
          cutTitle: 'Online Subscriptions',
        );
      }
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
      expectCentreFits(tester, ['Total', '1,269,123', '12 categories'], scale: scale);
      final row = find.text(longestCategoryName);
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pump();
      await tester.tap(row);
      await settle(tester);
      expectCentreFits(
        tester,
        ['1,234,568', '97.3% of total'],
        scale: scale,
        cutTitle: longestCategoryName,
      );
      await closeApp(tester, db);
    });
  }
}
