import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/backup/backup_archive.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/budgets_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/data/settings_store.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/test_db.dart';

void main() {
  late Directory temp;
  late AppDatabase db;
  late Directory photos;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('stb_backup_');
    photos = Directory(p.join(temp.path, 'photos'))..createSync();
    db = openTestDatabase();
    await db.customSelect('SELECT 1').get();
  });
  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  Future<int> personal() async => (await PocketsRepo(db).defaultPocket()).id;

  /// Two pockets, three expenses (one with a photo), a budget, a setting.
  Future<void> fill() async {
    final home = await personal();
    final trip = await PocketsRepo(db).add(name: 'Trip', emoji: '🧳');
    final expenses = ExpensesRepo(db);
    File(p.join(photos.path, 'r_1_0001.jpg')).writeAsBytesSync([1, 2, 3, 4]);
    File(p.join(photos.path, 'orphan.jpg')).writeAsBytesSync([9]);
    await expenses.add(pocketId: home, categoryId: 1, amount: 63000, day: dayOf(2026, 11, 16), note: 'Bazaar');
    await expenses.add(pocketId: home, categoryId: 2, amount: 15000, day: dayOf(2026, 11, 17), photoPath: 'r_1_0001.jpg');
    await expenses.add(pocketId: trip, categoryId: 3, amount: 11000, day: dayOf(2026, 11, 17));
    await BudgetsRepo(db).set(home, 2, 500000);
    await SettingsStore(db).write('mood', 'iris');
  }

  Future<File> backUp() async {
    final zip = File(p.join(temp.path, 'backup.zip'));
    await writeBackup(
      db: db,
      photosDir: photos,
      work: Directory(p.join(temp.path, 'work')),
      target: zip,
      now: DateTime.utc(2026, 11, 19, 15, 14),
    );
    return zip;
  }

  test('a backup holds the manifest, the database and only used photos', () async {
    await fill();
    final zip = await backUp();
    final input = InputFileStream(zip.path);
    addTearDown(input.close);
    final archive = ZipDecoder().decodeBuffer(input);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, {'manifest.json', 'data.sqlite', 'photos/r_1_0001.jpg'});
    final manifest = BackupManifest.fromJson(
      jsonDecode(utf8.decode(archive.findFile('manifest.json')!.content as List<int>)),
    );
    expect(manifest.expenses, 3);
    expect(manifest.pockets, 2);
    expect(manifest.photos, 1);
    expect(manifest.schema, db.schemaVersion);
    expect(manifest.format, BackupManifest.currentFormat);
    expect(manifest.createdAt.toUtc(), DateTime.utc(2026, 11, 19, 15, 14));
  });

  test('restore brings everything back, and keeps this phone\'s backup settings', () async {
    await fill();
    final zip = await backUp();

    // Change everything after the backup.
    final home = await personal();
    await ExpensesRepo(db).add(pocketId: home, categoryId: 1, amount: 99900, day: dayOf(2026, 11, 18));
    await (db.delete(db.expenses)..where((e) => e.note.equals('Bazaar'))).go();
    await BudgetsRepo(db).set(home, 2, null);
    await SettingsStore(db).write('mood', 'coral');
    await SettingsStore(db).write('backup.email', 'me@example.com');

    final unpacked = await readBackup(zip, Directory(p.join(temp.path, 'in')), appSchema: db.schemaVersion);
    expect(unpacked.photos.map((f) => p.basename(f.path)), ['r_1_0001.jpg']);
    expect(unpacked.photos.single.readAsBytesSync(), [1, 2, 3, 4]);
    await upgradeBackupDatabase(unpacked.database);
    await restoreDatabase(db, unpacked.database);

    final rows = await db.select(db.expenses).get();
    expect(rows.map((e) => e.amount).toList()..sort(), [11000, 15000, 63000]);
    expect(rows.firstWhere((e) => e.amount == 15000).photoPath, 'r_1_0001.jpg');
    expect((await db.select(db.pockets).get()).map((x) => x.name).toSet(), {'Personal', 'Trip'});
    expect(await BudgetsRepo(db).get(home, 2), 500000);
    final settings = await SettingsStore(db).load();
    expect(settings['mood'], 'iris');
    expect(settings['backup.email'], 'me@example.com', reason: 'device setting kept');
  });

  test('restore updates what the screens watch', () async {
    await fill();
    final zip = await backUp();
    final home = await personal();
    final seen = <int>[];
    final sub = ExpensesRepo(db).watchTotal(home, 0, 99999).listen(seen.add);
    await pumpEventQueue();
    await ExpensesRepo(db).add(pocketId: home, categoryId: 1, amount: 100, day: dayOf(2026, 11, 18));
    await pumpEventQueue();
    final unpacked = await readBackup(zip, Directory(p.join(temp.path, 'in')), appSchema: db.schemaVersion);
    await upgradeBackupDatabase(unpacked.database);
    await restoreDatabase(db, unpacked.database);
    await pumpEventQueue();
    expect(seen.last, 78000);
    await sub.cancel();
  });

  test('a backup from an older app (schema 2) is upgraded and restored', () async {
    await fill();
    final zip = await backUp();
    // Turn the zip's database into a schema 2 one: no budgets table.
    final unpackedDir = Directory(p.join(temp.path, 'old'));
    final unpacked = await readBackup(zip, unpackedDir, appSchema: db.schemaVersion);
    sqlite3.open(unpacked.database.path)
      ..execute('DROP TABLE category_budgets')
      ..execute('PRAGMA user_version = 2')
      ..dispose();
    await upgradeBackupDatabase(unpacked.database);
    await restoreDatabase(db, unpacked.database);
    expect(await db.select(db.categoryBudgets).get(), isEmpty);
    expect((await db.select(db.expenses).get()).length, 3);
  });

  group('refuses what it cannot restore', () {
    Future<File> zipOf(Map<String, List<int>> files) async {
      final zip = File(p.join(temp.path, 'odd.zip'));
      final enc = ZipFileEncoder()..create(zip.path);
      for (final MapEntry(key: name, value: bytes) in files.entries) {
        enc.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
      }
      await enc.close();
      return zip;
    }

    List<int> manifest({int format = 1, int schema = 3}) => utf8.encode(
      jsonEncode({
        'format': format,
        'schema': schema,
        'createdAt': '2026-11-19T15:14:00Z',
        'expenses': 1,
        'pockets': 1,
        'photos': 0,
      }),
    );

    Future<String> error(File zip) async {
      try {
        await readBackup(zip, Directory(p.join(temp.path, 'x')), appSchema: 3);
        return 'no error';
      } on BackupFormatException catch (e) {
        return e.message;
      }
    }

    test('not a zip', () async {
      final f = File(p.join(temp.path, 'n.zip'))..writeAsStringSync('hello');
      expect(await error(f), 'This backup is damaged.');
    });

    test('a zip without a manifest', () async {
      expect(await error(await zipOf({'a.txt': [1]})), 'This is not a Spill the Bills backup.');
    });

    test('a newer app\'s backup', () async {
      final data = utf8.encode('SQLite format 3\u0000');
      expect(
        await error(await zipOf({'manifest.json': manifest(schema: 4), 'data.sqlite': data})),
        'This backup was made by a newer version of the app. Update the app first.',
      );
      expect(
        await error(await zipOf({'manifest.json': manifest(format: 2), 'data.sqlite': data})),
        'This backup was made by a newer version of the app. Update the app first.',
      );
    });

    test('a data file that is not a database', () async {
      expect(
        await error(await zipOf({'manifest.json': manifest(), 'data.sqlite': [1, 2, 3]})),
        'This backup is damaged.',
      );
    });

    test('photo names that climb out of the folder are skipped', () async {
      await fill();
      final good = await backUp();
      final input = InputFileStream(good.path);
      final archive = ZipDecoder().decodeBuffer(input);
      final files = {for (final f in archive.files) f.name: f.content as List<int>};
      await input.close();
      files['photos/../../evil.jpg'] = [6, 6, 6];
      final zip = await zipOf(files);
      final unpacked = await readBackup(zip, Directory(p.join(temp.path, 'y')), appSchema: 3);
      expect(unpacked.photos.map((f) => p.basename(f.path)), ['r_1_0001.jpg']);
      expect(File(p.join(temp.path, 'evil.jpg')).existsSync(), isFalse);
    });
  });

  test('upgrading a file that is not a database says it is damaged', () async {
    final f = File(p.join(temp.path, 'bad.sqlite'))..writeAsStringSync('SQLite format 3\u0000garbage');
    await expectLater(upgradeBackupDatabase(f), throwsA(isA<BackupFormatException>()));
  });

  // Keeps the imports honest when helpers change.
  test('NativeDatabase and Value are available', () {
    expect(NativeDatabase.memory, isNotNull);
    expect(const Value(1).present, isTrue);
  });
}
