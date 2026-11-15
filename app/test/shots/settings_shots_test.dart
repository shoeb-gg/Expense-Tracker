@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/board.dart';
import '../support/shots.dart';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('settings: the whole screen (NewSettings + PocketSettings)', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await addMockupPockets(tester, db);
    await pumpApp(tester, db: db, location: Routes.settings);
    // The board minus its Theme row (68 px): that choice is hidden for now.
    await boardHeight(tester, 1740 + 128 - 68);
    expect(find.text('34,555'), findsOneWidget);
    expect(find.text('+13'), findsOneWidget);
    await takeShot(tester, 'settings_default');
    await closeApp(tester, db);
  });

  testWidgets('settings: first screenful', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.settings);
    await takeShot(tester, 'settings_top');
    await closeApp(tester, db);
  });

  testWidgets('settings: Appearance at the largest text size', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.settings,
      settings: AppSettings(textScale: textScaleSteps.last),
    );
    await takeShot(tester, 'settings_top_largest');
    await closeApp(tester, db);
  });

  testWidgets('settings: Coral, Large text, separator off', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.settings,
      settings: const AppSettings(
        mood: Mood.coral,
        textScale: 17 / 15,
        thousandsSeparator: false,
      ),
    );
    await boardHeight(tester, 1960 - 68);
    expect(find.text('1234567.89'), findsOneWidget);
    await takeShot(tester, 'settings_coral_large');
    await closeApp(tester, db);
  });

  const sheets = {
    'number': 'Number format',
    'week': 'First day of the week',
    'calc': 'Calculator keys',
  };
  for (final MapEntry(key: name, value: row) in sheets.entries) {
    testWidgets('settings sheet: $row', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.settings);
      await revealRow(tester, find.text(row));
      await tester.tap(find.text(row));
      await settle(tester);
      await takeShot(tester, 'settings_sheet_$name');
      await closeApp(tester, db);
    });
  }

  testWidgets('settings: number format sheet with the separator off', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.settings,
      settings: const AppSettings(thousandsSeparator: false),
    );
    await revealRow(tester, find.text('Number format'));
    await tester.tap(find.text('Number format'));
    await settle(tester);
    expect(find.text('1234567,89'), findsOneWidget);
    await takeShot(tester, 'settings_sheet_number_nosep');
    await closeApp(tester, db);
  });

  testWidgets('settings: delete all data dialog at the largest text size', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.settings,
      settings: AppSettings(textScale: textScaleSteps.last),
    );
    await revealRow(tester, find.text('Delete all data'));
    await tester.tap(find.text('Delete all data'));
    await settle(tester);
    expect(
      find.text('All pockets, expenses, categories and photos'),
      findsOneWidget,
    );
    await takeShot(tester, 'settings_delete_all_largest');
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await closeApp(tester, db);
  });

  testWidgets('settings: delete all data dialog, then ticked', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.settings);
    await revealRow(tester, find.text('Delete all data'));
    await tester.tap(find.text('Delete all data'));
    await settle(tester);
    await takeShot(tester, 'settings_delete_all');
    await tester.tap(find.text('Yes, erase everything'));
    await settle(tester);
    await takeShot(tester, 'settings_delete_all_ticked');
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.byType(AppDialog), findsNothing);
    await closeApp(tester, db);
  });
}
