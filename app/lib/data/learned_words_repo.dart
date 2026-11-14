/// Type to add memory: which category a word belongs to. Shared by all
/// pockets. Words are stored trimmed and lower-case.
library;

import 'package:drift/drift.dart';

import '../core/days.dart';
import 'db.dart';

class LearnedWordsRepo {
  LearnedWordsRepo(this._db, {Clock clock = const Clock()}) : _clock = clock;

  final AppDatabase _db;
  final Clock _clock;

  $LearnedWordsTable get _t => _db.learnedWords;

  static String _key(String word) => word.trim().toLowerCase();

  /// Remembers that [word] goes to [categoryId] (replacing an older choice).
  Future<void> learn(String word, int categoryId) async {
    final key = _key(word);
    if (key.isEmpty) return;
    await _db.into(_t).insertOnConflictUpdate(
          LearnedWordsCompanion.insert(
            word: key,
            categoryId: categoryId,
            updatedAt: Value(_clock.now()),
          ),
        );
  }

  /// Remembers several words for one category.
  Future<void> learnAll(Iterable<String> words, int categoryId) {
    return _db.transaction(() async {
      for (final w in words) {
        await learn(w, categoryId);
      }
    });
  }

  /// The categories of the given words that were learned: word -> id.
  Future<Map<String, int>> lookup(Iterable<String> words) async {
    final keys = words.map(_key).where((w) => w.isNotEmpty).toSet().toList();
    if (keys.isEmpty) return const {};
    final rows = await (_db.select(_t)..where((w) => w.word.isIn(keys))).get();
    return {for (final r in rows) r.word: r.categoryId};
  }

  /// Every learned word: word -> category id (for the type to add parser).
  Stream<Map<String, int>> watchAll() => _db
      .select(_t)
      .watch()
      .map((rows) => {for (final r in rows) r.word: r.categoryId});

  /// Forgets one word.
  Future<void> forget(String word) async {
    await (_db.delete(_t)..where((w) => w.word.equals(_key(word)))).go();
  }

  /// Forgets every word of a category; returns how many.
  Future<int> forgetCategory(int categoryId) =>
      (_db.delete(_t)..where((w) => w.categoryId.equals(categoryId))).go();
}
