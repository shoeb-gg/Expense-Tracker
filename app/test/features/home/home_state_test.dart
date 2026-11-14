import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/home/home_state.dart';
import 'package:spill_the_bills/state/providers.dart';

Expense _expense(int id, int day, int amount, DateTime createdAt) => Expense(
  id: id,
  pocketId: 1,
  categoryId: 1,
  amount: amount,
  note: '',
  day: day,
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  group('groupByDay', () {
    test('newest day first, latest added first inside a day', () {
      final d1 = dayOf(2026, 10, 16);
      final d2 = dayOf(2026, 10, 18);
      final groups = groupByDay([
        _expense(1, d1, 500, DateTime(2026, 10, 16, 9)),
        _expense(2, d2, 1000, DateTime(2026, 10, 18, 8)),
        _expense(3, d1, 250, DateTime(2026, 10, 16, 18)),
        _expense(4, d2, 30, DateTime(2026, 10, 18, 8)),
      ]);
      expect(groups.map((g) => g.day), [d2, d1]);
      expect(groups[0].total, 1030);
      expect(groups[1].total, 750);
      // Same time: higher id first.
      expect(groups[0].expenses.map((e) => e.id), [4, 2]);
      expect(groups[1].expenses.map((e) => e.id), [3, 1]);
    });

    test('no expenses, no groups', () {
      expect(groupByDay(const []), isEmpty);
    });

    test('totalOf adds every amount', () {
      final d = dayOf(2026, 10, 1);
      expect(
        totalOf([
          _expense(1, d, 1500000, DateTime(2026)),
          _expense(2, d, 9000, DateTime(2026)),
        ]),
        1509000,
      );
    });
  });

  group('months', () {
    test('stepMonth crosses years both ways', () {
      expect(stepMonth((year: 2026, month: 1), -1), (year: 2025, month: 12));
      expect(stepMonth((year: 2026, month: 12), 1), (year: 2027, month: 1));
      expect(stepMonth((year: 2026, month: 10), -1), (year: 2026, month: 9));
    });

    test('monthIndex orders months', () {
      expect(
        monthIndex((year: 2026, month: 1)) >
            monthIndex((year: 2025, month: 12)),
        isTrue,
      );
    });

    test('Home follows today until a month is chosen', () {
      final container = ProviderContainer.test(
        overrides: [clockProvider.overrideWithValue(Clock.fixed(mockupNow))],
      );
      expect(container.read(homeShownMonthProvider), (year: 2026, month: 10));
      container.read(homeMonthProvider.notifier).showDay(dayOf(2025, 3, 14));
      expect(container.read(homeShownMonthProvider), (year: 2025, month: 3));
    });
  });

  test('the masked total is six bullets', () {
    expect(maskedAmount, '•' * 6);
  });
}
