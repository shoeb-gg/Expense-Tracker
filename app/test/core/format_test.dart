import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';

const _nb = '\u00A0';

void main() {
  group('amounts', () {
    test('the four styles, in the order the sheet lists them', () {
      expect(NumberStyle.values, [
        NumberStyle.comma,
        NumberStyle.spaceDot,
        NumberStyle.lakh,
        NumberStyle.plain,
      ]);
      expect([for (final s in NumberStyle.values) s.sample], [
        '1,234,567.89',
        '1${_nb}234${_nb}567.89',
        '12,34,567.89',
        '1234567.89',
      ]);
      expect(NumberStyle.lakh.note, 'Lakh, crore');
      expect(NumberStyle.plain.note, isEmpty);
    });

    test('each style formats 1234567.89 and 840.5', () {
      const expected = {
        NumberStyle.comma: ('1,234,567.89', '840.50'),
        NumberStyle.spaceDot: ('1${_nb}234${_nb}567.89', '840.50'),
        NumberStyle.lakh: ('12,34,567.89', '840.50'),
        NumberStyle.plain: ('1234567.89', '840.50'),
      };
      for (final MapEntry(key: style, value: (big, small)) in expected.entries) {
        final f = AmountFormat(style: style);
        expect(f.format(123456789), big, reason: style.name);
        expect(f.format(84050), small, reason: style.name);
      }
    });

    test('lakh grouping', () {
      const f = AmountFormat(style: NumberStyle.lakh);
      expect(f.format(100), '1');
      expect(f.format(99900), '999');
      expect(f.format(100000), '1,000');
      expect(f.format(10000000), '1,00,000');
      expect(f.format(1234567800), '1,23,45,678');
    });

    test('the no-grouping style never groups', () {
      const f = AmountFormat(style: NumberStyle.plain);
      expect(f.format(123456789), '1234567.89');
      expect(f.format(3455500), '34555');
      expect(f.formatWhole(123456789), '1234568');
      expect(f.count(1266), '1266');
      expect(f.typed('1234.5'), '1234.5');
    });

    test('the decimal mark is always a dot', () {
      for (final s in NumberStyle.values) {
        final f = AmountFormat(style: s);
        expect(f.format(1250), endsWith('.50'), reason: s.name);
        expect(f.typed('12.5'), '12.5', reason: s.name);
        expect(f.short(166500), '1.7K', reason: s.name);
        expect(f.decimalMark, '.');
      }
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

    group('show decimals off', () {
      const off = {
        NumberStyle.comma: ('1,234,568', '841'),
        NumberStyle.spaceDot: ('1\u00A0234\u00A0568', '841'),
        NumberStyle.lakh: ('12,34,568', '841'),
        NumberStyle.plain: ('1234568', '841'),
      };
      const on = {
        NumberStyle.comma: ('1,234,567.89', '840.50'),
        NumberStyle.spaceDot: ('1\u00A0234\u00A0567.89', '840.50'),
        NumberStyle.lakh: ('12,34,567.89', '840.50'),
        NumberStyle.plain: ('1234567.89', '840.50'),
      };

      test('each style formats 1234567.89 and 840.5 with decimals on', () {
        for (final MapEntry(key: style, value: (big, small)) in on.entries) {
          const decimals = true;
          final f = AmountFormat(style: style, showDecimals: decimals);
          expect(f.format(123456789), big, reason: style.name);
          expect(f.format(84050), small, reason: style.name);
          expect(f.format(84025), '840.25', reason: style.name);
          expect(f.format(84000), '840', reason: style.name);
        }
      });

      test('each style formats 1234567.89 and 840.5 rounded when off', () {
        for (final MapEntry(key: style, value: (big, small)) in off.entries) {
          final f = AmountFormat(style: style, showDecimals: false);
          expect(f.format(123456789), big, reason: style.name);
          expect(f.format(84050), small, reason: style.name);
        }
      });

      test('rounds half up', () {
        const f = AmountFormat(showDecimals: false);
        expect(f.format(84050), '841');
        expect(f.format(84025), '840');
        expect(f.format(84049), '840');
        expect(f.format(84099), '841');
        expect(f.format(50), '1');
        expect(f.format(49), '0');
        expect(f.format(0), '0');
        expect(f.format(99950), '1,000');
        expect(f.format(99949), '999');
        expect(f.format(84000), '840');
        expect(f.format(123456750), '1,234,568');
      });

      test('a total is rounded once, not row by row', () {
        const f = AmountFormat(showDecimals: false);
        const rows = [84040, 84040]; // 840.40 twice
        expect(f.format(rows.fold<int>(0, (a, b) => a + b)), '1,681');
        expect([for (final r in rows) f.format(r)], ['840', '840']);
      });

      test('negative amounts round away from zero and never show -0', () {
        const f = AmountFormat(showDecimals: false);
        expect(f.format(-84050), '-841');
        expect(f.format(-84025), '-840');
        expect(f.format(-20), '0');
      });

      test('formatExact, typed text, samples and whole figures are not affected', () {
        const f = AmountFormat(showDecimals: false);
        expect(f.formatExact(84050), '840.50');
        expect(f.formatExact(84025), '840.25');
        expect(f.formatExact(84000), '840');
        expect(f.typed('840.5'), '840.5');
        expect(f.parse('840.5'), 84050);
        expect(f.formatWhole(84050), '841');
        expect(f.short(166500), '1.7K');
        expect(f.short(83500), '835');
        expect(f.count(1266), '1,266');
        for (final s in NumberStyle.values) {
          expect(AmountFormat(style: s, showDecimals: false).format(123456789),
              isNot(contains('.')));
          expect(s.sample, endsWith('.89'), reason: 'samples describe the style');
        }
      });

      test('equality and hashCode follow both fields', () {
        expect(const AmountFormat(), const AmountFormat(showDecimals: true));
        expect(const AmountFormat().hashCode, const AmountFormat().hashCode);
        expect(const AmountFormat(showDecimals: false),
            const AmountFormat(showDecimals: false));
        expect(const AmountFormat(showDecimals: false).hashCode,
            const AmountFormat(showDecimals: false).hashCode);
        expect(const AmountFormat(), isNot(const AmountFormat(showDecimals: false)));
        expect(const AmountFormat(style: NumberStyle.lakh),
            isNot(const AmountFormat()));
        expect(
          const AmountFormat(style: NumberStyle.lakh, showDecimals: false),
          isNot(const AmountFormat(style: NumberStyle.lakh)),
        );
      });
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
    });

    test('keypad display', () {
      const f = AmountFormat();
      expect(f.typed(''), '0');
      expect(f.typed('1234'), '1,234');
      expect(f.typed('1234.5'), '1,234.5');
      expect(f.typed('12.'), '12.');
      expect(const AmountFormat(style: NumberStyle.spaceDot).typed('1234.5'), '1${_nb}234.5');
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
      expect(f.parse('1.20'), 120, reason: 'a dot is always a decimal mark');
      expect(f.parse('1.200'), isNull, reason: 'never a grouping mark');
      expect(f.parse('  12.5 '), 1250);
      for (final s in NumberStyle.values) {
        expect(AmountFormat(style: s).parse('12.5'), 1250, reason: s.name);
        expect(AmountFormat(style: s).parse('1,200.5'), 120050, reason: s.name);
      }
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
