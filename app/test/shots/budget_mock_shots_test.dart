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
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/budgets_repo.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
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
  return budgetUsesProvider.overrideWith((ref, key) => uses);
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

  Future<(AppDatabase, int)> formDb(WidgetTester tester, {bool twoPockets = false}) async {
    final db = await sampleDatabase(tester);
    final snacks = await tester.runAsync(() async {
      final pocket = (await PocketsRepo(db).defaultPocket()).id;
      final cat = (await CategoriesRepo(db).all()).firstWhere((c) => c.name == 'Snacks').id;
      await BudgetsRepo(db).set(pocket, cat, 500000);
      if (twoPockets) await PocketsRepo(db).add(name: 'Business', emoji: '💼');
      return cat;
    });
    return (db, snacks!);
  }

  for (final theme in ['dark_aqua', 'light_iris']) {
    testWidgets('budget form: edit Snacks with a budget, $theme', (tester) async {
      final (db, snacks) = await formDb(tester);
      await pumpApp(tester, db: db, location: Routes.editCategory(snacks), settings: themes[theme]!);
      await boardHeight(tester, 791);
      await _save(tester, 'form_edit_$theme');
      await closeApp(tester, db);
    }, skip: !_enabled);

    testWidgets('budget form: add category, empty, $theme', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db, location: Routes.newCategory, settings: themes[theme]!);
      await boardHeight(tester, 791);
      await _save(tester, 'form_add_$theme');
      await closeApp(tester, db);
    }, skip: !_enabled);
  }

  testWidgets('budget form: two pockets, dark Aqua', (tester) async {
    final (db, snacks) = await formDb(tester, twoPockets: true);
    await pumpApp(tester, db: db, location: Routes.editCategory(snacks));
    await boardHeight(tester, 791);
    await _save(tester, 'form_two_pockets_dark_aqua');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('budget form: not an amount, dark Aqua', (tester) async {
    final (db, snacks) = await formDb(tester);
    await pumpApp(tester, db: db, location: Routes.editCategory(snacks));
    await boardHeight(tester, 791);
    await tester.enterText(find.byType(EditableText).at(1), '50..0');
    await _save(tester, 'form_invalid_dark_aqua');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('budget form: largest text, dark Aqua', (tester) async {
    final (db, snacks) = await formDb(tester, twoPockets: true);
    await pumpApp(
      tester,
      db: db,
      location: Routes.editCategory(snacks),
      settings: const AppSettings(textScale: 19 / 15),
    );
    await boardHeight(tester, 791);
    await _save(tester, 'form_largest_dark_aqua');
    await closeApp(tester, db);
  }, skip: !_enabled);

  /// Sample data plus a Snacks budget just above or below this month's spend,
  /// then [amount] saved on the keypad: Home with the toast.
  Future<void> toastShot(
    WidgetTester tester,
    String name, {
    required int headroom,
    required String amount,
    AppSettings settings = const AppSettings(),
  }) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(() async {
      final pocket = (await PocketsRepo(db).defaultPocket()).id;
      final cat = (await CategoriesRepo(db).all()).firstWhere((c) => c.name == 'Snacks').id;
      final spent = await ExpensesRepo(db).categoryTotal(pocket, cat, dayOf(2026, 10, 1), dayOf(2026, 10, 31));
      await BudgetsRepo(db).set(pocket, cat, spent + headroom);
    });
    await pumpApp(tester, db: db, location: Routes.add(), settings: settings);
    await boardHeight(tester, 791);
    await tester.tap(find.text('Snacks').first);
    await settle(tester);
    for (final k in amount.split('')) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await _save(tester, name);
    await tester.pump(const Duration(seconds: 6));
    await closeApp(tester, db);
  }

  testWidgets('budget toast: over, dark Aqua', (tester) async {
    await toastShot(tester, 'toast_over_dark_aqua', headroom: 20000, amount: '800');
  }, skip: !_enabled);

  testWidgets('budget toast: over, light Iris', (tester) async {
    await toastShot(
      tester,
      'toast_over_light_iris',
      headroom: 20000,
      amount: '800',
      settings: const AppSettings(mood: Mood.iris, themeMode: AppThemeMode.light),
    );
  }, skip: !_enabled);

  testWidgets('budget toast: passing 90%, dark Coral', (tester) async {
    // Spent + headroom is the budget; 950 more lands between 90% and 100%.
    await toastShot(
      tester,
      'toast_near_dark_coral',
      headroom: 100000,
      amount: '950',
      settings: const AppSettings(mood: Mood.coral),
    );
  }, skip: !_enabled);

  testWidgets('budget rings, largest text, dark Aqua', (tester) async {
    final db = await open(tester, const AppSettings(textScale: 19 / 15));
    await _save(tester, 'open_dark_aqua_largest');
    await closeApp(tester, db);
  }, skip: !_enabled);
}
