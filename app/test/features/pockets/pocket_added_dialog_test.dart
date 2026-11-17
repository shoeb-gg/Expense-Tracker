import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/router.dart';

import '../../support/shots.dart';

/// "Pocket added": a long name is cut in the buttons, so each button keeps
/// one line (phone test 2026-11-17: "Switch to QA Test Pocket with a very
/// long name tha" took two lines).
void main() {
  testWidgets('long names are cut with "…" in the buttons', (tester) async {
    await loadShotFonts();
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.newPocket);
    await tester.enterText(find.byType(EditableText).first, 'A very long pocket name here');
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Switch to A very long poc…'), findsOneWidget);
    expect(find.text('Stay in Personal'), findsOneWidget);
    // The question itself keeps the whole name.
    expect(find.textContaining('A very long pocket name here now?'), findsOneWidget);
    await closeApp(tester, db);
  });
}
