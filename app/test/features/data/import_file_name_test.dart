import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/board.dart';
import '../../support/import_files.dart';
import '../../support/shots.dart';

/// A long file name on Import step 2 has no spaces. It breaks only after
/// "_", "-", "." or a space, never in the middle of a word, shows at most two
/// lines, and ends with "…" when it is still too long.
void main() {
  setUpAll(loadShotFonts);

  const zeroWidthSpace = '\u200B';

  List<Override> picking(String name, Uint8List bytes) => [
    importFilePickerProvider.overrideWithValue(() async => (name: name, bytes: bytes)),
  ];

  /// What the name Text looks like once it is laid out: its lines (each the
  /// letters on it, without the invisible break marks) and whether it ended
  /// in "…".
  Future<({List<String> lines, bool ellipsis})> layOut(
    WidgetTester tester,
    String name, {
    required AppSettings settings,
  }) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: settings,
      overrides: picking(name, step2File()),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await boardHeight(tester, 1700);
    final finder = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').replaceAll(zeroWidthSpace, '') == name,
    );
    expect(finder, findsOneWidget, reason: name);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)).first,
    );
    final plain = paragraph.text.toPlainText();
    final lines = <double, StringBuffer>{};
    for (var i = 0; i < plain.length; i++) {
      if (plain[i] == zeroWidthSpace) continue;
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isEmpty) continue;
      lines.putIfAbsent(boxes.first.top, StringBuffer.new).write(plain[i]);
    }
    final tops = lines.keys.toList()..sort();
    final result = (
      lines: [for (final t in tops) lines[t].toString()],
      ellipsis: paragraph.didExceedMaxLines,
    );
    await closeApp(tester, db);
    return result;
  }

  /// Every line but the last ends where the name may break.
  void expectBreaksAtSeparators(List<String> lines) {
    for (final line in lines.sublist(0, lines.length - 1)) {
      expect(
        RegExp(r'[_\-. ]$').hasMatch(line),
        isTrue,
        reason: 'a line ends in the middle of a word: "$line" in $lines',
      );
    }
  }

  testWidgets('a name that fits on two lines breaks after a separator', (tester) async {
    final shown = await layOut(
      tester,
      'expenses_export_2026_final.csv',
      settings: const AppSettings(),
    );
    expect(shown.lines.length, 2, reason: '${shown.lines}');
    expect(shown.ellipsis, isFalse);
    expectBreaksAtSeparators(shown.lines);
  });

  testWidgets('a name too long for two lines ends with an ellipsis', (tester) async {
    final shown = await layOut(
      tester,
      'expenses_export_2026_november_final_version.csv',
      settings: AppSettings(textScale: textScaleSteps.last),
    );
    expect(shown.lines.length, 2, reason: '${shown.lines}');
    expect(shown.ellipsis, isTrue);
    expectBreaksAtSeparators(shown.lines);
  });

  testWidgets('a name with dashes breaks after a dash at the largest size', (tester) async {
    final shown = await layOut(
      tester,
      'bank-statement-march-2026.csv',
      settings: AppSettings(textScale: textScaleSteps.last),
    );
    expect(shown.lines.length, lessThanOrEqualTo(2), reason: '${shown.lines}');
    expectBreaksAtSeparators(shown.lines);
  });
}
