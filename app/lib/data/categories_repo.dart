/// Categories: one list for the whole app (all pockets).
library;

import 'package:drift/drift.dart';

import '../core/days.dart';
import 'db.dart';

class CategoriesRepo {
  CategoriesRepo(this._db, {Clock clock = const Clock()}) : _clock = clock;

  final AppDatabase _db;
  final Clock _clock;

  $CategoriesTable get _t => _db.categories;

  SimpleSelectStatement<$CategoriesTable, ExpenseCategory> _ordered() =>
      _db.select(_t)
        ..orderBy([
          (c) => OrderingTerm.asc(c.sortOrder),
          (c) => OrderingTerm.asc(c.id),
        ]);

  /// Every category in the user's order.
  Stream<List<ExpenseCategory>> watchAll() => _ordered().watch();

  /// Every category in the user's order, once.
  Future<List<ExpenseCategory>> all() => _ordered().get();

  /// One category, or null.
  Future<ExpenseCategory?> get(int id) =>
      (_db.select(_t)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Miscellaneous (always exists).
  Future<ExpenseCategory> misc() async {
    final row = await (_db.select(_t)
          ..where((c) => c.isMisc.equals(true))
          ..limit(1))
        .getSingleOrNull();
    if (row != null) return row;
    // Should never happen; recreate it rather than fail.
    final fallback = defaultCategories.firstWhere(
      (d) => d.name == miscCategoryName,
    );
    final id = await add(
      name: fallback.name,
      emoji: fallback.emoji,
      color: fallback.color.argb,
      isMisc: true,
    );
    return (await get(id))!;
  }

  /// A category whose name matches [name] ignoring case and outer spaces.
  Future<ExpenseCategory?> findByName(String name) async {
    final key = name.trim().toLowerCase();
    final list = await all();
    for (final c in list) {
      if (c.name.trim().toLowerCase() == key) return c;
    }
    return null;
  }

  /// Whether another category already uses [name] (ignoring case).
  Future<bool> nameExists(String name, {int? exceptId}) async {
    final found = await findByName(name);
    return found != null && found.id != exceptId;
  }

  /// Adds a category and returns its id. It goes to the end of the list,
  /// just before Miscellaneous when Miscellaneous is last.
  Future<int> add({
    required String name,
    required String emoji,
    required int color,
    bool isMisc = false,
  }) {
    return _db.transaction(() async {
      final list = await all();
      var order = list.isEmpty ? 0 : list.last.sortOrder + 1;
      if (!isMisc && list.isNotEmpty && list.last.isMisc) {
        order = list.last.sortOrder;
        await (_db.update(_t)..where((c) => c.id.equals(list.last.id)))
            .write(CategoriesCompanion(sortOrder: Value(order + 1)));
      }
      return _db.into(_t).insert(
            CategoriesCompanion.insert(
              name: name.trim(),
              emoji: emoji,
              color: color,
              sortOrder: Value(order),
              isMisc: Value(isMisc),
              createdAt: Value(_clock.now()),
            ),
          );
    });
  }

  /// Saves name, emoji and colour of [category].
  Future<void> update(ExpenseCategory category) async {
    await (_db.update(_t)..where((c) => c.id.equals(category.id))).write(
      CategoriesCompanion(
        name: Value(category.name.trim()),
        emoji: Value(category.emoji),
        color: Value(category.color),
      ),
    );
  }

  /// Saves a new order: [ids] from first to last.
  Future<void> reorder(List<int> ids) {
    return _db.batch((b) {
      for (var i = 0; i < ids.length; i++) {
        b.update(
          _t,
          CategoriesCompanion(sortOrder: Value(i)),
          where: (c) => c.id.equals(ids[i]),
        );
      }
    });
  }

  /// Deletes a category. Its expenses in EVERY pocket move to
  /// Miscellaneous; returns how many moved. The words type to add learned
  /// for it are forgotten (so the next time the app asks again instead of
  /// quietly filing them under Miscellaneous), and so are its budgets.
  /// Throws a [StateError] for Miscellaneous.
  Future<int> delete(int id) {
    return _db.transaction(() async {
      final target = await get(id);
      if (target == null) return 0;
      if (target.isMisc) {
        throw StateError('Miscellaneous cannot be deleted');
      }
      final misc = await this.misc();
      final moved = await (_db.update(_db.expenses)
            ..where((e) => e.categoryId.equals(id)))
          .write(
        ExpensesCompanion(
          categoryId: Value(misc.id),
          updatedAt: Value(_clock.now()),
        ),
      );
      await (_db.delete(_db.learnedWords)
            ..where((w) => w.categoryId.equals(id)))
          .go();
      await (_db.delete(_db.categoryBudgets)..where((b) => b.categoryId.equals(id))).go();
      await (_db.delete(_t)..where((c) => c.id.equals(id))).go();
      return moved;
    });
  }

  /// Number of expenses in a category, across all pockets.
  Future<int> countExpenses(int categoryId) async {
    final e = _db.expenses;
    final n = e.id.count();
    final q = _db.selectOnly(e)
      ..addColumns([n])
      ..where(e.categoryId.equals(categoryId));
    final r = await q.getSingle();
    return r.read(n) ?? 0;
  }

  /// Expenses per category across all pockets: categoryId -> count
  /// (categories without expenses are missing).
  Stream<Map<int, int>> watchExpenseCounts() {
    final e = _db.expenses;
    final n = e.id.count();
    final q = _db.selectOnly(e)
      ..addColumns([e.categoryId, n])
      ..groupBy([e.categoryId]);
    return q.watch().map(
          (rows) => {
            for (final r in rows) r.read(e.categoryId)!: r.read(n) ?? 0,
          },
        );
  }
}
