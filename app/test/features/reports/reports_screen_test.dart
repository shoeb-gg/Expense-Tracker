import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/shots.dart';

void main() {
  // The real fonts: Ahem's square letters would not fit any column.
  setUpAll(loadShotFonts);

  group('Month by month', () {
    // The month in progress is listed with a "so far" chip. A long month
    // name (November, September) used to be cut to "Novemb…" beside it.
    for (final (month, today) in [
      ('October', dayOf(2026, 10, 18)),
      ('September', dayOf(2026, 9, 16)),
      ('November', dayOf(2026, 11, 16)),
    ]) {
      for (final big in [false, true]) {
        testWidgets(
          '$month so far: the name is whole, the chip fits, columns line up '
          '(${big ? 'largest' : 'default'} text)',
          (tester) async {
            final db = await sampleDatabase(tester);
            await pumpApp(
              tester,
              db: db,
              location: Routes.reports,
              settings: big
                  ? AppSettings(textScale: textScaleSteps.last)
                  : const AppSettings(),
              overrides: [todayProvider.overrideWithValue(today)],
            );
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -4000),
            );
            await settle(tester);

            final name = find.text(month);
            expect(name, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(name);
            expect(paragraph.didExceedMaxLines, isFalse);
            final nameRect = tester.getRect(name);
            // The name is as wide as the whole word needs.
            final painter = TextPainter(
              text: TextSpan(text: month, style: paragraph.text.style),
              textDirection: TextDirection.ltr,
              textScaler: paragraph.textScaler,
            )..layout();
            expect(nameRect.width, closeTo(painter.width, 0.5));
            painter.dispose();

            // The chip is as wide as its text, beside the name or under it.
            final chip = tester.getRect(find.text('so far'));
            expect(
              chip.left >= nameRect.right || chip.top >= nameRect.bottom,
              isTrue,
              reason: 'the chip neither covers nor cuts the name',
            );
            final chipBox = tester.getRect(
              find.ancestor(
                of: find.text('so far'),
                matching: find.byType(Container),
              ).first,
            );
            expect(chipBox.width, lessThan(chip.width + 20));

            // Columns line up with the heading: the names with "Month", the
            // amounts and the changes at the right edge of "Spent" and
            // "vs previous".
            final head = tester.getRect(find.text('Month'));
            expect(nameRect.left, head.left);
            final spent = tester.getRect(find.text('Spent'));
            final vsPrev = tester.getRect(find.text('vs previous'));
            expect(vsPrev.height, lessThan(24), reason: 'one line');
            final august = tester.getRect(find.text('52,475').last);
            expect(august.right, closeTo(spent.right, 0.5));
            expect(nameRect.right, lessThan(spent.left));
            expect(tester.takeException(), isNull);
            await closeApp(tester, db);
          },
        );
      }
    }
  });
}
