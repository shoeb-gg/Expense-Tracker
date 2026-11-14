import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';

import '../support/sample_data.dart';
import '../support/test_db.dart';

void main() {
  test('generator matches the mockup numbers', () {
    final rows = generateSampleExpenses();
    expect(rows, hasLength(1266));
    int sum(int from, int to) => rows
        .where((x) => x.day >= from && x.day <= to)
        .fold(0, (s, x) => s + x.amount);
    expect(sum(dayOf(2026, 10, 1), sampleToday), 34555);
    expect(sum(sampleToday, sampleToday), 1180);
    expect(sum(dayOf(2026, 10, 17), dayOf(2026, 10, 17)), 135);
    final oct18 = rows.where((x) => x.day == sampleToday).single;
    expect(oct18.catId, 'health');
    expect(oct18.note, 'Doctor visit');
  });

  test('fills a database with the same totals', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final summary = await fillSampleData(db);
    expect(summary.count, 1266);
    final repo = ExpensesRepo(db);
    expect(
      await repo.watchTotal(summary.pocketId, dayOf(2026, 10, 1), sampleToday).first,
      3455500,
    );
    expect(
      await repo.watchTotal(summary.pocketId, sampleToday, sampleToday).first,
      118000,
    );
    final days = await repo
        .watchDayTotals(summary.pocketId, dayOf(2026, 10, 1), sampleToday)
        .first;
    expect(days[dayOf(2026, 10, 1)], 1509000);
    expect(days[dayOf(2026, 10, 5)], 166500);
    final cats = await (db.select(db.categories)).get();
    final health = cats.firstWhere((c) => c.name == 'Health');
    final today = await repo.listRange(summary.pocketId, sampleToday, sampleToday);
    expect(today.single.categoryId, health.id);
    expect(today.single.createdAt.hour, greaterThanOrEqualTo(8));
  });
}
