import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/text_cut.dart';

/// A selection of 123,456 expenses: Export shows the count whole (on the
/// card and on the button), at the largest text size too, with nothing
/// overflowing the phone's 360 px width.
void main() {
  setUpAll(loadShotFonts);

  for (final (name, scale) in [
    ('default text size', 1.0),
    ('largest text size', textScaleSteps.last),
  ]) {
    testWidgets('export: six digits of count show in full at the $name', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.export,
        settings: AppSettings(textScale: scale),
        overrides: [
          exportCountProvider.overrideWith((ref, key) => Stream.value(123456)),
        ],
      );
      await boardHeight(tester, 791);
      // The count is on the card ("123,456 expenses") and on the button.
      final onCard = find.text('123,456 expenses');
      final onButton = find.text('Export 123,456 expenses');
      expect(isCut(tester, onCard), isFalse, reason: 'on the card');
      expect(isCut(tester, onButton), isFalse, reason: 'on the button');
      // Nothing sticks out of the screen.
      for (final finder in [onCard, onButton]) {
        final r = tester.getRect(finder);
        expect(r.left, greaterThanOrEqualTo(0), reason: '$finder');
        expect(r.right, lessThanOrEqualTo(360), reason: '$finder');
      }
      expect(tester.takeException(), isNull);
      await closeApp(tester, db);
    });
  }
}
