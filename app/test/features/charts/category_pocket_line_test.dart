import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/overlap.dart';
import '../../support/shots.dart';

/// The category drill-down names its pocket under the category name, like
/// Calendar, Charts and Reports: only with two or more pockets, and it is the
/// pocket whose expenses the screen shows (an expense's own pocket when opened
/// from "See all").

const String _personal = '\u{1F45B} Personal';
const String _business = '\u{1F4BC} Business';
const int _groceries = 1;

void main() {
  setUpAll(loadShotFonts);

  Future<({AppDatabase db, int? business})> open(
    WidgetTester tester, {
    bool twoPockets = true,
    bool showBusiness = false,
    String businessName = 'Business',
    double scale = 1.0,
  }) async {
    final db = await sampleDatabase(tester);
    final business = twoPockets
        ? await tester.runAsync(() => PocketsRepo(db).add(name: businessName, emoji: '\u{1F4BC}'))
        : null;
    await pumpApp(
      tester,
      db: db,
      location: Routes.category(
        _groceries,
        from: dayOf(2026, 10, 1),
        to: dayOf(2026, 10, 31),
        pocket: showBusiness ? business : null,
      ),
      settings: AppSettings(textScale: scale),
    );
    return (db: db, business: business);
  }

  /// The header: the row with the back button.
  Rect header(WidgetTester tester) => tester.getRect(
    find.ancestor(of: find.byType(BackRoundButton), matching: find.byType(SizedBox)).first,
  );

  Rect monthButton(WidgetTester tester) => tester.getRect(
    find.ancestor(of: find.text('Oct 2026'), matching: find.byType(Pressable)).first,
  );

  testWidgets('one pocket: no pocket line', (tester) async {
    final o = await open(tester, twoPockets: false);
    expect(find.text(_personal), findsNothing);
    await closeApp(tester, o.db);
  });

  testWidgets('two pockets: the pocket in use is named under the category', (tester) async {
    final o = await open(tester);
    expect(find.text(_personal), findsOneWidget);
    final title = tester.getRect(find.text('Groceries').first);
    final line = tester.getRect(find.text(_personal));
    expect(line.top, greaterThanOrEqualTo(title.bottom - 0.01));
    expect(line.bottom, lessThanOrEqualTo(header(tester).bottom));
    expect(line.right, lessThan(monthButton(tester).left));
    await closeApp(tester, o.db);
  });

  testWidgets('opened for another pocket (from "See all"): names that pocket', (tester) async {
    final o = await open(tester, showBusiness: true);
    expect(find.text(_business), findsOneWidget);
    expect(find.text(_personal), findsNothing);
    await closeApp(tester, o.db);
  });

  testWidgets('the header and what is under it keep their size and place', (tester) async {
    final one = await open(tester, twoPockets: false);
    final before = (
      header: header(tester).height,
      below: tester.getRect(find.text('Spent on Groceries')).top,
      month: monthButton(tester),
    );
    await closeApp(tester, one.db);

    final two = await open(tester);
    expect(header(tester).height, before.header);
    expect(tester.getRect(find.text('Spent on Groceries')).top, before.below);
    expect(monthButton(tester), before.month);
    await closeApp(tester, two.db);
  });

  testWidgets('largest text, a long pocket name: one line, inside the header, clear of the month', (
    tester,
  ) async {
    final o = await open(
      tester,
      showBusiness: true,
      businessName: 'WWWWWWWWWWWWWWWWWW',
      scale: textScaleSteps.last,
    );
    expect(tester.takeException(), isNull);
    final line = find.text('\u{1F4BC} WWWWWWWWWWWWWWW…');
    expect(line, findsOneWidget);
    final rect = tester.getRect(line);
    expect(rect.bottom, lessThanOrEqualTo(header(tester).bottom));
    expect(rect.left, greaterThanOrEqualTo(16 + 40 + 12));
    expect(rect.right, lessThanOrEqualTo(monthButton(tester).left - 12));
    expectNothingUnder(tester, find.byType(BackRoundButton));
    await closeApp(tester, o.db);
  });
}
