import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart' as csvlib;
import 'package:excel/excel.dart' as xl;

import '../../core/days.dart';

/// One cell of an imported file, typed at the boundary so the rest of the
/// import never touches the packages' untyped values.
sealed class ImportCell {
  const ImportCell();

  /// The cell as the file shows it (used for samples and text parsing).
  String get text;

  bool get isEmpty => text.trim().isEmpty;
}

/// A text cell (every CSV cell, and text cells of a spreadsheet).
final class TextCell extends ImportCell {
  const TextCell(this.text);

  @override
  final String text;
}

/// A number cell of a spreadsheet or a JSON number.
final class NumberCell extends ImportCell {
  const NumberCell(this.value);

  final double value;

  @override
  String get text {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

/// A date cell of a spreadsheet, as a day number.
final class DateCell extends ImportCell {
  const DateCell(this.day);

  final int day;

  @override
  String get text {
    final d = dateOfDay(day);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

/// One data row; [line] is its row number in the file (1 = first line), so
/// the review can point at "Row 14" the way a spreadsheet shows it.
class ImportRow {
  const ImportRow({required this.line, required this.cells});

  final int line;
  final List<ImportCell> cells;

  ImportCell cell(int column) =>
      column >= 0 && column < cells.length ? cells[column] : const TextCell('');
}

/// A file read into a header row and data rows.
class ImportTable {
  const ImportTable({
    required this.fileName,
    required this.headers,
    required this.rows,
  });

  final String fileName;

  /// One name per column ("Column C" when the file has no header row).
  final List<String> headers;
  final List<ImportRow> rows;

  int get columnCount => headers.length;

  /// The first non-empty value of [column], as the file writes it.
  String? sample(int column) {
    for (final r in rows) {
      final c = r.cell(column);
      if (!c.isEmpty) return c.text.trim();
    }
    return null;
  }
}

enum ImportFileKind { csv, xlsx, json }

/// Why a file could not be read; [message] is shown to the user.
class ImportFileError implements Exception {
  const ImportFileError(this.message);

  final String message;

  @override
  String toString() => message;
}

ImportFileKind? importKindOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return switch (fileName.substring(dot + 1).toLowerCase()) {
    'csv' || 'txt' => ImportFileKind.csv,
    'xlsx' => ImportFileKind.xlsx,
    'json' => ImportFileKind.json,
    _ => null,
  };
}

/// Spreadsheet-style column name: 0 -> A, 25 -> Z, 26 -> AA.
String columnLetter(int index) {
  var n = index;
  var out = '';
  do {
    out = String.fromCharCode(65 + n % 26) + out;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return out;
}

/// Reads a CSV, Excel (.xlsx) or JSON file. Throws [ImportFileError].
ImportTable readImportTable(String fileName, Uint8List bytes) {
  final kind = importKindOf(fileName);
  final List<List<ImportCell>> grid = switch (kind) {
    ImportFileKind.csv => _readCsv(bytes),
    ImportFileKind.xlsx => _readXlsx(bytes),
    ImportFileKind.json => _readJson(bytes),
    null => throw const ImportFileError(
      'Choose a CSV, Excel (.xlsx) or JSON file.',
    ),
  };
  return tableFromGrid(
    fileName,
    grid,
    jsonHeaders: kind == ImportFileKind.json,
  );
}

/// Turns raw rows into a table: drops empty rows, finds the header row.
ImportTable tableFromGrid(
  String fileName,
  List<List<ImportCell>> grid, {
  bool jsonHeaders = false,
}) {
  final lines = <ImportRow>[];
  for (var i = 0; i < grid.length; i++) {
    final cells = grid[i];
    if (cells.every((c) => c.isEmpty)) continue;
    lines.add(ImportRow(line: i + 1, cells: cells));
  }
  if (lines.isEmpty) {
    throw const ImportFileError('This file is empty.');
  }
  var width = 0;
  for (final l in lines) {
    if (l.cells.length > width) width = l.cells.length;
  }
  final first = lines.first;
  final hasHeader = jsonHeaders || !first.cells.any(_looksLikeData);
  final headers = <String>[
    for (var col = 0; col < width; col++)
      hasHeader && first.cell(col).text.trim().isNotEmpty
          ? first.cell(col).text.trim()
          : 'Column ${columnLetter(col)}',
  ];
  return ImportTable(
    fileName: fileName,
    headers: headers,
    rows: hasHeader ? lines.sublist(1) : lines,
  );
}

final RegExp _dataLike = RegExp(r'^[\d\s.,/:\-()+]+$');

bool _looksLikeData(ImportCell cell) => switch (cell) {
  NumberCell() || DateCell() => true,
  TextCell(:final text) =>
    _dataLike.hasMatch(text.trim()) && text.contains(RegExp(r'\d')),
};

List<List<ImportCell>> _readCsv(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  if (text.trim().isEmpty) throw const ImportFileError('This file is empty.');
  final List<List<Object?>> raw;
  try {
    raw = csvlib.Csv(skipEmptyLines: false).decode(text);
  } on FormatException {
    throw const ImportFileError("This file can't be read as CSV.");
  }
  return [
    for (final row in raw)
      [for (final Object? f in row) TextCell(f == null ? '' : f.toString())],
  ];
}

List<List<ImportCell>> _readXlsx(Uint8List bytes) {
  final xl.Excel book;
  try {
    book = xl.Excel.decodeBytes(bytes);
  } on Object {
    throw const ImportFileError("This Excel file can't be opened.");
  }
  for (final sheet in book.tables.values) {
    final rows = sheet.rows;
    if (rows.isEmpty) continue;
    final grid = [
      for (final row in rows) [for (final data in row) _cellOf(data?.value)],
    ];
    if (grid.any((r) => r.any((c) => !c.isEmpty))) return grid;
  }
  throw const ImportFileError('This file is empty.');
}

ImportCell _cellOf(xl.CellValue? v) => switch (v) {
  null => const TextCell(''),
  xl.TextCellValue(:final value) => TextCell(value.toString()),
  xl.IntCellValue(:final value) => NumberCell(value.toDouble()),
  xl.DoubleCellValue(:final value) => NumberCell(value),
  xl.DateCellValue(:final year, :final month, :final day) => DateCell(
    dayOf(year, month, day),
  ),
  xl.DateTimeCellValue(:final year, :final month, :final day) => DateCell(
    dayOf(year, month, day),
  ),
  xl.BoolCellValue(:final value) => TextCell(value ? 'TRUE' : 'FALSE'),
  xl.TimeCellValue() => TextCell(v.toString()),
  xl.FormulaCellValue() => const TextCell(''),
};

List<List<ImportCell>> _readJson(Uint8List bytes) {
  final Object? root;
  try {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    root = jsonDecode(text);
  } on FormatException {
    throw const ImportFileError("This file can't be read as JSON.");
  }
  final items = _jsonItems(root);
  if (items == null || items.isEmpty) {
    throw const ImportFileError('This JSON file has no list of expenses.');
  }
  final keys = <String>[];
  for (final item in items) {
    for (final Object? k in item.keys) {
      final key = '$k';
      if (!keys.contains(key)) keys.add(key);
    }
  }
  final grid = <List<ImportCell>>[
    [for (final k in keys) TextCell(k)],
  ];
  for (final item in items) {
    final byKey = <String, Object?>{
      for (final MapEntry<Object?, Object?> e in item.entries)
        '${e.key}': e.value,
    };
    grid.add([for (final k in keys) _jsonCell(byKey[k])]);
  }
  return grid;
}

/// The list of objects in a JSON file: the root list, or the first list of
/// objects inside the root object (e.g. `{"expenses": [...]}`).
List<Map<Object?, Object?>>? _jsonItems(Object? root) {
  List<Map<Object?, Object?>>? asItems(Object? v) {
    if (v is! List) return null;
    final out = <Map<Object?, Object?>>[];
    for (final Object? e in v) {
      if (e is Map) out.add(e);
    }
    return out.isEmpty ? null : out;
  }

  final direct = asItems(root);
  if (direct != null) return direct;
  if (root is Map) {
    for (final Object? v in root.values) {
      final found = asItems(v);
      if (found != null) return found;
    }
  }
  return null;
}

ImportCell _jsonCell(Object? v) => switch (v) {
  null => const TextCell(''),
  final String s => TextCell(s),
  final num n => NumberCell(n.toDouble()),
  final bool b => TextCell(b ? 'true' : 'false'),
  _ => TextCell(jsonEncode(v)),
};
