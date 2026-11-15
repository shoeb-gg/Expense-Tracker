import '../../core/days.dart';
import '../../core/format.dart';
import '../../data/categories_repo.dart';
import '../../data/db.dart';
import '../../data/expenses_repo.dart';
import '../../theme/tokens.dart';
import 'import_table.dart';

/// The four things an imported row can carry. Date and amount are needed in
/// every row; category and title are optional.
enum ImportField {
  date('Date'),
  amount('Amount'),
  category('Category'),
  title('Title');

  const ImportField(this.label);

  final String label;

  bool get required => this == date || this == amount;
}

enum DateOrder { dayFirst, monthFirst }

/// Which column of the file feeds each field (missing = not mapped).
typedef ColumnMapping = Map<ImportField, int>;

// ---------------------------------------------------------------------------
// Guessing the columns
// ---------------------------------------------------------------------------

const Map<ImportField, List<String>> _exactWords = {
  ImportField.date: ['date', 'day', 'when', 'time', 'datetime', 'on'],
  ImportField.amount: [
    'amount',
    'amt',
    'price',
    'cost',
    'sum',
    'total',
    'spent',
    'value',
    'debit',
    'money',
    'paid',
    'expense',
    'tk',
    'taka',
    'bdt',
  ],
  ImportField.category: [
    'category',
    'cat',
    'type',
    'group',
    'kind',
    'tag',
    'label',
    'class',
  ],
  ImportField.title: [
    'title',
    'note',
    'notes',
    'description',
    'desc',
    'memo',
    'details',
    'detail',
    'name',
    'item',
    'remark',
    'remarks',
    'comment',
    'narration',
    'purpose',
    'what',
    'payee',
    'merchant',
  ],
};

const Map<ImportField, List<String>> _partWords = {
  ImportField.date: ['date'],
  ImportField.amount: ['amount', 'price', 'cost', 'spent', 'total'],
  ImportField.category: ['category', 'type'],
  ImportField.title: ['title', 'note', 'description', 'memo', 'detail'],
};

String _norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z]'), '');

/// Guesses which column is which, first by the header names, then (for the
/// date and amount) by what the columns hold.
ColumnMapping guessColumns(ImportTable table) {
  final out = <ImportField, int>{};
  final taken = <int>{};
  for (final field in ImportField.values) {
    var best = -1;
    var bestScore = 0;
    for (var col = 0; col < table.columnCount; col++) {
      if (taken.contains(col)) continue;
      final h = _norm(table.headers[col]);
      if (h.isEmpty) continue;
      var score = 0;
      if (_exactWords[field]!.contains(h)) {
        score = 2;
      } else if (_partWords[field]!.any(h.contains)) {
        score = 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = col;
      }
    }
    if (best >= 0) {
      out[field] = best;
      taken.add(best);
    }
  }
  if (!out.containsKey(ImportField.date)) {
    final col = _bestByContent(table, taken, (c) => _anyDate(c) != null);
    if (col != null) {
      out[ImportField.date] = col;
      taken.add(col);
    }
  }
  if (!out.containsKey(ImportField.amount)) {
    final col = _bestByContent(
      table,
      taken,
      (c) => parseAmountCell(c, decimalMark: '.') != null,
    );
    if (col != null) {
      out[ImportField.amount] = col;
      taken.add(col);
    }
  }
  return Map.unmodifiable(out);
}

int? _bestByContent(
  ImportTable table,
  Set<int> taken,
  bool Function(ImportCell) test,
) {
  int? best;
  var bestShare = 0.6;
  for (var col = 0; col < table.columnCount; col++) {
    if (taken.contains(col)) continue;
    var filled = 0;
    var hits = 0;
    for (final r in table.rows.take(200)) {
      final c = r.cell(col);
      if (c.isEmpty) continue;
      filled++;
      if (test(c)) hits++;
    }
    if (filled == 0) continue;
    final share = hits / filled;
    if (share >= bestShare && (best == null || share > bestShare)) {
      best = col;
      bestShare = share;
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

final RegExp _numericDate = RegExp(
  r'^(\d{1,4})\s*[./\-]\s*(\d{1,2})\s*[./\-]\s*(\d{1,4})(?:[ T,].*)?$',
);

const List<String> _monthKeys = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

int? _validDay(int y, int m, int d) {
  if (y < 1900 || y > 2200 || m < 1 || m > 12 || d < 1) return null;
  if (d > daysInMonth(y, m)) return null;
  return dayOf(y, m, d);
}

int _fullYear(int y) => y < 100 ? 2000 + y : y;

/// Reads a date cell. Numeric dates like 05/03/2025 use [order]; ISO dates,
/// month names, spreadsheet dates and serial numbers need no order.
int? parseDateCell(ImportCell cell, DateOrder order) {
  switch (cell) {
    case DateCell(:final day):
      return day;
    case NumberCell(:final value):
      // Spreadsheet serial number (1954 to 2119).
      if (value >= 20000 && value < 80000) {
        return dayOf(1899, 12, 30) + value.floor();
      }
      return null;
    case TextCell(:final text):
      return parseDateText(text, order);
  }
}

int? parseDateText(String raw, DateOrder order) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final m = _numericDate.firstMatch(s);
  if (m != null) {
    final a = m.group(1)!;
    final b = int.parse(m.group(2)!);
    final cStr = m.group(3)!;
    if (a.length == 4) return _validDay(int.parse(a), b, int.parse(cStr));
    if (cStr.length == 3) return null;
    final y = _fullYear(int.parse(cStr));
    final first = int.parse(a);
    return order == DateOrder.dayFirst
        ? _validDay(y, b, first)
        : _validDay(y, first, b);
  }
  return _textMonthDate(s);
}

/// "Oct 18, 2026", "18 October 2026", "Sun, Oct 18, 2026", "18-Oct-26".
int? _textMonthDate(String s) {
  final tokens = s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  int? month;
  final numbers = <String>[];
  for (final t in tokens) {
    if (RegExp(r'^\d+$').hasMatch(t)) {
      numbers.add(t);
    } else if (t.length >= 3 && month == null) {
      final i = _monthKeys.indexOf(t.substring(0, 3));
      if (i >= 0 &&
          (t.length == 3 ||
              monthNames[i].toLowerCase().startsWith(t) ||
              t == 'sept')) {
        month = i + 1;
      }
    }
  }
  if (month == null || numbers.length < 2) return null;
  int? day;
  int? year;
  for (final n in numbers) {
    if (n.length == 4 && year == null) {
      year = int.parse(n);
    } else if (n.length <= 2 && day == null) {
      day = int.parse(n);
    } else if (n.length <= 2 && year == null) {
      year = _fullYear(int.parse(n));
    }
  }
  if (day == null || year == null) return null;
  return _validDay(year, month, day);
}

int? _anyDate(ImportCell cell) =>
    parseDateCell(cell, DateOrder.dayFirst) ??
    parseDateCell(cell, DateOrder.monthFirst);

/// What the date column says about day-first versus month-first.
class DateScan {
  const DateScan({required this.ambiguous, this.settled, this.example});

  /// True when the file can be read both ways (the user picks).
  final bool ambiguous;

  /// The order the file settles by itself (a day above 12 somewhere).
  final DateOrder? settled;

  /// A value that reads differently each way, e.g. "05/03/2025".
  final String? example;

  static const DateScan none = DateScan(ambiguous: false);
}

DateScan scanDates(ImportTable table, int? column) {
  if (column == null) return DateScan.none;
  var dayFirst = 0;
  var monthFirst = 0;
  String? example;
  for (final r in table.rows) {
    final c = r.cell(column);
    if (c is! TextCell) continue;
    final m = _numericDate.firstMatch(c.text.trim());
    if (m == null || m.group(1)!.length == 4) continue;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    if (a > 12 && b <= 12) {
      dayFirst++;
    } else if (b > 12 && a <= 12) {
      monthFirst++;
    } else if (a != b && a <= 12 && b <= 12) {
      example ??= c.text.trim();
    }
  }
  if (dayFirst > 0 || monthFirst > 0) {
    return DateScan(
      ambiguous: false,
      settled: dayFirst >= monthFirst
          ? DateOrder.dayFirst
          : DateOrder.monthFirst,
    );
  }
  if (example != null) return DateScan(ambiguous: true, example: example);
  return DateScan.none;
}

/// "March 5, 2025".
String fullDate(int day) {
  final d = dateOfDay(day);
  return '${monthName(d.month)} ${d.day}, ${d.year}';
}

// ---------------------------------------------------------------------------
// Amounts
// ---------------------------------------------------------------------------

/// Which mark the amount column uses for decimals ('.' or ',').
String detectDecimalMark(ImportTable table, int? column) {
  if (column == null) return '.';
  var comma = 0;
  var dot = 0;
  var dotGroups = 0;
  final commaDecimal = RegExp(r'\d,\d{1,2}$');
  final dotDecimal = RegExp(r'\d\.\d{1,2}$');
  final dotThousands = RegExp(r'^\d{1,3}(\.\d{3})+$');
  for (final r in table.rows) {
    final c = r.cell(column);
    if (c is! TextCell) continue;
    final t = _amountText(c.text);
    if (t.isEmpty) continue;
    final lastComma = t.lastIndexOf(',');
    final lastDot = t.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      lastComma > lastDot ? comma++ : dot++;
    } else if (commaDecimal.hasMatch(t)) {
      comma++;
    } else if (dotDecimal.hasMatch(t)) {
      dot++;
    } else if (dotThousands.hasMatch(t)) {
      dotGroups++;
    }
  }
  if (comma > dot) return ',';
  if (comma == 0 && dot == 0 && dotGroups > 0) return ',';
  return '.';
}

/// Keeps digits and the marks between them; drops signs, currency words and
/// symbols ("Tk. 1,250.00" -> "1,250.00", "(45.50)" -> "45.50").
String _amountText(String raw) => raw
    .replaceAll(RegExp(r'[^0-9.,]'), '')
    .replaceFirst(RegExp(r'^[.,]+'), '')
    .replaceFirst(RegExp(r'[.,]+$'), '');

/// Reads an amount into minor units (x100). Negative amounts (how banks
/// write spending) count as positive; zero and unreadable values give null.
int? parseAmountCell(ImportCell cell, {required String decimalMark}) {
  switch (cell) {
    case NumberCell(:final value):
      final minor = (value.abs() * 100).round();
      return minor > 0 && minor < 1e15 ? minor : null;
    case DateCell():
      return null;
    case TextCell(:final text):
      return parseAmountText(text, decimalMark: decimalMark);
  }
}

int? parseAmountText(String raw, {required String decimalMark}) {
  var t = _amountText(raw.trim());
  if (!t.contains(RegExp(r'\d'))) return null;
  final group = decimalMark == '.' ? ',' : '.';
  t = t.replaceAll(group, '');
  if (decimalMark.allMatches(t).length > 1) t = t.replaceAll(decimalMark, '');
  final parts = t.split(decimalMark);
  final whole = parts[0].isEmpty ? '0' : parts[0];
  if (!RegExp(r'^\d+$').hasMatch(whole) || whole.length > 13) return null;
  var minor = int.parse(whole) * 100;
  if (parts.length == 2 && parts[1].isNotEmpty) {
    final frac = parts[1];
    if (!RegExp(r'^\d+$').hasMatch(frac)) return null;
    final two = '${frac}00'.substring(0, 2);
    minor += int.parse(two);
    if (frac.length > 2 && int.parse(frac[2]) >= 5) minor += 1;
  }
  return minor > 0 ? minor : null;
}

// ---------------------------------------------------------------------------
// The plan shown on "Review and import"
// ---------------------------------------------------------------------------

/// A row that will be added.
class PlannedExpense {
  const PlannedExpense({
    required this.line,
    required this.day,
    required this.amount,
    required this.title,
    required this.categoryName,
    this.categoryId,
  });

  final int line;
  final int day;
  final int amount;
  final String title;

  /// The category as the app will show it.
  final String categoryName;

  /// Null when the category is new (created on import).
  final int? categoryId;

  bool get newCategory => categoryId == null;
}

/// A row that cannot be read.
class BadRow {
  const BadRow({
    required this.line,
    required this.noDate,
    required this.noAmount,
  });

  final int line;
  final bool noDate;
  final bool noAmount;
}

class ImportPlan {
  const ImportPlan({
    required this.rowCount,
    required this.toAdd,
    required this.skipped,
    required this.bad,
    required this.newCategories,
  });

  /// Data rows in the file.
  final int rowCount;
  final List<PlannedExpense> toAdd;

  /// Rows already in the app (same date, amount, category and title).
  final int skipped;
  final List<BadRow> bad;

  /// Category names that will be created, in the order they first appear.
  final List<String> newCategories;

  int get total => toAdd.fold(0, (sum, e) => sum + e.amount);

  int? get firstDay => toAdd.isEmpty
      ? null
      : toAdd.map((e) => e.day).reduce((a, b) => a < b ? a : b);

  int? get lastDay => toAdd.isEmpty
      ? null
      : toAdd.map((e) => e.day).reduce((a, b) => a > b ? a : b);
}

/// Everything step 2 decides, enough to build the plan.
class ImportSettings {
  const ImportSettings({
    required this.mapping,
    required this.order,
    required this.decimalMark,
  });

  final ColumnMapping mapping;
  final DateOrder order;
  final String decimalMark;
}

/// Works out what the import will do. Reads the app's categories and the
/// pocket's expenses in the file's date span; writes nothing.
Future<ImportPlan> planImport({
  required ImportTable table,
  required ImportSettings settings,
  required int pocketId,
  required CategoriesRepo categories,
  required ExpensesRepo expenses,
}) async {
  final dateCol = settings.mapping[ImportField.date];
  final amountCol = settings.mapping[ImportField.amount];
  final catCol = settings.mapping[ImportField.category];
  final titleCol = settings.mapping[ImportField.title];

  final cats = await categories.all();
  final byName = <String, ExpenseCategory>{
    for (final c in cats) c.name.trim().toLowerCase(): c,
  };
  final misc =
      cats.where((c) => c.isMisc).firstOrNull ?? await categories.misc();

  final readable = <PlannedExpense>[];
  final bad = <BadRow>[];
  final newNames = <String, String>{}; // lower-case -> first spelling
  for (final row in table.rows) {
    final day = dateCol == null
        ? null
        : parseDateCell(row.cell(dateCol), settings.order);
    final amount = amountCol == null
        ? null
        : parseAmountCell(
            row.cell(amountCol),
            decimalMark: settings.decimalMark,
          );
    if (day == null || amount == null) {
      bad.add(
        BadRow(line: row.line, noDate: day == null, noAmount: amount == null),
      );
      continue;
    }
    final catText = catCol == null
        ? ''
        : row.cell(catCol).text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final title = titleCol == null
        ? ''
        : row.cell(titleCol).text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final ExpenseCategory? known = catText.isEmpty
        ? misc
        : byName[catText.toLowerCase()];
    final String name;
    if (known != null) {
      name = known.name;
    } else {
      name = newNames.putIfAbsent(catText.toLowerCase(), () => catText);
    }
    readable.add(
      PlannedExpense(
        line: row.line,
        day: day,
        amount: amount,
        title: title,
        categoryName: name,
        categoryId: known?.id,
      ),
    );
  }

  var skipped = 0;
  final toAdd = <PlannedExpense>[];
  if (readable.isNotEmpty) {
    var from = readable.first.day;
    var to = from;
    for (final e in readable) {
      if (e.day < from) from = e.day;
      if (e.day > to) to = e.day;
    }
    final existing = await expenses.listRange(pocketId, from, to);
    final keys = <String>{
      for (final e in existing) _key(e.day, e.amount, e.categoryId, e.note),
    };
    for (final e in readable) {
      if (e.categoryId != null &&
          keys.contains(_key(e.day, e.amount, e.categoryId!, e.title))) {
        skipped++;
      } else {
        toAdd.add(e);
      }
    }
  }
  return ImportPlan(
    rowCount: table.rows.length,
    toAdd: toAdd,
    skipped: skipped,
    bad: bad,
    newCategories: newNames.values.toList(),
  );
}

String _key(int day, int amount, int categoryId, String note) =>
    '$day|$amount|$categoryId|${note.trim()}';

/// What an import added, so Undo can take it back.
class ImportResult {
  const ImportResult({required this.expenseIds, required this.categoryIds});

  final List<int> expenseIds;
  final List<int> categoryIds;

  int get count => expenseIds.length;
}

/// Emoji of a category created by an import (the user can change it later).
const String importedCategoryEmoji = '\u{1F3F7}\u{FE0F}';

/// Saves the plan: creates the new categories, then adds the expenses in
/// one transaction. New categories get the colours no category has yet, in
/// palette order, and then the whole palette in turn
/// ([CategoryColor.forNew]).
Future<ImportResult> applyImport({
  required ImportPlan plan,
  required int pocketId,
  required CategoriesRepo categories,
  required ExpensesRepo expenses,
}) async {
  final created = <String, int>{};
  final existing = <String, int>{};
  final missing = <String>[];
  for (final name in plan.newCategories) {
    final found = await categories.findByName(name);
    if (found == null) {
      missing.add(name);
    } else {
      existing[name] = found.id;
    }
  }
  final colours = CategoryColor.forNew(
    missing.length,
    [for (final c in await categories.all()) c.color],
  );
  var next = 0;
  for (final name in plan.newCategories) {
    created[name] =
        existing[name] ??
        await categories.add(
          name: name,
          emoji: importedCategoryEmoji,
          color: colours[next++].argb,
        );
  }
  final ids = await expenses.addAll([
    for (final e in plan.toAdd)
      ExpenseDraft(
        pocketId: pocketId,
        categoryId: e.categoryId ?? created[e.categoryName]!,
        amount: e.amount,
        day: e.day,
        note: e.title,
      ),
  ]);
  return ImportResult(expenseIds: ids, categoryIds: created.values.toList());
}

/// Takes an import back: removes its expenses and the categories it
/// created (unless something else now uses them).
Future<void> undoImport({
  required ImportResult result,
  required CategoriesRepo categories,
  required ExpensesRepo expenses,
}) async {
  await expenses.deleteMany(result.expenseIds);
  for (final id in result.categoryIds) {
    if (await categories.countExpenses(id) == 0) {
      await categories.delete(id);
    }
  }
}

/// "Rows 14, 87, 203 · no date or amount" (at most three row numbers).
String badRowsLine(List<BadRow> bad) {
  if (bad.isEmpty) return '';
  final shown = bad.take(3).map((b) => '${b.line}').join(', ');
  final more = bad.length > 3 ? ' and ${bad.length - 3} more' : '';
  final rows = bad.length == 1 ? 'Row' : 'Rows';
  final noDate = bad.any((b) => b.noDate);
  final noAmount = bad.any((b) => b.noAmount);
  final why = noDate && noAmount
      ? 'no date or amount'
      : noDate
      ? 'no date'
      : 'no amount';
  return '$rows $shown$more · $why';
}

/// "Pets and Travel will be created".
String newCategoriesLine(List<String> names) {
  final String list;
  if (names.length == 1) {
    list = names.first;
  } else if (names.length <= 3) {
    list = '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  } else {
    list = '${names.take(2).join(', ')} and ${names.length - 2} more';
  }
  return '$list will be created';
}

/// "Mar 2 to Dec 30, 2025", "Dec 30, 2024 to Mar 2, 2025" or "Mar 2, 2025".
String importSpan(int first, int last) {
  if (first == last) return mediumDate(first);
  if (yearOfDay(first) == yearOfDay(last)) {
    return '${monthDay(first)} to ${mediumDate(last)}';
  }
  return '${mediumDate(first)} to ${mediumDate(last)}';
}
