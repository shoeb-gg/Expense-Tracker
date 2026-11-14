import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart' as csvlib;
import 'package:excel/excel.dart' as xl;
import 'package:path/path.dart' as p;

import '../../core/days.dart';
import '../../data/db.dart';

enum ExportFormat {
  xlsx(
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ),
  csv('csv', 'text/csv');

  const ExportFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

/// The column names of an exported file. Import recognises them, so an
/// exported file goes straight back in.
const List<String> exportHeaders = ['Date', 'Category', 'Title', 'Amount'];

/// One exported row: one expense.
class ExportRow {
  const ExportRow({
    required this.day,
    required this.category,
    required this.title,
    required this.amount,
  });

  final int day;
  final String category;
  final String title;

  /// Minor units.
  final int amount;
}

/// Rows oldest first (a spreadsheet reads top to bottom). Expenses come
/// newest first from the repository.
List<ExportRow> exportRows(
  List<Expense> expenses,
  Map<int, ExpenseCategory> categories,
) {
  final sorted = [...expenses]
    ..sort((a, b) {
      final byDay = a.day.compareTo(b.day);
      if (byDay != 0) return byDay;
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  return [
    for (final e in sorted)
      ExportRow(
        day: e.day,
        category: categories[e.categoryId]?.name ?? miscCategoryName,
        title: e.note,
        amount: e.amount,
      ),
  ];
}

/// "2026-10-18".
String isoDay(int day) {
  final d = dateOfDay(day);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Plain decimal with a dot and no grouping: 118000 -> "1180", 1250 -> "12.50".
String plainAmount(int minor) {
  final whole = minor ~/ 100;
  final cents = minor % 100;
  return cents == 0 ? '$whole' : '$whole.${cents.toString().padLeft(2, '0')}';
}

/// CSV text with a UTF-8 byte-order mark so spreadsheet apps read emoji and
/// accents correctly.
String encodeCsv(List<ExportRow> rows) {
  final codec = csvlib.Csv(addBom: true);
  return codec.encode([
    exportHeaders,
    for (final r in rows)
      [isoDay(r.day), r.category, r.title, plainAmount(r.amount)],
  ]);
}

/// An Excel workbook with one sheet, "Expenses". Dates are real date cells
/// and amounts real numbers, so the user can sort and sum them.
Uint8List encodeXlsx(List<ExportRow> rows) {
  final book = xl.Excel.createExcel();
  final first = book.getDefaultSheet() ?? 'Sheet1';
  book.rename(first, 'Expenses');
  book.setDefaultSheet('Expenses');
  final sheet = book['Expenses'];
  final bold = xl.CellStyle(bold: true);
  sheet.appendRow([for (final h in exportHeaders) xl.TextCellValue(h)]);
  for (var col = 0; col < exportHeaders.length; col++) {
    sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
            .cellStyle =
        bold;
  }
  for (final r in rows) {
    final d = dateOfDay(r.day);
    sheet.appendRow([
      xl.DateCellValue(year: d.year, month: d.month, day: d.day),
      xl.TextCellValue(r.category),
      xl.TextCellValue(r.title),
      r.amount % 100 == 0
          ? xl.IntCellValue(r.amount ~/ 100)
          : xl.DoubleCellValue(r.amount / 100),
    ]);
  }
  sheet.setColumnWidth(0, 14);
  sheet.setColumnWidth(1, 22);
  sheet.setColumnWidth(2, 32);
  sheet.setColumnWidth(3, 12);
  final bytes = book.encode();
  if (bytes == null) throw StateError('The Excel file could not be written');
  return Uint8List.fromList(bytes);
}

Uint8List encodeExport(List<ExportRow> rows, ExportFormat format) =>
    switch (format) {
      ExportFormat.xlsx => encodeXlsx(rows),
      ExportFormat.csv => Uint8List.fromList(utf8.encode(encodeCsv(rows))),
    };

/// "Spill the Bills - Personal - 2026-10-01 to 2026-10-18.xlsx".
String exportFileName({
  required String pocketName,
  required int from,
  required int to,
  required ExportFormat format,
}) {
  final pocket = pocketName
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
      .trim();
  final span = from == to ? isoDay(from) : '${isoDay(from)} to ${isoDay(to)}';
  final parts = ['Spill the Bills', if (pocket.isNotEmpty) pocket, span];
  return '${parts.join(' - ')}.${format.extension}';
}

/// Writes the file to `<cache>/exports/`, where Clear cache removes it.
Future<File> writeExportFile({
  required Directory cacheDir,
  required String fileName,
  required Uint8List bytes,
}) async {
  final dir = Directory(p.join(cacheDir.path, 'exports'));
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
