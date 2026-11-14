/// Raw key/value access to the SettingsEntries table. Screens use
/// `settingsProvider` (state/settings.dart) instead.
library;

import 'db.dart';

class SettingsStore {
  SettingsStore(this._db);

  final AppDatabase _db;

  /// Every stored setting: key -> value.
  Future<Map<String, String>> load() async {
    final rows = await _db.select(_db.settingsEntries).get();
    return {for (final r in rows) r.key: r.value};
  }

  /// Stores one setting.
  Future<void> write(String key, String value) async {
    await _db.into(_db.settingsEntries).insertOnConflictUpdate(
          SettingsEntriesCompanion.insert(key: key, value: value),
        );
  }

  /// Removes one setting (it falls back to its default).
  Future<void> remove(String key) async {
    await (_db.delete(_db.settingsEntries)..where((s) => s.key.equals(key)))
        .go();
  }
}
