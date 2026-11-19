import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/backup.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/shots.dart';

/// "Google Drive backup" is a long title for the header, which has only a
/// back button: at every text size it shows whole, at its full size, centred
/// on the screen, clear of the back button.
void main() {
  setUpAll(loadShotFonts);

  const title = 'Google Drive backup';

  for (final signedIn in [false, true]) {
    for (final scale in textScaleSteps) {
      testWidgets('${signedIn ? 'signed in' : 'signed out'}, text size '
          '${scale.toStringAsFixed(2)}: the title is whole and full size', (tester) async {
        final db = await sampleDatabase(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.backup,
          settings: AppSettings(textScale: scale),
          overrides: [
            if (signedIn)
              initialBackupStateProvider.overrideWithValue(
                BackupState(email: 'me@example.com', lastBackupAt: DateTime(2026, 10, 18, 9)),
              ),
          ],
        );
        final text = find.descendant(of: find.byType(SubHeader), matching: find.text(title));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)).first,
        );
        final rect = tester.getRect(text);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(rect.width / paragraph.size.width, closeTo(1, 0.001), reason: 'not scaled down');
        expect(rect.center.dx, closeTo(180, 0.5), reason: 'centred');
        expect(rect.left, greaterThanOrEqualTo(tester.getRect(find.byType(BackRoundButton)).right + 8));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 5));
        await closeApp(tester, db);
      });
    }
  }
}
