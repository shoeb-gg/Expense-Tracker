/// Light theme review shots: every main screen and pop-up in Aqua light, plus
/// Home and Settings in Coral light and Iris light. Written to
/// `build/shots/light/`.
@Tags(['shots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/features/charts/column_chart.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/features/home/pocket_button.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/add_support.dart';
import '../support/board.dart';
import '../support/import_files.dart';
import '../support/pocket_samples.dart' as samples;
import '../support/shots.dart';
import '../support/test_db.dart';

const AppSettings _light = AppSettings(themeMode: AppThemeMode.light);

AppSettings _lightIn(Mood mood) =>
    AppSettings(themeMode: AppThemeMode.light, mood: mood);

List<Override> _picking(String name, Uint8List bytes) => [
  importFilePickerProvider.overrideWithValue(
    () async => (name: name, bytes: bytes),
  ),
  exportSharerProvider.overrideWithValue((File file, String mime) async {}),
];

Future<void> _tall(WidgetTester tester, double height) async {
  tester.view.physicalSize = Size(720, height * 2);
  await tester.pump();
  await settle(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settle(tester);
}

Future<void> _keys(WidgetTester tester, String typed) async {
  for (final k in typed.split(' ')) {
    await tester.tap(find.text(k).last);
    await tester.pump();
  }
  await settle(tester);
}

void main() {
  setUpAll(loadShotFonts);

  // ---- Home ---------------------------------------------------------------

  testWidgets('light: Home, the quick menu and the delete question', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, settings: _light);
    await takeShot(tester, 'light/home');
    await tester.longPress(find.text('Doctor visit'));
    await settle(tester);
    await takeShot(tester, 'light/home_quick_menu');
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await takeShot(tester, 'light/home_delete_expense');
    await closeApp(tester, db);
  });

  testWidgets('light: Home, the pocket switcher and the month pop-up', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(() => samples.addMockupPockets(db));
    await pumpApp(tester, db: db, settings: _light);
    await tester.tap(find.byType(PocketButton));
    await settle(tester);
    await takeShot(tester, 'light/home_pocket_switch');
    await tester.tapAt(const Offset(180, 700));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Choose month, October 2026'));
    await settle(tester);
    await takeShot(tester, 'light/pop_month');
    await closeApp(tester, db);
  });

  // ---- Add expense --------------------------------------------------------

  testWidgets('light: Add expense, the category grid and the keypad', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.add(), settings: _light);
    await takeShot(tester, 'light/add_open');
    await _tapText(tester, 'Snacks');
    await _keys(tester, '1 2 0');
    await tester.enterText(find.byType(EditableText).first, 'Coffee');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await takeShot(tester, 'light/add_keypad');
    await _tapText(tester, 'Today');
    await tester.tap(find.text('12'));
    await settle(tester);
    await takeShot(tester, 'light/pop_date');
    await closeApp(tester, db);
  });

  // ---- Calendar -----------------------------------------------------------

  testWidgets('light: Calendar', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(),
      settings: _light,
    );
    await takeShot(tester, 'light/calendar');
    await closeApp(tester, db);
  });

  testWidgets('light: Calendar, a six-week month', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.calendar(day: dayOf(2026, 8, 31)),
      settings: _light,
    );
    await takeShot(tester, 'light/calendar_six_weeks');
    await closeApp(tester, db);
  });

  // ---- Charts -------------------------------------------------------------

  testWidgets('light: Charts, month views', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts, settings: _light);
    await _tall(tester, 1606);
    await takeShot(tester, 'light/charts_month_categories');
    await tester.tap(find.text('Groceries'));
    await settle(tester);
    await takeShot(tester, 'light/charts_month_categories_selected');
    await tester.tap(find.text('Top days'));
    await settle(tester);
    await takeShot(tester, 'light/charts_month_topdays');
    await tester.tap(find.text('Over time'));
    await settle(tester);
    await takeShot(tester, 'light/charts_month_overtime');
    final chart = tester.getTopLeft(find.byType(ColumnChart));
    await tester.tapAt(chart + Offset(38 + 254 / 31 * 6.5, 150));
    await settle(tester);
    await takeShot(tester, 'light/charts_month_overtime_pinned');
    await closeApp(tester, db);
  });

  testWidgets('light: Charts, week and year views', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts, settings: _light);
    await _tall(tester, 1606);
    await tester.tap(find.text('Week'));
    await settle(tester);
    await takeShot(tester, 'light/charts_week_categories');
    await tester.tap(find.text('Top days'));
    await settle(tester);
    await takeShot(tester, 'light/charts_week_topdays');
    await tester.tap(find.text('Over time'));
    await settle(tester);
    await takeShot(tester, 'light/charts_week_overtime');
    await tester.tap(find.text('Year'));
    await settle(tester);
    await takeShot(tester, 'light/charts_year_overtime');
    await tester.tap(find.text('Categories'));
    await settle(tester);
    await takeShot(tester, 'light/charts_year_categories');
    await tester.tap(find.text('Top days'));
    await settle(tester);
    await takeShot(tester, 'light/charts_year_topdays');
    await closeApp(tester, db);
  });

  testWidgets('light: Charts, custom range pop-up and the year pop-up', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.charts, settings: _light);
    await tester.tap(find.text('Custom'));
    await settle(tester);
    await takeShot(tester, 'light/charts_custom_popup');
    await tester.tap(find.text('30 days'));
    await settle(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    await _tall(tester, 1606);
    await takeShot(tester, 'light/charts_custom_categories');
    await tester.tap(find.text('Year'));
    await settle(tester);
    await tester.tap(find.text('2025'));
    await settle(tester);
    await tester.tap(find.text('2025'));
    await settle(tester);
    await takeShot(tester, 'light/charts_year_popup');
    await closeApp(tester, db);
  });

  testWidgets('light: Charts, nothing spent', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.charts, settings: _light);
    await _tall(tester, 1000);
    await takeShot(tester, 'light/charts_empty');
    await closeApp(tester, db);
  });

  // ---- Reports ------------------------------------------------------------

  testWidgets('light: Reports', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.reports, settings: _light);
    await boardHeight(tester, 1474);
    await takeShot(tester, 'light/reports');
    await tester.tap(find.text('2025'));
    await settle(tester);
    await boardHeight(tester, 1580);
    await takeShot(tester, 'light/reports_2025');
    await closeApp(tester, db);
  });

  // ---- Category screen ----------------------------------------------------

  testWidgets('light: the Groceries category screen', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.category(
        1,
        from: dayOf(2026, 10, 1),
        to: dayOf(2026, 10, 31),
      ),
      settings: _light,
    );
    await _tall(tester, 834);
    await takeShot(tester, 'light/category_groceries');
    await tester.tap(find.text('By date'));
    await settle(tester);
    await takeShot(tester, 'light/category_groceries_bydate');
    await closeApp(tester, db);
  });

  // ---- Categories (Settings) ---------------------------------------------

  testWidgets('light: Categories list, delete question, edit form', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.categories,
      settings: _light,
    );
    await boardHeight(tester, 1114);
    await takeShot(tester, 'light/categories_list');
    await tester.tap(find.bySemanticsLabel('Delete Groceries'));
    await settle(tester);
    await takeShot(tester, 'light/categories_delete');
    await closeApp(tester, db);

    final db2 = await sampleDatabase(tester);
    final gym = await tester.runAsync(
      () => CategoriesRepo(db2).findByName('Gym'),
    );
    await pumpApp(
      tester,
      db: db2,
      location: Routes.editCategory(gym!.id),
      settings: _light,
    );
    await boardHeight(tester, 1000);
    await takeShot(tester, 'light/categories_edit');
    await closeApp(tester, db2);
  });

  // ---- Expense details ----------------------------------------------------

  testWidgets('light: Expense details and the delete question', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, settings: _light);
    await attachReceipt(tester, db);
    await pushRoute(tester, Routes.expense(doctorVisitId));
    await settleImages(tester);
    await takeShot(tester, 'light/expense_details');
    await _tapText(tester, 'Delete');
    await takeShot(tester, 'light/expense_delete');
    await closeAppWithFiles(tester, db);
  });

  testWidgets('light: Edit expense, its photo sheet and the photo viewer', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, settings: _light);
    await attachReceipt(tester, db);
    await pushRoute(tester, Routes.editExpense(doctorVisitId));
    await settleImages(tester);
    await takeShot(tester, 'light/expense_edit');
    await tester.tap(
      find.bySemanticsLabel('Receipt photo attached, tap to view or replace'),
    );
    await settleImages(tester);
    await takeShot(tester, 'light/expense_edit_photo_sheet');
    await closeAppWithFiles(tester, db);
  });

  testWidgets('light: the receipt photo viewer stays dark', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, settings: _light);
    await attachReceipt(tester, db);
    await pushRoute(tester, Routes.expensePhoto(doctorVisitId));
    await settleImages(tester);
    await takeShot(tester, 'light/photo_viewer');
    await closeAppWithFiles(tester, db);
  });

  // ---- Settings -----------------------------------------------------------

  testWidgets('light: Settings, whole screen and sheets', (tester) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(() => samples.addMockupPockets(db));
    await pumpApp(
      tester,
      db: db,
      location: Routes.settings,
      settings: _light,
    );
    await takeShot(tester, 'light/settings_top');
    await boardHeight(tester, 1868);
    await takeShot(tester, 'light/settings');
    await closeApp(tester, db);
  });

  testWidgets('light: Settings, an option sheet and the delete-all dialog', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.settings,
      settings: _light,
    );
    await revealRow(tester, find.text('First day of the week'));
    await tester.tap(find.text('First day of the week'));
    await settle(tester);
    await takeShot(tester, 'light/settings_sheet_week_start');
    await tester.tap(find.text('Sunday').last);
    await settle(tester);
    await revealRow(tester, find.text('Delete all data'));
    await tester.tap(find.text('Delete all data'));
    await settle(tester);
    await takeShot(tester, 'light/settings_delete_all');
    await tester.tap(find.text('Yes, erase everything'));
    await settle(tester);
    await takeShot(tester, 'light/settings_delete_all_ticked');
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await closeApp(tester, db);
  });

  // ---- Pockets ------------------------------------------------------------

  testWidgets('light: Pockets list, delete question, form', (tester) async {
    final db = await sampleDatabase(tester);
    final ids = (await tester.runAsync(() => samples.addMockupPockets(db)))!;
    await pumpApp(tester, db: db, location: Routes.pockets, settings: _light);
    await takeShot(tester, 'light/pockets_list');
    await tester.tap(find.bySemanticsLabel('Delete Business'));
    await settle(tester);
    await takeShot(tester, 'light/pockets_delete');
    await tester.tap(find.text('Yes, delete 214 expenses'));
    await settle(tester);
    await takeShot(tester, 'light/pockets_delete_ticked');
    await closeApp(tester, db);

    final db2 = await sampleDatabase(tester);
    await tester.runAsync(() => samples.addMockupPockets(db2));
    await pumpApp(
      tester,
      db: db2,
      location: Routes.editPocket(ids.business),
      settings: _light,
    );
    await takeShot(tester, 'light/pockets_edit');
    await closeApp(tester, db2);

    final db3 = await sampleDatabase(tester);
    await pumpApp(tester, db: db3, location: Routes.newPocket, settings: _light);
    await takeShot(tester, 'light/pockets_add');
    await closeApp(tester, db3);
  });

  // ---- Import and export --------------------------------------------------

  testWidgets('light: Export', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.export, settings: _light);
    await takeShot(tester, 'light/export');
    await closeApp(tester, db);
  });

  testWidgets('light: Import, every step and the toast', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: _light,
    );
    await takeShot(tester, 'light/import_1');
    await closeApp(tester, db);

    final db2 = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db2,
      location: Routes.importStart,
      settings: _light,
      overrides: _picking('expenses-2025.csv', step2File()),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await takeShot(tester, 'light/import_2');
    await closeApp(tester, db2);

    final db3 = await sampleDatabase(tester);
    final file = await tester.runAsync(() => step3File(db3));
    await pumpApp(
      tester,
      db: db3,
      location: Routes.importStart,
      settings: _light,
      overrides: _picking('expenses-2025.csv', file!),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await boardHeight(tester, 900);
    await takeShot(tester, 'light/import_3');
    await tester.tap(find.text('Import 298 expenses'));
    await settle(tester);
    await takeShot(tester, 'light/import_done_toast');
    await tester.pump(const Duration(seconds: 7));
    await closeApp(tester, db3);
  });

  testWidgets('light: Import, a file that cannot be used', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.importStart,
      settings: _light,
      overrides: _picking('receipt.pdf', Uint8List(4)),
    );
    await tester.tap(find.text('Choose a file').last);
    await settle(tester);
    await takeShot(tester, 'light/import_bad_file');
    await closeApp(tester, db);
  });

  // ---- Pop-ups ------------------------------------------------------------

  testWidgets('light: day, month and year pop-ups', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, settings: _light);
    final ctx = tester.element(find.byType(HomeScreen));
    unawaited(showDayPicker(ctx, initialDay: dayOf(2026, 10, 12)));
    await settle(tester);
    await takeShot(tester, 'light/pop_date_home');
    await tester.tapAt(const Offset(180, 40));
    await settle(tester);
    unawaited(showMonthPicker(ctx, year: 2026, month: 10));
    await settle(tester);
    await tester.tap(find.text('2026').last);
    await settle(tester);
    await takeShot(tester, 'light/pop_year');
    await closeApp(tester, db);
  });

  // ---- Coral and Iris -----------------------------------------------------

  for (final mood in [Mood.coral, Mood.iris]) {
    testWidgets('light: Home and Settings in ${mood.label}', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, settings: _lightIn(mood));
      await takeShot(tester, 'light/home_${mood.name}');
      await tester.tap(find.text('Settings'));
      await settle(tester);
      await takeShot(tester, 'light/settings_${mood.name}');
      await closeApp(tester, db);
    });
  }
}
