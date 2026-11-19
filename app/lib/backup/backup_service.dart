/// Backs up to Google Drive and restores from it.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/db.dart';
import '../data/photo_store.dart';
import 'backup_archive.dart';
import 'drive_client.dart';

/// One backup in Drive, as the restore list shows it.
@immutable
class BackupInfo {
  const BackupInfo({required this.id, required this.createdAt, required this.expenses, required this.size});

  factory BackupInfo.fromDrive(DriveFile f, {DateTime? fallbackTime}) => BackupInfo(
    id: f.id,
    createdAt: f.createdTime ?? fallbackTime ?? DateTime.fromMillisecondsSinceEpoch(0),
    expenses: int.tryParse(f.properties['expenses'] ?? ''),
    size: f.size,
  );

  final String id;
  final DateTime createdAt;

  /// How many expenses it holds (null for a file without that note).
  final int? expenses;

  /// Bytes.
  final int? size;

  @override
  bool operator ==(Object other) =>
      other is BackupInfo && other.id == id && other.createdAt == createdAt && other.expenses == expenses && other.size == size;

  @override
  int get hashCode => Object.hash(id, createdAt, expenses, size);
}

class BackupService {
  BackupService({
    required this.db,
    required this.photos,
    required this.workDir,
    required this.drive,
    required this.now,
    required this.cleanUpPhotos,
  });

  final AppDatabase db;
  final PhotoStore photos;

  /// A folder for scratch files (the app's cache).
  final Future<Directory> Function() workDir;
  final DriveClient drive;
  final DateTime Function() now;

  /// Deletes receipt photos no expense uses any more (after a restore).
  final Future<void> Function() cleanUpPhotos;

  /// How many backups Drive keeps; older ones are deleted.
  static const int keep = 10;

  /// "Spill the Bills backup 2026-11-19 21-14.zip".
  static String fileNameFor(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Spill the Bills backup ${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}-${two(t.minute)}.zip';
  }

  Future<Directory> _scratch(String what) async {
    final dir = Directory(p.join((await workDir()).path, '${what}_${DateTime.now().microsecondsSinceEpoch}'));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<void> _remove(Directory dir) async {
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on FileSystemException {
      // A scratch folder left behind is cleared with the cache.
    }
  }

  /// Uploads a backup of everything, then deletes all but the newest [keep].
  Future<BackupInfo> backUp() async {
    final work = await _scratch('backup');
    final at = now();
    try {
      final zip = File(p.join(work.path, fileNameFor(at)));
      final manifest = await writeBackup(
        db: db,
        photosDir: await photos.folder(),
        work: Directory(p.join(work.path, 'tmp')),
        target: zip,
        now: at,
      );
      final folder = await drive.ensureFolder();
      final file = await drive.upload(
        zip,
        folderId: folder,
        name: p.basename(zip.path),
        properties: {
          'expenses': '${manifest.expenses}',
          'pockets': '${manifest.pockets}',
          'photos': '${manifest.photos}',
          'schema': '${manifest.schema}',
          'format': '${manifest.format}',
        },
      );
      await _prune(folder);
      return BackupInfo.fromDrive(file, fallbackTime: at);
    } finally {
      await _remove(work);
    }
  }

  Future<void> _prune(String folder) async {
    try {
      final files = (await drive.list(folder)).where((f) => f.name.endsWith('.zip')).toList();
      for (final old in files.skip(keep)) {
        await drive.delete(old.id);
      }
    } on DriveException {
      // The backup itself is safe; old ones go next time.
    }
  }

  /// The backups in Drive, newest first.
  Future<List<BackupInfo>> list() async {
    final folder = await drive.ensureFolder();
    return [
      for (final f in await drive.list(folder))
        if (f.name.endsWith('.zip')) BackupInfo.fromDrive(f),
    ];
  }

  /// Replaces everything in the app with [backup]. All or nothing for the
  /// data: if the backup cannot be read, nothing changes. Returns what it
  /// held.
  Future<BackupManifest> restore(BackupInfo backup) async {
    final work = await _scratch('restore');
    try {
      final zip = File(p.join(work.path, 'backup.zip'));
      await drive.download(backup.id, zip);
      final unpacked = await readBackup(zip, Directory(p.join(work.path, 'in')), appSchema: db.schemaVersion);
      await upgradeBackupDatabase(unpacked.database);
      // Photos first, under their own (unique) names, so every restored
      // expense finds its photo; the ones nothing uses go afterwards.
      final folder = await photos.folder();
      for (final photo in unpacked.photos) {
        await photo.copy(p.join(folder.path, p.basename(photo.path)));
      }
      await restoreDatabase(db, unpacked.database);
      await cleanUpPhotos();
      return unpacked.manifest;
    } finally {
      await _remove(work);
    }
  }
}
