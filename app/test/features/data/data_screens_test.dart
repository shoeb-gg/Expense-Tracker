import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/features/data/export_screen.dart';
import 'package:spill_the_bills/features/data/import_table.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/router.dart';

import '../../support/board.dart';
import '../../support/import_files.dart';
import '../../support/shots.dart';
import '../../support/test_db.dart';

/// Overrides the file picker and the share sheet; shared files land in
/// [shared].
List<Override> fakes({
  String name = 'a.csv',
  Uint8List? bytes,
  List<File>? shared,
}) => [
  importFilePickerProvider.overrideWithValue(
    () async => bytes == null ? null : (name: name, bytes: bytes),
  ),
  exportSharerProvider.overrideWithValue((File file, String mime) async {
    shared?.add(file);
  }),
];

Future<void> addExpenses(
  WidgetTester tester,
  AppDatabase db,
  int pocketId,
  int n,
) => tester.runAsync(() async {
  final repo = ExpensesRepo(db);
  for (var i = 0; i < n; i++) {
    await repo.add(
      pocketId: pocketId,
      categoryId: 1,
      amount: 1000 + i,
      day: dayOf(2026, 10, 1 + i),
      note: 'Item $i',
    );
  }
});

void main() {
  test('export location', () {
    expect(exportLocation(), Routes.export);
    expect(exportLocation(pocketId: 3), '/settings/export?pocket=3');
  });

  testWidgets('export shares a file of the pocket in use', (tester) async {
    final db = openTestDatabase();
    await addExpenses(tester, db, 1, 3);
    final shared = <File>[];
    await pumpApp(
      tester,
      db: db,
      location: Routes.export,
      overrides: fakes(shared: shared),
    );
    await settleUntil(tester, find.text('Export 3 expenses'));
    await tester.tap(find.text('CSV (.csv)'));
    await tester.pump();
    await tester.tap(find.text('Export 3 expenses'));
    await settleFor(tester);
    expect(shared, hasLength(1));
    final file = shared.single;
    expect(
      file.path,
      endsWith('Spill the Bills - Personal - 2026-10-01 to 2026-10-18.csv'),
    );
    final table = readImportTable(
      'x.csv',
      await tester.runAsync(file.readAsBytes) ?? Uint8List(0),
    );
    expect(table.rows.length, 3);
    await closeApp(tester, db);
  });

  testWidgets('export ?pocket= exports that pocket; dates can be picked', (
    tester,
  ) async {
    final db = openTestDatabase();
    final business = (await tester.runAsync(
      () => PocketsRepo(db).add(name: 'Business', emoji: '\u{1F4BC}'),
    ))!;
    await addExpenses(tester, db, business, 2);
    final shared = <File>[];
    await pumpApp(
      tester,
      db: db,
      location: exportLocation(pocketId: business),
      overrides: fakes(shared: shared),
    );
    await settleUntil(tester, find.text('Export 2 expenses'));
    expect(find.text('\u{1F4BC} Business'), findsOneWidget);

    // From: Oct 2 leaves one expense; the quick choice is cleared.
    await tester.tap(find.text('Oct 1, 2026'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Friday, October 2'));
    await tester.tap(find.text('Confirm'));
    await settleUntil(tester, find.text('Export 1 expense'));
    expect(find.text('Oct 2, 2026'), findsOneWidget);
    await tester.tap(find.text('Export 1 expense'));
    await settleFor(tester);
    expect(
      shared.single.path,
      endsWith('Business - 2026-10-02 to 2026-10-18.xlsx'),
    );
    await closeApp(tester, db);
  });

  testWidgets('export with nothing in range is turned off', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.export, overrides: fakes());
    await settleUntil(tester, find.text('Nothing to export'));
    expect(find.text('Nothing to export'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('import: three steps, toast on Home, Undo takes it back', (
    tester,
  ) async {
    final db = openTestDatabase();
    const csv =
        'When,Spent,Type,Note\n'
        '2025-03-02,2450,Groceries,Weekly bazaar\n'
        '2025-03-03,890,Pets,Cat food\n'
        ',12,Groceries,No date\n';
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      overrides: fakes(bytes: Uint8List.fromList(utf8.encode(csv))),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    expect(find.text('4 of 4 found'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settleUntil(tester, find.text('Import 2 expenses'));
    expect(find.text('1 row can’t be read'), findsOneWidget);
    expect(find.text('Row 4 · no date'), findsOneWidget);
    expect(find.text('Pets will be created'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    // Nothing is saved before the button.
    expect(await tester.runAsync(() => ExpensesRepo(db).count(1)), 0);

    await tester.tap(find.text('Import 2 expenses'));
    await settleUntil(tester, find.text('2 expenses added'));
    expect(find.text('2 expenses added'), findsOneWidget);
    expect(await tester.runAsync(() => ExpensesRepo(db).count(1)), 2);
    expect(
      await tester.runAsync(() => CategoriesRepo(db).findByName('Pets')),
      isNotNull,
    );

    await tester.tap(find.text('Undo'));
    await settleFor(tester);
    expect(await tester.runAsync(() => ExpensesRepo(db).count(1)), 0);
    expect(
      await tester.runAsync(() => CategoriesRepo(db).findByName('Pets')),
      isNull,
    );
    await closeApp(tester, db);
  });

  testWidgets('import: the real Home shows the added expenses; Undo removes '
      'them', (tester) async {
    final db = await sampleDatabase(tester);
    const csv =
        'Date,Amount,Category,Title\n'
        '2026-10-18,1000,Groceries,Imported shop\n'
        '2026-10-10,445,Snacks,\n';
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      overrides: fakes(bytes: Uint8List.fromList(utf8.encode(csv))),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settleUntil(tester, find.text('Import 2 expenses'));
    await tester.tap(find.text('Import 2 expenses'));
    await settleUntil(tester, find.text('2 expenses added'));

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Spent in October'), findsOneWidget);
    expect(find.text('36,000'), findsOneWidget); // 34,555 + 1,445
    expect(find.text('Imported shop'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settleFor(tester);
    expect(find.text('2 expenses added'), findsNothing);
    expect(find.text('34,555'), findsOneWidget);
    expect(find.text('Imported shop'), findsNothing);
    expect(tester.takeException(), isNull);
    await closeApp(tester, db);
  });

  testWidgets('import: a missing column keeps Next off until chosen', (
    tester,
  ) async {
    final db = openTestDatabase();
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      overrides: fakes(name: 'shops.csv', bytes: noAmountFile()),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    expect(find.text('Choose a column'), findsOneWidget);
    expect(find.text('1 of 4 found'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(
      find.text('Check the columns'),
      findsOneWidget,
      reason: 'Next is off',
    );

    await tester.tap(find.text('Choose a column'));
    await settle(tester);
    expect(
      find.text('Which column of your file holds the amount?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Shop'));
    await settle(tester);
    expect(find.text('2 of 4 found'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settleUntil(tester, find.text('Nothing to import'));
    expect(find.text('2 rows can’t be read'), findsOneWidget);
    expect(find.text('Nothing to import'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('import: dates that read both ways can be switched', (
    tester,
  ) async {
    final db = openTestDatabase();
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      overrides: fakes(name: 'expenses-2025.csv', bytes: step2File()),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    expect(
      find.text('05/03/2025 is read as March 5, 2025', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Month first'));
    await settle(tester);
    expect(
      find.text('05/03/2025 is read as May 3, 2025', findRichText: true),
      findsOneWidget,
    );
    await closeApp(tester, db);
  });

  testWidgets('import: a file that cannot be used offers another', (
    tester,
  ) async {
    final db = openTestDatabase();
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      overrides: fakes(
        name: 'empty.csv',
        bytes: Uint8List.fromList(utf8.encode('Date,Amount\n')),
      ),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    expect(find.text("Can't use this file"), findsOneWidget);
    expect(
      find.text('It has column names but no rows under them.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Add expenses from a file'), findsOneWidget);
    await closeApp(tester, db);
  });
}
