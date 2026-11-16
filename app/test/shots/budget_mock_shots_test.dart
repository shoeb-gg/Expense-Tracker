/// Pictures of the category budget rings on Add expense, for review. They are
/// only drawn when the run says so (a normal `flutter test` skips them):
///
/// ```
/// flutter test --dart-define=BUDGET_SHOTS_DIR=<folder> test/shots/budget_mock_shots_test.dart
/// ```
///
/// The budget use is made up (a test override), so no budgets are stored.
@Tags(['shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/budgets.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/board.dart';
import '../support/shots.dart';

const String _dir = String.fromEnvironment('BUDGET_SHOTS_DIR');
const bool _enabled = _dir != '';

/// Made-up use of each budget, as a share of the budget (no entry: no budget).
const Map<String, double> _uses = {
  'Snacks': 0.30,
  'Transportation': 0.92,
  'Shopping': 1.12,
  'House Rent': 1.00,
  'Electric Bill': 0.05,
  'Gas': 0.60,
};

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

Future<Override> _fakeBudgets(WidgetTester tester, AppDatabase db) async {
  final cats = await tester.runAsync(() => CategoriesRepo(db).all()) ?? const <ExpenseCategory>[];
  final uses = <int, BudgetUse>{
    for (final cat in cats)
      if (_uses[cat.name] case final share?)
        cat.id: BudgetUse(spent: (share * 500000).round(), budget: 500000),
  };
  return budgetUsesProvider.overrideWith((ref, monthStart) => uses);
}

void main() {
  setUpAll(loadShotFonts);

  final themes = <String, AppSettings>{
    'dark_aqua': const AppSettings(),
    'dark_coral': const AppSettings(mood: Mood.coral),
    'dark_iris': const AppSettings(mood: Mood.iris),
    'light_aqua': const AppSettings(themeMode: AppThemeMode.light),
    'light_coral': const AppSettings(mood: Mood.coral, themeMode: AppThemeMode.light),
    'light_iris': const AppSettings(mood: Mood.iris, themeMode: AppThemeMode.light),
  };

  Future<AppDatabase> open(WidgetTester tester, AppSettings settings) async {
    final db = await sampleDatabase(tester);
    final fake = await _fakeBudgets(tester, db);
    await pumpApp(tester, db: db, location: Routes.add(), settings: settings, overrides: [fake]);
    await boardHeight(tester, 791);
    return db;
  }

  for (final MapEntry(key: theme, value: settings) in themes.entries) {
    testWidgets('budget rings, nothing picked, $theme', (tester) async {
      final db = await open(tester, settings);
      await _save(tester, 'open_$theme');
      await closeApp(tester, db);
    }, skip: !_enabled);

    testWidgets('budget rings, Snacks picked (green), $theme', (tester) async {
      final db = await open(tester, settings);
      await tester.tap(find.text('Snacks').first);
      await _save(tester, 'snacks_$theme');
      await closeApp(tester, db);
    }, skip: !_enabled);

    testWidgets('budget rings, Shopping picked (red), $theme', (tester) async {
      final db = await open(tester, settings);
      await tester.tap(find.text('Shopping').first);
      await _save(tester, 'shopping_$theme');
      await closeApp(tester, db);
    }, skip: !_enabled);

    testWidgets('budget rings, waiting for a pick, $theme', (tester) async {
      final db = await open(tester, settings);
      await tester.enterText(find.byType(EditableText).last, 'saree 12000');
      await _save(tester, 'waiting_$theme');
      await closeApp(tester, db);
    }, skip: !_enabled);
  }

  testWidgets('budget rings, largest text, dark Aqua', (tester) async {
    final db = await open(tester, const AppSettings(textScale: 19 / 15));
    await _save(tester, 'open_dark_aqua_largest');
    await closeApp(tester, db);
  }, skip: !_enabled);
}
