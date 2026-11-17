import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/features/add/add_screen.dart';
import 'package:spill_the_bills/router.dart';

import '../../support/add_support.dart';
import '../../support/shots.dart';

/// Back on Add expense with the keyboard up first only lowers the keyboard;
/// the next Back asks about discarding (the user's request, phone test
/// 2026-11-17: it went straight to "Discard this expense?").
void main() {
  setUpAll(loadShotFonts);

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  testWidgets('typed something: Back lowers the keyboard, then asks', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add());
    await tester.tap(find.byType(EditableText).last);
    await tester.enterText(find.byType(EditableText).last, 'coffee 120');
    showSoftKeyboard(tester);
    await settle(tester);

    await back(tester);
    expect(find.text('Discard this expense?'), findsNothing);
    expect(find.byType(AddScreen), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<EditableText>()));

    hideSoftKeyboard(tester);
    await settle(tester);
    await back(tester);
    expect(find.text('Discard this expense?'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('nothing typed: Back with the keyboard up stays, then leaves', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await tester.tap(find.bySemanticsLabel('Add expense'));
    await settle(tester);
    await tester.tap(find.byType(EditableText).last);
    showSoftKeyboard(tester);
    await settle(tester);

    await back(tester);
    expect(find.byType(AddScreen), findsOneWidget);

    hideSoftKeyboard(tester);
    await settle(tester);
    await back(tester);
    expect(find.byType(AddScreen), findsNothing);
    await closeApp(tester, db);
  });
}
