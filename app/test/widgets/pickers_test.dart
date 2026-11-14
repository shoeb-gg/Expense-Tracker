import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

/// A bare app (no database) with today pinned to 18 Oct 2026.
Future<BuildContext> pumpBare(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
}) async {
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
        home: const Scaffold(body: SizedBox.expand(key: Key('home'))),
      ),
    ),
  );
  return tester.element(find.byKey(const Key('home')));
}

/// The centre of the pop-up card.
Offset cardCentre(WidgetTester tester) =>
    tester.getCenter(find.byType(AppPopupCard));

Future<void> swipe(WidgetTester tester, Offset by) async {
  // Start between rows so the drag never begins on a button edge case.
  await tester.dragFrom(cardCentre(tester), by);
  await tester.pumpAndSettle();
}

void main() {
  group('date pop-up', () {
    testWidgets('opens on the given day; Confirm returns the chosen day',
        (tester) async {
      final ctx = await pumpBare(tester);
      int? result = -1;
      unawaited(
        showDayPicker(ctx, initialDay: dayOf(2026, 10, 12))
            .then((v) => result = v),
      );
      await tester.pumpAndSettle();
      expect(find.text('Date of this expense'), findsOneWidget);
      expect(find.text('Mon, Oct 12, 2026'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Thursday, October 15'));
      await tester.pumpAndSettle();
      expect(find.text('Thu, Oct 15, 2026'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, dayOf(2026, 10, 15));
    });

    testWidgets('Cancel returns null', (tester) async {
      final ctx = await pumpBare(tester);
      int? result = -1;
      unawaited(
        showDayPicker(ctx, initialDay: dayOf(2026, 10, 12))
            .then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('today is marked; six weeks with neighbouring days',
        (tester) async {
      final ctx = await pumpBare(tester);
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Sunday, October 18, today'), findsOneWidget);
      // Sunday start: Sep 27 opens the grid, Nov 7 closes it.
      expect(find.bySemanticsLabel('Sunday, September 27'), findsOneWidget);
      expect(find.bySemanticsLabel('Saturday, November 7'), findsOneWidget);
    });

    testWidgets('weeks start on the day set in Settings', (tester) async {
      final ctx = await pumpBare(
        tester,
        settings: const AppSettings(firstDayOfWeek: FirstDayOfWeek.monday),
      );
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Monday, September 28'), findsOneWidget);
      expect(find.bySemanticsLabel('Sunday, September 27'), findsNothing);
    });

    testWidgets('tapping a faint neighbouring day moves to its month',
        (tester) async {
      final ctx = await pumpBare(tester);
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Wednesday, November 4'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Wed, Nov 4, 2026'), findsOneWidget);
    });

    testWidgets('swipe and arrows: finger left-to-right / top-to-bottom shows '
        'the PREVIOUS month, right-to-left / bottom-to-top the NEXT',
        (tester) async {
      final ctx = await pumpBare(tester);
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
      await tester.pumpAndSettle();

      await swipe(tester, const Offset(120, 0)); // finger moves right
      expect(find.text('September 2026'), findsOneWidget);
      await swipe(tester, const Offset(-120, 0)); // finger moves left
      expect(find.text('October 2026'), findsOneWidget);
      await swipe(tester, const Offset(0, 100)); // finger moves down
      expect(find.text('September 2026'), findsOneWidget);
      await swipe(tester, const Offset(0, -100)); // finger moves up
      expect(find.text('October 2026'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);

      // A swipe never changes the chosen day.
      expect(find.text('Mon, Oct 12, 2026'), findsOneWidget);
    });

    testWidgets('a swipe that starts on a day does not pick it',
        (tester) async {
      final ctx = await pumpBare(tester);
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
      await tester.pumpAndSettle();
      final day15 = tester.getCenter(find.bySemanticsLabel('Thursday, October 15'));
      await tester.dragFrom(day15, const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Mon, Oct 12, 2026'), findsOneWidget);
    });

    testWidgets('month name opens the month tiles, then the years',
        (tester) async {
      final ctx = await pumpBare(tester);
      unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('October 2026'));
      await tester.pumpAndSettle();
      expect(find.text('Mar'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);

      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(find.text('2018 – 2029'), findsOneWidget);
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();
      expect(find.text('March 2025'), findsOneWidget);
      expect(find.text('Mon, Oct 12, 2026'), findsOneWidget);
    });
  });

  group('month pop-up', () {
    testWidgets('pick a month and confirm', (tester) async {
      final ctx = await pumpBare(tester);
      (int, int)? result;
      unawaited(
        showMonthPicker(ctx, year: 2026, month: 10).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      expect(find.text('Month to show'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, (2026, 3));
    });

    testWidgets('swipes and arrows step a year; twelve in the year view',
        (tester) async {
      final ctx = await pumpBare(tester);
      unawaited(showMonthPicker(ctx, year: 2026, month: 10));
      await tester.pumpAndSettle();
      await swipe(tester, const Offset(120, 0));
      expect(find.text('2025'), findsOneWidget);
      await swipe(tester, const Offset(0, -100));
      expect(find.text('2026'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next year'));
      await tester.pumpAndSettle();
      expect(find.text('2027'), findsOneWidget);

      await tester.tap(find.text('2027'));
      await tester.pumpAndSettle();
      expect(find.text('2018 – 2029'), findsOneWidget);
      await swipe(tester, const Offset(-120, 0));
      expect(find.text('2030 – 2041'), findsOneWidget);
      await swipe(tester, const Offset(0, 100));
      expect(find.text('2018 – 2029'), findsOneWidget);
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();
      expect(find.text('2024'), findsOneWidget); // back on the months
      expect(find.text('Jan'), findsOneWidget);
    });

    testWidgets('Cancel returns null', (tester) async {
      final ctx = await pumpBare(tester);
      (int, int)? result = (0, 0);
      unawaited(
        showMonthPicker(ctx, year: 2026, month: 10).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('sheets, dialogs, toast', () {
    testWidgets('option sheet: a tap chooses and closes', (tester) async {
      final ctx = await pumpBare(tester);
      FirstDayOfWeek? result;
      unawaited(
        showOptionSheet<FirstDayOfWeek>(
          ctx,
          title: 'First day of the week',
          message: 'Used by the calendar and the weekly chart.',
          current: FirstDayOfWeek.sunday,
          options: [
            for (final d in FirstDayOfWeek.values)
              SheetOption(value: d, label: d.label),
          ],
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monday'));
      await tester.pumpAndSettle();
      expect(result, FirstDayOfWeek.monday);
      expect(find.text('First day of the week'), findsNothing);
    });

    testWidgets('dialog with a tick box stays locked until ticked',
        (tester) async {
      final ctx = await pumpBare(tester);
      bool? result;
      unawaited(
        showAppDialog(
          ctx,
          title: 'Delete all data?',
          boldLine: 'All expenses, categories and photos',
          quietLine: "This can't be undone.",
          tickLabel: 'Yes, erase everything',
          actionLabel: 'Delete all',
          destructive: true,
        ).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      expect(result, isNull); // still open
      await tester.tap(find.text('Yes, erase everything'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete all'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('toast with Undo', (tester) async {
      final ctx = await pumpBare(tester);
      var undone = false;
      showToast(ctx, 'Moved to Business', onUndo: () => undone = true);
      await tester.pumpAndSettle();
      expect(find.text('Moved to Business'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, isTrue);
      expect(find.text('Moved to Business'), findsNothing);

      showToast(ctx, 'Saved');
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('switch and segmented control report changes', (tester) async {
      await pumpBare(tester);
      var on = false;
      var seg = 'month';
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Mood.aqua),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  AppSwitch(value: on, onChanged: (v) => setState(() => on = v)),
                  AppSegmented<String>(
                    segments: const [
                      Segment('week', 'Week'),
                      Segment('month', 'Month'),
                    ],
                    value: seg,
                    onChanged: (v) => setState(() => seg = v),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();
      expect(on, isTrue);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(seg, 'week');
    });
  });
}
