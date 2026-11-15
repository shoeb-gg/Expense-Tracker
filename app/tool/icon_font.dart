// Regenerates assets/fonts/MaterialSymbolsRounded.ttf from the
// material_symbols_icons package (a dev dependency): every glyph's `gvar`
// data padded to an even length, so Flutter's release icon tree shaker
// cannot misalign it, then trimmed to the icons in lib/theme/symbols.dart
// with Flutter's own font-subset.
//
// Run in app/ after adding or removing an icon in lib/theme/symbols.dart:
//   dart run tool/icon_font.dart

import 'dart:convert';
import 'dart:io';

import 'src/ttf.dart';

const String _output = 'assets/fonts/MaterialSymbolsRounded.ttf';

Future<void> main() async {
  final icons = parseIconConstants(File('lib/theme/symbols.dart').readAsStringSync());
  if (icons.isEmpty) _fail('No icon constants found in lib/theme/symbols.dart.');
  final fontSubset = findFontSubset();
  if (fontSubset == null) _fail('Flutter\'s font-subset was not found. Run "flutter doctor".');

  final source = _packageFont();
  final full = TtfFont.read(source);
  padGlyphVariations(full);

  final tmp = Directory.systemTemp.createTempSync('icon_font');
  try {
    final padded = '${tmp.path}${Platform.pathSeparator}padded.ttf';
    File(padded).writeAsBytesSync(full.toBytes());
    final bytes = await runFontSubset(fontSubset, padded, icons.map((i) => i.codePoint));
    final trimmed = TtfFont.parse(bytes);
    // Already even when font-subset copies the padded data as is; pads again
    // in case a future font-subset does not.
    final repadded = padGlyphVariations(trimmed);

    final problems = checkGlyphVariations(trimmed);
    if (problems.isNotEmpty) _fail('The trimmed font is broken:\n  ${problems.join('\n  ')}');
    final cmap = trimmed.cmap();
    final missing = [
      for (final i in icons)
        if (cmap[i.codePoint] == null || trimmed.contourCount(cmap[i.codePoint]!) == 0) i.name,
    ];
    if (missing.isNotEmpty) _fail('Not in the source font: ${missing.join(', ')}');

    File(_output).writeAsBytesSync(repadded ? trimmed.toBytes() : bytes);
    stdout.writeln('Wrote $_output: ${icons.length} icons, ${trimmed.numGlyphs} glyphs, '
        '${File(_output).lengthSync()} bytes (from $source).');
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

/// The package's MaterialSymbolsRounded.ttf, found through
/// .dart_tool/package_config.json.
String _packageFont() {
  const name = 'material_symbols_icons';
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) _fail('Run "flutter pub get" first.');
  final Object? config = jsonDecode(configFile.readAsStringSync());
  final Object? packages = config is Map<String, Object?> ? config['packages'] : null;
  if (packages is List<Object?>) {
    for (final p in packages) {
      if (p is Map<String, Object?> && p['name'] == name && p['rootUri'] is String) {
        final root = configFile.absolute.uri.resolve('${p['rootUri']}/');
        final font = File.fromUri(root.resolve('lib/fonts/MaterialSymbolsRounded.ttf'));
        if (font.existsSync()) return font.path;
      }
    }
  }
  _fail('$name is not resolved. It must stay in dev_dependencies; run "flutter pub get".');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
