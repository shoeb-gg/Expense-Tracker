/// Pictures of the number settings, for review. They are only drawn when the
/// run says so (a normal `flutter test` skips them):
///
/// ```
/// flutter test --dart-define=NUMFMT_SHOTS=true --dart-define=NUMFMT_SHOTS_DIR=<folder> test/shots/numfmt_shots_test.dart
/// ```
///
/// [NUMFMT_SHOTS_DIR] defaults to `build/shots/numfmt`. Each picture is a
/// 360 x 791 dp phone at pixel ratio 2, drawn with the real fonts.
@Tags(['shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/board.dart';
import '../support/shots.dart';

const bool _enabled = bool.fromEnvironment('NUMFMT_SHOTS');
const String _dir = String.fromEnvironment(
  'NUMFMT_SHOTS_DIR',
  defaultValue: 'build/shots/numfmt',
);

/// Writes the frame to `<_dir>/<name>.png`.
Future<void> _save(WidgetTester tester, String name) async {
  await settle(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey<String>('shot-boundary')),
  );
  final file = File(p.join(_dir, '$name.png'));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// The sample data plus an 840.50 expense today.
Future<AppDatabase> _withBazaar(WidgetTester tester) async {
  final db = await sampleDatabase(tester);
  await tester.runAsync(() async {
    final pocket = (await PocketsRepo(db).defaultPocket()).id;
    await ExpensesRepo(db).add(
      pocketId: pocket,
      categoryId: 1,
      amount: 84050,
      day: dayOf(2026, 10, 18),
      note: 'Weekly bazaar',
    );
  });
  return db;
}

void main() {
  setUpAll(loadShotFonts);

  Future<void> openOn(
    WidgetTester tester,
    AppDatabase db,
    String location,
    AppSettings settings,
  ) async {
    await pumpApp(tester, db: db, location: location, settings: settings);
    await boardHeight(tester, 791);
  }

  testWidgets('settings, Numbers section, dark Aqua', (tester) async {
    final db = await sampleDatabase(tester);
    await openOn(tester, db, Routes.settings, const AppSettings());
    await revealRow(tester, find.text('Show decimals'));
    await _save(tester, 'settings_numbers_dark_aqua');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('Number format sheet, dark Aqua', (tester) async {
    final db = await sampleDatabase(tester);
    await openOn(tester, db, Routes.settings, const AppSettings());
    await revealRow(tester, find.text('Number format'));
    await tester.tap(find.text('Number format'));
    await settle(tester);
    await _save(tester, 'number_format_sheet_dark_aqua');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('Home with 840.50, decimals on', (tester) async {
    final db = await _withBazaar(tester);
    await openOn(tester, db, Routes.home, const AppSettings());
    expect(find.text('840.50'), findsWidgets);
    await _save(tester, 'home_840_50_decimals_on');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('Home with 840.50, decimals off', (tester) async {
    final db = await _withBazaar(tester);
    await openOn(
      tester,
      db,
      Routes.home,
      const AppSettings(showDecimals: false),
    );
    expect(find.text('841'), findsWidgets);
    await _save(tester, 'home_840_50_decimals_off');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('settings, Numbers section, light Iris', (tester) async {
    final db = await sampleDatabase(tester);
    await openOn(
      tester,
      db,
      Routes.settings,
      const AppSettings(mood: Mood.iris, themeMode: AppThemeMode.light),
    );
    await revealRow(tester, find.text('Show decimals'));
    await _save(tester, 'settings_numbers_light_iris');
    await closeApp(tester, db);
  }, skip: !_enabled);
}
