import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/charts/chart_model.dart';
import 'package:spill_the_bills/features/charts/column_chart.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/text_fit.dart';

/// The "Over time" column chart of Charts on the 360 x 791 phone at every
/// text size, with the real fonts: the axis labels, the "Peak ..." label and
/// the pinned label of a column show in full and inside the chart (296 px
/// wide, in its card), also with a day of 1,234,567.89.
void main() {
  setUpAll(loadShotFonts);

  /// Opens Over time on [tab] ("Week", "Month", "Year").
  Future<void> openOverTime(
    WidgetTester tester,
    AppDatabase db,
    double scale, {
    String tab = 'Month',
    NumberStyle style = NumberStyle.comma,
  }) async {
    await pumpApp(
      tester,
      db: db,
      location: Routes.charts,
      // Weeks start on Monday: this week is Oct 12 to 18.
      settings: AppSettings(
        textScale: scale,
        numberStyle: style,
        firstDayOfWeek: FirstDayOfWeek.monday,
      ),
    );
    await boardHeight(tester, 791);
    await tester.tap(find.text('Over time'));
    await settle(tester);
    if (tab != 'Month') {
      await tester.tap(find.text(tab));
      await settle(tester);
    }
  }

  /// Every text of the chart whole (the axis labels sit in their 28 px
  /// column, right aligned), and the labels that float over the columns, the
  /// peak's and the pinned one, inside the chart's box.
  void expectChartWhole(WidgetTester tester) {
    final chart = find.byType(ColumnChart);
    expect(chart, findsOneWidget);
    final box = tester.getRect(chart);
    expect(cutTexts(tester, within: chart), isEmpty);
    for (final label in [
      find.ancestor(of: find.textContaining('Peak'), matching: find.byType(Positioned)),
      find.descendant(
        of: chart,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).boxShadow != null,
        ),
      ),
    ]) {
      if (label.evaluate().isEmpty) continue;
      final inside = label.first;
      expect(textsOutside(tester, inside, box), isEmpty);
      final texts = find.descendant(of: inside, matching: find.byType(Text));
      for (var i = 0; i < texts.evaluate().length; i++) {
        final rect = tester.getRect(texts.at(i));
        expect(rect.left, greaterThanOrEqualTo(box.left - 0.5));
        expect(rect.right, lessThanOrEqualTo(box.right + 0.5));
      }
    }
    expect(tester.takeException(), isNull);
  }

  /// Pins the column at [index] of [count] by tapping it.
  Future<void> pinColumn(WidgetTester tester, int index, int count) async {
    final box = tester.getRect(find.byType(ColumnChart));
    final pitch = columnPlotWidth / count;
    await tester.tapAt(
      Offset(box.left + ColumnChart.padLeft + ColumnChart.inset + pitch * (index + 0.5), box.top + 100),
    );
    await settle(tester);
  }

  for (final (stepIndex, scale) in textScaleSteps.indexed) {
    final size = stepIndex == textScaleSteps.length - 1
        ? 'largest text'
        : 'text size ${stepIndex + 1} of ${textScaleSteps.length}';

    for (final tab in ['Month', 'Week', 'Year']) {
      testWidgets('Over time, $size, the mockup data, $tab: the labels show '
          'in full', (tester) async {
        final db = await sampleDatabase(tester);
        await openOverTime(tester, db, scale, tab: tab);
        expectChartWhole(tester);
        await closeApp(tester, db);
      });
    }

    // The big day sits near the left edge (Oct 2 of the month), in the middle
    // (Thursday Oct 15 of the week, October of the year) or near the right
    // edge (Sunday Oct 18 of the week).
    for (final (tab, day, columns, at) in [
      ('Month', 2, 31, 1),
      ('Week', 15, 7, 3),
      ('Week', 18, 7, 6),
      ('Year', 5, 12, 9),
    ]) {
      testWidgets('Over time, $size, $tab, a big day (Oct $day): the axis, '
          'the peak label and the pinned label show in full', (tester) async {
        final db = await sampleWithBigDay(tester, day: day);
        await openOverTime(tester, db, scale, tab: tab);
        expect(find.textContaining('Peak 1,2'), findsOneWidget);
        expectChartWhole(tester);
        // Pinned, the peak label gives way to the label of the column.
        await pinColumn(tester, at, columns);
        expect(find.textContaining('Peak'), findsNothing);
        expectChartWhole(tester);
        await closeApp(tester, db);
      });
    }

    for (final style in NumberStyle.values) {
      testWidgets('Over time, $size, ${style.name} style, a big day: the peak '
          'label shows in full', (tester) async {
        final db = await sampleWithBigDay(tester, day: 2);
        await openOverTime(tester, db, scale, style: style);
        expect(find.textContaining('Peak'), findsOneWidget);
        expectChartWhole(tester);
        await closeApp(tester, db);
      });
    }
  }
}
