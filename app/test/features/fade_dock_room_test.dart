import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/board.dart';
import '../support/shots.dart';

/// Categories and Pockets float their "Add" button over the end of the list.
/// Scrolled all the way down, the last row must sit fully above that button,
/// whatever the phone puts at the bottom of the screen: nothing, a gesture
/// bar, or the 48 dp three-button bar (the user's phone, 2026-11-17: the
/// Miscellaneous row was half hidden behind "Add category").
void main() {
  setUpAll(loadShotFonts);

  /// Bottom system bars in dp: none, gesture bar, three buttons.
  const insets = [0.0, 24.0, 48.0];

  Future<void> withBottomBar(WidgetTester tester, double dp) async {
    tester.view.padding = FakeViewPadding(top: 56, bottom: dp * 2);
    tester.view.viewPadding = FakeViewPadding(top: 56, bottom: dp * 2);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
  }

  /// Scrolls to the very end and returns how far [last] (the last thing in
  /// the list) reaches past the top of the dock of the button labelled
  /// [button] (0 or less is fine).
  Future<double> overlap(WidgetTester tester, Finder last, String button) async {
    await tester.fling(find.byType(Scrollable).first, const Offset(0, -6000), 4000);
    await settle(tester);
    // The whole row (its outermost Row: tile, name and buttons) against the
    // top of the dock, fade included: a row under the fade looks hidden too.
    final row = tester.getRect(last);
    final dock = tester.getRect(find.ancestor(of: find.text(button), matching: find.byType(FadeDock)));
    return row.bottom - dock.top;
  }

  for (final dp in insets) {
    for (final scale in [1.0, textScaleSteps.last]) {
      final name = 'bottom bar ${dp.round()} dp, text x${scale.toStringAsFixed(2)}';

      testWidgets('Categories: the last row clears "Add category" ($name)', (tester) async {
        final db = await sampleDatabase(tester);
        await pumpApp(tester, db: db, location: Routes.categories, settings: AppSettings(textScale: scale));
        await withBottomBar(tester, dp);
        await boardHeight(tester, 791);
        final misc = find.ancestor(of: find.text('Miscellaneous').last, matching: find.byType(Row)).last;
        expect(await overlap(tester, misc, 'Add category'), lessThanOrEqualTo(0));
        await closeApp(tester, db);
      });

      testWidgets('Pockets: the last row clears "Add pocket" ($name)', (tester) async {
        final db = await sampleDatabase(tester);
        await tester.runAsync(() async {
          for (var i = 1; i <= 9; i++) {
            await PocketsRepo(db).add(name: 'Trip $i', emoji: '🧳');
          }
        });
        await pumpApp(tester, db: db, location: Routes.pockets, settings: AppSettings(textScale: scale));
        await withBottomBar(tester, dp);
        await boardHeight(tester, 791);
        final howCard = find.ancestor(of: find.text('How pockets work'), matching: find.byType(BandCard));
        expect(await overlap(tester, howCard, 'Add pocket'), lessThanOrEqualTo(0));
        await closeApp(tester, db);
      });
    }
  }
}
