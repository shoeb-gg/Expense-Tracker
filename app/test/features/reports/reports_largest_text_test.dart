import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/text_fit.dart';

/// "Monthly statistics": the data and the figures it must show.
typedef Scene = ({
  String name,
  Future<AppDatabase> Function(WidgetTester) open,
  String spent,
  String average,
  String versus,
});

/// Reports on the 360 x 791 phone at every text size, with the real fonts
/// (Ahem's square letters would fit nothing): every text of the cards shows in
/// full, and nothing paints outside its card.
void main() {
  setUpAll(loadShotFonts);

  final scenes = <Scene>[
    (
      name: 'the mockup data',
      open: sampleDatabase,
      spent: '34,555',
      average: '1,920',
      versus: '2% more',
    ),
    (
      name: 'a big month, twice last month',
      open: (tester) =>
          bigSpendDatabase(tester, spent: 1234567, before: 617284, monthly: 1234567),
      spent: '1,234,567',
      average: '68,587',
      versus: '100% more',
    ),
    (
      name: 'a big month, a third less than last month',
      open: (tester) =>
          bigSpendDatabase(tester, spent: 1234567, before: 1899334, monthly: 1234567),
      spent: '1,234,567',
      average: '68,587',
      versus: '35% less',
    ),
  ];

  Finder statsCard() => find.ancestor(
    of: find.text('Monthly statistics'),
    matching: find.byType(BandCard),
  );

  /// The label and the value of one stat, each a single text. The card's
  /// "Biggest category" row may repeat a figure; the stats come first.
  List<Finder> stat(String label, String value) => [
    find.descendant(of: statsCard(), matching: find.text(label)).first,
    find.descendant(of: statsCard(), matching: find.text(value)).first,
  ];

  for (final (stepIndex, scale) in textScaleSteps.indexed) {
    final size = stepIndex == textScaleSteps.length - 1
        ? 'largest text'
        : 'text size ${stepIndex + 1} of ${textScaleSteps.length}';
    for (final scene in scenes) {
      testWidgets('Monthly statistics, $size, ${scene.name}: the three stats show '
          'in full, inside the card', (tester) async {
        final db = await scene.open(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.reports,
          settings: AppSettings(textScale: scale),
        );
        await boardHeight(tester, 791);

        final stats = <List<Finder>>[
          stat('Spent so far', scene.spent),
          stat('Daily average', scene.average),
          stat('vs Sep 1–18', scene.versus),
        ];
        final card = tester.getRect(statsCard());
        // The stats sit in the card's 16 px padding, side by side.
        final inner = Rect.fromLTRB(card.left + 16, card.top, card.right - 16, card.bottom);
        Rect? before;
        for (final texts in stats) {
          for (final finder in texts) {
            expect(finder, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '"${paragraph.text.toPlainText()}" hit its line limit',
            );
            expect(
              cutReason(paragraph),
              isNull,
              reason: '"${paragraph.text.toPlainText()}" is cut',
            );
            final rect = tester.getRect(finder);
            expect(rect.left, greaterThanOrEqualTo(inner.left - 0.5), reason: '$finder');
            expect(rect.right, lessThanOrEqualTo(inner.right + 0.5), reason: '$finder');
          }
          final both = tester.getRect(texts[0]).expandToInclude(tester.getRect(texts[1]));
          if (before != null) {
            expect(
              both.left,
              greaterThan(before.right),
              reason: 'the stats must not run into each other',
            );
          }
          before = both;
        }
        // The three stats line up: the labels on one line, the values on one.
        for (final part in [0, 1]) {
          final tops = [for (final texts in stats) tester.getTopLeft(texts[part]).dy];
          expect(
            tops.every((t) => (t - tops.first).abs() < 0.01),
            isTrue,
            reason: 'the ${part == 0 ? 'labels' : 'values'} are on one line: $tops',
          );
        }
        expect(
          textsOutside(tester, statsCard(), card),
          isEmpty,
          reason: 'nothing of the card paints outside it',
        );
        expect(tester.takeException(), isNull);
        await closeApp(tester, db);
      });
    }
  }

  // The cards of Reports, at every size: no text cut, none outside its card.
  // The mockup data is what the owner sees; the big figures are the longest
  // realistic ones.
  Finder bandCard(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(BandCard));
  // "All time" has no band: its card is the container the label sits in.
  Finder allTimeCard() =>
      find.ancestor(of: find.text('All time'), matching: find.byType(Container)).first;

  for (final big in [false, true]) {
    for (final (stepIndex, scale) in textScaleSteps.indexed) {
      final size = stepIndex == textScaleSteps.length - 1
          ? 'largest text'
          : 'text size ${stepIndex + 1} of ${textScaleSteps.length}';
      testWidgets('Reports, $size, ${big ? 'big figures' : 'the mockup data'}: '
          'every card shows its texts in full, inside itself', (tester) async {
        final db = big
            ? await bigSpendDatabase(tester, spent: 1234567, before: 617284, monthly: 1234567)
            : await sampleDatabase(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.reports,
          settings: AppSettings(textScale: scale),
        );
        // Tall enough that the whole list is built.
        await boardHeight(tester, 3000);
        final cards = <String, Finder>{
          'Monthly statistics': bandCard('Monthly statistics'),
          'Year at a glance': bandCard('Year at a glance'),
          'All time': allTimeCard(),
          'Month by month': bandCard('Month by month'),
        };
        final problems = <String>[];
        cards.forEach((name, card) {
          expect(card, findsOneWidget, reason: name);
          problems
            ..addAll(cutTexts(tester, within: card).map((t) => '$name: $t'))
            ..addAll(
              textsOutside(tester, card, tester.getRect(card)).map((t) => '$name: $t'),
            );
        });
        expect(problems, isEmpty);
        await closeApp(tester, db);
      });
    }
  }
}
