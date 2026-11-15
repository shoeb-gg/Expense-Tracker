import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/learned_words_repo.dart';
import 'package:spill_the_bills/data/maintenance.dart';
import 'package:spill_the_bills/data/photo_store.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/data/settings_store.dart';
import 'package:spill_the_bills/state/settings.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/test_db.dart';

/// A PhotoStore in a temp folder that "compresses" by copying.
PhotoStore tempPhotoStore(Directory dir) => PhotoStore(
      baseDir: () async => dir,
      compressor: (source, target) async {
        await File(source).copy(target);
        return true;
      },
    );

void main() {
  late AppDatabase db;
  late Directory temp;
  late PhotoStore photos;
  late ExpensesRepo expenses;
  late CategoriesRepo categories;
  late PocketsRepo pockets;
  late LearnedWordsRepo words;
  final clock = Clock.fixed(mockupNow);
  final today = dayOf(2026, 10, 18);

  setUp(() async {
    db = openTestDatabase();
    temp = await Directory.systemTemp.createTemp('stb_test_');
    photos = tempPhotoStore(Directory(p.join(temp.path, 'docs')));
    expenses = ExpensesRepo(db, clock: clock);
    categories = CategoriesRepo(db, clock: clock);
    pockets = PocketsRepo(db, photos: photos, clock: clock);
    words = LearnedWordsRepo(db, clock: clock);
  });

  tearDown(() async {
    await db.close();
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Future<int> catId(String name) async => (await categories.findByName(name))!.id;

  group('seed', () {
    test('one default pocket "Personal" and the 15 categories in order', () async {
      final ps = await pockets.all();
      expect(ps, hasLength(1));
      expect(ps.single.name, 'Personal');
      expect(ps.single.emoji, '\u{1F45B}');
      expect(ps.single.isDefault, isTrue);

      final cs = await categories.all();
      expect(cs.map((c) => c.name).toList(), [
        'Groceries', 'Snacks', 'Transportation', 'Shopping', 'House Rent', //
        'Electric Bill', 'Internet Bill', 'Phone', 'Gas', 'Health', 'Gym',
        'Self Care', 'Online Subscriptions', 'Gifts', 'Miscellaneous',
      ]);
      expect(cs.where((c) => c.isMisc).single.name, 'Miscellaneous');
      expect(cs.first.emoji, '\u{1F966}');
      expect(cs.first.color, CategoryColor.green.argb);
      expect(cs[1].emoji, '\u{1F357}');
      expect(cs[4].color, CategoryColor.blue.argb);
      expect(cs.last.color, CategoryColor.slate.argb);
    });
  });

  group('expenses', () {
    test('add, update, delete returns the row, restore puts it back', () async {
      final pocket = (await pockets.defaultPocket()).id;
      final snacks = await catId('Snacks');
      final id = await expenses.add(
        pocketId: pocket,
        categoryId: snacks,
        amount: 12000,
        day: today,
        note: ' Coffee ',
      );
      var e = (await expenses.get(id))!;
      expect(e.note, 'Coffee');
      expect(e.createdAt, mockupNow);

      await expenses.update(e.copyWith(amount: 15000, note: 'Tea'));
      e = (await expenses.get(id))!;
      expect(e.amount, 15000);
      expect(e.note, 'Tea');

      final removed = await expenses.delete(id);
      expect(removed?.id, id);
      expect(await expenses.get(id), isNull);
      expect(await expenses.delete(id), isNull);

      await expenses.restore(removed!);
      expect(await expenses.get(id), removed);
    });

    test('move to another pocket', () async {
      final a = (await pockets.defaultPocket()).id;
      final b = await pockets.add(name: 'Business', emoji: '\u{1F4BC}');
      final id = await expenses.add(
        pocketId: a,
        categoryId: await catId('Gifts'),
        amount: 500,
        day: today,
      );
      await expenses.moveToPocket(id, b);
      expect((await expenses.get(id))!.pocketId, b);
      expect(await expenses.count(a), 0);
      expect(await expenses.count(b), 1);
    });

    test('sums by day, category and month; totals; span; count', () async {
      final pocket = (await pockets.defaultPocket()).id;
      final snacks = await catId('Snacks');
      final rent = await catId('House Rent');
      Future<void> add(int cat, int amount, int day) =>
          expenses.add(pocketId: pocket, categoryId: cat, amount: amount, day: day);
      await add(snacks, 100, dayOf(2026, 9, 30));
      await add(rent, 1500000, dayOf(2026, 10, 1));
      await add(snacks, 12000, dayOf(2026, 10, 18));
      await add(snacks, 3000, dayOf(2026, 10, 18));

      final oct = (monthStart(2026, 10), monthEnd(2026, 10));
      expect(
        await expenses.watchDayTotals(pocket, oct.$1, oct.$2).first,
        {dayOf(2026, 10, 1): 1500000, dayOf(2026, 10, 18): 15000},
      );
      expect(
        await expenses.watchCategoryTotals(pocket, oct.$1, oct.$2).first,
        [
          CategoryTotal(categoryId: rent, total: 1500000, count: 1),
          CategoryTotal(categoryId: snacks, total: 15000, count: 2),
        ],
      );
      expect(
        await expenses.watchMonthTotals(pocket, yearStart(2026), yearEnd(2026)).first,
        const [
          MonthTotal(year: 2026, month: 9, total: 100, count: 1),
          MonthTotal(year: 2026, month: 10, total: 1515000, count: 3),
        ],
      );
      expect(await expenses.watchTotal(pocket, oct.$1, oct.$2).first, 1515000);
      expect(await expenses.watchAllTimeTotal(pocket).first, 1515100);
      expect(
        await expenses.watchDaySpan(pocket).first,
        (first: dayOf(2026, 9, 30), last: dayOf(2026, 10, 18)),
      );
      expect(await expenses.watchCount(pocket).first, 4);
      expect(await expenses.count(pocket, from: oct.$1, to: oct.$2), 3);

      final list = await expenses.watchRange(pocket, oct.$1, oct.$2).first;
      expect(list.map((e) => e.day).toList(), [
        dayOf(2026, 10, 18), dayOf(2026, 10, 18), dayOf(2026, 10, 1), //
      ]);
      final onlyRent =
          await expenses.listRange(pocket, oct.$1, oct.$2, categoryId: rent);
      expect(onlyRent.single.amount, 1500000);
      expect(
        await expenses.watchPocketTotals(oct.$1, oct.$2).first,
        {pocket: 1515000},
      );
      expect(
        await expenses.exists(
          pocketId: pocket,
          day: dayOf(2026, 10, 1),
          amount: 1500000,
          categoryId: rent,
          note: '',
        ),
        isTrue,
      );
    });

    test('empty pocket gives zeros and an empty span', () async {
      final pocket = (await pockets.defaultPocket()).id;
      expect(await expenses.watchAllTimeTotal(pocket).first, 0);
      expect(await expenses.watchDaySpan(pocket).first, (first: null, last: null));
      expect(await expenses.watchDayTotals(pocket, 0, today).first, isEmpty);
    });

    test('addAll and deleteMany (import and its Undo)', () async {
      final pocket = (await pockets.defaultPocket()).id;
      final misc = (await categories.misc()).id;
      final ids = await expenses.addAll([
        for (var i = 0; i < 3; i++)
          ExpenseDraft(pocketId: pocket, categoryId: misc, amount: 100 * i, day: today),
      ]);
      expect(ids, hasLength(3));
      expect(await expenses.count(pocket), 3);
      expect(await expenses.deleteMany(ids), 3);
      expect(await expenses.count(pocket), 0);
    });

    test('streams update when data changes', () async {
      final pocket = (await pockets.defaultPocket()).id;
      final stream = expenses.watchTotal(pocket, today, today);
      final seen = <int>[];
      final sub = stream.listen(seen.add);
      await pumpEventQueue();
      await expenses.add(
        pocketId: pocket,
        categoryId: await catId('Gym'),
        amount: 100000,
        day: today,
      );
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [0, 100000]);
    });
  });

  group('categories', () {
    test('delete moves expenses in EVERY pocket to Miscellaneous', () async {
      final a = (await pockets.defaultPocket()).id;
      final b = await pockets.add(name: 'Trip', emoji: '\u{1F3D6}\u{FE0F}');
      final snacks = await catId('Snacks');
      final misc = (await categories.misc()).id;
      for (final pocket in [a, a, b]) {
        await expenses.add(pocketId: pocket, categoryId: snacks, amount: 100, day: today);
      }
      await words.learn('coffee', snacks);
      expect(await categories.countExpenses(snacks), 3);

      final moved = await categories.delete(snacks);
      expect(moved, 3);
      expect(await categories.get(snacks), isNull);
      expect(await categories.countExpenses(misc), 3);
      final all = await expenses.listRange(a, 0, today);
      expect(all.every((e) => e.categoryId == misc), isTrue);
      expect(await words.lookup(['coffee']), isEmpty); // forgotten
    });

    test('Miscellaneous can never be deleted', () async {
      final misc = (await categories.misc()).id;
      expect(() => categories.delete(misc), throwsStateError);
      expect(await categories.get(misc), isNotNull);
    });

    test('add goes before Miscellaneous; update; reorder; name check', () async {
      final id = await categories.add(
        name: ' Pets ',
        emoji: '\u{1F436}',
        color: CategoryColor.amber.argb,
      );
      var list = await categories.all();
      expect(list[list.length - 2].id, id);
      expect(list[list.length - 2].name, 'Pets');
      expect(list.last.isMisc, isTrue);

      await categories.update(list[list.length - 2].copyWith(name: 'Pet care'));
      expect((await categories.get(id))!.name, 'Pet care');
      expect(await categories.nameExists('pet CARE'), isTrue);
      expect(await categories.nameExists('Pet care', exceptId: id), isFalse);

      final reversed = list.map((c) => c.id).toList().reversed.toList();
      await categories.reorder(reversed);
      list = await categories.all();
      expect(list.map((c) => c.id).toList(), reversed);
    });

    test('expense counts per category', () async {
      final pocket = (await pockets.defaultPocket()).id;
      final gym = await catId('Gym');
      await expenses.add(pocketId: pocket, categoryId: gym, amount: 1, day: today);
      await expenses.add(pocketId: pocket, categoryId: gym, amount: 1, day: today);
      expect(await categories.watchExpenseCounts().first, {gym: 2});
    });
  });

  group('pockets', () {
    test('delete removes its expenses and their photos; default is refused', () async {
      final def = await pockets.defaultPocket();
      final trip = await pockets.add(name: 'Trip', emoji: '\u{1F3D6}\u{FE0F}');
      final source = File(p.join(temp.path, 'pick.jpg'))..writeAsBytesSync([1, 2, 3]);
      final photo = await photos.savePicked(source.path);
      final cat = await catId('Gifts');
      await expenses.add(pocketId: trip, categoryId: cat, amount: 1, day: today, photoPath: photo);
      await expenses.add(pocketId: trip, categoryId: cat, amount: 2, day: today);
      await expenses.add(pocketId: def.id, categoryId: cat, amount: 3, day: today);
      expect((await photos.file(photo)).existsSync(), isTrue);
      expect(await pockets.watchExpenseCounts().first, {trip: 2, def.id: 1});

      expect(await pockets.delete(trip), 2);
      expect(await pockets.get(trip), isNull);
      expect((await photos.file(photo)).existsSync(), isFalse);
      expect(await expenses.count(def.id), 1);

      expect(() => pockets.delete(def.id), throwsStateError);
      expect(await pockets.get(def.id), isNotNull);
    });

    test('add, update, reorder, unique names', () async {
      final b = await pockets.add(name: 'Business', emoji: '\u{1F4BC}');
      final c = await pockets.add(name: 'Family trip', emoji: '\u{1F3D6}\u{FE0F}');
      expect((await pockets.all()).map((x) => x.name).toList(),
          ['Personal', 'Business', 'Family trip']);
      await pockets.update((await pockets.get(b))!.copyWith(name: 'Work'));
      expect((await pockets.get(b))!.name, 'Work');
      expect(await pockets.nameExists('work'), isTrue);
      expect(await pockets.nameExists('Work', exceptId: b), isFalse);
      final def = (await pockets.defaultPocket()).id;
      await pockets.reorder([c, b, def]);
      expect((await pockets.all()).map((x) => x.id).toList(), [c, b, def]);
    });
  });

  group('learned words', () {
    test('learn, lookup, relearn, forget', () async {
      final snacks = await catId('Snacks');
      final gifts = await catId('Gifts');
      await words.learn(' Coffee ', snacks);
      await words.learnAll(['saree', 'cake'], gifts);
      expect(await words.lookup(['coffee', 'SAREE', 'unknown']), {
        'coffee': snacks,
        'saree': gifts,
      });
      await words.learn('cake', snacks);
      expect((await words.lookup(['cake']))['cake'], snacks);
      expect(await words.watchAll().first, {'coffee': snacks, 'saree': gifts, 'cake': snacks});
      await words.forget('coffee');
      expect(await words.forgetCategory(snacks), 1);
      expect(await words.watchAll().first, {'saree': gifts});
    });
  });

  group('maintenance', () {
    test('delete all data wipes everything and re-seeds; settings stay', () async {
      final store = SettingsStore(db);
      await store.write(AppSettings.kMood, 'coral');
      final trip = await pockets.add(name: 'Trip', emoji: '\u{1F3D6}\u{FE0F}');
      final source = File(p.join(temp.path, 'pick.jpg'))..writeAsBytesSync([1, 2, 3]);
      final photo = await photos.savePicked(source.path);
      await expenses.add(
        pocketId: trip,
        categoryId: await catId('Gym'),
        amount: 1,
        day: today,
        photoPath: photo,
      );
      await categories.add(name: 'Pets', emoji: '\u{1F436}', color: CategoryColor.cyan.argb);
      await words.learn('coffee', await catId('Snacks'));

      final cache = Directory(p.join(temp.path, 'cache'))..createSync();
      File(p.join(cache.path, 'export.csv')).writeAsStringSync('x');
      final m = DataMaintenance(db, photos: photos, cacheDir: () async => cache);
      final newPocket = await m.deleteAllData();

      final ps = await pockets.all();
      expect(ps.single.id, newPocket);
      expect(ps.single.name, 'Personal');
      expect(ps.single.isDefault, isTrue);
      expect(await categories.all(), hasLength(15));
      expect(await expenses.count(newPocket), 0);
      expect(await words.watchAll().first, isEmpty);
      expect((await photos.file(photo)).existsSync(), isFalse);
      expect(cache.listSync(), isEmpty);
      expect((await store.load())[AppSettings.kMood], 'coral');
    });

    test('clear cache frees temp files and orphan photos only', () async {
      final pocket = (await pockets.defaultPocket()).id;
      final source = File(p.join(temp.path, 'pick.jpg'))..writeAsBytesSync(List.filled(100, 7));
      final kept = await photos.savePicked(source.path);
      final orphan = await photos.savePicked(source.path);
      final id = await expenses.add(
        pocketId: pocket,
        categoryId: await catId('Gym'),
        amount: 1,
        day: today,
        photoPath: kept,
      );
      final orphanOwner = await expenses.add(
        pocketId: pocket,
        categoryId: await catId('Gym'),
        amount: 2,
        day: today,
        photoPath: orphan,
      );
      await expenses.delete(orphanOwner); // its photo stays until purged

      final cache = Directory(p.join(temp.path, 'cache'))..createSync();
      File(p.join(cache.path, 'old_export.xlsx')).writeAsBytesSync(List.filled(50, 1));
      final m = DataMaintenance(db, photos: photos, cacheDir: () async => cache);
      final freed = await m.clearCache();
      expect(freed, 150);
      expect((await photos.file(kept)).existsSync(), isTrue);
      expect((await photos.file(orphan)).existsSync(), isFalse);
      expect(await expenses.get(id), isNotNull);
      expect(formatBytes(freed), '0 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    });
  });

  group('settings', () {
    test('round trip through the table, broken values fall back', () async {
      final store = SettingsStore(db);
      const s = AppSettings(
        mood: Mood.iris,
        textScale: 17 / 15,
        privacyMask: true,
        firstDayOfWeek: FirstDayOfWeek.monday,
        thousandsSeparator: false,
        calcKeys: CalcKeys.allFour,
        currentPocketId: 7,
        lastCustomRange: (from: 20700, to: 20744),
      );
      for (final e in s.toEntries().entries) {
        await store.write(e.key, e.value);
      }
      final loaded = await AppSettings.load(store);
      expect(loaded, s);
      expect(loaded.textSizeIndex, 3);
      expect(AppSettings.fromEntries({'mood': 'nope', 'privacyMask': 'x'}),
          const AppSettings());
      expect(const AppSettings().copyWith(currentPocketId: () => null).currentPocketId, isNull);
    });
  });
}
