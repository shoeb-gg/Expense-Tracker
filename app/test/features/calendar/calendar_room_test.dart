import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/board.dart';
import '../../support/shots.dart';

/// The calendar on the owner's phone (1080 x 2374 px at density 480: 360 x
/// 791 dp). The month grid is pinned, so a six-week month at the largest text
/// size left the day card almost no room. The weeks of the grid now shrink
/// (never below 52 dp) until the day card keeps its header and two expenses,
/// while every day and amount stays whole.
void main() {
  setUpAll(loadShotFonts);

  final oct = (name: 'a five-week month (Oct 2026)', year: 2026, month: 10);
  final aug = (name: 'a six-week month (Aug 2026)', year: 2026, month: 8);
  final sizes = <(String, double)>[
    ('default', 1.0),
    ('largest', textScaleSteps.last),
  ];

  /// The day of the month with the most expenses (two at least), so the day
  /// card has rows to keep room for.
  Future<int> busiestDay(WidgetTester tester, AppDatabase db, int year, int month) async {
    final expenses = await tester.runAsync(() async {
      final pocket = (await PocketsRepo(db).defaultPocket()).id;
      return ExpensesRepo(
        db,
      ).listRange(pocket, monthStart(year, month), monthEnd(year, month));
    });
    final perDay = <int, int>{};
    for (final e in expenses!) {
      perDay[e.day] = (perDay[e.day] ?? 0) + 1;
    }
    final best = perDay.entries.reduce((a, b) => b.value > a.value ? b : a);
    expect(best.value, greaterThanOrEqualTo(2), reason: 'the sample needs a busy day');
    return best.key;
  }

  /// The cells of the month grid.
  Finder cells() => find.descendant(
    of: find.byType(SwipeArea),
    matching: find.byType(Pressable),
  );

  /// The part of a rect that a transform (a scaled-down text) really covers.
  Rect painted(WidgetTester tester, Finder f) =>
      Rect.fromPoints(tester.getTopLeft(f), tester.getBottomRight(f));

  for (final month in [oct, aug]) {
    for (final (size, scale) in sizes) {
      group('${month.name}, $size text', () {
        late AppDatabase db;
        late int day;

        Future<void> open(WidgetTester tester) async {
          db = await sampleDatabase(tester);
          day = await busiestDay(tester, db, month.year, month.month);
          await pumpApp(
            tester,
            db: db,
            location: Routes.calendar(day: day),
            settings: AppSettings(textScale: scale),
          );
          await boardHeight(tester, 791);
        }

        testWidgets('the day card keeps room for its header and two expenses', (tester) async {
          await open(tester);
          final viewport = tester.getRect(find.byType(SingleChildScrollView));
          final rows = find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Pressable),
          );
          // Two expense rows and "Add expense on ...".
          expect(rows.evaluate().length, greaterThanOrEqualTo(3));
          final second = tester.getRect(rows.at(1));
          expect(
            second.bottom,
            lessThanOrEqualTo(viewport.bottom),
            reason: 'the second expense ends at ${second.bottom}, '
                'the room ends at ${viewport.bottom}',
          );
          expect(tester.takeException(), isNull);
          await closeApp(tester, db);
        });

        testWidgets('every week shows whole, and the grid does not move down', (tester) async {
          await open(tester);
          final first = monthStart(month.year, month.month);
          final last = monthEnd(month.year, month.month);
          final viewport = tester.getRect(find.byType(SingleChildScrollView));
          final all = cells().evaluate().length;
          expect(all, last - first + 1);
          for (var i = 0; i < all; i++) {
            final rect = tester.getRect(cells().at(i));
            expect(rect.height, inInclusiveRange(52, 64), reason: 'cell $i');
            // Whole, and above the part that scrolls.
            expect(rect.bottom, lessThanOrEqualTo(viewport.top), reason: 'cell $i');
          }
          await closeApp(tester, db);
        });

        testWidgets('day numbers and amounts stay inside their cell', (tester) async {
          await open(tester);
          final count = cells().evaluate().length;
          for (var i = 0; i < count; i++) {
            final cell = tester.getRect(cells().at(i));
            final texts = find.descendant(of: cells().at(i), matching: find.byType(Text));
            final n = texts.evaluate().length;
            expect(n, greaterThanOrEqualTo(1), reason: 'cell $i has a day number');
            for (var t = 0; t < n; t++) {
              final r = painted(tester, texts.at(t));
              final what = (tester.widget(texts.at(t)) as Text).data;
              expect(r.left, greaterThanOrEqualTo(cell.left - 0.5), reason: '"$what" in cell $i');
              expect(r.right, lessThanOrEqualTo(cell.right + 0.5), reason: '"$what" in cell $i');
            }
            // The day number sits above the amount.
            if (n == 2) {
              final number = painted(tester, texts.at(0));
              final amount = painted(tester, texts.at(1));
              expect(number.center.dy, lessThan(amount.center.dy - 12), reason: 'cell $i');
            }
          }
          expect(tester.takeException(), isNull);
          await closeApp(tester, db);
        });
      });
    }
  }

  testWidgets('a five-week month keeps the 64 dp weeks', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.calendar(day: dayOf(2026, 10, 18)));
    await boardHeight(tester, 791);
    final rect = tester.getRect(cells().first);
    expect(rect.height, 64);
    await closeApp(tester, db);
  });

  testWidgets('a six-week month at the largest size shrinks, not below 52 dp', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2026, 8, 31)),
      settings: AppSettings(textScale: textScaleSteps.last),
    );
    await boardHeight(tester, 791);
    final h = tester.getRect(cells().first).height;
    expect(h, lessThan(64));
    expect(h, greaterThanOrEqualTo(52));
    await closeApp(tester, db);
  });

  testWidgets('with a status bar and a gesture bar the day card still keeps its room', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    final day = await busiestDay(tester, db, 2026, 8);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: day),
      settings: AppSettings(textScale: textScaleSteps.last),
    );
    // A 28 dp status bar on top and a 24 dp gesture bar below (2 px per dp).
    tester.view.padding = const FakeViewPadding(top: 56, bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(top: 56, bottom: 48);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await boardHeight(tester, 791);
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    final rows = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Pressable),
    );
    final second = tester.getRect(rows.at(1));
    expect(second.bottom, lessThanOrEqualTo(viewport.bottom - 24));
    expect(tester.getRect(cells().first).height, greaterThanOrEqualTo(52));
    expect(tester.takeException(), isNull);
    await closeApp(tester, db);
  });

  testWidgets('a short phone keeps every week whole at the least height', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2026, 8, 31)),
      settings: AppSettings(textScale: textScaleSteps.last),
    );
    await boardHeight(tester, 600);
    expect(tester.getRect(cells().first).height, 52);
    expect(tester.takeException(), isNull);
    await closeApp(tester, db);
  });
}
