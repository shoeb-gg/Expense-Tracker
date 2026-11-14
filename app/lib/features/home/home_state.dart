import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/days.dart';
import '../../data/db.dart';
import '../../state/providers.dart';

/// The month Home shows. Null means "the month of today", so Home follows
/// the clock until the user picks or swipes to another month.
///
/// Other screens may set it too: Add expense's "save and jump to that month"
/// calls `ref.read(homeMonthProvider.notifier).showDay(day)`.
class HomeMonthNotifier extends Notifier<YearMonth?> {
  @override
  YearMonth? build() => null;

  /// Shows [month] on Home.
  void show(YearMonth month) => state = month;

  /// Shows the month that holds [day].
  void showDay(int day) => state = yearMonthOfDay(day);
}

final homeMonthProvider = NotifierProvider<HomeMonthNotifier, YearMonth?>(
  HomeMonthNotifier.new,
);

/// The month on screen: the chosen one, else the month of today.
final homeShownMonthProvider = Provider<YearMonth>(
  (ref) =>
      ref.watch(homeMonthProvider) ?? yearMonthOfDay(ref.watch(todayProvider)),
);

/// The month [delta] months away from [month] (-1 = previous, 1 = next).
YearMonth stepMonth(YearMonth month, int delta) =>
    addMonths(month.year, month.month, delta);

/// A month as one ordinal number, for comparing months.
int monthIndex(YearMonth month) => month.year * 12 + month.month - 1;

/// Whether the Home total is masked right now. It starts as the "Privacy
/// hide" setting and the eye button flips it for this session only.
class HomeTotalHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(settingsProvider.select((s) => s.privacyMask));

  void toggle() => state = !state;
}

final homeTotalHiddenProvider = NotifierProvider<HomeTotalHiddenNotifier, bool>(
  HomeTotalHiddenNotifier.new,
);

/// What a masked amount reads: six bullets, as on the mockup.
const String maskedAmount = '••••••';

/// One day card on Home: the day, its total and its expenses (newest first).
class DayGroup {
  const DayGroup({
    required this.day,
    required this.total,
    required this.expenses,
  });

  final int day;
  final int total;
  final List<Expense> expenses;
}

/// Groups [expenses] into day cards: newest day first, and inside a day the
/// latest added first (then the higher id), whatever order they came in.
List<DayGroup> groupByDay(List<Expense> expenses) {
  final sorted = [...expenses]
    ..sort((a, b) {
      final byDay = b.day.compareTo(a.day);
      if (byDay != 0) return byDay;
      final byTime = b.createdAt.compareTo(a.createdAt);
      if (byTime != 0) return byTime;
      return b.id.compareTo(a.id);
    });
  final groups = <DayGroup>[];
  var start = 0;
  while (start < sorted.length) {
    final day = sorted[start].day;
    var end = start;
    var total = 0;
    while (end < sorted.length && sorted[end].day == day) {
      total += sorted[end].amount;
      end++;
    }
    groups.add(
      DayGroup(
        day: day,
        total: total,
        expenses: List.unmodifiable(sorted.sublist(start, end)),
      ),
    );
    start = end;
  }
  return groups;
}

/// Sum of [expenses] in minor units.
int totalOf(List<Expense> expenses) =>
    expenses.fold(0, (sum, e) => sum + e.amount);
