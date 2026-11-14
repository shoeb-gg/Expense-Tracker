import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';

const _nb = ' ';

void main() {
  group('amounts', () {
    test('all five styles', () {
      const n = 123456789; // 1,234,567.89
      expect(const AmountFormat().format(n), '1,234,567.89');
      expect(const AmountFormat(style: NumberStyle.dotComma).format(n), '1.234.567,89');
      expect(const AmountFormat(style: NumberStyle.spaceDot).format(n), '1${_nb}234${_nb}567.89');
      expect(const AmountFormat(style: NumberStyle.spaceComma).format(n), '1${_nb}234${_nb}567,89');
      expect(const AmountFormat(style: NumberStyle.lakh).format(n), '12,34,567.89');
    });

    test('lakh grouping', () {
      const f = AmountFormat(style: NumberStyle.lakh);
      expect(f.format(100), '1');
      expect(f.format(99900), '999');
      expect(f.format(100000), '1,000');
      expect(f.format(10000000), '1,00,000');
      expect(f.format(1234567800), '1,23,45,678');
    });

    test('separator off', () {
      for (final s in NumberStyle.values) {
        final f = AmountFormat(style: s, separator: false);
        expect(f.format(123456789), '1234567${s.decimal}89');
        expect(f.format(3455500), '34555');
      }
      expect(NumberStyle.comma.sample(separator: false), '1234567.89');
      expect(NumberStyle.dotComma.sample(separator: false), '1234567,89');
      expect(NumberStyle.comma.sample(), '1,234,567.89');
    });

    test('whole amounts have no decimals, others two', () {
      const f = AmountFormat();
      expect(f.format(3455500), '34,555');
      expect(f.format(118000), '1,180');
      expect(f.format(1250), '12.50');
      expect(f.format(1205), '12.05');
      expect(f.format(5), '0.05');
      expect(f.format(0), '0');
      expect(f.format(99999), '999.99');
      expect(f.format(-1250), '-12.50');
      expect(f.formatWhole(123456), '1,235');
      expect(f.count(1266), '1,266');
    });

    test('calendar short form', () {
      const f = AmountFormat();
      expect(f.short(83500), '835');
      expect(f.short(99900), '999');
      expect(f.short(100000), '1K');
      expect(f.short(166500), '1.7K'); // 1,665 -> 1.7K (mockup example)
      expect(f.short(118000), '1.2K');
      expect(f.short(200000), '2K'); // trailing .0 dropped
      expect(f.short(994900), '9.9K');
      expect(f.short(995000), '10K');
      expect(f.short(1509000), '15K'); // 15,090 -> 15K (mockup example)
      expect(const AmountFormat(style: NumberStyle.dotComma).short(166500), '1,7K');
    });

    test('keypad display', () {
      const f = AmountFormat();
      expect(f.typed(''), '0');
      expect(f.typed('1234'), '1,234');
      expect(f.typed('1234.5'), '1,234.5');
      expect(f.typed('12.'), '12.');
      expect(const AmountFormat(style: NumberStyle.dotComma).typed('1234.5'), '1.234,5');
      expect(minorToKeypad(118000), '1180');
      expect(minorToKeypad(1250), '12.5');
      expect(minorToKeypad(1205), '12.05');
    });

    test('parsing typed amounts', () {
      const f = AmountFormat();
      expect(f.parse('120'), 12000);
      expect(f.parse('1,200'), 120000);
      expect(f.parse('12.5'), 1250);
      expect(f.parse('12.05'), 1205);
      expect(f.parse('12.345'), isNull);
      expect(f.parse('abc'), isNull);
      expect(f.parse(''), isNull);
      expect(f.parse('-5'), isNull);
      const eu = AmountFormat(style: NumberStyle.dotComma);
      expect(eu.parse('1.200'), 120000);
      expect(eu.parse('12,5'), 1250);
      expect(const AmountFormat(style: NumberStyle.spaceDot).parse('1${_nb}200.50'), 120050);
      expect(parseDotDecimal('0.5'), 50);
    });
  });

  group('date words', () {
    final today = dayOf(2026, 10, 18);
    test('day card labels', () {
      expect(dayLabel(today, today), 'Today');
      expect(dayLabel(today - 1, today), 'Yesterday');
      expect(dayLabel(dayOf(2026, 10, 15), today), 'Thursday');
      expect(daySubLabel(today, today), 'Sunday');
      expect(daySubLabel(today - 1, today), 'Saturday');
      expect(daySubLabel(today - 2, today), '2 days ago');
      expect(daySubLabel(today + 1, today), 'Tomorrow');
    });

    test('long and short dates', () {
      expect(longDate(today), 'Sunday, October 18, 2026');
      expect(weekdayDate(dayOf(2026, 10, 12)), 'Mon, Oct 12, 2026');
      expect(mediumDate(today), 'Oct 18, 2026');
      expect(monthDay(today), 'Oct 18');
      expect(weekdayMonthDay(today), 'Sun, Oct 18');
      expect(longMonthDay(today, currentYear: 2026), 'October 18');
      expect(longMonthDay(today, currentYear: 2027), 'October 18, 2026');
      expect(monthYear(2026, 10), 'October 2026');
      expect(shortMonthYear(2026, 10), 'Oct 2026');
      expect(dayRangeLabel(dayOf(2026, 10, 12), today), 'Oct 12 – Oct 18');
      expect(dayOrToday(today, today), 'Today, Oct 18');
      expect(dayOrToday(dayOf(2026, 9, 19), today), 'Sep 19, 2026');
      expect(weekdayName(today), 'Sunday');
      expect(weekdayShortName(today), 'Sun');
    });

    test('times', () {
      expect(timeOfDay(DateTime(2026, 10, 18, 10, 18)), '10:18 AM');
      expect(timeOfDay(DateTime(2026, 10, 18, 0, 5)), '12:05 AM');
      expect(timeOfDay(DateTime(2026, 10, 18, 12, 0)), '12:00 PM');
      expect(timeOfDay(DateTime(2026, 10, 18, 21, 7)), '9:07 PM');
      expect(addedLabel(DateTime(2026, 10, 18, 10, 18)), 'Added Oct 18, 2026 at 10:18 AM');
      expect(expenseCount(1, const AmountFormat()), '1 expense');
      expect(expenseCount(1266, const AmountFormat()), '1,266 expenses');
    });
  });
}
