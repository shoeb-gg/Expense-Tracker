import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/shots.dart';

/// [PageHeader] with and without a subtitle, with the real font: the header
/// is 64 px either way, the title keeps its place while the line fits under
/// it, and the line never leaves the header.
Future<void> _pump(
  WidgetTester tester, {
  String? subtitle,
  double scale = 1,
  double endRoom = 0,
}) async {
  tester.view.physicalSize = const Size(720, 1560);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Mood.aqua),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: PageHeader(
            title: 'Charts',
            subtitle: subtitle,
            endRoom: endRoom,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadShotFonts);

  testWidgets('without a subtitle the title is where it always was', (
    tester,
  ) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(PageHeader)).height, 64);
    final title = tester.getRect(find.text('Charts'));
    expect(title.left, 16);
    expect(title.top, 18);
    expect(title.bottom, 46);
  });

  for (final scale in textScaleSteps) {
    final size = 'text size ${scale.toStringAsFixed(2)}';

    testWidgets('$size: 64 px high, the line inside it, under the title', (
      tester,
    ) async {
      await _pump(tester, subtitle: 'Personal', scale: scale);
      expect(tester.getSize(find.byType(PageHeader)).height, 64);
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Charts'));
      final line = tester.getRect(find.text('Personal'));
      expect(title.left, 16);
      expect(line.left, 16);
      expect(line.top, closeTo(title.bottom, 0.01), reason: 'right under it');
      expect(line.bottom, lessThanOrEqualTo(64 - 2 + 0.01));
      expect(title.top, greaterThanOrEqualTo(0));
      // The title moves only when the line would not fit below it.
      await _pump(tester, scale: scale);
      final alone = tester.getRect(find.text('Charts'));
      expect(
        title.top,
        lessThanOrEqualTo(alone.top + 0.01),
        reason: 'not down',
      );
      if (title.top < alone.top - 0.01) {
        expect(line.bottom, closeTo(62, 0.01), reason: 'moved only to fit');
      } else {
        expect(title.top, closeTo(alone.top, 0.01), reason: 'did not need to');
      }
      if (scale <= 1) {
        expect(title.top, closeTo(alone.top, 0.01), reason: 'default or less');
      }
    });
  }

  testWidgets('a long line scales to one line and stops short of endRoom', (
    tester,
  ) async {
    const long = 'A pocket name that is much too long for one line at all';
    await _pump(
      tester,
      subtitle: long,
      scale: textScaleSteps.last,
      endRoom: 120,
    );
    expect(tester.takeException(), isNull);
    final line = tester.getRect(find.text(long));
    expect(line.height, lessThan(24), reason: 'one line');
    expect(line.right, lessThanOrEqualTo(360 - 16 - 120 + 0.01));
    expect(line.bottom, lessThanOrEqualTo(64));
  });

  testWidgets('the subtitle is drawn in the quiet text colour', (tester) async {
    await _pump(tester, subtitle: 'Personal');
    final text = tester.widget<Text>(find.text('Personal'));
    final context = tester.element(find.text('Personal'));
    expect(text.style?.color, context.colors.text3);
  });
}
