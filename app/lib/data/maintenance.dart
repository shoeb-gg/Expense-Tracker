/// "Delete all data" and "Clear cache".
library;

import 'dart:io';

import 'db.dart';
import 'expenses_repo.dart';
import 'photo_store.dart';

class DataMaintenance {
  /// [cacheDir] is the app's temporary folder (path_provider's
  /// getTemporaryDirectory in the app; a temp folder in tests).
  DataMaintenance(
    this._db, {
    required PhotoStore photos,
    required Future<Directory> Function() cacheDir,
  })  : _photos = photos,
        _cacheDir = cacheDir;

  final AppDatabase _db;
  final PhotoStore _photos;
  final Future<Directory> Function() _cacheDir;

  /// Wipes every pocket, expense, learned word, receipt photo and category,
  /// then re-creates the defaults (one empty "Personal" pocket and the 15
  /// categories). Settings such as the colour theme stay. Returns the id of
  /// the new default pocket (use `DataActions.deleteAllData`, which also
  /// switches the app to it).
  Future<int> deleteAllData() async {
    final pocketId = await _db.transaction(() async {
      await _db.delete(_db.expenses).go();
      await _db.delete(_db.learnedWords).go();
      await _db.delete(_db.categoryBudgets).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.pockets).go();
      return _db.seedDefaults();
    });
    await _photos.deleteAll();
    await clearCache();
    return pocketId;
  }

  /// Deletes temporary files only: everything in the app's cache folder
  /// (small copies of picked photos, old export files) and receipt photos no
  /// expense refers to any more. Every expense and its photo stay.
  /// Returns the bytes freed.
  Future<int> clearCache() async {
    var freed = 0;
    final dir = await _cacheDir();
    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        try {
          if (entity is File) {
            freed += entity.lengthSync();
            await entity.delete();
          } else if (entity is Directory) {
            freed += _sizeOf(entity);
            await entity.delete(recursive: true);
          }
        } on FileSystemException {
          // A file in use; skip it.
        }
      }
    }
    freed += await purgeOrphanPhotos();
    return freed;
  }

  /// Deletes receipt photos that no expense refers to (left behind by
  /// deleted expenses once Undo is no longer possible). Returns bytes freed.
  Future<int> purgeOrphanPhotos() async {
    final keep = await ExpensesRepo(_db).photoNames();
    return _photos.purgeExcept(keep);
  }

  static int _sizeOf(Directory dir) {
    var total = 0;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += entity.lengthSync();
        } on FileSystemException {
          // ignore
        }
      }
    }
    return total;
  }
}

/// "12.3 MB", "640 KB", "0 KB" (for the Clear cache message).
String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }
  return '${(bytes / 1024).round()} KB';
}
