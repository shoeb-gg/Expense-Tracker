import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/features/charts/range_popups.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

/// A bare app (no database) with today pinned to 18 Oct 2026.
Future<BuildContext> pumpBare(WidgetTester tester) async {
  tester.view.physicalSize = const Size(720, 1560);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWithValue(Clock.fixed(mockupNow))],
      child: MaterialApp(
        theme: buildAppTheme(Mood.aqua),
        home: const Scaffold(body: SizedBox.expand(key: Key('home'))),
      ),
    ),
  );
  return tester.element(find.byKey(const Key('home')));
}

Future<void> swipe(WidgetTester tester, Offset by) async {
  await tester.dragFrom(tester.getCenter(find.byType(AppPopupCard)), by);
  await tester.pumpAndSettle();
}

Finder pill(String what) => find.bySemanticsLabel('Back to $what');

/// Which way the pop-up's page slid on its last change.
bool forward(WidgetTester tester) =>
    tester.widget<SlideSwitcher>(find.byType(SlideSwitcher)).forward;

void main() {
  group('date pop-up: "Today"', () {
    testWidgets("shows while the day or the page is not today's; a tap shows "
        'today and chooses it', (tester) async {
      final ctx = await pumpBare(tester);
      int? result;
      unawaited(
        showDayPicker(
          ctx,
          initialDay: dayOf(2026, 10, 12),
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      // October 12 is chosen: not today.
      expect(pill('today'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(pill('today'));
      await tester.pumpAndSettle();
      expect(find.text('Sun, Oct 18, 2026'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(pill('today'), findsNothing);

      // Today is chosen but the page moved: the pill is back.
      await swipe(tester, const Offset(120, 0));
      expect(find.text('September 2026'), findsOneWidget);
      expect(pill('today'), findsOneWidget);
      await tester.tap(pill('today'));
      await tester.pump();
      expect(forward(tester), isTrue, reason: 'back from the past');
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(pill('today'), findsNothing);

      // And from a later page the other way.
      await swipe(tester, const Offset(-120, 0));
      expect(find.text('November 2026'), findsOneWidget);
      await tester.tap(pill('today'));
      await tester.pump();
      expect(forward(tester), isFalse, reason: 'back from the future');
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, dayOf(2026, 10, 18));
    });

    testWidgets('opened on today there is no pill; the month and year views '
        "show today's page again", (tester) async {
      final ctx = await pumpBare(tester);
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 18)));
      await tester.pumpAndSettle();
      expect(pill('today'), findsNothing);

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      expect(find.text('Mar'), findsOneWidget);
      expect(pill('today'), findsNothing);
      await swipe(tester, const Offset(120, 0));
      expect(find.text('2025'), findsOneWidget);
      expect(pill('today'), findsOneWidget);
      await tester.tap(pill('today'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget, reason: 'days again');
      expect(find.text('Sun, Oct 18, 2026'), findsOneWidget);
      expect(pill('today'), findsNothing);

      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(find.text('2018 – 2029'), findsOneWidget);
      expect(pill('today'), findsNothing);
      await swipe(tester, const Offset(-120, 0));
      expect(find.text('2030 – 2041'), findsOneWidget);
      expect(pill('today'), findsOneWidget);
      await tester.tap(pill('today'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(pill('today'), findsNothing);
    });
  });

  group('month pop-up: "This month"', () {
    testWidgets('a tap shows this year and chooses this month', (tester) async {
      final ctx = await pumpBare(tester);
      (int, int)? result;
      unawaited(
        showMonthPicker(ctx, year: 2024, month: 3).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      expect(find.text('March 2024'), findsOneWidget);
      expect(pill('this month'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
      await tester.tap(pill('this month'));
      await tester.pump();
      expect(forward(tester), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(pill('this month'), findsNothing);

      // This month is chosen, but another year is shown.
      await swipe(tester, const Offset(-120, 0));
      expect(find.text('2027'), findsOneWidget);
      expect(pill('this month'), findsOneWidget);
      await tester.tap(pill('this month'));
      await tester.pump();
      expect(forward(tester), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsOneWidget);

      // The year view too: it goes back to the months.
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(find.text('2018 – 2029'), findsOneWidget);
      await swipe(tester, const Offset(120, 0));
      expect(find.text('2006 – 2017'), findsOneWidget);
      await tester.tap(pill('this month'));
      await tester.pumpAndSettle();
      expect(find.text('Oct'), findsOneWidget, reason: 'months again');
      expect(find.text('2026'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, (2026, 10));
    });

    testWidgets('none on this month; shows once the year or month moves',
        (tester) async {
      final ctx = await pumpBare(tester);
      unawaited(showMonthPicker(ctx, year: 2026, month: 10));
      await tester.pumpAndSettle();
      expect(pill('this month'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Previous year'));
      await tester.pumpAndSettle();
      expect(pill('this month'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next year'));
      await tester.pumpAndSettle();
      expect(pill('this month'), findsNothing);
      // Another month is chosen: it shows even on this year.
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();
      expect(pill('this month'), findsOneWidget);
    });

    testWidgets('the pop-up stays where it was when the pill comes and goes',
        (tester) async {
      final ctx = await pumpBare(tester);
      unawaited(showMonthPicker(ctx, year: 2026, month: 10));
      await tester.pumpAndSettle();
      final without = tester.getRect(find.byType(AppPopupCard));
      await tester.tap(find.bySemanticsLabel('Previous year'));
      await tester.pumpAndSettle();
      expect(pill('this month'), findsOneWidget);
      expect(tester.getRect(find.byType(AppPopupCard)), without);
    });
  });

  group('year pop-up: "This year"', () {
    testWidgets("a tap shows this year's page and chooses it", (tester) async {
      final ctx = await pumpBare(tester);
      int? result;
      unawaited(showYearPicker(ctx, year: 2040).then((v) => result = v));
      await tester.pumpAndSettle();
      expect(find.text('2030 – 2041'), findsOneWidget);
      expect(pill('this year'), findsOneWidget);
      expect(find.text('This year'), findsOneWidget);
      await tester.tap(pill('this year'));
      await tester.pump();
      expect(forward(tester), isFalse, reason: 'back from the future');
      await tester.pumpAndSettle();
      expect(find.text('2018 – 2029'), findsOneWidget);
      expect(pill('this year'), findsNothing);

      // 2026 is chosen, the page moves: the pill returns, the other way.
      await swipe(tester, const Offset(120, 0));
      expect(find.text('2006 – 2017'), findsOneWidget);
      expect(pill('this year'), findsOneWidget);
      await tester.tap(pill('this year'));
      await tester.pump();
      expect(forward(tester), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('2018 – 2029'), findsOneWidget);

      // Another year chosen on this page: the pill chooses this year again.
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();
      expect(pill('this year'), findsOneWidget);
      await tester.tap(pill('this year'));
      await tester.pumpAndSettle();
      expect(pill('this year'), findsNothing);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, 2026);
    });
  });
}
