import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';

void main() {
  test('day numbers match the mockup dn()', () {
    expect(dayOf(1970, 1, 1), 0);
    // Date.UTC(2026, 9, 18) / 86400000 in the mockup.
    expect(dayOf(2026, 10, 18), 20744);
    expect(dateOfDay(20744), DateTime.utc(2026, 10, 18));
    expect(dayFromDate(DateTime(2026, 10, 18, 23, 59)), 20744);
    expect(dayFromDate(mockupNow), 20744);
  });

  test('no daylight saving jumps: every day is exactly +1', () {
    var prev = dayOf(2024, 1, 1);
    for (var i = 1; i < 366 * 3; i++) {
      final next = dayFromDate(DateTime(2024, 1, 1 + i, 12));
      expect(next, prev + 1);
      prev = next;
    }
  });

  test('weekday and calendar fields', () {
    final d = dayOf(2026, 10, 18);
    expect(weekdayOfDay(d), DateTime.sunday);
    expect(yearOfDay(d), 2026);
    expect(monthOfDay(d), 10);
    expect(dayOfMonth(d), 18);
  });

  test('month and year bounds', () {
    expect(monthStart(2026, 10), dayOf(2026, 10, 1));
    expect(monthEnd(2026, 10), dayOf(2026, 10, 31));
    expect(monthEnd(2024, 2), dayOf(2024, 2, 29));
    expect(daysInMonth(2025, 2), 28);
    expect(monthStartOfDay(dayOf(2026, 10, 18)), dayOf(2026, 10, 1));
    expect(monthEndOfDay(dayOf(2026, 2, 3)), dayOf(2026, 2, 28));
    expect(yearStart(2026), dayOf(2026, 1, 1));
    expect(yearEnd(2026), dayOf(2026, 12, 31));
  });

  test('add months', () {
    expect(addMonths(2026, 10, 1), (year: 2026, month: 11));
    expect(addMonths(2026, 12, 1), (year: 2027, month: 1));
    expect(addMonths(2026, 1, -1), (year: 2025, month: 12));
    expect(addMonths(2026, 3, -27), (year: 2023, month: 12));
    expect(addMonthsToDay(dayOf(2026, 1, 31), 1), dayOf(2026, 2, 28));
    expect(addMonthsToDay(dayOf(2026, 3, 15), -1), dayOf(2026, 2, 15));
  });

  test('same month / year', () {
    expect(sameMonth(dayOf(2026, 10, 1), dayOf(2026, 10, 31)), isTrue);
    expect(sameMonth(dayOf(2026, 10, 31), dayOf(2026, 11, 1)), isFalse);
    expect(sameMonth(dayOf(2025, 10, 5), dayOf(2026, 10, 5)), isFalse);
    expect(sameYear(dayOf(2026, 1, 1), dayOf(2026, 12, 31)), isTrue);
  });

  test('week start for each first day of week', () {
    final sun18 = dayOf(2026, 10, 18); // Sunday
    expect(weekStart(sun18, FirstDayOfWeek.sunday), sun18);
    expect(weekStart(sun18, FirstDayOfWeek.monday), dayOf(2026, 10, 12));
    expect(weekStart(sun18, FirstDayOfWeek.saturday), dayOf(2026, 10, 17));
    final wed14 = dayOf(2026, 10, 14);
    expect(weekStart(wed14, FirstDayOfWeek.sunday), dayOf(2026, 10, 11));
    expect(weekEnd(wed14, FirstDayOfWeek.monday), dayOf(2026, 10, 18));
    expect(weekdayOrder(FirstDayOfWeek.sunday), [7, 1, 2, 3, 4, 5, 6]);
    expect(weekdayOrder(FirstDayOfWeek.saturday), [6, 7, 1, 2, 3, 4, 5]);
  });

  test('six-week grid starts on the first day of the week', () {
    final grid = sixWeekGrid(2026, 10, FirstDayOfWeek.sunday);
    expect(grid.length, 42);
    // Oct 1, 2026 is a Thursday: the grid starts on Sunday Sep 27.
    expect(grid.first, dayOf(2026, 9, 27));
    expect(grid.last, dayOf(2026, 11, 7));
    expect(sixWeekGrid(2026, 10, FirstDayOfWeek.monday).first, dayOf(2026, 9, 28));
  });

  test('fixed clock', () {
    final clock = Clock.fixed(mockupNow);
    expect(clock.now(), DateTime(2026, 10, 18, 10, 18));
    expect(clock.today(), dayOf(2026, 10, 18));
  });
}
