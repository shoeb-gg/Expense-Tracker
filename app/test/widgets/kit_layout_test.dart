// Kit pop-ups measured with the real app font against their boards
// (a 312 px card centred on a 360 px screen; PopMonth / PopDate have
// padding 16, so their content runs from x 40 to x 320).
import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/shots.dart' show loadShotFonts;
import 'pickers_test.dart' show pumpBare;

void main() {
  setUpAll(loadShotFonts);

  group('pop-up navigation row', () {
    testWidgets('month pop-up: the year arrows sit at the right content edge', (
      tester,
    ) async {
      final ctx = await pumpBare(tester);
      unawaited(showMonthPicker(ctx, year: 2026, month: 10));
      await tester.pumpAndSettle();

      final prev = tester.getRect(find.bySemanticsLabel('Previous year'));
      final next = tester.getRect(find.bySemanticsLabel('Next year'));
      expect(next.right, 320);
      expect(prev.right, next.left);
      expect(prev.left, 240);
    });

    testWidgets('date pop-up: the month name is shown in full', (
      tester,
    ) async {
      final ctx = await pumpBare(tester);
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
      await tester.pumpAndSettle();

      final label = tester.renderObject<RenderParagraph>(
        find.text('October 2026'),
      );
      expect(label.didExceedMaxLines, isFalse);
      // PopDate draws the month name with proportional figures.
      expect(tester.widget<Text>(find.text('October 2026')).style!.fontFeatures,
          isNull);
      expect(tester.getRect(find.bySemanticsLabel('Next month')).right, 320);

      // The longest month name fits too.
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 9, 12)));
      await tester.pumpAndSettle();
      final september = tester.renderObject<RenderParagraph>(
        find.text('September 2026'),
      );
      expect(september.didExceedMaxLines, isFalse);
    });
  });

  group('dialog bold line', () {
    testWidgets('proportional figures by default (expense delete board)', (
      tester,
    ) async {
      final ctx = await pumpBare(tester);
      unawaited(
        showAppDialog(
          ctx,
          title: 'Delete this expense?',
          boldLine: 'Doctor visit · 1,180',
          actionLabel: 'Delete',
          destructive: true,
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.text('Doctor visit · 1,180');
      expect(tester.widget<Text>(finder).style!.fontFeatures, isNull);
    });

    testWidgets('tabular figures on request (pocket delete board)', (
      tester,
    ) async {
      final ctx = await pumpBare(tester);
      unawaited(
        showAppDialog(
          ctx,
          title: 'Delete Trip?',
          boldLine: 'Also deletes 12 expenses and photos',
          boldTabular: true,
          actionLabel: 'Delete pocket',
          destructive: true,
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.text('Also deletes 12 expenses and photos');
      expect(
        tester.widget<Text>(finder).style!.fontFeatures,
        const [FontFeature.tabularFigures()],
      );
    });
  });
}
