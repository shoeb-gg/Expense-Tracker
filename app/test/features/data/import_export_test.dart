import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/data/data_providers.dart';
import 'package:spill_the_bills/features/data/export_logic.dart';
import 'package:spill_the_bills/features/data/import_logic.dart';
import 'package:spill_the_bills/features/data/import_table.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../../support/sample_data.dart';
import '../../support/test_db.dart';

Uint8List csvBytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  late AppDatabase db;
  late ExpensesRepo expenses;
  late CategoriesRepo categories;
  late PocketsRepo pockets;
  late int personal;
  final clock = Clock.fixed(mockupNow);

  setUp(() async {
    db = openTestDatabase();
    expenses = ExpensesRepo(db, clock: clock);
    categories = CategoriesRepo(db, clock: clock);
    pockets = PocketsRepo(db, clock: clock);
    personal = (await pockets.defaultPocket()).id;
  });
  tearDown(() => db.close());

  Future<Map<int, ExpenseCategory>> catsById() async => {
    for (final c in await categories.all()) c.id: c,
  };

  Future<ImportPlan> plan(ImportSession s, int pocketId) => planImport(
    table: s.table,
    settings: s.settings,
    pocketId: pocketId,
    categories: categories,
    expenses: expenses,
  );

  group('export', () {
    test('rows are oldest first with category names', () async {
      final groceries = (await categories.findByName('Groceries'))!;
      await expenses.add(
        pocketId: personal,
        categoryId: groceries.id,
        amount: 125050,
        day: dayOf(2026, 10, 2),
        note: 'Weekly bazaar',
      );
      await expenses.add(
        pocketId: personal,
        categoryId: groceries.id,
        amount: 30000,
        day: dayOf(2026, 10, 1),
      );
      final list = await expenses.listRange(
        personal,
        dayOf(2026, 10, 1),
        dayOf(2026, 10, 31),
      );
      final rows = exportRows(list, await catsById());
      expect(rows.map((r) => r.day), [dayOf(2026, 10, 1), dayOf(2026, 10, 2)]);
      final csv = encodeCsv(rows);
      expect(csv.startsWith('﻿'), isTrue);
      expect(csv.substring(1).split('\r\n').take(3).toList(), [
        'Date,Category,Title,Amount',
        '2026-10-01,Groceries,,300',
        '2026-10-02,Groceries,Weekly bazaar,1250.50',
      ]);
    });

    test('files keep exact cents, whatever the display settings', () {
      // The files are written from the stored minor units, never from the
      // formatted text, so "Show decimals" and the number style do not
      // reach them.
      final day = dayOf(2026, 10, 18);
      final rows = [
        for (final amount in [84050, 84025, 50, 84000, 123456789])
          ExportRow(day: day, category: 'Groceries', title: 'x', amount: amount),
      ];
      expect(encodeCsv(rows).substring(1).split('\r\n').skip(1).take(5).toList(), [
        '2026-10-18,Groceries,x,840.50',
        '2026-10-18,Groceries,x,840.25',
        '2026-10-18,Groceries,x,0.50',
        '2026-10-18,Groceries,x,840',
        '2026-10-18,Groceries,x,1234567.89',
      ]);
      final book = readImportTable('x.xlsx', encodeXlsx(rows));
      expect([
        for (final r in book.rows) parseAmountCell(r.cell(3), decimalMark: '.'),
      ], [84050, 84025, 50, 84000, 123456789]);
    });

    test('file name names the pocket and the range', () {
      expect(
        exportFileName(
          pocketName: 'Family: trip?',
          from: dayOf(2026, 10, 1),
          to: dayOf(2026, 10, 18),
          format: ExportFormat.xlsx,
        ),
        'Spill the Bills - Family trip - 2026-10-01 to 2026-10-18.xlsx',
      );
      expect(plainAmount(118000), '1180');
      expect(plainAmount(1205), '12.05');
    });
  });

  group('round trip', () {
    Future<void> roundTrip(ExportFormat format) async {
      await fillSampleData(db);
      final from = dayOf(2026, 9, 1);
      final to = dayOf(2026, 10, 18);
      final list = await expenses.listRange(personal, from, to);
      expect(list, isNotEmpty);
      final bytes = encodeExport(exportRows(list, await catsById()), format);

      final table = readImportTable('back.${format.extension}', bytes);
      expect(table.headers, exportHeaders);
      expect(table.rows.length, list.length);
      final session = ImportSession.start(table);
      expect(session.mapping, {
        ImportField.date: 0,
        ImportField.category: 1,
        ImportField.title: 2,
        ImportField.amount: 3,
      });
      expect(session.scan.ambiguous, isFalse);

      // Into an empty pocket: everything is new, nothing created.
      final business = await pockets.add(name: 'Business', emoji: '💼');
      final p1 = await plan(session, business);
      expect(p1.toAdd.length, list.length);
      expect(p1.bad, isEmpty);
      expect(p1.newCategories, isEmpty);
      expect(p1.total, list.fold<int>(0, (s, e) => s + e.amount));
      await applyImport(
        plan: p1,
        pocketId: business,
        categories: categories,
        expenses: expenses,
      );
      final copied = await expenses.listRange(business, from, to);
      String sig(Expense e) => '${e.day}|${e.amount}|${e.categoryId}|${e.note}';
      expect(copied.map(sig).toList()..sort(), list.map(sig).toList()..sort());

      // Back into the pocket it came from: every row is already there.
      final p2 = await plan(session, personal);
      expect(p2.toAdd, isEmpty);
      expect(p2.skipped, list.length);
    }

    test('CSV', () => roundTrip(ExportFormat.csv));
    test('Excel', () => roundTrip(ExportFormat.xlsx));
  });

  group('reading files', () {
    test('CSV with semicolons and a byte-order mark', () {
      final t = readImportTable(
        'a.csv',
        csvBytes(
          '﻿When;Spent;Type;Note\n05/03/2025;1.250,00;Groceries;Weekly bazaar\n\n',
        ),
      );
      expect(t.headers, ['When', 'Spent', 'Type', 'Note']);
      expect(t.rows.single.line, 2);
      expect(t.sample(1), '1.250,00');
    });

    test('a file without a header row gets lettered columns', () {
      final t = readImportTable(
        'a.csv',
        csvBytes('2025-03-02,2450,Groceries\n2025-03-03,600,Transportation\n'),
      );
      expect(t.headers, ['Column A', 'Column B', 'Column C']);
      expect(t.rows.length, 2);
      final m = guessColumns(t);
      expect(m[ImportField.date], 0);
      expect(m[ImportField.amount], 1);
      expect(m.containsKey(ImportField.category), isFalse);
    });

    test('JSON list of objects', () {
      final t = readImportTable(
        'a.json',
        csvBytes(
          jsonEncode({
            'expenses': [
              {'date': '2025-03-02', 'amount': 2450, 'category': 'Groceries'},
              {'date': '2025-03-03', 'amount': 600.5, 'note': 'Bus pass'},
            ],
          }),
        ),
      );
      expect(t.headers, ['date', 'amount', 'category', 'note']);
      expect(t.rows[1].cell(1), isA<NumberCell>());
      expect(parseAmountCell(t.rows[1].cell(1), decimalMark: '.'), 60050);
    });

    test('unsupported and empty files', () {
      expect(
        () => readImportTable('a.pdf', csvBytes('x')),
        throwsA(isA<ImportFileError>()),
      );
      expect(
        () => readImportTable('a.csv', csvBytes('\n\n')),
        throwsA(isA<ImportFileError>()),
      );
      expect(
        () => readImportTable('a.xlsx', csvBytes('not a zip')),
        throwsA(isA<ImportFileError>()),
      );
    });
  });

  group('column mapping', () {
    test('guesses by header names, including Type and Note', () {
      final t = readImportTable(
        'a.csv',
        csvBytes('Note,Type,Amount,Date\nBus,Transport,50,2025-03-02\n'),
      );
      expect(guessColumns(t), {
        ImportField.date: 3,
        ImportField.amount: 2,
        ImportField.category: 1,
        ImportField.title: 0,
      });
    });

    test('changing a column moves it away from another field', () {
      final t = readImportTable(
        'a.csv',
        csvBytes('Date,Amount,Type,Note\n2025-03-02,50,Bus,x\n'),
      );
      var s = ImportSession.start(t);
      s = s.withColumn(ImportField.title, 2);
      expect(s.mapping[ImportField.title], 2);
      expect(s.mapping.containsKey(ImportField.category), isFalse);
      expect(s.foundCount, 3);
      s = s.withColumn(ImportField.amount, null);
      expect(s.ready, isFalse);
    });
  });

  group('dates', () {
    test('ambiguous file asks; a day above 12 settles it', () {
      final ambiguous = readImportTable(
        'a.csv',
        csvBytes('Date,Amount\n05/03/2025,10\n07/04/2025,20\n'),
      );
      final scan = scanDates(ambiguous, 0);
      expect(scan.ambiguous, isTrue);
      expect(scan.example, '05/03/2025');
      expect(
        parseDateText('05/03/2025', DateOrder.dayFirst),
        dayOf(2025, 3, 5),
      );
      expect(
        parseDateText('05/03/2025', DateOrder.monthFirst),
        dayOf(2025, 5, 3),
      );
      expect(fullDate(dayOf(2025, 3, 5)), 'March 5, 2025');

      final settled = readImportTable(
        'a.csv',
        csvBytes('Date,Amount\n05/03/2025,10\n25/03/2025,20\n'),
      );
      final s = ImportSession.start(settled);
      expect(s.scan.ambiguous, isFalse);
      expect(s.order, DateOrder.dayFirst);

      final us = readImportTable(
        'a.csv',
        csvBytes('Date,Amount\n12/25/2025,10\n'),
      );
      expect(ImportSession.start(us).order, DateOrder.monthFirst);
    });

    test('other date forms', () {
      expect(
        parseDateText('2025-03-02', DateOrder.monthFirst),
        dayOf(2025, 3, 2),
      );
      expect(
        parseDateText('2025/3/2 14:05', DateOrder.dayFirst),
        dayOf(2025, 3, 2),
      );
      expect(
        parseDateText('Oct 18, 2026', DateOrder.dayFirst),
        dayOf(2026, 10, 18),
      );
      expect(
        parseDateText('Sun, Oct 18, 2026', DateOrder.dayFirst),
        dayOf(2026, 10, 18),
      );
      expect(
        parseDateText('18 October 2026', DateOrder.dayFirst),
        dayOf(2026, 10, 18),
      );
      expect(
        parseDateText('18-Sept-26', DateOrder.dayFirst),
        dayOf(2026, 9, 18),
      );
      expect(parseDateText('31/02/2025', DateOrder.dayFirst), isNull);
      expect(parseDateText('soon', DateOrder.dayFirst), isNull);
      expect(
        parseDateCell(const NumberCell(45718), DateOrder.dayFirst),
        dayOf(2025, 3, 2),
      );
    });
  });

  group('amounts', () {
    test('marks, signs and currency words', () {
      expect(parseAmountText('1,250.00', decimalMark: '.'), 125000);
      expect(parseAmountText('1.250,50', decimalMark: ','), 125050);
      expect(parseAmountText('1 234 567,8', decimalMark: ','), 123456780);
      expect(parseAmountText('(45.50)', decimalMark: '.'), 4550);
      expect(parseAmountText('-12', decimalMark: '.'), 1200);
      expect(parseAmountText('Tk. 1,250', decimalMark: '.'), 125000);
      expect(parseAmountText('৳300', decimalMark: '.'), 30000);
      expect(parseAmountText('12.345', decimalMark: '.'), 1235);
      expect(parseAmountText('0', decimalMark: '.'), isNull);
      expect(parseAmountText('', decimalMark: '.'), isNull);
      expect(parseAmountText('n/a', decimalMark: '.'), isNull);
    });

    test('a comma-decimal file still imports exactly', () async {
      // The decimal mark comes from the file, not from the number style.
      const file =
          'Date,Amount,Category,Title\n'
          '2025-03-02,"12,50",Groceries,Bazaar\n'
          '2025-03-03,"1.200,75",Groceries,Rent\n'
          '2025-03-04,"840,5",Groceries,Half\n';
      final s = ImportSession.start(readImportTable('c.csv', csvBytes(file)));
      expect(s.settings.decimalMark, ',');
      final p = await plan(s, personal);
      expect([for (final e in p.toAdd) e.amount], [1250, 120075, 84050]);
      expect(p.total, 1250 + 120075 + 84050);
      expect(p.bad, isEmpty);

      const dotFile =
          'Date,Amount,Category,Title\n'
          '2025-03-02,"1,250.50",Groceries,Bazaar\n'
          '2025-03-03,12.5,Groceries,Rent\n';
      final d = ImportSession.start(readImportTable('d.csv', csvBytes(dotFile)));
      expect(d.settings.decimalMark, '.');
      final q = await plan(d, personal);
      expect([for (final e in q.toAdd) e.amount], [125050, 1250]);
    });

    test('the decimal mark is read from the column', () {
      final comma = readImportTable(
        'a.csv',
        csvBytes('Date,Amount\n2025-03-02,"12,50"\n2025-03-03,"1.200,75"\n'),
      );
      expect(detectDecimalMark(comma, 1), ',');
      final dot = readImportTable(
        'a.csv',
        csvBytes('Date,Amount\n2025-03-02,"1,250"\n2025-03-03,12.5\n'),
      );
      expect(detectDecimalMark(dot, 1), '.');
      final thousands = readImportTable(
        'a.csv',
        csvBytes('Date,Amount\n2025-03-02,1.250\n2025-03-03,2.000\n'),
      );
      expect(detectDecimalMark(thousands, 1), ',');
    });
  });

  group('review', () {
    const file =
        'Date,Amount,Category,Title\n'
        '2025-03-02,2450,Groceries,Weekly bazaar\n'
        '2025-03-03,600,transportation,Bus pass\n'
        '2025-03-03,890,Pets,Cat food\n'
        ',100,Groceries,No date\n'
        '2025-03-04,,Groceries,No amount\n'
        '2025-03-05,75,,Blank category\n'
        '2025-03-06,40,Travel,Taxi\n'
        'later,,,\n';

    test('bad rows, new categories, blank category and matching', () async {
      final s = ImportSession.start(readImportTable('a.csv', csvBytes(file)));
      final p = await plan(s, personal);
      expect(p.rowCount, 8);
      expect(p.toAdd.length, 5);
      expect(p.bad.map((b) => b.line), [5, 6, 9]);
      expect(badRowsLine(p.bad), 'Rows 5, 6, 9 · no date or amount');
      expect(badRowsLine(p.bad.take(1).toList()), 'Row 5 · no date');
      expect(p.newCategories, ['Pets', 'Travel']);
      expect(
        newCategoriesLine(p.newCategories),
        'Pets and Travel will be created',
      );
      expect(p.toAdd[1].categoryName, 'Transportation');
      expect(p.toAdd[1].newCategory, isFalse);
      expect(p.toAdd[3].categoryName, miscCategoryName);
      expect(p.total, (2450 + 600 + 890 + 75 + 40) * 100);
      expect(importSpan(p.firstDay!, p.lastDay!), 'Mar 2 to Mar 6, 2025');
    });

    test(
      'import creates categories; Undo removes everything it added',
      () async {
        final before = await expenses.count(personal);
        final catsBefore = (await categories.all()).length;
        final s = ImportSession.start(readImportTable('a.csv', csvBytes(file)));
        final p = await plan(s, personal);
        final result = await applyImport(
          plan: p,
          pocketId: personal,
          categories: categories,
          expenses: expenses,
        );
        expect(result.count, 5);
        expect(await expenses.count(personal), before + 5);
        final pets = (await categories.findByName('pets'))!;
        expect(pets.emoji, importedCategoryEmoji);
        expect(
          (await categories.all()).last.isMisc,
          isTrue,
          reason: 'new categories go before Miscellaneous',
        );

        // Importing the same file again skips what is now in the app.
        final again = await plan(s, personal);
        expect(again.toAdd, isEmpty);
        expect(again.skipped, 5);
        expect(again.newCategories, isEmpty);

        await undoImport(
          result: result,
          categories: categories,
          expenses: expenses,
        );
        expect(await expenses.count(personal), before);
        expect((await categories.all()).length, catsBefore);
        expect(await categories.findByName('Pets'), isNull);
      },
    );

    test('new categories get colours nobody has, then the palette in turn',
        () async {
      // The 15 defaults leave Red, Yellow and Sand free.
      const names = ['Pets', 'Travel', 'Books', 'Toys', 'Fish'];
      final file =
          'date,amount,category,title\n'
          '${[for (final n in names) '2025-03-02,10,$n,x'].join('\n')}\n';
      final s = ImportSession.start(readImportTable('b.csv', csvBytes(file)));
      final p = await plan(s, personal);
      expect(p.newCategories, names);
      await applyImport(
        plan: p,
        pocketId: personal,
        categories: categories,
        expenses: expenses,
      );
      Future<int> colourOf(String name) async =>
          (await categories.findByName(name))!.color;
      expect(await colourOf('Pets'), CategoryColor.red.argb);
      expect(await colourOf('Travel'), CategoryColor.yellow.argb);
      expect(await colourOf('Books'), CategoryColor.sand.argb);
      // Everything is taken now: back to the start of the palette.
      expect(await colourOf('Toys'), CategoryColor.blue.argb);
      expect(await colourOf('Fish'), CategoryColor.green.argb);
    });

    test('a category that already exists takes no colour from the import',
        () async {
      final file =
          'date,amount,category,title\n'
          '2025-03-02,10,groceries,x\n'
          '2025-03-02,10,Pets,x\n';
      final s = ImportSession.start(readImportTable('c.csv', csvBytes(file)));
      final p = await plan(s, personal);
      expect(p.newCategories, ['Pets']);
      await applyImport(
        plan: p,
        pocketId: personal,
        categories: categories,
        expenses: expenses,
      );
      expect(
        (await categories.findByName('Pets'))!.color,
        CategoryColor.red.argb,
      );
    });

    test('Undo keeps a created category that is now in use', () async {
      final s = ImportSession.start(readImportTable('a.csv', csvBytes(file)));
      final result = await applyImport(
        plan: await plan(s, personal),
        pocketId: personal,
        categories: categories,
        expenses: expenses,
      );
      final travel = (await categories.findByName('Travel'))!;
      await expenses.add(
        pocketId: personal,
        categoryId: travel.id,
        amount: 100,
        day: dayOf(2025, 4, 1),
      );
      await undoImport(
        result: result,
        categories: categories,
        expenses: expenses,
      );
      expect(await categories.findByName('Travel'), isNotNull);
      expect(await categories.findByName('Pets'), isNull);
    });

    test('a file with no usable rows plans nothing', () async {
      final s = ImportSession.start(
        readImportTable('a.csv', csvBytes('Date,Amount\nsoon,lots\nlater,\n')),
      );
      final p = await plan(s, personal);
      expect(p.toAdd, isEmpty);
      expect(p.bad.length, 2);
      expect(p.firstDay, isNull);
    });
  });
}
