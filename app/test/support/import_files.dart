import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart' as csvlib;
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/data/export_logic.dart';

Uint8List _csv(List<List<String>> rows) =>
    Uint8List.fromList(utf8.encode(csvlib.Csv().encode(rows)));

String _ddmm(int day) {
  final d = dateOfDay(day);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// The file drawn on "Import: step 2": expenses-2025.csv, 312 rows, columns
/// Date, Amount, Type and Note, dates that read both ways (05/03/2025).
Uint8List step2File() {
  const types = ['Groceries', 'Snacks', 'Transportation', 'Health', 'Pets'];
  final rows = <List<String>>[
    ['Date', 'Amount', 'Type', 'Note'],
    ['05/03/2025', '1,250.00', 'Groceries', 'Weekly bazaar'],
  ];
  for (var i = 1; i < 312; i++) {
    final day = dayOf(2025, 1 + i % 12, 1 + (i * 7) % 12);
    rows.add([
      _ddmm(day),
      '${100 + i * 5}.00',
      types[i % types.length],
      'Row ${i + 1}',
    ]);
  }
  return _csv(rows);
}

/// The file drawn on "Import: step 3", built against the sample data:
/// 312 rows = 298 new (412,560 from Mar 2 to Dec 30, 2025), 11 already in
/// the app, rows 14, 87 and 203 unreadable, and two new categories (Pets,
/// Travel).
Future<Uint8List> step3File(AppDatabase db) async {
  final pocket = (await PocketsRepo(db).defaultPocket()).id;
  final names = {for (final c in await CategoriesRepo(db).all()) c.id: c.name};
  final existing = await ExpensesRepo(
    db,
  ).listRange(pocket, dayOf(2025, 3, 4), dayOf(2025, 12, 29));
  final dups = existing.take(11).toList();
  const bad = {12, 85, 201};
  const dupAt = [3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15];
  const cycle = ['Groceries', 'Snacks', 'Travel', 'Health'];
  final rows = <List<String>>[
    ['Date', 'Amount', 'Type', 'Note'],
  ];
  var k = 0;
  for (var r = 0; r < 312; r++) {
    if (r == 0) {
      rows.add(['2025-03-02', '2450', 'Groceries', 'Weekly bazaar']);
    } else if (r == 1) {
      rows.add(['2025-03-03', '600', 'Transportation', 'Bus pass']);
    } else if (r == 2) {
      rows.add(['2025-03-03', '890', 'Pets', 'Cat food']);
    } else if (bad.contains(r)) {
      rows.add(['', '', 'Groceries', 'Lost receipt']);
    } else if (dupAt.contains(r)) {
      final e = dups[dupAt.indexOf(r)];
      rows.add([
        isoDay(e.day),
        plainAmount(e.amount),
        names[e.categoryId]!,
        e.note,
      ]);
    } else {
      final day = dayOf(2025, 3, 4) + (k * 301) ~/ 294;
      final amount = k < 294 ? '1385' : '1430';
      rows.add([isoDay(day), amount, cycle[k % cycle.length], 'Item ${k + 1}']);
      k++;
    }
  }
  return _csv(rows);
}

/// A file whose amount column cannot be found ("Choose a column").
Uint8List noAmountFile() => _csv([
  ['When', 'Shop'],
  ['2025-03-05', 'Bazaar'],
  ['2025-03-06', 'Pharmacy'],
]);
