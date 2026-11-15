import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/features/charts/range_popups.dart';
import 'package:spill_the_bills/features/home/hero_card.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/overlap.dart';
import '../support/shots.dart';

/// Where the "back to now" pill sits on every screen and pop-up, with the
/// real font, at the default and the largest text size: in free space, at
/// the right, and never over text or an icon.
/// A bare app (no screen behind the pop-up) with today pinned to 18 Oct 2026
/// and the text scaled as [settings] say.
Future<BuildContext> pumpBare(WidgetTester tester, AppSettings settings) async {
  tester.view.physicalSize = const Size(720, 1560);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(Clock.fixed(mockupNow)),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: MaterialApp(
        theme: buildAppTheme(Mood.aqua),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(settings.textScale)),
          child: child!,
        ),
        home: const Scaffold(body: SizedBox.expand(key: Key('home'))),
      ),
    ),
  );
  return tester.element(find.byKey(const Key('home')));
}

void main() {
  setUpAll(loadShotFonts);

  final sizes = [
    for (final scale in [1.0, textScaleSteps.last])
      AppSettings(textScale: scale),
  ];

  Future<void> drag(WidgetTester tester, Offset from, Offset by) async {
    await tester.dragFrom(from, by);
    await settle(tester);
  }

  for (final settings in sizes) {
    final size = 'text size ${settings.textScale.toStringAsFixed(2)}';

    testWidgets('Home, $size: hangs over the lower edge of the month card',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, settings: settings);
      expect(find.byType(Pill), findsNothing);
      await drag(tester, const Offset(30, 420), const Offset(300, 0));
      expect(find.byType(Pill), findsOneWidget);
      expectNothingUnder(tester, find.byType(Pill));
      final box = tester.getRect(find.byType(Pill));
      final card = tester.getRect(find.byType(HeroCard));
      expect(box.size.height, 32);
      expect(box.right, 360 - 16);
      expect(box.top, greaterThan(card.top + 60), reason: 'below the number');
      expect(box.top, lessThan(card.bottom));
      expect(box.bottom, greaterThan(card.bottom));
      await closeApp(tester, db);
    });

    testWidgets('Calendar, $size: at the right of the header, centred in it',
        (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.calendar(day: dayOf(2026, 9, 1)),
        settings: settings,
      );
      expect(find.byType(Pill), findsOneWidget);
      expectNothingUnder(tester, find.byType(Pill));
      final box = tester.getRect(find.byType(Pill));
      expect(box.right, 360 - 16);
      expect(box.top, 14);
      expect(box.bottom, 46);
      expect(
        box.left,
        greaterThan(tester.getRect(find.text('Calendar')).right),
      );
      await closeApp(tester, db);
    });

    testWidgets('Charts, $size: at the right of the title on Week, Month '
        'and Year', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.charts,
        settings: settings,
      );
      for (final kind in ['Week', 'Month', 'Year']) {
        await tester.tap(find.text(kind));
        await settle(tester);
        await drag(tester, const Offset(30, 420), const Offset(300, 0));
        expect(find.byType(Pill), findsOneWidget, reason: kind);
        expectNothingUnder(tester, find.byType(Pill));
        final box = tester.getRect(find.byType(Pill));
        expect(box.right, 360 - 16);
        expect(box.top, 16);
        expect(box.bottom, 48);
        expect(
          box.left,
          greaterThan(tester.getRect(find.text('Charts').first).right),
        );
      }
      await closeApp(tester, db);
    });

    testWidgets('pop-ups, $size: over the top edge of the card, clear of its '
        'heading', (tester) async {
      final ctx = await pumpBare(tester, settings);
      final opens = <String, void Function()>{
        'date': () => unawaited(
              showDayPicker(ctx, initialDay: dayOf(2026, 9, 3)),
            ),
        'month': () => unawaited(showMonthPicker(ctx, year: 2025, month: 3)),
        'year': () => unawaited(showYearPicker(ctx, year: 2022)),
      };
      for (final entry in opens.entries) {
        entry.value();
        await tester.pumpAndSettle();
        final pill = find.byType(Pill);
        final card = tester.getRect(find.byType(AppPopupCard));
        final box = tester.getRect(pill);
        final reason = '${entry.key} pop-up';
        expect(box.right, card.right - 16, reason: reason);
        expect(box.top, lessThan(card.top - 10), reason: 'mostly above');
        expect(box.bottom, greaterThan(card.top + 4), reason: reason);
        expectNothingUnder(tester, pill);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
    });
  }
}
