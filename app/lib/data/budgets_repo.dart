import 'package:drift/drift.dart';

import 'db.dart';

/// Category budgets: one monthly amount per category and pocket.
class BudgetsRepo {
  BudgetsRepo(this._db);

  final AppDatabase _db;

  $CategoryBudgetsTable get _t => _db.categoryBudgets;

  /// A pocket's budgets: category id -> monthly amount (minor units).
  Stream<Map<int, int>> watch(int pocketId) {
    final q = _db.select(_t)..where((b) => b.pocketId.equals(pocketId));
    return q.watch().map(
      (rows) => {for (final r in rows) r.categoryId: r.amount},
    );
  }

  /// A category's budget in a pocket, or null when it has none.
  Future<int?> get(int pocketId, int categoryId) async {
    final row = await (_db.select(_t)
          ..where((b) => b.pocketId.equals(pocketId) & b.categoryId.equals(categoryId)))
        .getSingleOrNull();
    return row?.amount;
  }

  /// Sets a category's monthly budget in a pocket. Null, zero or less
  /// removes it.
  Future<void> set(int pocketId, int categoryId, int? amount) async {
    if (amount == null || amount <= 0) {
      await (_db.delete(_t)
            ..where((b) => b.pocketId.equals(pocketId) & b.categoryId.equals(categoryId)))
          .go();
      return;
    }
    await _db.into(_t).insertOnConflictUpdate(
      CategoryBudgetsCompanion.insert(
        pocketId: pocketId,
        categoryId: categoryId,
        amount: amount,
      ),
    );
  }
}
