/// Pockets: separate books of expenses. There is always one default pocket.
library;

import 'package:drift/drift.dart';

import '../core/days.dart';
import 'db.dart';
import 'photo_store.dart';

class PocketsRepo {
  PocketsRepo(this._db, {PhotoStore? photos, Clock clock = const Clock()})
      : _photos = photos,
        _clock = clock;

  final AppDatabase _db;
  final PhotoStore? _photos;
  final Clock _clock;

  $PocketsTable get _t => _db.pockets;

  SimpleSelectStatement<$PocketsTable, Pocket> _ordered() => _db.select(_t)
    ..orderBy([
      (p) => OrderingTerm.asc(p.sortOrder),
      (p) => OrderingTerm.asc(p.id),
    ]);

  /// Every pocket in the user's order.
  Stream<List<Pocket>> watchAll() => _ordered().watch();

  /// Every pocket in the user's order, once.
  Future<List<Pocket>> all() => _ordered().get();

  /// One pocket, or null.
  Future<Pocket?> get(int id) =>
      (_db.select(_t)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// The default pocket (always exists after the database is created).
  Future<Pocket> defaultPocket() async {
    final row = await (_db.select(_t)
          ..where((p) => p.isDefault.equals(true))
          ..limit(1))
        .getSingleOrNull();
    if (row != null) return row;
    final list = await all();
    if (list.isNotEmpty) return list.first;
    final id = await _db.seedDefaultPocketOnly(_clock.now());
    return (await get(id))!;
  }

  /// Whether another pocket already uses [name] (ignoring case). Two
  /// pockets cannot have the same name.
  Future<bool> nameExists(String name, {int? exceptId}) async {
    final key = name.trim().toLowerCase();
    for (final p in await all()) {
      if (p.id != exceptId && p.name.trim().toLowerCase() == key) return true;
    }
    return false;
  }

  /// Adds a pocket at the end and returns its id.
  Future<int> add({required String name, required String emoji}) {
    return _db.transaction(() async {
      final list = await all();
      final order = list.isEmpty ? 0 : list.last.sortOrder + 1;
      return _db.into(_t).insert(
            PocketsCompanion.insert(
              name: name.trim(),
              emoji: emoji,
              sortOrder: Value(order),
              createdAt: Value(_clock.now()),
            ),
          );
    });
  }

  /// Saves name and emoji of [pocket].
  Future<void> update(Pocket pocket) async {
    await (_db.update(_t)..where((p) => p.id.equals(pocket.id))).write(
      PocketsCompanion(
        name: Value(pocket.name.trim()),
        emoji: Value(pocket.emoji),
      ),
    );
  }

  /// Saves a new order: [ids] from first to last.
  Future<void> reorder(List<int> ids) {
    return _db.batch((b) {
      for (var i = 0; i < ids.length; i++) {
        b.update(
          _t,
          PocketsCompanion(sortOrder: Value(i)),
          where: (p) => p.id.equals(ids[i]),
        );
      }
    });
  }

  /// Deletes a pocket with all its expenses and their receipt photos.
  /// Returns how many expenses were deleted. Throws a [StateError] for the
  /// default pocket. (If it was the pocket in use, the app falls back to the
  /// default pocket by itself; see `currentPocketProvider`.)
  Future<int> delete(int id) async {
    final photoNames = <String>[];
    final deleted = await _db.transaction(() async {
      final target = await get(id);
      if (target == null) return 0;
      if (target.isDefault) {
        throw StateError('The default pocket cannot be deleted');
      }
      final e = _db.expenses;
      final withPhotos = await (_db.select(e)
            ..where((x) => x.pocketId.equals(id) & x.photoPath.isNotNull()))
          .get();
      photoNames.addAll(withPhotos.map((x) => x.photoPath!));
      final n = await (_db.delete(e)..where((x) => x.pocketId.equals(id))).go();
      await (_db.delete(_t)..where((p) => p.id.equals(id))).go();
      return n;
    });
    final photos = _photos;
    if (photos != null) {
      for (final name in photoNames) {
        await photos.delete(name);
      }
    }
    return deleted;
  }

  /// Number of expenses in a pocket.
  Future<int> countExpenses(int pocketId) async {
    final e = _db.expenses;
    final n = e.id.count();
    final q = _db.selectOnly(e)
      ..addColumns([n])
      ..where(e.pocketId.equals(pocketId));
    final r = await q.getSingle();
    return r.read(n) ?? 0;
  }

  /// Expenses per pocket: pocketId -> count (empty pockets are missing).
  Stream<Map<int, int>> watchExpenseCounts() {
    final e = _db.expenses;
    final n = e.id.count();
    final q = _db.selectOnly(e)
      ..addColumns([e.pocketId, n])
      ..groupBy([e.pocketId]);
    return q.watch().map(
          (rows) => {
            for (final r in rows) r.read(e.pocketId)!: r.read(n) ?? 0,
          },
        );
  }
}
