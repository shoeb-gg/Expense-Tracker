/// Number and date wording used across the app. No currency symbols anywhere.
///
/// Amounts are stored as minor units (amount x 100). Whole amounts are shown
/// without decimals ("1,180"); others always show two ("12.50").
library;

import 'package:flutter/foundation.dart';

import 'days.dart';

/// The five number styles offered in Settings > Number format.
/// Spaces are no-break spaces (U+00A0) so an amount never wraps.
enum NumberStyle {
  /// 1,234,567.89 (the default).
  comma(',', '.'),

  /// 1.234.567,89
  dotComma('.', ','),

  /// 1 234 567.89
  spaceDot(' ', '.'),

  /// 1 234 567,89
  spaceComma(' ', ','),

  /// 12,34,567.89 (lakh and crore).
  lakh(',', '.');

  const NumberStyle(this.group, this.decimal);

  /// Thousands (or lakh) separator.
  final String group;

  /// Decimal mark.
  final String decimal;

  /// The seven-digit sample shown in Settings and the Number format sheet,
  /// e.g. "1,234,567.89", or "1234567.89" when [separator] is off.
  String sample({bool separator = true}) =>
      AmountFormat(style: this, separator: separator).format(123456789);

  /// Note shown on the right of an option in the Number format sheet.
  String get note => this == NumberStyle.lakh ? 'Lakh, crore' : '';
}

/// Formats and parses amounts for one number style. Read the app-wide one
/// with `ref.watch(amountFormatProvider)`.
@immutable
class AmountFormat {
  const AmountFormat({this.style = NumberStyle.comma, this.separator = true});

  final NumberStyle style;

  /// Whether thousands separators are shown.
  final bool separator;

  /// The decimal mark of the style ("." or ",").
  String get decimalMark => style.decimal;

  /// 118000 -> "1,180"; 1250 -> "12.50"; 123456789 -> "1,234,567.89".
  String format(int minor) {
    final negative = minor < 0;
    final abs = minor.abs();
    final whole = abs ~/ 100;
    final cents = abs % 100;
    final buffer = StringBuffer(negative ? '-' : '')..write(group(whole));
    if (cents != 0) {
      buffer
        ..write(style.decimal)
        ..write(cents.toString().padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Rounded to whole units, always without decimals ("34,555").
  /// Use for chart axes, averages and other rounded figures.
  String formatWhole(int minor) {
    final units = (minor / 100).round();
    return units < 0 ? '-${group(-units)}' : group(units);
  }

  /// A plain count with separators, e.g. "1,266" in "1,266 expenses".
  String count(int n) => n < 0 ? '-${group(-n)}' : group(n);

  /// The calendar's short form. Under 1,000: whole number ("835");
  /// under 9,950: one decimal plus K ("1.7K", trailing ".0" dropped: "2K");
  /// else whole K ("15K"). Same rule as the mockup's `short()`.
  String short(int minor) {
    final v = minor / 100;
    if (v < 1000) return group(v.round());
    if (v < 9950) {
      var s = (v / 1000).toStringAsFixed(1);
      if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
      return '${s.replaceAll('.', style.decimal)}K';
    }
    return '${group((v / 1000).round())}K';
  }

  /// The keypad display of a typed number string that uses "." as its
  /// decimal mark internally (the mockup's `pretty()`):
  /// "" -> "0", "1234" -> "1,234", "1234.5" -> "1,234.5", "12." -> "12.".
  String typed(String raw) {
    if (raw.isEmpty) return '0';
    final parts = raw.split('.');
    final whole = int.tryParse(parts.first.isEmpty ? '0' : parts.first) ?? 0;
    final head = group(whole);
    return parts.length > 1 ? '$head${style.decimal}${parts[1]}' : head;
  }

  /// Parses a user-typed amount to minor units, or null when it is not a
  /// plain positive amount with at most two decimals. Grouping marks of the
  /// style are ignored ("1,200" -> 120000; dotComma: "12,5" -> 1250).
  int? parse(String text) {
    var s = text.trim().replaceAll(' ', '').replaceAll(' ', '');
    if (style.decimal == ',') {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
    return parseDotDecimal(s);
  }

  /// Digits grouped with this style's separator (no decimals).
  String group(int whole) {
    final digits = whole.toString();
    if (!separator || digits.length <= 3) return digits;
    final sep = style.group;
    if (style == NumberStyle.lakh) {
      final head = digits.substring(0, digits.length - 3);
      final tail = digits.substring(digits.length - 3);
      final groups = <String>[];
      var end = head.length;
      while (end > 0) {
        final start = end - 2 < 0 ? 0 : end - 2;
        groups.insert(0, head.substring(start, end));
        end = start;
      }
      return '${groups.join(sep)}$sep$tail';
    }
    final buffer = StringBuffer();
    final lead = digits.length % 3;
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (i - lead) % 3 == 0) buffer.write(sep);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is AmountFormat &&
      other.style == style &&
      other.separator == separator;

  @override
  int get hashCode => Object.hash(style, separator);
}

final RegExp _dotDecimal = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

/// Parses "120", "120.5" or "120.50" (dot decimal, no grouping) to minor
/// units. Returns null for anything else. Used by the keypad.
int? parseDotDecimal(String s) {
  final m = _dotDecimal.firstMatch(s);
  if (m == null) return null;
  final whole = int.tryParse(m.group(1)!);
  if (whole == null) return null;
  final frac = m.group(2);
  final cents = frac == null ? 0 : int.parse(frac.padRight(2, '0'));
  return whole * 100 + cents;
}

/// Minor units as a dot-decimal string without grouping, for prefilling the
/// keypad: 118000 -> "1180", 1250 -> "12.5", 1205 -> "12.05".
String minorToKeypad(int minor) {
  final whole = minor ~/ 100;
  final cents = minor % 100;
  if (cents == 0) return '$whole';
  final frac = cents.toString().padLeft(2, '0');
  return '$whole.${frac.endsWith('0') ? frac.substring(0, 1) : frac}';
}

// ---------------------------------------------------------------------------
// Date words. All take day numbers (see days.dart).

/// "January" ... "December", index 0 = January.
const List<String> monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// "Jan" ... "Dec", index 0 = January.
const List<String> monthShortNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', //
  'Nov', 'Dec',
];

/// "Monday" ... "Sunday", index = DateTime.weekday - 1.
const List<String> weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];

/// "Mon" ... "Sun", index = DateTime.weekday - 1.
const List<String> weekdayShortNames = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

/// "M" ... "S", index = DateTime.weekday - 1 (calendar header letters).
const List<String> weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Month name of a 1-based month: "October".
String monthName(int month) => monthNames[month - 1];

/// Short month name of a 1-based month: "Oct".
String monthShortName(int month) => monthShortNames[month - 1];

/// "Sunday".
String weekdayName(int day) => weekdayNames[weekdayOfDay(day) - 1];

/// "Sun".
String weekdayShortName(int day) => weekdayShortNames[weekdayOfDay(day) - 1];

/// Home day card title: "Today", "Yesterday", else the weekday ("Thursday").
String dayLabel(int day, int today) {
  if (day == today) return 'Today';
  if (day == today - 1) return 'Yesterday';
  return weekdayName(day);
}

/// Home day card sub-line: the weekday for today and yesterday, else
/// "2 days ago" ... ; future days read "Tomorrow" / "In 3 days".
String daySubLabel(int day, int today) {
  if (day >= today - 1 && day <= today) return weekdayName(day);
  if (day < today) return '${today - day} days ago';
  if (day == today + 1) return 'Tomorrow';
  return 'In ${day - today} days';
}

/// "Sunday, October 18, 2026" (Details).
String longDate(int day) {
  final d = dateOfDay(day);
  return '${weekdayName(day)}, ${monthName(d.month)} ${d.day}, ${d.year}';
}

/// "Sun, Oct 18, 2026" (date pop-up heading).
String weekdayDate(int day) {
  final d = dateOfDay(day);
  return '${weekdayShortName(day)}, ${monthShortName(d.month)} ${d.day}, '
      '${d.year}';
}

/// "Oct 18, 2026".
String mediumDate(int day) {
  final d = dateOfDay(day);
  return '${monthShortName(d.month)} ${d.day}, ${d.year}';
}

/// "Oct 18".
String monthDay(int day) {
  final d = dateOfDay(day);
  return '${monthShortName(d.month)} ${d.day}';
}

/// "Sun, Oct 18" (chart tooltips).
String weekdayMonthDay(int day) => '${weekdayShortName(day)}, ${monthDay(day)}';

/// "October 18", plus ", 2025" when the year differs from [currentYear].
String longMonthDay(int day, {int? currentYear}) {
  final d = dateOfDay(day);
  final base = '${monthName(d.month)} ${d.day}';
  return currentYear == null || currentYear == d.year ? base : '$base, ${d.year}';
}

/// "Today, Oct 18" for today, else "Sep 19, 2026" (custom range rows).
String dayOrToday(int day, int today) =>
    day == today ? 'Today, ${monthDay(day)}' : mediumDate(day);

/// "October 2026".
String monthYear(int year, int month) => '${monthName(month)} $year';

/// "Oct 2026".
String shortMonthYear(int year, int month) => '${monthShortName(month)} $year';

/// "Oct 12 – Oct 18" (en dash with spaces).
String dayRangeLabel(int from, int to) => '${monthDay(from)} – ${monthDay(to)}';

/// "10:18 AM".
String timeOfDay(DateTime time) {
  final h12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final mm = time.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// "Added Oct 18, 2026 at 10:18 AM" (Details).
String addedLabel(DateTime createdAt) {
  final day = dayFromDate(createdAt);
  return 'Added ${mediumDate(day)} at ${timeOfDay(createdAt)}';
}

/// "1 expense" / "1,266 expenses".
String expenseCount(int n, AmountFormat format) =>
    n == 1 ? '1 expense' : '${format.count(n)} expenses';
