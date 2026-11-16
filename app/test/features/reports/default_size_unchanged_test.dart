import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/charts/chart_parts.dart';
import 'package:spill_the_bills/features/charts/column_chart.dart';
import 'package:spill_the_bills/features/charts/ring_chart.dart';
import 'package:spill_the_bills/router.dart';

import '../../support/board.dart';
import '../../support/shots.dart';

/// At the default text size the figures that large text now scales down sit
/// exactly where they always did: the rectangles below were measured before
/// the change (360 px wide phone, real fonts, mockup data). A figure that
/// fits is a plain text, in the same box.
void main() {
  setUpAll(loadShotFonts);

  void expectAt(WidgetTester tester, Finder finder, Rect rect, String what) {
    expect(finder, findsOneWidget, reason: what);
    final r = tester.getRect(finder);
    for (final (a, b, side) in [
      (r.left, rect.left, 'left'),
      (r.top, rect.top, 'top'),
      (r.right, rect.right, 'right'),
      (r.bottom, rect.bottom, 'bottom'),
    ]) {
      expect(a, closeTo(b, 0.01), reason: '$what, $side: $r instead of $rect');
    }
  }

  /// [finder] under the ring centre, its box measured from the ring's
  /// top left corner (the ring scrolls with the page).
  void expectInRing(WidgetTester tester, String text, Rect rect) {
    final finder = find.descendant(of: find.byType(RingCenter), matching: find.text(text));
    final ring = tester.getTopLeft(find.byType(RingChart));
    expectAt(tester, finder, rect.shift(ring), '"$text" in the ring');
  }

  testWidgets('Reports: the stats, the axis, the month rows and the all-time '
      'figures do not move', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.reports);
    await boardHeight(tester, 2200);
    final card = find.ancestor(
      of: find.text('Monthly statistics'),
      matching: find.byType(Column),
    ).first;
    Finder inStats(String text) => find.descendant(of: card, matching: find.text(text));

    expectAt(tester, inStats('Spent so far'), const Rect.fromLTRB(32, 128, 103.45, 144), 'Spent so far');
    expectAt(tester, inStats('34,555'), const Rect.fromLTRB(32, 146, 95.04, 170), '34,555');
    expectAt(tester, inStats('Daily average'), const Rect.fromLTRB(139.94, 128, 220.06, 144), 'Daily average');
    expectAt(tester, inStats('1,920'), const Rect.fromLTRB(155.71, 146, 204.29, 170), '1,920');
    expectAt(tester, inStats('vs Sep 1–18'), const Rect.fromLTRB(261.64, 128, 328, 144), 'vs Sep 1–18');
    expectAt(tester, inStats('2% more'), const Rect.fromLTRB(248.39, 146, 328, 170), '2% more');
    expectAt(tester, find.text('Biggest category'), const Rect.fromLTRB(88, 201, 191.91, 217), 'Biggest category');
    expectAt(tester, find.text('Year at a glance'), const Rect.fromLTRB(32, 284, 188, 304), 'Year at a glance');
    // The axis (the 28 px column) and the amounts of the month rows.
    expectAt(tester, find.text('60K'), const Rect.fromLTRB(32, 409, 60, 423), '60K');
    expectAt(tester, find.text('0').first, const Rect.fromLTRB(32, 549, 60, 563), '0');
    expectAt(tester, find.text('52,475').last, const Rect.fromLTRB(160, 970, 248, 990), '52,475');
    expectAt(tester, find.text('50,276'), const Rect.fromLTRB(254.69, 692, 328, 720), '50,276');
    await closeApp(tester, db);
  });

  testWidgets('Charts: the total, the average and the chip do not move', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts);
    await boardHeight(tester, 791);
    expectAt(tester, find.text('Total spent'), const Rect.fromLTRB(32, 184, 235.89, 200), 'Total spent');
    expectAt(tester, find.text('Daily average'), const Rect.fromLTRB(247.89, 184, 328, 200), 'Daily average');
    expectAt(tester, find.text('34,555').first, const Rect.fromLTRB(32, 202, 235.89, 242), 'the total');
    expectAt(tester, find.text('1,920'), const Rect.fromLTRB(247.89, 215.71, 328, 239.71), 'the average');
    expectAt(tester, find.text('2% more than Sep 1–18'), const Rect.fromLTRB(64, 260, 203, 276), 'the chip');

    await tester.tap(find.text('Year'));
    await settle(tester);
    expectAt(tester, find.text('493,610').first, const Rect.fromLTRB(32, 202, 216.9, 242), 'the year total');
    expectAt(tester, find.text('51,006'), const Rect.fromLTRB(228.9, 215.71, 328, 239.71), 'the year average');
    expectAt(
      tester,
      find.text('3% more than the same period in 2025'),
      const Rect.fromLTRB(64, 260, 295.1, 276),
      'the long chip',
    );
    await closeApp(tester, db);
  });

  testWidgets('Charts: the ring centre does not move (the total, and a tapped '
      'slice with its Details pill)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts);
    await boardHeight(tester, 791);
    // Measured before the ring centre fitted itself to the hole of the ring.
    expectInRing(tester, 'Total', const Rect.fromLTRB(121.45, 103, 150.55, 119));
    expectInRing(tester, '34,555', const Rect.fromLTRB(95.18, 121, 176.82, 151));
    expectInRing(tester, '11 categories', const Rect.fromLTRB(99.29, 153, 172.71, 169));

    // A tapped slice: name, amount, share, "Details" and the pill round it.
    final tapped = <(String, Rect, String, Rect, String, Rect)>[
      (
        'Groceries',
        const Rect.fromLTRB(106.13, 88, 165.87, 104),
        '6,540',
        const Rect.fromLTRB(101.41, 106, 170.59, 136),
        '18.9% of total',
        const Rect.fromLTRB(96.81, 138, 175.19, 154),
      ),
      (
        'Health',
        const Rect.fromLTRB(116.27, 88, 155.73, 104),
        '1,180',
        const Rect.fromLTRB(106.94, 106, 165.06, 136),
        '3.4% of total',
        const Rect.fromLTRB(98.99, 138, 173.01, 154),
      ),
    ];
    for (final (name, nameBox, amount, amountBox, share, shareBox) in tapped) {
      final row = find.text(name);
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pump();
      await tester.tap(row);
      await settle(tester);
      expectInRing(tester, name, nameBox);
      expectInRing(tester, amount, amountBox);
      expectInRing(tester, share, shareBox);
      expectInRing(tester, 'Details', const Rect.fromLTRB(109.83, 164, 150.17, 180));
      expectAt(
        tester,
        find.descendant(of: find.byType(RingCenter), matching: find.byType(DetailsPill)),
        const Rect.fromLTRB(99.83, 160, 172.17, 184).shift(tester.getTopLeft(find.byType(RingChart))),
        'the Details pill',
      );
      // Tap it again: back to the total.
      await tester.tap(find.text(name).last);
      await settle(tester);
    }
    await closeApp(tester, db);
  });

  /// [text] under [within], its box measured from the top left of [origin].
  void expectUnder(WidgetTester tester, Finder within, Finder origin, String text, Rect rect) {
    final finder = find.descendant(of: within, matching: find.text(text));
    expectAt(tester, finder, rect.shift(tester.getTopLeft(origin)), '"$text"');
  }

  testWidgets('Charts: the Top days legend does not move', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts);
    await boardHeight(tester, 1000);
    await tester.tap(find.text('Top days'));
    await settle(tester);
    // Measured before the legend fitted its lines (from the ring's top left).
    final ring = find.byType(RingChart);
    final card = find.ancestor(of: ring, matching: find.byType(ChartCard)).first;
    expectUnder(tester, card, ring, 'Thu, Oct 1', const Rect.fromLTRB(24, 290, 83.29, 306));
    expectUnder(tester, card, ring, '15,090', const Rect.fromLTRB(24, 306, 63.59, 322));
    expectUnder(tester, card, ring, 'Mon, Oct 12', const Rect.fromLTRB(184, 338, 255.88, 354));
    expectUnder(tester, card, ring, '12 other days', const Rect.fromLTRB(184, 386, 263.28, 402));
    expectUnder(tester, card, ring, '8,900', const Rect.fromLTRB(184, 402, 216.39, 418));
    await closeApp(tester, db);
  });

  testWidgets('Charts: the Over time axis and labels do not move', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts);
    await boardHeight(tester, 791);
    await tester.tap(find.text('Over time'));
    await settle(tester);
    // Measured before the axis labels and the peak label fitted themselves
    // (from the chart's top left).
    final chart = find.byType(ColumnChart);
    void at(String text, Rect rect) => expectUnder(tester, chart, chart, text, rect);
    at('0', const Rect.fromLTRB(0, 187, 28, 201));
    at('20K', const Rect.fromLTRB(0, 17, 28, 31));
    at('29', const Rect.fromLTRB(251.52, 202, 291.52, 216));
    at('Still to come', const Rect.fromLTRB(207.67, 155.68, 269.81, 169.68));
    at('Peak 15,090', const Rect.fromLTRB(39.1, 47.74, 107.71, 61.74));

    await tester.tap(find.text('Year'));
    await settle(tester);
    at('80K', const Rect.fromLTRB(0, 17, 28, 31));
    at('so far', const Rect.fromLTRB(250.58, 118.57, 290.58, 132.57));
    at('Peak 54,330', const Rect.fromLTRB(55.67, 60.55, 126.16, 74.55));

    await tester.tap(find.text('Week'));
    await settle(tester);
    at('1,500', const Rect.fromLTRB(0, 17, 28, 31));
    at('Peak 1,180', const Rect.fromLTRB(45.14, 42.27, 103.11, 56.27));
    await closeApp(tester, db);
  });
}

