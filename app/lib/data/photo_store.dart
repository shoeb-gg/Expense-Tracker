/// Receipt photos: compressed JPEGs in the app's private `photos/` folder.
/// The database stores only the file name (`Expenses.photoPath`).
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

/// Compresses [source] into a JPEG at [target]. Returns false when it could
/// not (the original is then copied as is).
typedef ImageCompressor = Future<bool> Function(String source, String target);

/// The default compressor: JPEG quality 80, short edge at least 1200 px, so
/// a 4:3 phone photo ends up about 1600 x 1200.
Future<bool> compressReceipt(String source, String target) async {
  final result = await FlutterImageCompress.compressAndGetFile(
    source,
    target,
    minWidth: 1200,
    minHeight: 1200,
    quality: 80,
    format: CompressFormat.jpeg,
  );
  return result != null;
}

class PhotoStore {
  /// [baseDir] returns the app's private documents folder (path_provider in
  /// the app, a temp folder in tests). Photos go into `<baseDir>/photos/`.
  PhotoStore({
    required Future<Directory> Function() baseDir,
    ImageCompressor compressor = compressReceipt,
  })  : _baseDir = baseDir,
        _compressor = compressor;

  final Future<Directory> Function() _baseDir;
  final ImageCompressor _compressor;
  final Random _random = Random();

  /// The `photos/` folder (created when missing).
  Future<Directory> folder() async {
    final dir = Directory(p.join((await _baseDir()).path, 'photos'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Saves a picked image (camera or gallery file at [sourcePath]) as a
  /// compressed JPEG and returns its file name, e.g. "r_1760782680000_4821.jpg".
  Future<String> savePicked(String sourcePath) async {
    final dir = await folder();
    final name = 'r_${DateTime.now().millisecondsSinceEpoch}_'
        '${_random.nextInt(10000).toString().padLeft(4, '0')}.jpg';
    final target = p.join(dir.path, name);
    var ok = false;
    try {
      ok = await _compressor(sourcePath, target);
    } on Object {
      ok = false;
    }
    if (!ok || !File(target).existsSync()) {
      await File(sourcePath).copy(target);
    }
    return name;
  }

  /// The file of a stored photo (it may not exist any more).
  Future<File> file(String fileName) async =>
      File(p.join((await folder()).path, p.basename(fileName)));

  /// Deletes a stored photo. Missing files are ignored.
  Future<void> delete(String fileName) async {
    final f = await file(fileName);
    if (f.existsSync()) await f.delete();
  }

  /// Deletes every stored photo whose name is not in [keep]. Returns the
  /// bytes freed.
  Future<int> purgeExcept(Set<String> keep) async {
    final dir = await folder();
    var freed = 0;
    for (final entity in dir.listSync()) {
      if (entity is File && !keep.contains(p.basename(entity.path))) {
        freed += entity.lengthSync();
        await entity.delete();
      }
    }
    return freed;
  }

  /// Deletes every stored photo (Delete all data).
  Future<void> deleteAll() async {
    final dir = await folder();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
