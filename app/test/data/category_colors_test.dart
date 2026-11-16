import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/test_db.dart';

/// OKLab distance x 100 between two colours (what the palette was checked
/// with: the data-viz palette validator's "normal vision" number).
double deltaE(Color a, Color b) {
  List<double> lab(Color c) {
    double lin(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final r = lin(c.r), g = lin(c.g), bl = lin(c.b);
    final l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl, 1 / 3);
    final m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl, 1 / 3);
    final s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl, 1 / 3);
    return [
      0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
    ];
  }

  final x = lab(a), y = lab(b);
  return 100 *
      math.sqrt(
        math.pow(x[0] - y[0], 2) +
            math.pow(x[1] - y[1], 2) +
            math.pow(x[2] - y[2], 2),
      );
}

void main() {
  group('the category palette', () {
    test('keeps the first eight exactly (stored values and picks still match)',
        () {
      expect(
        CategoryColor.values.take(8).map((c) => (c.label, c.argb)).toList(),
        [
          ('Blue', 0xFF3987E5),
          ('Green', 0xFF41AE61),
          ('Violet', 0xFF9085E9),
          ('Amber', 0xFFC98500),
          ('Cyan', 0xFF0096AF),
          ('Pink', 0xFFD55181),
          ('Orange', 0xFFD95926),
          ('Coral', 0xFFE66767),
        ],
      );
    });

    test('has 18 distinct, named colours', () {
      final all = CategoryColor.values;
      expect(all, hasLength(18));
      expect(all.map((c) => c.argb).toSet(), hasLength(18));
      expect(all.map((c) => c.label).toSet(), hasLength(18));
      expect(
        all.skip(8).map((c) => c.label).toList(),
        [
          'Red', 'Yellow', 'Lime', 'Teal', 'Sky', 'Indigo', 'Magenta', 'Rose',
          'Sand', 'Slate', //
        ],
      );
      for (final c in all) {
        expect(CategoryColor.fromArgb(c.argb), c);
        expect(c.color.a, 1.0, reason: '${c.label} is opaque');
      }
    });

    test('no two colours are alike to normal vision', () {
      // The old eight already had Orange and Coral 7.1 apart; the ten new
      // colours are all at least 8 away from every other colour.
      final all = CategoryColor.values;
      final old = all.take(8).toSet();
      var worst = double.infinity;
      var worstNew = double.infinity;
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          final d = deltaE(all[i].color, all[j].color);
          worst = math.min(worst, d);
          if (!(old.contains(all[i]) && old.contains(all[j]))) {
            worstNew = math.min(worstNew, d);
          }
        }
      }
      expect(worst, greaterThan(7.0));
      expect(worstNew, greaterThan(8.0));
    });

    test('firstFree: the first colour nobody uses, else the first colour', () {
      expect(CategoryColor.firstFree(const <int>[]), CategoryColor.blue);
      expect(
        CategoryColor.firstFree([CategoryColor.blue.argb]),
        CategoryColor.green,
      );
      expect(
        CategoryColor.firstFree([
          CategoryColor.blue.argb,
          CategoryColor.violet.argb, // order of use does not matter
          CategoryColor.green.argb,
        ]),
        CategoryColor.amber,
      );
      expect(
        CategoryColor.firstFree([0xFF123456]),
        CategoryColor.blue,
        reason: 'a custom colour takes nothing from the palette',
      );
      expect(
        CategoryColor.firstFree(CategoryColor.values.map((c) => c.argb)),
        CategoryColor.blue,
        reason: 'everything taken: back to the first',
      );
    });

    test('forNew: free colours first, then the whole palette in turn', () {
      final taken = CategoryColor.values.skip(2).map((c) => c.argb).toList();
      // Only Blue and Green are free.
      expect(CategoryColor.forNew(0, taken), isEmpty);
      expect(CategoryColor.forNew(1, taken), [CategoryColor.blue]);
      expect(
        CategoryColor.forNew(5, taken),
        [
          CategoryColor.blue,
          CategoryColor.green,
          CategoryColor.blue, // nothing left: cycle from the start
          CategoryColor.green,
          CategoryColor.violet,
        ],
      );
      expect(
        CategoryColor.forNew(3, const <int>[]),
        [CategoryColor.blue, CategoryColor.green, CategoryColor.violet],
      );
      expect(
        CategoryColor.forNew(20, const <int>[]).skip(18),
        [CategoryColor.blue, CategoryColor.green],
      );
    });
  });

  group('the default categories', () {
    test('each has its own colour', () {
      final colours = defaultCategories.map((c) => c.color).toList();
      expect(colours, hasLength(15));
      expect(colours.toSet(), hasLength(15));
    });

    test('the first of each old shared set kept its colour', () {
      Map<String, CategoryColor> byName() => {
            for (final c in defaultCategories) c.name: c.color,
          };
      expect(byName(), containsPair('Groceries', CategoryColor.green));
      expect(byName(), containsPair('Snacks', CategoryColor.violet));
      expect(byName(), containsPair('Transportation', CategoryColor.pink));
      expect(byName(), containsPair('House Rent', CategoryColor.blue));
      expect(byName(), containsPair('Electric Bill', CategoryColor.amber));
      expect(byName(), containsPair('Internet Bill', CategoryColor.cyan));
      expect(byName(), containsPair('Gas', CategoryColor.orange));
      expect(byName(), containsPair('Self Care', CategoryColor.coral));
    });

    test('the others got new colours, far from their neighbours', () {
      final colours = {for (final c in defaultCategories) c.name: c.color};
      expect(colours['Shopping'], CategoryColor.magenta);
      expect(colours['Phone'], CategoryColor.indigo);
      expect(colours['Health'], CategoryColor.teal);
      expect(colours['Gym'], CategoryColor.lime);
      expect(colours['Online Subscriptions'], CategoryColor.sky);
      expect(colours['Gifts'], CategoryColor.rose);
      expect(colours['Miscellaneous'], CategoryColor.slate);
      // Charts put categories side by side: any two within three places of
      // each other are at least 7 apart (Gas and Self Care, the old Orange
      // and Coral, are 7.1 apart and keep their colours).
      for (var i = 0; i < defaultCategories.length; i++) {
        for (var j = i + 1; j < defaultCategories.length && j <= i + 3; j++) {
          final d = deltaE(
            defaultCategories[i].color.color,
            defaultCategories[j].color.color,
          );
          expect(
            d,
            greaterThan(7.0),
            reason:
                '${defaultCategories[i].name} and ${defaultCategories[j].name}',
          );
        }
      }
    });

    test('a first start seeds exactly those colours', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final rows = await CategoriesRepo(db).all();
      expect(
        rows.map((c) => (c.name, c.color)).toList(),
        [for (final d in defaultCategories) (d.name, d.color.argb)],
      );
    });

    test('a recreated Miscellaneous gets its default colour', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = CategoriesRepo(db);
      final misc = await repo.misc();
      await db.delete(db.categories).delete(misc);
      final again = await repo.misc();
      expect(again.color, CategoryColor.slate.argb);
      expect(again.emoji, misc.emoji);
    });
  });

  group('schema 2: recolour the defaults', () {
    // What an install made before this change holds: the eight colours,
    // shared out with repeats.
    const old = <String, CategoryColor>{
      'Groceries': CategoryColor.green,
      'Snacks': CategoryColor.violet,
      'Transportation': CategoryColor.pink,
      'Shopping': CategoryColor.pink,
      'House Rent': CategoryColor.blue,
      'Electric Bill': CategoryColor.amber,
      'Internet Bill': CategoryColor.cyan,
      'Phone': CategoryColor.cyan,
      'Gas': CategoryColor.orange,
      'Health': CategoryColor.cyan,
      'Gym': CategoryColor.orange,
      'Self Care': CategoryColor.coral,
      'Online Subscriptions': CategoryColor.blue,
      'Gifts': CategoryColor.coral,
      'Miscellaneous': CategoryColor.violet,
    };

    Future<void> makeSchema1(AppDatabase db) async {
      for (final entry in old.entries) {
        await (db.update(db.categories)
              ..where((c) => c.name.equals(entry.key)))
            .write(CategoriesCompanion(color: Value(entry.value.argb)));
      }
    }

    Future<Map<String, int>> colours(AppDatabase db) async => {
          for (final c in await CategoriesRepo(db).all()) c.name: c.color,
        };

    test('the table of old colours is what the old seed had', () {
      expect(seedColorsV1, old);
    });

    test('each default still wearing its old colour gets its new one',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      await makeSchema1(db);
      final changed = await db.recolourDefaultCategories();
      expect(changed, 7, reason: 'the 7 that shared a colour');
      expect(await colours(db), {
        for (final d in defaultCategories) d.name: d.color.argb,
      });
    });

    test('a colour the user chose stays, and so do their own categories',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      await makeSchema1(db);
      final repo = CategoriesRepo(db);
      // The user gave Gym a pink and Health a colour of their own.
      await (db.update(db.categories)..where((c) => c.name.equals('Gym')))
          .write(CategoriesCompanion(color: Value(CategoryColor.pink.argb)));
      await (db.update(db.categories)..where((c) => c.name.equals('Health')))
          .write(const CategoriesCompanion(color: Value(0xFF123456)));
      // Phone was renamed; Pets is the user's own, in a default's old colour.
      await (db.update(db.categories)..where((c) => c.name.equals('Phone')))
          .write(const CategoriesCompanion(name: Value('Mobile')));
      await repo.add(
        name: 'Pets',
        emoji: '\u{1F436}',
        color: CategoryColor.pink.argb,
      );

      await db.recolourDefaultCategories();
      final after = await colours(db);
      expect(after['Gym'], CategoryColor.pink.argb);
      expect(after['Health'], 0xFF123456);
      expect(after['Mobile'], CategoryColor.cyan.argb);
      expect(after['Pets'], CategoryColor.pink.argb);
      expect(after['Shopping'], CategoryColor.magenta.argb);
      expect(after['Gifts'], CategoryColor.rose.argb);
      expect(after['Miscellaneous'], CategoryColor.slate.argb);
      expect(after['Groceries'], CategoryColor.green.argb);
    });

    test('names match ignoring case, and running it twice changes nothing',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      await makeSchema1(db);
      await (db.update(db.categories)..where((c) => c.name.equals('Shopping')))
          .write(const CategoriesCompanion(name: Value('shopping')));
      expect(await db.recolourDefaultCategories(), 7);
      expect((await colours(db))['shopping'], CategoryColor.magenta.argb);
      expect(await db.recolourDefaultCategories(), 0);
    });

    test('opening a schema 1 database file upgrades it to the latest schema', () async {
      final dir = Directory.systemTemp.createTempSync('stb_upgrade_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'spill.sqlite'));

      var db = AppDatabase.forTesting(NativeDatabase(file));
      await makeSchema1(db);
      await (db.update(db.categories)..where((c) => c.name.equals('Gym')))
          .write(CategoriesCompanion(color: Value(CategoryColor.pink.argb)));
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();

      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      final after = await colours(db);
      expect(after['Shopping'], CategoryColor.magenta.argb);
      expect(after['Phone'], CategoryColor.indigo.argb);
      expect(after['Health'], CategoryColor.teal.argb);
      expect(after['Online Subscriptions'], CategoryColor.sky.argb);
      expect(after['Gifts'], CategoryColor.rose.argb);
      expect(after['Miscellaneous'], CategoryColor.slate.argb);
      expect(after['Gym'], CategoryColor.pink.argb, reason: 'user choice');
      expect(after['Groceries'], CategoryColor.green.argb);
      final version = await db
          .customSelect('PRAGMA user_version')
          .map((r) => r.read<int>('user_version'))
          .getSingle();
      // Schema 2's recolour ran, then schema 3 added the budgets table.
      expect(version, 3);
      expect(db.schemaVersion, 3);
      expect(await db.select(db.categoryBudgets).get(), isEmpty);
    });

    test('a fresh install is already schema 2 and is not recoloured', () async {
      final dir = Directory.systemTemp.createTempSync('stb_fresh_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'spill.sqlite'));
      var db = AppDatabase.forTesting(NativeDatabase(file));
      // The user picked Pink for Shopping on schema 2: that is not "old".
      await (db.update(db.categories)..where((c) => c.name.equals('Shopping')))
          .write(CategoriesCompanion(color: Value(CategoryColor.pink.argb)));
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      expect(
        (await colours(db))['Shopping'],
        CategoryColor.pink.argb,
        reason: 'no upgrade runs on a schema 2 file',
      );
    });
  });
}
