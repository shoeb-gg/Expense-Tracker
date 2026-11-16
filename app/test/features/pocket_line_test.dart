import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/charts/chart_model.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/pocket_line.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/overlap.dart';
import '../support/shots.dart';

/// The pocket line under the title of Calendar, Charts and Reports: shown
/// with two or more pockets, never with one, and it never changes the header's
/// height or anything below it.

const String _personal = '\u{1F45B} Personal';
const String _business = '\u{1F4BC} Business';

/// The three screens that follow the pocket chosen on Home.
enum _Screen {
  calendar,
  charts,
  reports;

  /// Where the screen opens. Calendar opens on 1 Sep 2026 (not today) so its
  /// "Today" pill shows.
  String get location => switch (this) {
    _Screen.calendar => Routes.calendar(day: dayOf(2026, 9, 1)),
    _Screen.charts => Routes.charts,
    _Screen.reports => Routes.reports,
  };

  String get title => switch (this) {
    _Screen.calendar => 'Calendar',
    _Screen.charts => 'Charts',
    _Screen.reports => 'Reports',
  };

  /// The header: Calendar has a SubHeader, the tab screens a PageHeader.
  Finder get header => switch (this) {
    _Screen.calendar => find.byType(SubHeader),
    _ => find.byType(PageHeader),
  };

  Finder get titleText =>
      find.descendant(of: header, matching: find.text(title));

  /// The first thing under the header.
  Finder get below => switch (this) {
    _Screen.calendar => find.text('September 2026'),
    _Screen.charts => find.byType(AppSegmented<PeriodKind>),
    _Screen.reports => find.byType(ListView),
  };
}

/// The screens the tests below run on.
const List<_Screen> _screens = <_Screen>[_Screen.calendar];

/// What the app was opened with.
class _Opened {
  _Opened(this.db, this.business);

  final AppDatabase db;

  /// Id of the second pocket (null with one pocket).
  final int? business;
}

/// Opens [screen] with the default "Personal" pocket and, when [extra] is
/// given, a second pocket; [second] makes the second one the pocket in use.
Future<_Opened> _open(
  WidgetTester tester,
  _Screen screen, {
  ({String name, String emoji})? extra,
  bool second = false,
  double scale = 1.0,
  Mood mood = Mood.aqua,
  AppThemeMode mode = AppThemeMode.dark,
}) async {
  final db = await sampleDatabase(tester);
  final id = extra == null
      ? null
      : await tester.runAsync(
          () => PocketsRepo(db).add(name: extra.name, emoji: extra.emoji),
        );
  await pumpApp(
    tester,
    db: db,
    location: screen.location,
    settings: AppSettings(
      textScale: scale,
      mood: mood,
      themeMode: mode,
      currentPocketId: second ? id : null,
    ),
  );
  return _Opened(db, id);
}

const ({String name, String emoji}) _businessPocket = (
  name: 'Business',
  emoji: '\u{1F4BC}',
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

/// Moves the pocket in use, like choosing one on Home.
Future<void> _switchTo(WidgetTester tester, int pocketId) async {
  await tester.runAsync(
    () => _container(
      tester,
    ).read(settingsProvider.notifier).setCurrentPocketId(pocketId),
  );
  await settle(tester);
}

/// Swipes the Charts body to the previous period so the "This month" pill
/// shows.
Future<void> _awayFromNow(WidgetTester tester) async {
  await tester.dragFrom(const Offset(30, 420), const Offset(300, 0));
  await settle(tester);
}

/// The measures the rules are about.
typedef _Geometry = ({double header, double below, Rect title});

_Geometry _measure(WidgetTester tester, _Screen screen) => (
  header: tester.getRect(screen.header).height,
  below: tester.getRect(screen.below).top,
  title: tester.getRect(screen.titleText),
);

void main() {
  // The real Plus Jakarta Sans: the default test font is far wider.
  setUpAll(loadShotFonts);

  group('pocketLabel and the two-pockets rule', () {
    Pocket pocket(String name, [String emoji = '\u{1F4BC}']) => Pocket(
      id: 1,
      name: name,
      emoji: emoji,
      sortOrder: 0,
      isDefault: false,
      createdAt: DateTime(2026),
    );

    test('emoji and name; null gives nothing', () {
      expect(pocketLabel(pocket('Business')), _business);
      expect(pocketLabel(null), '');
    });

    test('a name of 16 characters stays whole, a longer one is cut', () {
      expect(
        pocketLabel(pocket('1234567890123456')),
        '\u{1F4BC} 1234567890123456',
      );
      expect(
        pocketLabel(pocket('12345678901234567')),
        '\u{1F4BC} 123456789012345…',
      );
    });

    test('a pocket is named only when there are two or more', () {
      final one = pocket('Personal');
      expect(pocketWhenSeveral([one], one), isNull);
      expect(pocketWhenSeveral([one, pocket('Business')], one), one);
      expect(pocketWhenSeveral([one, pocket('Business')], null), isNull);
      expect(pocketWhenSeveral(const [], null), isNull);
    });
  });

  for (final screen in _screens) {
    group('${screen.title}: pocket line', () {
      testWidgets('one pocket: no pocket line', (tester) async {
        final opened = await _open(tester, screen);
        expect(find.textContaining('Personal'), findsNothing);
        expect(find.text(_personal), findsNothing);
        await closeApp(tester, opened.db);
      });

      testWidgets('two pockets: the pocket in use is named, and follows a '
          'switch', (tester) async {
        final opened = await _open(tester, screen, extra: _businessPocket);
        expect(find.text(_personal), findsOneWidget);
        expect(find.text(_business), findsNothing);

        await _switchTo(tester, opened.business!);
        expect(find.text(_business), findsOneWidget);
        expect(find.text(_personal), findsNothing);

        // And it is the title's line: under it, inside the header.
        final header = tester.getRect(screen.header);
        final title = tester.getRect(screen.titleText);
        final line = tester.getRect(find.text(_business));
        expect(line.top, greaterThanOrEqualTo(title.bottom));
        expect(line.bottom, lessThanOrEqualTo(header.bottom));
        await closeApp(tester, opened.db);
      });

      testWidgets('the header and what is under it keep their size and '
          'place', (tester) async {
        final one = await _open(tester, screen);
        final before = _measure(tester, screen);
        await closeApp(tester, one.db);

        final two = await _open(tester, screen, extra: _businessPocket);
        final after = _measure(tester, screen);
        expect(after.header, before.header, reason: 'header height');
        expect(after.below, before.below, reason: 'first widget below');
        expect(after.title.left, before.title.left);
        await closeApp(tester, two.db);
      });

      testWidgets('a long name is cut with an ellipsis, on one line', (
        tester,
      ) async {
        final opened = await _open(
          tester,
          screen,
          extra: (name: 'Household budget for the family', emoji: '\u{1F4BC}'),
          second: true,
        );
        const cut = '\u{1F4BC} Household budge…';
        expect(find.text(cut), findsOneWidget);
        expect(find.textContaining('family'), findsNothing);
        expect(tester.getRect(find.text(cut)).height, lessThan(20));
        expect(tester.takeException(), isNull);
        await closeApp(tester, opened.db);
      });

      for (final (:name, :mood, :mode) in [
        (name: 'dark Aqua', mood: Mood.aqua, mode: AppThemeMode.dark),
        (name: 'light Iris', mood: Mood.iris, mode: AppThemeMode.light),
      ]) {
        testWidgets('$name: the line is drawn in the quiet text colour', (
          tester,
        ) async {
          final opened = await _open(
            tester,
            screen,
            extra: _businessPocket,
            mood: mood,
            mode: mode,
          );
          final text = tester.widget<Text>(find.text(_personal));
          final context = tester.element(find.text(_personal));
          expect(text.style?.color, context.colors.text3);
          await closeApp(tester, opened.db);
        });
      }

      testWidgets('largest text, two pockets: no overflow, inside the '
          'header', (tester) async {
        final opened = await _open(
          tester,
          screen,
          extra: _businessPocket,
          scale: textScaleSteps.last,
        );
        expect(tester.takeException(), isNull);
        final header = tester.getRect(screen.header);
        final title = tester.getRect(screen.titleText);
        final line = tester.getRect(find.text(_personal));
        expect(header.height, screen == _Screen.calendar ? 60 : 64);
        expect(title.top, greaterThanOrEqualTo(header.top));
        expect(line.top, greaterThanOrEqualTo(title.bottom - 0.01));
        expect(line.bottom, lessThanOrEqualTo(header.bottom));
        await closeApp(tester, opened.db);
      });

      testWidgets('largest text, a long name: no overflow, and clear of the '
          'back-to-now pill', (tester) async {
        final opened = await _open(
          tester,
          screen,
          extra: (name: 'WWWWWWWWWWWWWWWWWW', emoji: '\u{1F4BC}'),
          second: true,
          scale: textScaleSteps.last,
        );
        if (screen == _Screen.charts) await _awayFromNow(tester);
        expect(tester.takeException(), isNull);
        if (screen != _Screen.reports) {
          expect(find.byType(Pill), findsOneWidget, reason: 'the pill shows');
          expectNothingUnder(tester, find.byType(Pill));
          final pill = tester.getRect(find.byType(Pill));
          final line = tester.getRect(find.text('\u{1F4BC} WWWWWWWWWWWWWWW…'));
          expect(line.right, lessThan(pill.left));
        }
        await closeApp(tester, opened.db);
      });
    });
  }

  group('the pill and the line together', () {
    for (final scale in [1.0, textScaleSteps.last]) {
      testWidgets('Calendar at text size ${scale.toStringAsFixed(2)}: the '
          '"Today" pill covers neither the title nor the line', (tester) async {
        final opened = await _open(
          tester,
          _Screen.calendar,
          extra: _businessPocket,
          scale: scale,
        );
        expect(find.byType(Pill), findsOneWidget);
        expectNothingUnder(tester, find.byType(Pill));
        final pill = tester.getRect(find.byType(Pill));
        expect(pill.top, 14, reason: 'the pill keeps its place');
        expect(pill.right, 360 - 16);
        expect(tester.getRect(find.text(_personal)).right, lessThan(pill.left));
        await closeApp(tester, opened.db);
      });
    }

    testWidgets('widthFor is the width the pill really takes', (tester) async {
      for (final scale in [1.0, textScaleSteps.last]) {
        final opened = await _open(tester, _Screen.calendar, scale: scale);
        final context = tester.element(find.byType(Pill));
        expect(
          NowPill.widthFor(context, 'Today'),
          closeTo(tester.getRect(find.byType(Pill)).width, 0.5),
          reason: 'text size $scale',
        );
        await closeApp(tester, opened.db);
      }
    });
  });
}
