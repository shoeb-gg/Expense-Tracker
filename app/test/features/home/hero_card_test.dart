import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/features/home/hero_card.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/symbols.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/shots.dart';

/// A HeroCard on a 360 px wide screen with the text scaled by [scale] (the
/// app's Text size setting does the same).
Future<void> pumpHero(
  WidgetTester tester, {
  required int month,
  required double scale,
}) async {
  tester.view.physicalSize = const Size(720, 1560);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(Mood.aqua),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: HeroCard(
              month: (year: 2026, month: month),
              caption: 'Spent in ${monthName(month)}',
              value: '34,555',
              onMonthTap: () {},
              onValueTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _chip() => find
    .ancestor(of: find.text('2026'), matching: find.byType(Pressable))
    .first;

void main() {
  // The real font: the Ahem test font is far wider than the app's.
  setUpAll(loadShotFonts);

  bool inside(Rect box, Rect outer) =>
      box.left >= outer.left - 0.01 &&
      box.right <= outer.right + 0.01 &&
      box.top >= outer.top - 0.01 &&
      box.bottom <= outer.bottom + 0.01;

  testWidgets('default size: the chip and its text have not moved',
      (tester) async {
    await pumpHero(tester, month: 10, scale: 1);
    expect(tester.getSize(find.byType(HeroCard)).height, 92);
    expect(tester.getRect(_chip()), const Rect.fromLTRB(24, 24, 104, 100));
    final year = tester.getRect(find.text('2026'));
    expect(year.top, 35);
    expect(year.center.dx, closeTo(64, 0.1));
    final month = tester.getRect(find.text('Oct'));
    expect(month.left, closeTo(35.4, 0.1));
    expect(month.top, 57);
    expect(month.bottom, 93);
    final chevron = tester.getRect(find.byIcon(Symbols.expand_more_rounded));
    expect(chevron.left, closeTo(month.right, 0.1));
    expect(chevron.top, 66);
    // "Oct" and its chevron sit centred in the chip as a group.
    expect((month.left + chevron.right - 4) / 2, closeTo(64, 0.3));
  });

  group('the month chip never clips', () {
    for (final scale in textScaleSteps) {
      testWidgets('every month at text size $scale', (tester) async {
        for (var m = 1; m <= 12; m++) {
          await pumpHero(tester, month: m, scale: scale);
          final reason = '${monthShortName(m)} at $scale';
          final chip = tester.getRect(_chip());

          // The month is laid out in full, not cut to a narrower box.
          final label = tester.renderObject<RenderParagraph>(
            find.text(monthShortName(m)),
          );
          expect(
            label.size.width,
            greaterThanOrEqualTo(label.getMaxIntrinsicWidth(double.infinity)),
            reason: reason,
          );
          expect(
            label.size.height,
            greaterThanOrEqualTo(label.getMinIntrinsicHeight(double.infinity)),
            reason: reason,
          );

          // And the year, the month and the chevron all lie inside the chip.
          expect(
            inside(tester.getRect(find.text('2026')), chip),
            isTrue,
            reason: 'year, $reason',
          );
          expect(
            inside(tester.getRect(find.text(monthShortName(m))), chip),
            isTrue,
            reason: 'month, $reason',
          );
          expect(
            inside(
              tester.getRect(find.byIcon(Symbols.expand_more_rounded)),
              chip,
            ),
            isTrue,
            reason: 'chevron, $reason',
          );
        }
      });
    }
  });
}
