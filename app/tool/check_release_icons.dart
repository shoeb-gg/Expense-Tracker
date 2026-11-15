// Release-only icon guard. Widget tests and screenshots cannot catch a broken
// icon font, because only release builds tree-shake icon fonts. This builds
// the release APK the normal way (tree shaking on) and checks the fonts
// inside it:
//   1. every icon the app uses (`Symbols.<name>` in lib/) has a glyph with an
//      outline in the shaken MaterialSymbolsRounded.ttf;
//   2. every glyph's variation data (`gvar`) in every shaken font parses
//      cleanly, the way Android's renderer reads it.
// Exits 1 and lists the broken icons when either fails.
//
// Run in app/:
//   dart run tool/check_release_icons.dart              build, then check
//   dart run tool/check_release_icons.dart --no-build   check the last build
//   dart run tool/check_release_icons.dart --apk <path> check another APK

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'src/ttf.dart';

const String _defaultApk = 'build/app/outputs/flutter-apk/app-release.apk';
const String _symbolsFamily = 'MaterialSymbolsRounded';

Future<void> main(List<String> args) async {
  var build = !args.contains('--no-build');
  var apkPath = _defaultApk;
  final apkFlag = args.indexOf('--apk');
  if (apkFlag >= 0) {
    if (apkFlag + 1 >= args.length) _fail('--apk needs a path.');
    apkPath = args[apkFlag + 1];
    build = false;
  }

  if (build) {
    stdout.writeln('Building: flutter build apk --release');
    final process = await Process.start(
      'flutter',
      ['build', 'apk', '--release'],
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await process.exitCode;
    if (code != 0) _fail('flutter build apk --release failed ($code).');
  }

  final apkFile = File(apkPath);
  if (!apkFile.existsSync()) _fail('No APK at $apkPath.');
  final apk = _Zip(apkFile.readAsBytesSync());
  final fonts = _fontAssets(apk);
  final failures = <String>[];

  // 1. Every icon the app uses is in the shaken Symbols font.
  final declared = {
    for (final i in parseIconConstants(File('lib/theme/symbols.dart').readAsStringSync())) i.name: i.codePoint,
  };
  final used = _usedIconNames();
  final symbolsAsset = fonts[_symbolsFamily];
  final Map<int, List<String>> namesByGlyph = {};
  if (symbolsAsset == null) {
    failures.add('FontManifest.json has no "$_symbolsFamily" family.');
  } else {
    final font = TtfFont.parse(apk.read('assets/flutter_assets/$symbolsAsset'));
    final cmap = font.cmap();
    for (final name in used) {
      final cp = declared[name];
      final gid = cp == null ? null : cmap[cp];
      if (cp == null) {
        failures.add('Symbols.$name is used but not declared in lib/theme/symbols.dart.');
      } else if (gid == null) {
        failures.add('Symbols.$name (U+${_hex(cp)}) was dropped from $symbolsAsset.');
      } else if (font.contourCount(gid) == 0) {
        failures.add('Symbols.$name (U+${_hex(cp)}) has an empty outline.');
      } else {
        namesByGlyph.putIfAbsent(gid, () => []).add('Symbols.$name');
      }
    }
  }

  // 2. Every glyph's variation data in every font parses.
  for (final MapEntry(key: family, value: asset) in fonts.entries) {
    final font = TtfFont.parse(apk.read('assets/flutter_assets/$asset'));
    for (final problem in checkGlyphVariations(font)) {
      final gid = int.tryParse(RegExp(r'^glyph (\d+):').firstMatch(problem)?.group(1) ?? '');
      final icons = family == _symbolsFamily && gid != null ? namesByGlyph[gid] : null;
      failures.add('$asset ${icons == null ? '' : '(${icons.join(', ')}) '}$problem');
    }
  }

  final size = (apkFile.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
  if (failures.isNotEmpty) {
    stderr.writeln('FAIL: ${failures.length} problem(s) in $apkPath ($size MB):');
    for (final f in failures) {
      stderr.writeln('  $f');
    }
    exit(1);
  }
  stdout.writeln('OK: ${used.length} icons have intact glyphs in $apkPath ($size MB); '
      '${fonts.length} fonts checked.');
}

/// Family name to asset path, from the APK's FontManifest.json (first font of
/// each family).
Map<String, String> _fontAssets(_Zip apk) {
  final Object? manifest = jsonDecode(utf8.decode(apk.read('assets/flutter_assets/FontManifest.json')));
  final out = <String, String>{};
  if (manifest is! List<Object?>) _fail('Unexpected FontManifest.json.');
  for (final family in manifest) {
    if (family is! Map<String, Object?>) continue;
    final name = family['family'];
    final fonts = family['fonts'];
    if (name is! String || fonts is! List<Object?>) continue;
    for (final font in fonts) {
      if (font is Map<String, Object?> && font['asset'] is String) {
        out.putIfAbsent(name, () => font['asset']! as String);
      }
    }
  }
  return out;
}

/// Names of the `Symbols` icons referenced anywhere in lib/.
Set<String> _usedIconNames() {
  final re = RegExp(r'\bSymbols\.(\w+)');
  final names = <String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.uri.pathSegments.last == 'symbols.dart') continue;
    for (final m in re.allMatches(entity.readAsStringSync())) {
      names.add(m.group(1)!);
    }
  }
  return names;
}

String _hex(int cp) => cp.toRadixString(16).toUpperCase();

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

/// Just enough of a ZIP reader for an APK: the central directory, stored and
/// deflated entries.
class _Zip {
  _Zip(this.bytes) : _d = ByteData.sublistView(bytes) {
    var eocd = bytes.length - 22;
    while (eocd >= 0 && _d.getUint32(eocd, Endian.little) != 0x06054b50) {
      eocd--;
    }
    if (eocd < 0) throw const FormatException('Not a ZIP file.');
    final count = _d.getUint16(eocd + 10, Endian.little);
    var p = _d.getUint32(eocd + 16, Endian.little);
    for (var i = 0; i < count; i++) {
      if (_d.getUint32(p, Endian.little) != 0x02014b50) throw const FormatException('Bad ZIP directory.');
      final method = _d.getUint16(p + 10, Endian.little);
      final size = _d.getUint32(p + 20, Endian.little);
      final nameLen = _d.getUint16(p + 28, Endian.little);
      final extraLen = _d.getUint16(p + 30, Endian.little);
      final commentLen = _d.getUint16(p + 32, Endian.little);
      final local = _d.getUint32(p + 42, Endian.little);
      final name = utf8.decode(bytes.sublist(p + 46, p + 46 + nameLen));
      _entries[name] = (method, size, local);
      p += 46 + nameLen + extraLen + commentLen;
    }
  }

  final Uint8List bytes;
  final ByteData _d;
  final Map<String, (int, int, int)> _entries = {};

  Uint8List read(String name) {
    final entry = _entries[name];
    if (entry == null) _fail('$name is not in the APK.');
    final (method, size, local) = entry;
    final start = local + 30 + _d.getUint16(local + 26, Endian.little) + _d.getUint16(local + 28, Endian.little);
    final raw = Uint8List.sublistView(bytes, start, start + size);
    return switch (method) {
      0 => raw,
      8 => Uint8List.fromList(ZLibDecoder(raw: true).convert(raw)),
      _ => _fail('$name uses ZIP method $method.'),
    };
  }
}
