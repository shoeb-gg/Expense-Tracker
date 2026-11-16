import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

Future<BuildContext> pumpBare(
  WidgetTester tester,
  Mood mood,
  Brightness brightness,
) async {
  tester.view.physicalSize = const Size(720, 1560);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWithValue(Clock.fixed(mockupNow))],
      child: MaterialApp(
        theme: buildAppTheme(mood, brightness: brightness),
        home: const Scaffold(body: SizedBox.expand(key: Key('home'))),
      ),
    ),
  );
  return tester.element(find.byKey(const Key('home')));
}

Color? textColor(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

void main() {
  // The chosen day, month or year is the bright accent fill with ink on it,
  // the same fill as the Confirm button next to it, in every mood and in both
  // brightnesses (in dark the fill is the accent itself).
  for (final brightness in Brightness.values) {
    for (final mood in Mood.values) {
      final c = AppColors.of(mood, brightness: brightness);
      final label = '${mood.label} ${brightness.name}';

      testWidgets('the chosen day is the accent fill: $label', (tester) async {
        final ctx = await pumpBare(tester, mood, brightness);
        unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
        await tester.pumpAndSettle();
        final circle = tester.widget<AnimatedContainer>(
          find
              .ancestor(
                of: find.text('12'),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        expect((circle.decoration as BoxDecoration).color, c.accentFill);
        expect(textColor(tester, find.text('12')), c.onFill);
        // Today's marker (the 18th) keeps the deep accent text.
        expect(textColor(tester, find.text('18')), c.accent);
        // Confirm is the same fill.
        final confirm = tester.widget<Pressable>(
          find.ancestor(
            of: find.text('Confirm'),
            matching: find.byType(Pressable),
          ).first,
        );
        expect(confirm.color, c.accentFill);
      });

      testWidgets('the chosen month and year are the accent fill: $label', (
        tester,
      ) async {
        final ctx = await pumpBare(tester, mood, brightness);
        unawaited(showMonthPicker(ctx, year: 2026, month: 10));
        await tester.pumpAndSettle();
        Pressable tile(String text) => tester.widget<Pressable>(
          find.ancestor(of: find.text(text), matching: find.byType(Pressable)).first,
        );
        expect(tile('Oct').color, c.accentFill);
        expect(textColor(tester, find.text('Oct')), c.onFill);
        expect(tile('Sep').color, c.tile, reason: 'the others stay tiles');

        await tester.tap(find.text('2026').last);
        await tester.pumpAndSettle();
        expect(find.text('2018 – 2029'), findsOneWidget);
        expect(tile('2026').color, c.accentFill);
        expect(textColor(tester, find.text('2026')), c.onFill);
        expect(tile('2025').color, c.tile);
      });
    }
  }
}
