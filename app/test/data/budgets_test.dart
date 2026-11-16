import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/budgets_repo.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/maintenance.dart';
import 'package:spill_the_bills/data/photo_store.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/state/budgets.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late BudgetsRepo budgets;
  late int personal;
  late int snacks;
  late int gas;

  setUp(() async {
    db = openTestDatabase();
    budgets = BudgetsRepo(db);
    personal = (await PocketsRepo(db).defaultPocket()).id;
    final cats = await CategoriesRepo(db).all();
    snacks = cats.firstWhere((c) => c.name == 'Snacks').id;
    gas = cats.firstWhere((c) => c.name == 'Gas').id;
  });
  tearDown(() => db.close());

  group('BudgetsRepo', () {
    test('a category has no budget until one is set', () async {
      expect(await budgets.get(personal, snacks), isNull);
      expect(await budgets.watch(personal).first, isEmpty);
    });

    test('set, change and read back a budget', () async {
      await budgets.set(personal, snacks, 500000);
      expect(await budgets.get(personal, snacks), 500000);
      await budgets.set(personal, snacks, 650000);
      expect(await budgets.get(personal, snacks), 650000);
      expect(await budgets.watch(personal).first, {snacks: 650000});
    });

    test('null, zero or less removes the budget', () async {
      for (final clear in <int?>[null, 0, -100]) {
        await budgets.set(personal, snacks, 500000);
        await budgets.set(personal, snacks, clear);
        expect(await budgets.get(personal, snacks), isNull, reason: 'clear with $clear');
      }
    });

    test('each pocket has its own budgets', () async {
      final business = await PocketsRepo(db).add(name: 'Business', emoji: '💼');
      await budgets.set(personal, snacks, 500000);
      await budgets.set(business, snacks, 200000);
      await budgets.set(business, gas, 100000);
      expect(await budgets.watch(personal).first, {snacks: 500000});
      expect(await budgets.watch(business).first, {snacks: 200000, gas: 100000});
    });
  });

  group('deleting removes the budgets that belong to it', () {
    test('a category', () async {
      await budgets.set(personal, snacks, 500000);
      await budgets.set(personal, gas, 100000);
      await CategoriesRepo(db).delete(snacks);
      expect(await budgets.watch(personal).first, {gas: 100000});
    });

    test('a pocket', () async {
      final business = await PocketsRepo(db).add(name: 'Business', emoji: '💼');
      await budgets.set(business, snacks, 200000);
      await budgets.set(personal, snacks, 500000);
      await PocketsRepo(db).delete(business);
      expect(await budgets.watch(business).first, isEmpty);
      expect(await budgets.watch(personal).first, {snacks: 500000});
    });

    test('Delete all data', () async {
      final temp = Directory.systemTemp.createTempSync('stb_budget_');
      addTearDown(() => temp.deleteSync(recursive: true));
      await budgets.set(personal, snacks, 500000);
      final m = DataMaintenance(
        db,
        photos: PhotoStore(baseDir: () async => temp),
        cacheDir: () async => Directory(p.join(temp.path, 'cache'))..createSync(),
      );
      final fresh = await m.deleteAllData();
      expect(await db.select(db.categoryBudgets).get(), isEmpty);
      expect(await budgets.watch(fresh).first, isEmpty);
    });
  });

  test('a schema 2 database gets the budgets table on upgrade', () async {
    final temp = Directory.systemTemp.createTempSync('stb_migrate_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final file = File(p.join(temp.path, 'old.sqlite'));
    // Build today's schema, then take the table away and mark it schema 2.
    final first = AppDatabase.forTesting(NativeDatabase(file));
    await first.customSelect('SELECT 1').get();
    await first.close();
    final raw = sqlite3.open(file.path)
      ..execute('DROP TABLE category_budgets')
      ..execute('PRAGMA user_version = 2');
    raw.dispose();

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);
    final pocket = (await PocketsRepo(upgraded).defaultPocket()).id;
    final cat = (await CategoriesRepo(upgraded).all()).first.id;
    await BudgetsRepo(upgraded).set(pocket, cat, 123400);
    expect(await BudgetsRepo(upgraded).get(pocket, cat), 123400);
  });

  group('BudgetUse levels', () {
    BudgetLevel at(int spent) => BudgetUse(spent: spent, budget: 500000).level;

    test('green below 90%, yellow from 90% to exactly 100%, red over', () {
      expect(at(0), BudgetLevel.ok);
      expect(at(449999), BudgetLevel.ok);
      expect(at(450000), BudgetLevel.near);
      expect(at(500000), BudgetLevel.near);
      expect(at(500001), BudgetLevel.over);
    });

    test('progress and how much over', () {
      const use = BudgetUse(spent: 560000, budget: 500000);
      expect(use.progress, closeTo(1.12, 1e-9));
      expect(use.overBy, 60000);
      expect(const BudgetUse(spent: 100, budget: 500000).overBy, 0);
    });
  });

  test('budgetUsesProvider: this pocket, this month, only categories with a budget', () async {
    final business = await PocketsRepo(db).add(name: 'Business', emoji: '💼');
    final expenses = ExpensesRepo(db);
    final nov = dayOf(2026, 11, 1);
    await budgets.set(personal, snacks, 500000);
    await budgets.set(personal, gas, 100000);
    await expenses.add(pocketId: personal, categoryId: snacks, amount: 300000, day: dayOf(2026, 11, 3));
    await expenses.add(pocketId: personal, categoryId: snacks, amount: 160000, day: dayOf(2026, 11, 30));
    // Not counted: another month, another pocket.
    await expenses.add(pocketId: personal, categoryId: snacks, amount: 999900, day: dayOf(2026, 10, 31));
    await expenses.add(pocketId: personal, categoryId: snacks, amount: 999900, day: dayOf(2026, 12, 1));
    await expenses.add(pocketId: business, categoryId: snacks, amount: 999900, day: dayOf(2026, 11, 5));

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final key = (pocketId: personal, monthStart: nov);
    final sub = container.listen(budgetUsesProvider(key), (_, _) {});
    addTearDown(sub.close);
    await container.read(pocketBudgetsProvider(personal).future);
    await container.read(
      categoryTotalsProvider((pocketId: personal, from: nov, to: dayOf(2026, 11, 30))).future,
    );
    expect(container.read(budgetUsesProvider(key)), {
      snacks: const BudgetUse(spent: 460000, budget: 500000),
      gas: const BudgetUse(spent: 0, budget: 100000),
    });
    expect(container.read(budgetUsesProvider(key))[snacks]!.level, BudgetLevel.near);
  });
}
