// Guards assets/fonts/MaterialSymbolsRounded.ttf against Flutter's release
// icon tree shaker, which widget tests never run: it runs the same
// font-subset the release build runs and checks every glyph survives
// (FOUNDATION.md, "Icon font"). The full end-to-end check on a real APK is
// `dart run tool/check_release_icons.dart`.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/ttf.dart';

const String _fontPath = 'assets/fonts/MaterialSymbolsRounded.ttf';
const String _regenerate = 'Run "dart run tool/icon_font.dart" after changing lib/theme/symbols.dart.';

void main() {
  final icons = parseIconConstants(File('lib/theme/symbols.dart').readAsStringSync());
  final font = TtfFont.read(_fontPath);

  test('lib/theme/symbols.dart declares the icons', () {
    expect(icons, isNotEmpty);
    expect(icons.map((i) => i.name).toSet(), hasLength(icons.length));
  });

  test('every Symbols icon has an outline in the font', () {
    final cmap = font.cmap();
    final missing = [
      for (final i in icons)
        if (cmap[i.codePoint] == null || font.contourCount(cmap[i.codePoint]!) == 0) i.name,
    ];
    expect(missing, isEmpty, reason: _regenerate);
  });

  test('glyph variation data is sound and padded to even lengths', () {
    expect(checkGlyphVariations(font), isEmpty);
    expect(
      Gvar.parse(font.tables['gvar']!).allEven,
      isTrue,
      reason: 'Odd lengths get misaligned by the release tree shaker. $_regenerate',
    );
  });

  test('survives the release icon tree shaker (font-subset)', () async {
    final fontSubset = findFontSubset();
    expect(fontSubset, isNotNull, reason: 'Flutter\'s font-subset is missing; run "flutter doctor".');
    final shaken = TtfFont.parse(await runFontSubset(fontSubset!, _fontPath, icons.map((i) => i.codePoint)));
    expect(checkGlyphVariations(shaken), isEmpty);
    final cmap = shaken.cmap();
    expect([for (final i in icons) if (cmap[i.codePoint] == null) i.name], isEmpty);
  });

  test('the check catches a glyph whose data starts one byte early (the release bug)', () {
    final gvar = Gvar.parse(font.tables['gvar']!);
    final gid = [
      for (var g = 1; g < gvar.glyphData.length; g++)
        if (gvar.glyphData[g].isNotEmpty && gvar.glyphData[g - 1].isNotEmpty) g,
    ].first;
    final table = gvar.toPaddedBytes();
    final d = ByteData.sublistView(table);
    d.setUint32(20 + gid * 4, d.getUint32(20 + gid * 4) - 1);
    final broken = TtfFont.parse(font.toBytes())..tables['gvar'] = Uint8List.fromList(table);
    expect(checkGlyphVariations(broken), contains(startsWith('glyph $gid:')));
  });
}
