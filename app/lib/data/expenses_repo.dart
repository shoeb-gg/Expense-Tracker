/// Expenses: add, edit, delete (with Undo), move, and the totals every
/// screen shows. All ranges are inclusive day numbers (see core/days.dart);
/// all amounts are minor units.
library;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../core/days.dart';
import 'db.dart';

/// Spending of one category in a range.
@immutable
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.total,
    required this.count,
  });

  final int categoryId;

  /// Minor units.
  final int total;

  /// Number of expenses.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is CategoryTotal &&
      other.categoryId == categoryId &&
      other.total == total &&
      other.count == count;

  @override
  int get hashCode => Object.hash(categoryId, total, count);

  @override
  String toString() => 'CategoryTotal($categoryId, $total, $count)';
}

/// Spending of one calendar month.
@immutable
class MonthTotal {
  const MonthTotal({
    required this.year,
    required this.month,
    required this.total,
    required this.count,
  });

  final int year;

  /// 1-12.
  final int month;

  /// Minor units.
  final int total;

  /// Number of expenses.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is MonthTotal &&
      other.year == year &&
      other.month == month &&
      other.total == total &&
      other.count == count;

  @override
  int get hashCode => Object.hash(year, month, total, count);

  @override
  String toString() => 'MonthTotal($year-$month, $total, $count)';
}

/// First and last day that has an expense (both null when there is none).
typedef DaySpan = ({int? first, int? last});

/// A new expense, for [ExpensesRepo.addAll] (import).
@immutable
class ExpenseDraft {
  const ExpenseDraft({
    required this.pocketId,
    required this.categoryId,
    required this.amount,
    required this.day,
    this.note = '',
    this.photoPath,
    this.createdAt,
  });

  final int pocketId;
  final int categoryId;
  final int amount;
  final int day;
  final String note;
  final String? photoPath;

  /// Defaults to now.
  final DateTime? createdAt;
}

class ExpensesRepo {
  ExpensesRepo(this._db, {Clock clock = const Clock()}) : _clock = clock;

  final AppDatabase _db;
  final Clock _clock;

  $ExpensesTable get _t => _db.expenses;

  // ---------------------------------------------------------------- writes

  /// Adds an expense and returns its id.
  Future<int> add({
    required int pocketId,
    required int categoryId,
    required int amount,
    required int day,
    String note = '',
    String? photoPath,
  }) {
    final now = _clock.now();
    return _db.into(_t).insert(
          ExpensesCompanion.insert(
            pocketId: pocketId,
            categoryId: categoryId,
            amount: amount,
            day: day,
            note: Value(note.trim()),
            photoPath: Value(photoPath),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Adds many expenses in one transaction (import). Returns their ids in
  /// order, so the import can be undone with [deleteMany].
  Future<List<int>> addAll(List<ExpenseDraft> drafts) {
    return _db.transaction(() async {
      final now = _clock.now();
      final ids = <int>[];
      for (final d in drafts) {
        ids.add(
          await _db.into(_t).insert(
                ExpensesCompanion.insert(
                  pocketId: d.pocketId,
                  categoryId: d.categoryId,
                  amount: d.amount,
                  day: d.day,
                  note: Value(d.note.trim()),
                  photoPath: Value(d.photoPath),
                  createdAt: Value(d.createdAt ?? now),
                  updatedAt: Value(now),
                ),
              ),
        );
      }
      return ids;
    });
  }

  /// Saves every field of [expense] (use `expense.copyWith(...)`) and bumps
  /// `updatedAt`. createdAt is kept.
  Future<void> update(Expense expense) async {
    await (_db.update(_t)..where((e) => e.id.equals(expense.id))).write(
      ExpensesCompanion(
        pocketId: Value(expense.pocketId),
        categoryId: Value(expense.categoryId),
        amount: Value(expense.amount),
        note: Value(expense.note.trim()),
        day: Value(expense.day),
        photoPath: Value(expense.photoPath),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  /// Deletes an expense and returns the deleted row, so Undo can put it back
  /// with [restore]. The receipt photo FILE is kept on purpose (Undo needs
  /// it); unreferenced photos are removed by `DataMaintenance.clearCache`
  /// and at app start.
  Future<Expense?> delete(int id) {
    return _db.transaction(() async {
      final row = await get(id);
      if (row == null) return null;
      await (_db.delete(_t)..where((e) => e.id.equals(id))).go();
      return row;
    });
  }

  /// Deletes several expenses (Undo of an import). Returns how many.
  Future<int> deleteMany(Iterable<int> ids) {
    final list = ids.toList();
    if (list.isEmpty) return Future.value(0);
    return (_db.delete(_t)..where((e) => e.id.isIn(list))).go();
  }

  /// Puts a deleted expense back with the same id and all its fields.
  Future<void> restore(Expense expense) async {
    await _db.into(_t).insert(expense, mode: InsertMode.insertOrReplace);
  }

  /// Moves an expense to another pocket.
  Future<void> moveToPocket(int id, int pocketId) async {
    await (_db.update(_t)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        pocketId: Value(pocketId),
        updatedAt: Value(_clock.now()),
      ),
    );
  }

  // ----------------------------------------------------------------- reads

  /// One expense, or null.
  Future<Expense?> get(int id) =>
      (_db.select(_t)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// One expense as it changes (null once deleted).
  Stream<Expense?> watch(int id) =>
      (_db.select(_t)..where((e) => e.id.equals(id))).watchSingleOrNull();

  SimpleSelectStatement<$ExpensesTable, Expense> _range(
    int pocketId,
    int from,
    int to, {
    int? categoryId,
  }) {
    return _db.select(_t)
      ..where(
        (e) =>
            e.pocketId.equals(pocketId) &
            e.day.isBetweenValues(from, to) &
            (categoryId == null
                ? const Constant(true)
                : e.categoryId.equals(categoryId)),
      )
      ..orderBy([
        (e) => OrderingTerm.desc(e.day),
        (e) => OrderingTerm.desc(e.createdAt),
        (e) => OrderingTerm.desc(e.id),
      ]);
  }

  /// Expenses of a pocket between [from] and [to] (inclusive), newest day
  /// first, and within a day the most recently added first. Optionally only
  /// one category.
  Stream<List<Expense>> watchRange(
    int pocketId,
    int from,
    int to, {
    int? categoryId,
  }) =>
      _range(pocketId, from, to, categoryId: categoryId).watch();

  /// Same as [watchRange], once (export).
  Future<List<Expense>> listRange(
    int pocketId,
    int from,
    int to, {
    int? categoryId,
  }) =>
      _range(pocketId, from, to, categoryId: categoryId).get();

  Expression<bool> _inRange(int pocketId, int from, int to) =>
      _t.pocketId.equals(pocketId) & _t.day.isBetweenValues(from, to);

  /// Total per day (only days that have expenses): day -> minor units.
  Stream<Map<int, int>> watchDayTotals(int pocketId, int from, int to) {
    final total = _t.amount.sum();
    final q = _db.selectOnly(_t)
      ..addColumns([_t.day, total])
      ..where(_inRange(pocketId, from, to))
      ..groupBy([_t.day]);
    return q.watch().map(
          (rows) => {
            for (final r in rows) r.read(_t.day)!: r.read(total) ?? 0,
          },
        );
  }

  /// Total per category, biggest first.
  Stream<List<CategoryTotal>> watchCategoryTotals(
    int pocketId,
    int from,
    int to,
  ) {
    final total = _t.amount.sum();
    final n = _t.id.count();
    final q = _db.selectOnly(_t)
      ..addColumns([_t.categoryId, total, n])
      ..where(_inRange(pocketId, from, to))
      ..groupBy([_t.categoryId])
      ..orderBy([OrderingTerm.desc(total)]);
    return q.watch().map(
          (rows) => [
            for (final r in rows)
              CategoryTotal(
                categoryId: r.read(_t.categoryId)!,
                total: r.read(total) ?? 0,
                count: r.read(n) ?? 0,
              ),
          ],
        );
  }

  /// Total per calendar month (only months that have expenses), oldest
  /// first.
  Stream<List<MonthTotal>> watchMonthTotals(int pocketId, int from, int to) {
    return _db
        .customSelect(
          "SELECT CAST(strftime('%Y', day * 86400, 'unixepoch') AS INTEGER) AS y, "
          "CAST(strftime('%m', day * 86400, 'unixepoch') AS INTEGER) AS m, "
          'SUM(amount) AS total, COUNT(*) AS n '
          'FROM expenses WHERE pocket_id = ? AND day BETWEEN ? AND ? '
          'GROUP BY y, m ORDER BY y, m',
          variables: [
            Variable.withInt(pocketId),
            Variable.withInt(from),
            Variable.withInt(to),
          ],
          readsFrom: {_t},
        )
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              MonthTotal(
                year: r.read<int>('y'),
                month: r.read<int>('m'),
                total: r.read<int>('total'),
                count: r.read<int>('n'),
              ),
          ],
        );
  }

  /// Total of a range.
  Stream<int> watchTotal(int pocketId, int from, int to) {
    final total = _t.amount.sum();
    final q = _db.selectOnly(_t)
      ..addColumns([total])
      ..where(_inRange(pocketId, from, to));
    return q.watchSingle().map((r) => r.read(total) ?? 0);
  }

  /// All-time total of a pocket.
  Stream<int> watchAllTimeTotal(int pocketId) {
    final total = _t.amount.sum();
    final q = _db.selectOnly(_t)
      ..addColumns([total])
      ..where(_t.pocketId.equals(pocketId));
    return q.watchSingle().map((r) => r.read(total) ?? 0);
  }

  /// First and last day that has an expense in the pocket.
  Stream<DaySpan> watchDaySpan(int pocketId) {
    final first = _t.day.min();
    final last = _t.day.max();
    final q = _db.selectOnly(_t)
      ..addColumns([first, last])
      ..where(_t.pocketId.equals(pocketId));
    return q.watchSingle().map(
          (r) => (first: r.read(first), last: r.read(last)),
        );
  }

  JoinedSelectStatement<$ExpensesTable, Expense> _countQuery(
    Expression<int> n,
    int pocketId,
    int? from,
    int? to,
  ) {
    return _db.selectOnly(_t)
      ..addColumns([n])
      ..where(
        from == null || to == null
            ? _t.pocketId.equals(pocketId)
            : _inRange(pocketId, from, to),
      );
  }

  /// Number of expenses in a pocket (optionally in a range).
  Stream<int> watchCount(int pocketId, {int? from, int? to}) {
    final n = _t.id.count();
    return _countQuery(n, pocketId, from, to)
        .watchSingle()
        .map((r) => r.read(n) ?? 0);
  }

  /// Number of expenses in a pocket (optionally in a range), once.
  Future<int> count(int pocketId, {int? from, int? to}) async {
    final n = _t.id.count();
    final r = await _countQuery(n, pocketId, from, to).getSingle();
    return r.read(n) ?? 0;
  }

  /// Total per pocket in a range (the "Your pockets" panel shows this
  /// month's): pocketId -> minor units (pockets without expenses missing).
  Stream<Map<int, int>> watchPocketTotals(int from, int to) {
    final total = _t.amount.sum();
    final q = _db.selectOnly(_t)
      ..addColumns([_t.pocketId, total])
      ..where(_t.day.isBetweenValues(from, to))
      ..groupBy([_t.pocketId]);
    return q.watch().map(
          (rows) => {
            for (final r in rows) r.read(_t.pocketId)!: r.read(total) ?? 0,
          },
        );
  }

  /// Whether an expense with the same date, amount, category and title is
  /// already in the pocket (import skips these).
  Future<bool> exists({
    required int pocketId,
    required int day,
    required int amount,
    required int categoryId,
    required String note,
  }) async {
    final n = _t.id.count();
    final q = _db.selectOnly(_t)
      ..addColumns([n])
      ..where(
        _t.pocketId.equals(pocketId) &
            _t.day.equals(day) &
            _t.amount.equals(amount) &
            _t.categoryId.equals(categoryId) &
            _t.note.equals(note.trim()),
      );
    final r = await q.getSingle();
    return (r.read(n) ?? 0) > 0;
  }

  /// File names of every receipt photo still referenced by an expense.
  Future<Set<String>> photoNames() async {
    final q = _db.selectOnly(_t)
      ..addColumns([_t.photoPath])
      ..where(_t.photoPath.isNotNull());
    final rows = await q.get();
    return {for (final r in rows) r.read(_t.photoPath)!};
  }
}
