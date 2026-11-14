/// Calendar days as plain integers.
///
/// A "day" is the local calendar date as a number of days since 1970-01-01,
/// computed from `DateTime.utc(year, month, day)` exactly like the mockup's
/// `dn()`. Because the calendar fields are read in local time and the
/// arithmetic is done in UTC, there are no daylight-saving bugs: day + 1 is
/// always the next calendar date.
///
/// Months are 1-based (1 = January) everywhere in Dart code.
library;

const int _msPerDay = 86400000;

/// The day number of a calendar date (month is 1-based). Overflowing values
/// roll over like `DateTime.utc` does, so `dayOf(2026, 11, 0)` is Oct 31.
int dayOf(int year, int month, int day) =>
    DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ _msPerDay;

/// The day number of the calendar date of [dateTime], read in its own zone
/// (local for `DateTime.now()`).
int dayFromDate(DateTime dateTime) =>
    dayOf(dateTime.year, dateTime.month, dateTime.day);

/// A UTC midnight `DateTime` whose year/month/day fields are the calendar
/// date of [day]. Use its `.year`, `.month`, `.day`, `.weekday`.
DateTime dateOfDay(int day) =>
    DateTime.fromMillisecondsSinceEpoch(day * _msPerDay, isUtc: true);

/// A local `DateTime` at [hour]:[minute] on [day] (for createdAt values).
DateTime localDateTimeOfDay(int day, {int hour = 0, int minute = 0}) {
  final d = dateOfDay(day);
  return DateTime(d.year, d.month, d.day, hour, minute);
}

/// Weekday of [day]: 1 = Monday ... 7 = Sunday (same as `DateTime.weekday`).
int weekdayOfDay(int day) => dateOfDay(day).weekday;

/// Year of [day].
int yearOfDay(int day) => dateOfDay(day).year;

/// Month (1-12) of [day].
int monthOfDay(int day) => dateOfDay(day).month;

/// Day of month (1-31) of [day].
int dayOfMonth(int day) => dateOfDay(day).day;

/// First day of the month.
int monthStart(int year, int month) => dayOf(year, month, 1);

/// Last day of the month.
int monthEnd(int year, int month) => dayOf(year, month + 1, 0);

/// Number of days in the month.
int daysInMonth(int year, int month) =>
    monthEnd(year, month) - monthStart(year, month) + 1;

/// First day of the month that contains [day].
int monthStartOfDay(int day) {
  final d = dateOfDay(day);
  return monthStart(d.year, d.month);
}

/// Last day of the month that contains [day].
int monthEndOfDay(int day) {
  final d = dateOfDay(day);
  return monthEnd(d.year, d.month);
}

/// First day of the year.
int yearStart(int year) => dayOf(year, 1, 1);

/// Last day of the year.
int yearEnd(int year) => dayOf(year, 12, 31);

/// A calendar month. [month] is 1-based.
typedef YearMonth = ({int year, int month});

/// The month that contains [day].
YearMonth yearMonthOfDay(int day) {
  final d = dateOfDay(day);
  return (year: d.year, month: d.month);
}

/// [year]/[month] moved by [delta] months (negative goes back).
YearMonth addMonths(int year, int month, int delta) {
  final index = year * 12 + (month - 1) + delta;
  return (year: _floorDiv(index, 12), month: _floorMod(index, 12) + 1);
}

/// [day] moved by [delta] months, clamped to the end of the target month
/// (Jan 31 + 1 month = Feb 28/29).
int addMonthsToDay(int day, int delta) {
  final d = dateOfDay(day);
  final ym = addMonths(d.year, d.month, delta);
  final last = daysInMonth(ym.year, ym.month);
  return dayOf(ym.year, ym.month, d.day > last ? last : d.day);
}

/// Whether two days are in the same calendar month.
bool sameMonth(int a, int b) {
  final x = dateOfDay(a);
  final y = dateOfDay(b);
  return x.year == y.year && x.month == y.month;
}

/// Whether two days are in the same calendar year.
bool sameYear(int a, int b) => yearOfDay(a) == yearOfDay(b);

/// The first day of the week, as chosen in Settings.
/// Sheet order is Monday, Saturday, Sunday; the default is Sunday.
enum FirstDayOfWeek {
  monday(DateTime.monday, 'Monday'),
  saturday(DateTime.saturday, 'Saturday'),
  sunday(DateTime.sunday, 'Sunday');

  const FirstDayOfWeek(this.weekday, this.label);

  /// `DateTime.weekday` value (1 = Monday ... 7 = Sunday).
  final int weekday;

  /// Label shown in Settings and its sheet.
  final String label;
}

/// The first day of the week that contains [day].
int weekStart(int day, FirstDayOfWeek first) {
  final back = (weekdayOfDay(day) - first.weekday + 7) % 7;
  return day - back;
}

/// The last day of the week that contains [day].
int weekEnd(int day, FirstDayOfWeek first) => weekStart(day, first) + 6;

/// Weekdays (1 = Monday ... 7 = Sunday) in display order for [first].
List<int> weekdayOrder(FirstDayOfWeek first) =>
    List<int>.generate(7, (i) => (first.weekday - 1 + i) % 7 + 1);

/// The 42 days (six weeks) shown by a month grid, starting on the first day
/// of the week on or before the 1st. Neighbouring days are included.
List<int> sixWeekGrid(int year, int month, FirstDayOfWeek first) {
  final start = weekStart(monthStart(year, month), first);
  return List<int>.generate(42, (i) => start + i);
}

int _floorDiv(int a, int b) => (a / b).floor();
int _floorMod(int a, int b) => ((a % b) + b) % b;

/// "Now" for the whole app. Read it through `clockProvider` so tests can pin
/// today to 18 Oct 2026 10:18 like the mockup.
class Clock {
  const Clock();

  /// A clock that always returns [time].
  const factory Clock.fixed(DateTime time) = _FixedClock;

  /// The current local time.
  DateTime now() => DateTime.now();

  /// Today's day number.
  int today() => dayFromDate(now());
}

class _FixedClock extends Clock {
  const _FixedClock(this.time);

  final DateTime time;

  @override
  DateTime now() => time;
}

/// The mockup's "today": Sunday, 18 Oct 2026, 10:18 (local).
final DateTime mockupNow = DateTime(2026, 10, 18, 10, 18);
