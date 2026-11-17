import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/add/add_logic.dart';
import 'package:spill_the_bills/router.dart';

import '../../support/shots.dart';

/// "snacks 12.345" is an amount with one decimal too many. Type to add says
/// so, instead of "Now add the amount / Like “snacks 12.345 120”" (phone
/// test 2026-11-17).
void main() {
  test('which typed numbers have more than two decimals', () {
    expect(tooManyDecimals('snacks 12.345'), isTrue);
    expect(tooManyDecimals('snacks 1,234.567'), isTrue);
    expect(tooManyDecimals('12.3456 coffee'), isTrue);
    expect(tooManyDecimals('snacks 12.34'), isFalse);
    expect(tooManyDecimals('snacks 12'), isFalse);
    expect(tooManyDecimals('version 1.2.3'), isFalse);
    expect(tooManyDecimals('snacks'), isFalse);
  });

  testWidgets('the card asks for at most two decimals', (tester) async {
    await loadShotFonts();
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    await tester.enterText(find.byType(EditableText).last, 'snacks 12.345');
    await settle(tester);
    expect(find.text('Use at most 2 decimals'), findsOneWidget);
    expect(find.text('Now add the amount'), findsNothing);
    await closeApp(tester, db);
  });
}
