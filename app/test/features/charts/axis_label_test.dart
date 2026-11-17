import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/charts/column_chart.dart';
import 'package:spill_the_bills/router.dart';

import '../../support/shots.dart';
import '../../support/test_db.dart';

/// Chart side labels stay short: K from ten thousand, M from a million, B
/// from a billion (phone test 2026-11-17: Reports said "1000000K" and
/// Charts "1250M").
void main() {
  const fmt = AmountFormat();

  test('the shared short form', () {
    expect(compactAxisLabel(0, fmt), '0');
    expect(compactAxisLabel(2500, fmt), '2.5K');
    expect(compactAxisLabel(500000, fmt), '500K');
    expect(compactAxisLabel(1000000, fmt), '1M');
    expect(compactAxisLabel(1500000, fmt), '1.5M');
    expect(compactAxisLabel(250000000, fmt), '250M');
    expect(compactAxisLabel(1000000000, fmt), '1B');
    expect(compactAxisLabel(1250000000, fmt), '1.25B');
  });

  test('Charts: a billion-sized scale labels in B', () {
    final scale = ChartScale.fit(999999999.0);
    final labels = [for (final v in scale.ticks) scale.label(v, fmt)];
    expect(labels.where((l) => l.endsWith('000M') || l.endsWith('000K')), isEmpty);
    expect(labels, contains('1B'));
  });

  testWidgets('Reports: the year chart labels in M and B, not "1000000K"', (tester) async {
    await loadShotFonts();
    final db = openTestDatabase();
    await tester.runAsync(() async {
      final pocket = (await PocketsRepo(db).defaultPocket()).id;
      await ExpensesRepo(db).add(pocketId: pocket, categoryId: 1, amount: 99999999900, day: dayOf(2026, 10, 18));
    });
    await pumpApp(tester, db: db, location: Routes.reports);
    final texts = [
      for (final t in tester.widgetList<Text>(find.byType(Text))) t.data ?? '',
    ];
    expect(texts.where((t) => RegExp(r'^\d+000K$').hasMatch(t)), isEmpty);
    expect(texts, contains('1B'));
    await closeApp(tester, db);
  });
}
