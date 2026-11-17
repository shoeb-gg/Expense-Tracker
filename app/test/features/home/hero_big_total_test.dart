import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/home/hero_card.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/theme/symbols.dart';

import '../../support/shots.dart';
import '../../support/test_db.dart';

/// Home's month card: a very big total shrinks to fit and keeps clear of the
/// arrow button (phone test 2026-11-17: 99,99,99,999 ran under it).
void main() {
  setUpAll(loadShotFonts);

  for (final style in [NumberStyle.comma, NumberStyle.lakh]) {
    for (final scale in [1.0, textScaleSteps.last]) {
      testWidgets('a 9-digit total clears the arrow (${style.name}, text x$scale)', (tester) async {
        final db = openTestDatabase();
        await tester.runAsync(() async {
          final pocket = (await PocketsRepo(db).defaultPocket()).id;
          await ExpensesRepo(db).add(pocketId: pocket, categoryId: 1, amount: 99999999900, day: dayOf(2026, 10, 18));
        });
        await pumpApp(tester, db: db, settings: AppSettings(numberStyle: style, textScale: scale));
        final number = tester.getRect(
          find.descendant(of: find.byType(HeroCard), matching: find.textContaining('99,999')),
        );
        final arrow = tester.getRect(find.byIcon(Symbols.north_east_rounded));
        // The arrow's 32 px circle is centred on its icon.
        expect(number.right, lessThanOrEqualTo(arrow.center.dx - 16 - 8));
        await closeApp(tester, db);
      });
    }
  }
}
