import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/features/add/budget_alert.dart';
import 'package:spill_the_bills/state/budgets.dart';

void main() {
  const fmt = AmountFormat();
  final today = dayOf(2026, 11, 17);

  BudgetAlert? alert(int before, int after, {int budget = 500000, int? day, AmountFormat format = fmt}) =>
      budgetAlert(
        category: 'Snacks',
        before: before,
        after: after,
        budget: budget,
        day: day ?? today,
        today: today,
        fmt: format,
      );

  group('over budget', () {
    test('says by how much, and the month', () {
      expect(
        alert(480000, 560000),
        const BudgetAlert(
          level: BudgetLevel.over,
          title: 'Snacks is 600 over budget',
          detail: '5,600 of 5,000 spent this month',
        ),
      );
    });

    test('every time it is over, even when it already was', () {
      expect(alert(560000, 570000)?.title, 'Snacks is 700 over budget');
    });

    test('one cent over is over; exactly the budget is not', () {
      expect(alert(400000, 500001)?.level, BudgetLevel.over);
      expect(alert(400000, 500001)?.title, 'Snacks is 0.01 over budget');
      expect(alert(400000, 500000)?.level, BudgetLevel.near);
    });

    test('jumping from green straight past the budget says over, not 90%', () {
      expect(alert(100000, 900000)?.level, BudgetLevel.over);
    });
  });

  group('passing 90%', () {
    test('says it once, with the share and what is left', () {
      expect(
        alert(440000, 460000),
        const BudgetAlert(
          level: BudgetLevel.near,
          title: 'Snacks has used 92% of its budget',
          detail: '4,600 of 5,000 spent this month · 400 left',
        ),
      );
    });

    test('exactly 90% counts; the share is never rounded up to 100%', () {
      expect(alert(0, 450000)?.title, 'Snacks has used 90% of its budget');
      expect(alert(0, 499999)?.title, 'Snacks has used 99% of its budget');
    });

    test('exactly the budget: 100%, nothing left to mention', () {
      expect(alert(0, 500000)?.detail, '5,000 of 5,000 spent this month');
    });

    test('nothing when it was already past 90% before', () {
      expect(alert(450000, 470000), isNull);
      expect(alert(460000, 460000), isNull);
    });
  });

  test('nothing while still under 90%, or for a lower total after an edit', () {
    expect(alert(0, 449999), isNull);
    expect(alert(470000, 300000), isNull);
  });

  test('no budget, no alert', () {
    expect(alert(0, 900000, budget: 0), isNull);
  });

  group('the month', () {
    test('another month this year, and one in another year', () {
      expect(alert(0, 560000, day: dayOf(2026, 9, 3))?.detail, '5,600 of 5,000 spent in September');
      expect(alert(0, 560000, day: dayOf(2025, 12, 31))?.detail, '5,600 of 5,000 spent in December 2025');
    });
  });

  test('amounts follow the number settings', () {
    const lakh = AmountFormat(style: NumberStyle.lakh);
    expect(
      alert(0, 15000050, budget: 10000000, format: lakh)?.title,
      'Snacks is 50,000.50 over budget',
    );
    const whole = AmountFormat(showDecimals: false);
    expect(alert(0, 500050, format: whole)?.title, 'Snacks is 1 over budget');
  });

  test('with decimals hidden, less than 0.50 over never reads "0 over"', () {
    const whole = AmountFormat(showDecimals: false);
    expect(alert(0, 500040, format: whole)?.title, 'Snacks is 0.40 over budget');
  });
}
