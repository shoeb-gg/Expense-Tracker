// Minimal TrueType reading, checking and writing for the icon-font tooling
// (tool/icon_font.dart, tool/check_release_icons.dart and
// test/icon_font_test.dart). Pure Dart, no packages.
//
// Why this exists: Flutter's `font-subset` (the icon tree shaker behind
// `flutter build --release`) packs each glyph's `gvar` variation data back to
// back, then may store the offsets as 16-bit "offset / 2" values. When a
// glyph's data has an odd length, every later glyph's offset is rounded down
// by one byte, its variation header is read from garbage, and Android draws
// nothing for it. Fonts whose per-glyph data lengths are all even survive
// subsetting intact, so [padGlyphVariations] pads them and [checkGlyphVariations]
// proves a font is clean.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A parsed sfnt font: its tables by tag.
class TtfFont {
  TtfFont._(this.sfntVersion, this.tables);

  /// Parses a single TrueType font (not a collection).
  factory TtfFont.parse(Uint8List bytes) {
    final d = ByteData.sublistView(bytes);
    final sfntVersion = d.getUint32(0);
    final numTables = d.getUint16(4);
    final tables = <String, Uint8List>{};
    for (var i = 0; i < numTables; i++) {
      final rec = 12 + i * 16;
      final tag = ascii.decode(bytes.sublist(rec, rec + 4));
      final offset = d.getUint32(rec + 8);
      final length = d.getUint32(rec + 12);
      if (offset + length > bytes.length) {
        throw FormatException('Table $tag runs past the end of the file.');
      }
      tables[tag] = Uint8List.sublistView(bytes, offset, offset + length);
    }
    return TtfFont._(sfntVersion, tables);
  }

  /// Reads and parses the font at [path].
  factory TtfFont.read(String path) => TtfFont.parse(File(path).readAsBytesSync());

  final int sfntVersion;
  final Map<String, Uint8List> tables;

  ByteData _table(String tag) {
    final t = tables[tag];
    if (t == null) throw FormatException('Missing $tag table.');
    return ByteData.sublistView(t);
  }

  int get numGlyphs => _table('maxp').getUint16(4);

  /// Whether glyph outlines are TrueType (`glyf`), not CFF.
  bool get hasGlyf => tables.containsKey('glyf') && tables.containsKey('loca');

  /// Codepoint to glyph id, from cmap formats 4 and 12.
  Map<int, int> cmap() {
    final d = _table('cmap');
    final out = <int, int>{};
    final n = d.getUint16(2);
    for (var i = 0; i < n; i++) {
      final off = d.getUint32(4 + i * 8 + 4);
      final format = d.getUint16(off);
      if (format == 4) {
        final segX2 = d.getUint16(off + 6);
        final ends = off + 14;
        final starts = ends + segX2 + 2;
        final deltas = starts + segX2;
        final ranges = deltas + segX2;
        for (var s = 0; s < segX2 ~/ 2; s++) {
          final end = d.getUint16(ends + s * 2);
          final start = d.getUint16(starts + s * 2);
          final delta = d.getInt16(deltas + s * 2);
          final rangeOffset = d.getUint16(ranges + s * 2);
          for (var c = start; c <= end && c != 0xFFFF; c++) {
            var g = 0;
            if (rangeOffset == 0) {
              g = (c + delta) & 0xFFFF;
            } else {
              g = d.getUint16(ranges + s * 2 + rangeOffset + (c - start) * 2);
              if (g != 0) g = (g + delta) & 0xFFFF;
            }
            if (g != 0) out.putIfAbsent(c, () => g);
          }
        }
      } else if (format == 12) {
        final groups = d.getUint32(off + 12);
        for (var g = 0; g < groups; g++) {
          final o = off + 16 + g * 12;
          final first = d.getUint32(o);
          final last = d.getUint32(o + 4);
          final gid = d.getUint32(o + 8);
          for (var c = first; c <= last; c++) {
            out[c] = gid + (c - first);
          }
        }
      }
    }
    return out;
  }

  /// The `glyf` bytes of glyph [gid] (empty for a blank glyph).
  Uint8List glyphBytes(int gid) {
    final longLoca = _table('head').getInt16(50) == 1;
    final loca = _table('loca');
    int at(int i) => longLoca ? loca.getUint32(i * 4) : loca.getUint16(i * 2) * 2;
    return Uint8List.sublistView(tables['glyf']!, at(gid), at(gid + 1));
  }

  /// Number of contours of glyph [gid]: 0 for a blank glyph, -1 for a
  /// composite.
  int contourCount(int gid) {
    final g = glyphBytes(gid);
    if (g.isEmpty) return 0;
    return ByteData.sublistView(g).getInt16(0);
  }

  /// Outline points of glyph [gid] as `gvar` counts them (contour points, or
  /// one per component for a composite), without the 4 phantom points.
  int outlinePointCount(int gid) {
    final g = glyphBytes(gid);
    if (g.isEmpty) return 0;
    final d = ByteData.sublistView(g);
    final contours = d.getInt16(0);
    if (contours > 0) return d.getUint16(10 + (contours - 1) * 2) + 1;
    if (contours == 0) return 0;
    var components = 0;
    var p = 10;
    while (true) {
      final flags = d.getUint16(p);
      components++;
      p += 4 + ((flags & 0x0001) != 0 ? 4 : 2);
      if ((flags & 0x0008) != 0) {
        p += 2;
      } else if ((flags & 0x0040) != 0) {
        p += 4;
      } else if ((flags & 0x0080) != 0) {
        p += 8;
      }
      if ((flags & 0x0020) == 0) break;
    }
    return components;
  }

  /// Serialises the font: tables sorted by tag, 4-byte aligned, with fresh
  /// table checksums and `head.checkSumAdjustment`.
  Uint8List toBytes() {
    final tags = tables.keys.toList()..sort();
    final n = tags.length;
    var entrySelector = 0;
    while ((1 << (entrySelector + 1)) <= n) {
      entrySelector++;
    }
    final searchRange = (1 << entrySelector) * 16;
    var size = 12 + n * 16;
    final offsets = <String, int>{};
    for (final tag in tags) {
      offsets[tag] = size;
      size += (tables[tag]!.length + 3) & ~3;
    }
    final out = Uint8List(size);
    final d = ByteData.sublistView(out);
    d.setUint32(0, sfntVersion);
    d.setUint16(4, n);
    d.setUint16(6, searchRange);
    d.setUint16(8, entrySelector);
    d.setUint16(10, n * 16 - searchRange);
    for (var i = 0; i < n; i++) {
      final tag = tags[i];
      final data = Uint8List.fromList(tables[tag]!);
      if (tag == 'head') ByteData.sublistView(data).setUint32(8, 0);
      out.setRange(offsets[tag]!, offsets[tag]! + data.length, data);
      final rec = 12 + i * 16;
      out.setRange(rec, rec + 4, ascii.encode(tag));
      d.setUint32(rec + 4, _checksum(data));
      d.setUint32(rec + 8, offsets[tag]!);
      d.setUint32(rec + 12, data.length);
    }
    final adjust = (0xB1B0AFBA - _checksum(out)) & 0xFFFFFFFF;
    d.setUint32(offsets['head']! + 8, adjust);
    return out;
  }

  static int _checksum(Uint8List data) {
    var sum = 0;
    final padded = Uint8List((data.length + 3) & ~3)..setAll(0, data);
    final d = ByteData.sublistView(padded);
    for (var i = 0; i < padded.length; i += 4) {
      sum = (sum + d.getUint32(i)) & 0xFFFFFFFF;
    }
    return sum;
  }
}

/// The `gvar` table split into its parts.
class Gvar {
  Gvar._(this.axisCount, this.sharedTuples, this.glyphData, this.longOffsets);

  factory Gvar.parse(Uint8List table) {
    final d = ByteData.sublistView(table);
    final axisCount = d.getUint16(4);
    final sharedTupleCount = d.getUint16(6);
    final sharedTuplesOffset = d.getUint32(8);
    final glyphCount = d.getUint16(12);
    final longOffsets = (d.getUint16(14) & 1) == 1;
    final dataArray = d.getUint32(16);
    int offset(int i) => longOffsets ? d.getUint32(20 + i * 4) : d.getUint16(20 + i * 2) * 2;
    final sharedEnd = sharedTuplesOffset + sharedTupleCount * axisCount * 2;
    if (sharedEnd > table.length) throw const FormatException('gvar shared tuples run past the table.');
    final glyphData = <Uint8List>[];
    for (var i = 0; i < glyphCount; i++) {
      final start = dataArray + offset(i);
      final end = dataArray + offset(i + 1);
      if (end < start || end > table.length) {
        throw FormatException('gvar offsets for glyph $i are out of range.');
      }
      glyphData.add(Uint8List.sublistView(table, start, end));
    }
    return Gvar._(
      axisCount,
      Uint8List.sublistView(table, sharedTuplesOffset, sharedEnd),
      glyphData,
      longOffsets,
    );
  }

  final int axisCount;
  final Uint8List sharedTuples;
  final List<Uint8List> glyphData;
  final bool longOffsets;

  int get sharedTupleCount => sharedTuples.length ~/ (axisCount * 2);

  /// Whether every glyph's data has an even length, so any subsetter that
  /// packs it back to back with 16-bit offsets keeps every glyph aligned.
  bool get allEven => glyphData.every((g) => g.length.isEven);

  /// Re-encodes the table with every glyph's data padded to an even length
  /// (a trailing zero byte, which parsers ignore) and 32-bit offsets.
  Uint8List toPaddedBytes() {
    final glyphCount = glyphData.length;
    final offsetsStart = 20;
    final sharedStart = offsetsStart + (glyphCount + 1) * 4;
    final dataStart = sharedStart + sharedTuples.length;
    var dataLen = 0;
    for (final g in glyphData) {
      dataLen += (g.length + 1) & ~1;
    }
    final out = Uint8List(dataStart + dataLen);
    final d = ByteData.sublistView(out);
    d.setUint16(0, 1);
    d.setUint16(2, 0);
    d.setUint16(4, axisCount);
    d.setUint16(6, sharedTupleCount);
    d.setUint32(8, sharedStart);
    d.setUint16(12, glyphCount);
    d.setUint16(14, 1);
    d.setUint32(16, dataStart);
    out.setAll(sharedStart, sharedTuples);
    var at = 0;
    for (var i = 0; i < glyphCount; i++) {
      d.setUint32(offsetsStart + i * 4, at);
      out.setAll(dataStart + at, glyphData[i]);
      at += (glyphData[i].length + 1) & ~1;
    }
    d.setUint32(offsetsStart + glyphCount * 4, at);
    return out;
  }
}

/// Pads [font]'s `gvar` so every glyph's variation data has an even length.
/// Returns false when the font has no `gvar` or is already even.
bool padGlyphVariations(TtfFont font) {
  final table = font.tables['gvar'];
  if (table == null) return false;
  final gvar = Gvar.parse(table);
  if (gvar.allEven) return false;
  font.tables['gvar'] = gvar.toPaddedBytes();
  return true;
}

/// Checks every glyph's `gvar` data the way a renderer reads it: the tuple
/// headers, the point numbers and the x/y deltas must all parse inside the
/// glyph's own byte range and match its point count. Returns one message
/// per broken glyph (empty when the table is sound or absent).
List<String> checkGlyphVariations(TtfFont font) {
  final table = font.tables['gvar'];
  if (table == null) return const [];
  final Gvar gvar;
  try {
    gvar = Gvar.parse(table);
  } on FormatException catch (e) {
    return ['gvar: ${e.message}'];
  }
  final problems = <String>[];
  if (gvar.glyphData.length != font.numGlyphs) {
    problems.add('gvar covers ${gvar.glyphData.length} glyphs, the font has ${font.numGlyphs}.');
  }
  for (var gid = 0; gid < gvar.glyphData.length; gid++) {
    final data = gvar.glyphData[gid];
    if (data.isEmpty) continue;
    final points = font.hasGlyf ? font.outlinePointCount(gid) + 4 : null;
    try {
      _checkGlyphVariationData(data, gvar.axisCount, gvar.sharedTupleCount, points);
    } on _Broken catch (e) {
      problems.add('glyph $gid: ${e.reason}');
    } on RangeError {
      problems.add('glyph $gid: data ends early.');
    }
  }
  return problems;
}

class _Broken implements Exception {
  const _Broken(this.reason);
  final String reason;
}

void _checkGlyphVariationData(Uint8List bytes, int axisCount, int sharedTupleCount, int? points) {
  final d = ByteData.sublistView(bytes);
  final header = d.getUint16(0);
  final sharedPoints = (header & 0x8000) != 0;
  if ((header & 0x7000) != 0) throw _Broken('reserved flag bits set (0x${header.toRadixString(16)}).');
  final tupleCount = header & 0x0FFF;
  final dataOffset = d.getUint16(2);
  var p = 4;
  final sizes = <int>[];
  final privatePoints = <bool>[];
  for (var t = 0; t < tupleCount; t++) {
    if (p + 4 > dataOffset) throw _Broken('$tupleCount tuple headers overrun the data offset.');
    sizes.add(d.getUint16(p));
    final index = d.getUint16(p + 2);
    p += 4;
    if ((index & 0x1000) != 0) throw _Broken('reserved tuple flag set.');
    privatePoints.add((index & 0x2000) != 0);
    final coords = <int>[];
    if ((index & 0x8000) != 0) {
      for (var a = 0; a < axisCount; a++) {
        coords.add(d.getInt16(p + a * 2));
      }
      p += axisCount * 2;
    } else if ((index & 0x0FFF) >= sharedTupleCount) {
      throw _Broken('shared tuple ${index & 0x0FFF} does not exist.');
    }
    if ((index & 0x4000) != 0) {
      for (var a = 0; a < axisCount * 2; a++) {
        coords.add(d.getInt16(p + a * 2));
      }
      p += axisCount * 4;
    }
    if (coords.any((c) => c < -0x4000 || c > 0x4000)) throw _Broken('tuple coordinate outside -1..1.');
  }
  if (p > dataOffset || dataOffset > bytes.length) throw _Broken('data offset $dataOffset is out of range.');
  var pos = dataOffset;
  int? shared;
  if (sharedPoints) (shared, pos) = _readPoints(d, pos, points);
  for (var t = 0; t < tupleCount; t++) {
    final end = pos + sizes[t];
    if (end > bytes.length) throw _Broken('tuple $t runs ${end - bytes.length} byte(s) past the glyph data.');
    var count = shared;
    if (privatePoints[t]) (count, pos) = _readPoints(d, pos, points);
    if (count == null) throw _Broken('tuple $t has no point numbers.');
    pos = _readDeltas(d, pos, count);
    pos = _readDeltas(d, pos, count);
    if (pos > end) throw _Broken('tuple $t deltas overrun its size.');
    pos = end;
  }
}

/// Reads packed point numbers. Returns how many deltas follow (all points
/// when the count is 0) and the new position.
(int, int) _readPoints(ByteData d, int pos, int? points) {
  var count = d.getUint8(pos++);
  if ((count & 0x80) != 0) count = ((count & 0x7F) << 8) | d.getUint8(pos++);
  if (count == 0) {
    if (points == null) throw const _Broken('"all points" in a font without glyf.');
    return (points, pos);
  }
  var read = 0;
  var point = 0;
  while (read < count) {
    final control = d.getUint8(pos++);
    final run = (control & 0x7F) + 1;
    final words = (control & 0x80) != 0;
    if (read + run > count) throw const _Broken('point run overshoots its count.');
    for (var i = 0; i < run; i++) {
      point += words ? d.getUint16(pos) : d.getUint8(pos);
      pos += words ? 2 : 1;
      if (points != null && point >= points) throw _Broken('point $point is past the glyph\'s $points points.');
    }
    read += run;
  }
  return (count, pos);
}

/// Skips [count] packed deltas. Returns the new position.
int _readDeltas(ByteData d, int pos, int count) {
  var read = 0;
  while (read < count) {
    final control = d.getUint8(pos++);
    final run = (control & 0x3F) + 1;
    if (read + run > count) throw const _Broken('delta run overshoots its count.');
    pos += switch (control & 0xC0) {
      0x80 => 0,
      0x40 => run * 2,
      0xC0 => run * 4,
      _ => run,
    };
    if (pos > d.lengthInBytes) throw const _Broken('deltas run past the glyph data.');
    read += run;
  }
  return pos;
}

/// One icon constant from lib/theme/symbols.dart.
class IconConstant {
  const IconConstant(this.name, this.codePoint);
  final String name;
  final int codePoint;
}

/// The icon constants declared in [symbolsDart] (the source of
/// lib/theme/symbols.dart), in file order.
List<IconConstant> parseIconConstants(String symbolsDart) {
  final re = RegExp(r'static const IconData (\w+) =\s*IconData\(\s*0x([0-9a-fA-F]+)');
  return [
    for (final m in re.allMatches(symbolsDart)) IconConstant(m.group(1)!, int.parse(m.group(2)!, radix: 16)),
  ];
}

/// The path of Flutter's `font-subset` (the tool the icon tree shaker runs),
/// found next to the running engine binary, under `FLUTTER_ROOT`, or next to
/// the `flutter` on the PATH. Null when none exists.
String? findFontSubset() {
  final exe = Platform.isWindows ? 'font-subset.exe' : 'font-subset';
  final host = Platform.isWindows
      ? 'windows-x64'
      : Platform.isMacOS
          ? 'darwin-x64'
          : 'linux-x64';
  final candidates = <String>[
    // Inside `flutter test` the runner lives in the engine artifacts folder.
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$exe',
    if (Platform.environment['FLUTTER_ROOT'] case final String root)
      [root, 'bin', 'cache', 'artifacts', 'engine', host, exe].join(Platform.pathSeparator),
  ];
  final which = Process.runSync(Platform.isWindows ? 'where' : 'which', ['flutter'], runInShell: true);
  if (which.exitCode == 0) {
    final flutter = (which.stdout as String).split(RegExp(r'\r?\n')).first.trim();
    final root = File(flutter).parent.parent.path;
    candidates.add([root, 'bin', 'cache', 'artifacts', 'engine', host, exe].join(Platform.pathSeparator));
  }
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

/// Runs Flutter's `font-subset` on [input] keeping [codePoints], exactly as
/// the icon tree shaker does, and returns the subset font's bytes.
Future<Uint8List> runFontSubset(String fontSubset, String input, Iterable<int> codePoints) async {
  final dir = await Directory.systemTemp.createTemp('icon_subset');
  try {
    final output = '${dir.path}${Platform.pathSeparator}subset.ttf';
    final process = await Process.start(fontSubset, [output, input]);
    process.stdin.writeln(codePoints.join(' '));
    await process.stdin.close();
    final err = process.stderr.transform(utf8.decoder).join();
    final outText = process.stdout.transform(utf8.decoder).join();
    final code = await process.exitCode;
    if (code != 0) {
      throw ProcessException(fontSubset, [output, input], '${await outText}${await err}', code);
    }
    return File(output).readAsBytesSync();
  } finally {
    await dir.delete(recursive: true);
  }
}
