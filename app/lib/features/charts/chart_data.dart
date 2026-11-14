import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// One day's spending in one category (amount in minor units).
typedef DaySpend = ({int day, int categoryId, int amount});

/// A category's spending in a range (amount in minor units).
typedef CategorySpend = ({int categoryId, int amount});

/// A day's spending (amount in minor units).
typedef DayTotal = ({int day, int amount});

/// The spending of one pocket per day and category, kept in memory so the
/// Charts and Calendar screens can sum any range at once (switching a period
/// or a month never waits for the database).
@immutable
class SpendIndex {
  /// [rows] must be ordered by day, oldest first; rows of the same day in the
  /// order their categories were first used that day.
  SpendIndex(List<DaySpend> rows)
      : _rows = List.unmodifiable(rows),
        _rowDays = List.unmodifiable([for (final r in rows) r.day]) {
    for (final r in _rows) {
      if (_days.isEmpty || _days.last != r.day) {
        _days.add(r.day);
        _dayTotals.add(0);
      }
      _dayTotals[_dayTotals.length - 1] += r.amount;
    }
    var acc = 0;
    _cumulative.add(0);
    for (final t in _dayTotals) {
      acc += t;
      _cumulative.add(acc);
    }
  }

  /// No spending at all.
  static final SpendIndex empty = SpendIndex(const []);

  final List<DaySpend> _rows;
  final List<int> _rowDays;
  final List<int> _days = [];
  final List<int> _dayTotals = [];
  final List<int> _cumulative = [];

  /// True when the pocket has no expenses.
  bool get isEmpty => _days.isEmpty;

  /// First day with an expense (null when there are none).
  int? get firstDay => _days.isEmpty ? null : _days.first;

  /// Last day with an expense (null when there are none).
  int? get lastDay => _days.isEmpty ? null : _days.last;

  /// Index of the first entry in [list] that is >= [day].
  static int _lowerBound(List<int> list, int day) {
    var lo = 0;
    var hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid] < day) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Total spent on [day].
  int dayTotal(int day) {
    final i = _lowerBound(_days, day);
    return i < _days.length && _days[i] == day ? _dayTotals[i] : 0;
  }

  /// Total spent from [from] to [to] (inclusive). 0 when [to] < [from].
  int sum(int from, int to) {
    if (to < from) return 0;
    final a = _lowerBound(_days, from);
    final b = _lowerBound(_days, to + 1);
    return _cumulative[b] - _cumulative[a];
  }

  /// Day -> total for the days from [from] to [to] that have spending.
  Map<int, int> dayTotals(int from, int to) {
    final out = <int, int>{};
    if (to < from) return out;
    for (var i = _lowerBound(_days, from);
        i < _days.length && _days[i] <= to;
        i++) {
      out[_days[i]] = _dayTotals[i];
    }
    return out;
  }

  /// Totals per category from [from] to [to], biggest first. Ties keep the
  /// order in which the categories were first used in the range.
  List<CategorySpend> byCategory(int from, int to) {
    final totals = <int, int>{};
    if (to >= from) {
      for (var i = _lowerBound(_rowDays, from);
          i < _rows.length && _rows[i].day <= to;
          i++) {
        final r = _rows[i];
        totals[r.categoryId] = (totals[r.categoryId] ?? 0) + r.amount;
      }
    }
    final order = totals.keys.toList();
    final list = [
      for (var i = 0; i < order.length; i++)
        (index: i, categoryId: order[i], amount: totals[order[i]]!),
    ]..sort((p, q) =>
        p.amount != q.amount ? q.amount - p.amount : p.index - q.index);
    return [
      for (final e in list) (categoryId: e.categoryId, amount: e.amount),
    ];
  }

  /// Days from [from] to [to] that have spending, biggest first (ties: the
  /// earlier day first).
  List<DayTotal> topDays(int from, int to) {
    final list = [
      for (final e in dayTotals(from, to).entries)
        if (e.value > 0) (day: e.key, amount: e.value),
    ]..sort((p, q) =>
        p.amount != q.amount ? q.amount - p.amount : p.day - q.day);
    return list;
  }
}

/// Spending of a pocket per day and category (key: pocket id). Shared by
/// Charts and Calendar.
final spendIndexProvider =
    StreamProvider.autoDispose.family<SpendIndex, int>((ref, pocketId) {
  final db = ref.watch(databaseProvider);
  final e = db.expenses;
  final total = e.amount.sum();
  final firstId = e.id.min();
  final query = db.selectOnly(e)
    ..addColumns([e.day, e.categoryId, total, firstId])
    ..where(e.pocketId.equals(pocketId))
    ..groupBy([e.day, e.categoryId])
    ..orderBy([
      OrderingTerm.asc(e.day),
      OrderingTerm.asc(firstId),
    ]);
  return query.watch().map(
        (rows) => SpendIndex([
          for (final r in rows)
            (
              day: r.read(e.day)!,
              categoryId: r.read(e.categoryId)!,
              amount: r.read(total) ?? 0,
            ),
        ]),
      );
});
