import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/text_cut.dart';

/// The centred notes at the foot of Import step 1 and of Export never leave
/// one word alone on their last line, even at the largest text size.
void main() {
  setUpAll(loadShotFonts);

  final largest = AppSettings(textScale: textScaleSteps.last);

  testWidgets('Import step 1: the note does not end on a lone word', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.importStart, settings: largest);
    await boardHeight(tester, 1700);
    final words = lastLineWords(
      tester,
      noteText('A file exported from this app works as it is.'),
    );
    expect(words.length, greaterThanOrEqualTo(2), reason: 'last line: $words');
    await closeApp(tester, db);
  });

  testWidgets('Export: the note does not end on a lone word', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.export, settings: largest);
    await boardHeight(tester, 1700);
    final words = lastLineWords(tester, noteText('One row per expense. Photos are left out.'));
    expect(words.length, greaterThanOrEqualTo(2), reason: 'last line: $words');
    await closeApp(tester, db);
  });
}
