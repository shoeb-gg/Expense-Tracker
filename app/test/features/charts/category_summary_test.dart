import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/shots.dart';

/// The summary card of the category screen: "Spent on X | Daily average |
/// Entries". A long name used to be cut to "Spent on Transportati…".
void main() {
  // The real fonts: Ahem's square letters would not fit any column.
  setUpAll(loadShotFonts);

  Future<int> idOf(WidgetTester tester, AppDatabase db, String name) async {
    final rows = await tester.runAsync(
      () => (db.select(db.categories)..where((c) => c.name.equals(name))).get(),
    );
    return rows!.single.id;
  }

  for (final big in [false, true]) {
    final size = big ? 'largest' : 'default';
    final settings = big
        ? AppSettings(textScale: textScaleSteps.last)
        : const AppSettings();

    for (final name in ['Online Subscriptions', 'Transportation']) {
      testWidgets('"Spent on $name" shows whole ($size text)', (
        tester,
      ) async {
        final db = await sampleDatabase(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.category(
            await idOf(tester, db, name),
            from: dayOf(2026, 10, 1),
            to: dayOf(2026, 10, 31),
          ),
          settings: settings,
        );
        final label = find.text('Spent on $name');
        expect(label, findsOneWidget);
        final rect = tester.getRect(label);
        final line = 16 * settings.textScale;
        final average = tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data ?? '').replaceAll('\n', ' ') == 'Daily average',
          ),
        );
        final entries = tester.getRect(find.text('Entries'));

        // The whole name is shown: it wraps over two or three lines instead
        // of being cut to one, and ends before the average's label.
        expect(rect.height, greaterThan(line * 1.5), reason: 'it wraps');
        expect(rect.height, lessThan(line * 3.5));
        expect(rect.right, lessThanOrEqualTo(average.left));
        expect(average.right, lessThanOrEqualTo(entries.left));
        expect(entries.right, closeTo(360 - 16 - 16, 1));
        // The three labels start on the same line.
        expect(average.top, closeTo(rect.top, 1));
        expect(entries.top, closeTo(rect.top, 1));
        expect(tester.takeException(), isNull);
        await closeApp(tester, db);
      });
    }

    testWidgets('a short name keeps its place ($size text)', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.category(
          1,
          from: dayOf(2026, 10, 1),
          to: dayOf(2026, 10, 31),
        ),
        settings: settings,
      );
      final label = tester.getRect(find.text('Spent on Groceries'));
      final line = 16 * settings.textScale;
      if (big) {
        // The largest text no longer fits "Spent on Groceries" beside the
        // other two labels: it takes a second line, whole.
        expect(label.height, closeTo(2 * line, 1));
      } else {
        // The default layout is untouched: one 16 px line, with the labels
        // of the average and the entries on it.
        expect(label.height, closeTo(line, 1));
        expect(label.top, closeTo(tester.getRect(find.text('Entries')).top, 1));
      }
      expect(find.text('Daily average'), findsOneWidget);
      await closeApp(tester, db);
    });
  }
}
