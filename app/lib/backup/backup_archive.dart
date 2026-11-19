/// A backup file: one zip holding a snapshot of the whole database, the
/// receipt photos the expenses use, and a short manifest.
///
/// ```
/// manifest.json         what is inside (see [BackupManifest])
/// data.sqlite           the database, every pocket, expense, category,
///                       budget, learned word and setting
/// photos/<name>.jpg     the receipt photos
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/db.dart';

/// Thrown for a file that is not a backup this app can restore.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  /// Plain words for the user.
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// The summary at the root of a backup.
@immutable
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.schema,
    required this.createdAt,
    required this.expenses,
    required this.pockets,
    required this.photos,
  });

  /// The layout of the zip this app writes. A later app may write a higher
  /// one; this app refuses those.
  static const int currentFormat = 1;

  final int format;

  /// The database schema version inside.
  final int schema;
  final DateTime createdAt;
  final int expenses;
  final int pockets;
  final int photos;

  Map<String, Object> toJson() => {
    'format': format,
    'schema': schema,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expenses': expenses,
    'pockets': pockets,
    'photos': photos,
  };

  /// Reads a manifest; throws [BackupFormatException] when it is not one.
  factory BackupManifest.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const BackupFormatException('This is not a Spill the Bills backup.');
    }
    int number(String key) {
      final v = json[key];
      if (v is int) return v;
      throw const BackupFormatException('This backup is damaged.');
    }

    final created = DateTime.tryParse(json['createdAt'] is String ? json['createdAt']! as String : '');
    if (created == null) throw const BackupFormatException('This backup is damaged.');
    return BackupManifest(
      format: number('format'),
      schema: number('schema'),
      createdAt: created.toLocal(),
      expenses: number('expenses'),
      pockets: number('pockets'),
      photos: number('photos'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BackupManifest &&
      other.format == format &&
      other.schema == schema &&
      other.createdAt.isAtSameMomentAs(createdAt) &&
      other.expenses == expenses &&
      other.pockets == pockets &&
      other.photos == photos;

  @override
  int get hashCode => Object.hash(format, schema, createdAt.millisecondsSinceEpoch, expenses, pockets, photos);
}

const String _manifestName = 'manifest.json';
const String _dataName = 'data.sqlite';
const String _photosDir = 'photos';

/// A photo file name the app writes ("r_1760782680000_4821.jpg"): letters,
/// digits, "_", "-" and ".", nothing that could climb out of a folder.
final RegExp _safeName = RegExp(r'^[A-Za-z0-9_\-]+\.[A-Za-z0-9]+$');

/// Writes a backup of [db] and the photos in [photosDir] that expenses use
/// to [target] (a .zip), and returns its manifest. [work] is a scratch
/// folder for the database snapshot.
Future<BackupManifest> writeBackup({
  required AppDatabase db,
  required Directory photosDir,
  required Directory work,
  required File target,
  required DateTime now,
}) async {
  if (!work.existsSync()) await work.create(recursive: true);
  final snapshot = File(p.join(work.path, 'snapshot.sqlite'));
  if (snapshot.existsSync()) await snapshot.delete();
  // A consistent copy of the live database, written by SQLite itself.
  await db.customStatement('VACUUM INTO ?', [snapshot.path]);

  final expenses = await _count(db, 'expenses');
  final pockets = await _count(db, 'pockets');
  final names = await db
      .customSelect('SELECT DISTINCT photo_path AS name FROM expenses WHERE photo_path IS NOT NULL')
      .map((r) => r.read<String>('name'))
      .get();
  final photos = [
    for (final name in names)
      if (_safeName.hasMatch(name) && File(p.join(photosDir.path, name)).existsSync())
        File(p.join(photosDir.path, name)),
  ];

  final manifest = BackupManifest(
    format: BackupManifest.currentFormat,
    schema: db.schemaVersion,
    createdAt: now,
    expenses: expenses,
    pockets: pockets,
    photos: photos.length,
  );

  if (target.existsSync()) await target.delete();
  final zip = ZipFileEncoder()..create(target.path);
  try {
    final json = utf8.encode(jsonEncode(manifest.toJson()));
    zip.addArchiveFile(ArchiveFile(_manifestName, json.length, json));
    await zip.addFile(snapshot, _dataName);
    // JPEGs are already compressed: store them as they are.
    for (final photo in photos) {
      await zip.addFile(photo, '$_photosDir/${p.basename(photo.path)}', 0);
    }
  } finally {
    await zip.close();
    if (snapshot.existsSync()) await snapshot.delete();
  }
  return manifest;
}

Future<int> _count(AppDatabase db, String table) => db
    .customSelect('SELECT COUNT(*) AS n FROM $table')
    .map((r) => r.read<int>('n'))
    .getSingle();

/// What [readBackup] unpacked.
@immutable
class UnpackedBackup {
  const UnpackedBackup({required this.manifest, required this.database, required this.photos});

  final BackupManifest manifest;

  /// The database file, ready for [restoreDatabase].
  final File database;

  /// The receipt photos.
  final List<File> photos;
}

/// Unpacks the backup [zip] into the empty folder [into] and checks it.
/// Throws [BackupFormatException] for a file this app cannot restore:
/// not a backup, damaged, or made by a newer version of the app.
Future<UnpackedBackup> readBackup(File zip, Directory into, {required int appSchema}) async {
  final InputFileStream input;
  try {
    input = InputFileStream(zip.path);
  } on Object {
    throw const BackupFormatException('This backup is damaged.');
  }
  try {
    return await _unpack(input, into, appSchema: appSchema);
  } finally {
    await input.close();
  }
}

Future<UnpackedBackup> _unpack(InputFileStream input, Directory into, {required int appSchema}) async {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBuffer(input);
  } on Object {
    throw const BackupFormatException('This backup is damaged.');
  }
  ArchiveFile? find(String name) {
    for (final f in archive.files) {
      if (f.isFile && f.name == name) return f;
    }
    return null;
  }

  final manifestFile = find(_manifestName);
  final dataFile = find(_dataName);
  if (manifestFile == null || dataFile == null) {
    throw const BackupFormatException('This is not a Spill the Bills backup.');
  }
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(manifestFile.content as List<int>));
  } on FormatException {
    throw const BackupFormatException('This backup is damaged.');
  }
  final manifest = BackupManifest.fromJson(json);
  if (manifest.format > BackupManifest.currentFormat || manifest.schema > appSchema) {
    throw const BackupFormatException(
      'This backup was made by a newer version of the app. Update the app first.',
    );
  }
  if (manifest.schema < 1) throw const BackupFormatException('This backup is damaged.');

  if (!into.existsSync()) await into.create(recursive: true);
  final database = File(p.join(into.path, _dataName));
  await database.writeAsBytes(dataFile.content as List<int>, flush: true);
  final header = await database.openRead(0, 16).fold<List<int>>(<int>[], (a, b) => a..addAll(b));
  if (!listEquals(header, utf8.encode('SQLite format 3\u0000'))) {
    throw const BackupFormatException('This backup is damaged.');
  }

  final photosDir = Directory(p.join(into.path, _photosDir));
  await photosDir.create(recursive: true);
  final photos = <File>[];
  for (final f in archive.files) {
    if (!f.isFile || !f.name.startsWith('$_photosDir/')) continue;
    final name = f.name.substring(_photosDir.length + 1);
    if (!_safeName.hasMatch(name)) continue;
    final out = File(p.join(photosDir.path, name));
    await out.writeAsBytes(f.content as List<int>, flush: true);
    photos.add(out);
  }
  await archive.clear();
  return UnpackedBackup(manifest: manifest, database: database, photos: photos);
}

/// Brings an unpacked backup database up to this app's schema (a backup
/// from an older version gets the same upgrades the phone's own database
/// got). Throws when the file is not a database the app can open.
Future<void> upgradeBackupDatabase(File database) async {
  final db = AppDatabase.withExecutor(NativeDatabase(database));
  try {
    await db.customSelect('SELECT 1').get();
  } on Object {
    throw const BackupFormatException('This backup is damaged.');
  } finally {
    await db.close();
  }
}

/// The tables a restore copies, parents before children.
const List<String> _tables = [
  'pockets',
  'categories',
  'expenses',
  'learned_words',
  'category_budgets',
  'settings_entries',
];

/// Settings that belong to this phone, not to the data: the backup's own
/// state (which Google account, when it last ran). A restore keeps these.
const String deviceSettingPrefix = 'backup.';

/// Replaces everything in [live] with the database in [backup] (already
/// upgraded to the app's schema by [upgradeBackupDatabase]), in one
/// transaction: if anything fails, nothing changes. Settings that start with
/// [deviceSettingPrefix] stay as they are on this phone.
Future<void> restoreDatabase(AppDatabase live, File backup) async {
  await live.customStatement('ATTACH DATABASE ? AS restore_src', [backup.path]);
  try {
    final columns = <String, String>{};
    for (final table in _tables) {
      final names = await live
          .customSelect('SELECT name FROM pragma_table_info(?)', variables: [Variable<String>(table)])
          .map((r) => '"${r.read<String>('name')}"')
          .get();
      columns[table] = names.join(', ');
    }
    await live.transaction(() async {
      for (final table in _tables.reversed) {
        if (table == 'settings_entries') {
          await live.customStatement(
            "DELETE FROM main.settings_entries WHERE key NOT LIKE '$deviceSettingPrefix%'",
          );
        } else {
          await live.customStatement('DELETE FROM main.$table');
        }
      }
      for (final table in _tables) {
        final cols = columns[table]!;
        final where = table == 'settings_entries' ? " WHERE key NOT LIKE '$deviceSettingPrefix%'" : '';
        await live.customStatement(
          'INSERT INTO main.$table ($cols) SELECT $cols FROM restore_src.$table$where',
        );
      }
    });
  } finally {
    await live.customStatement('DETACH DATABASE restore_src');
  }
  live.markTablesUpdated(live.allTables);
}
