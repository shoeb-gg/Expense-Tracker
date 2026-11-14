/// Every shared provider (Riverpod 3, plain classes, no code generation).
///
/// Families take records as keys, e.g.
/// `ref.watch(dayTotalsProvider((pocketId: 1, from: a, to: b)))`.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/days.dart';
import '../core/format.dart';
import '../data/categories_repo.dart';
import '../data/db.dart';
import '../data/expenses_repo.dart';
import '../data/learned_words_repo.dart';
import '../data/maintenance.dart';
import '../data/photo_store.dart';
import '../data/pockets_repo.dart';
import '../data/settings_store.dart';
import 'settings.dart';

export '../data/expenses_repo.dart' show CategoryTotal, DaySpan, MonthTotal;
export 'settings.dart';

// ------------------------------------------------------------------ basics

/// The open database. Overridden in main() and in tests.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Override databaseProvider'),
);

/// "Now". Tests pin it: `clockProvider.overrideWithValue(Clock.fixed(mockupNow))`.
final clockProvider = Provider<Clock>((ref) => const Clock());

/// Today's day number.
final todayProvider = Provider<int>((ref) => ref.watch(clockProvider).today());

/// The app's private documents folder (photos live in `<it>/photos/`).
final documentsDirProvider = Provider<Future<Directory> Function()>(
  (ref) => getApplicationDocumentsDirectory,
);

/// The app's temporary folder (export files, picked-photo copies).
final cacheDirProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);

/// Extra font families tried for glyphs Plus Jakarta Sans lacks (emoji).
/// Empty in the app (the phone's own emoji font is used); screenshot tests
/// set it to the emoji font they load.
final fontFallbackProvider = Provider<List<String>>((ref) => const []);

// ------------------------------------------------------------ repositories

final photoStoreProvider = Provider<PhotoStore>(
  (ref) => PhotoStore(baseDir: ref.watch(documentsDirProvider)),
);

final expensesRepoProvider = Provider<ExpensesRepo>(
  (ref) => ExpensesRepo(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final categoriesRepoProvider = Provider<CategoriesRepo>(
  (ref) => CategoriesRepo(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final pocketsRepoProvider = Provider<PocketsRepo>(
  (ref) => PocketsRepo(
    ref.watch(databaseProvider),
    photos: ref.watch(photoStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

final learnedWordsRepoProvider = Provider<LearnedWordsRepo>(
  (ref) => LearnedWordsRepo(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(databaseProvider)),
);

final maintenanceProvider = Provider<DataMaintenance>(
  (ref) => DataMaintenance(
    ref.watch(databaseProvider),
    photos: ref.watch(photoStoreProvider),
    cacheDir: ref.watch(cacheDirProvider),
  ),
);

/// App-level actions that touch both data and settings.
final dataActionsProvider = Provider<DataActions>(DataActions.new);

class DataActions {
  DataActions(this._ref);

  final Ref _ref;

  /// Delete all data: wipes everything but the settings, re-creates the
  /// default pocket and categories, and switches to the new pocket.
  Future<void> deleteAllData() async {
    final pocketId = await _ref.read(maintenanceProvider).deleteAllData();
    await _ref.read(settingsProvider.notifier).setCurrentPocketId(pocketId);
  }

  /// Clear cache; returns bytes freed (see `formatBytes`).
  Future<int> clearCache() => _ref.read(maintenanceProvider).clearCache();

  /// Switches to another pocket.
  Future<void> switchPocket(int pocketId) =>
      _ref.read(settingsProvider.notifier).setCurrentPocketId(pocketId);
}

// ------------------------------------------------------------- app state

/// The amount formatter for the user's number style.
final amountFormatProvider = Provider<AmountFormat>(
  (ref) => ref.watch(settingsProvider.select((s) => s.amountFormat)),
);

/// Every pocket in the user's order.
final pocketsProvider = StreamProvider<List<Pocket>>(
  (ref) => ref.watch(pocketsRepoProvider).watchAll(),
);

/// The pocket in use: the one saved in settings, else the default pocket.
/// Null only while the pockets are loading.
final currentPocketProvider = Provider<Pocket?>((ref) {
  final pockets = ref.watch(pocketsProvider).value;
  if (pockets == null || pockets.isEmpty) return null;
  final id = ref.watch(settingsProvider.select((s) => s.currentPocketId));
  Pocket? fallback;
  for (final p in pockets) {
    if (p.id == id) return p;
    if (p.isDefault) fallback ??= p;
  }
  return fallback ?? pockets.first;
});

/// Id of the pocket in use (null while loading).
final currentPocketIdProvider =
    Provider<int?>((ref) => ref.watch(currentPocketProvider)?.id);

/// Every category in the user's order.
final categoriesProvider = StreamProvider<List<ExpenseCategory>>(
  (ref) => ref.watch(categoriesRepoProvider).watchAll(),
);

/// Categories by id (empty while loading).
final categoriesByIdProvider = Provider<Map<int, ExpenseCategory>>((ref) {
  final list = ref.watch(categoriesProvider).value ?? const [];
  return {for (final c in list) c.id: c};
});

/// Miscellaneous (null while loading).
final miscCategoryProvider = Provider<ExpenseCategory?>((ref) {
  final list = ref.watch(categoriesProvider).value ?? const [];
  for (final c in list) {
    if (c.isMisc) return c;
  }
  return null;
});

/// Every learned word: word -> category id.
final learnedWordsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(learnedWordsRepoProvider).watchAll(),
);

/// Expenses per category across all pockets.
final categoryExpenseCountsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(categoriesRepoProvider).watchExpenseCounts(),
);

/// Expenses per pocket.
final pocketExpenseCountsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(pocketsRepoProvider).watchExpenseCounts(),
);

// ------------------------------------------------------- data by range

/// A pocket and an inclusive day range.
typedef PocketRange = ({int pocketId, int from, int to});

/// A pocket, a category and an inclusive day range.
typedef CategoryRange = ({int pocketId, int categoryId, int from, int to});

/// An inclusive day range (all pockets).
typedef DayRangeKey = ({int from, int to});

/// Expenses of a pocket in a range, newest first.
final expensesInRangeProvider =
    StreamProvider.autoDispose.family<List<Expense>, PocketRange>(
  (ref, k) =>
      ref.watch(expensesRepoProvider).watchRange(k.pocketId, k.from, k.to),
);

/// Expenses of one category in a pocket and range, newest first.
final categoryExpensesProvider =
    StreamProvider.autoDispose.family<List<Expense>, CategoryRange>(
  (ref, k) => ref
      .watch(expensesRepoProvider)
      .watchRange(k.pocketId, k.from, k.to, categoryId: k.categoryId),
);

/// Day -> total (only days with expenses).
final dayTotalsProvider =
    StreamProvider.autoDispose.family<Map<int, int>, PocketRange>(
  (ref, k) =>
      ref.watch(expensesRepoProvider).watchDayTotals(k.pocketId, k.from, k.to),
);

/// Totals per category, biggest first.
final categoryTotalsProvider =
    StreamProvider.autoDispose.family<List<CategoryTotal>, PocketRange>(
  (ref, k) => ref
      .watch(expensesRepoProvider)
      .watchCategoryTotals(k.pocketId, k.from, k.to),
);

/// Totals per calendar month, oldest first.
final monthTotalsProvider =
    StreamProvider.autoDispose.family<List<MonthTotal>, PocketRange>(
  (ref, k) => ref
      .watch(expensesRepoProvider)
      .watchMonthTotals(k.pocketId, k.from, k.to),
);

/// Total of a range.
final rangeTotalProvider = StreamProvider.autoDispose.family<int, PocketRange>(
  (ref, k) =>
      ref.watch(expensesRepoProvider).watchTotal(k.pocketId, k.from, k.to),
);

/// All-time total of a pocket (key: pocket id).
final allTimeTotalProvider = StreamProvider.autoDispose.family<int, int>(
  (ref, pocketId) =>
      ref.watch(expensesRepoProvider).watchAllTimeTotal(pocketId),
);

/// First and last day with an expense in a pocket (key: pocket id).
final daySpanProvider = StreamProvider.autoDispose.family<DaySpan, int>(
  (ref, pocketId) => ref.watch(expensesRepoProvider).watchDaySpan(pocketId),
);

/// Number of expenses in a pocket (key: pocket id).
final expenseCountProvider = StreamProvider.autoDispose.family<int, int>(
  (ref, pocketId) => ref.watch(expensesRepoProvider).watchCount(pocketId),
);

/// One expense by id (null once deleted).
final expenseProvider = StreamProvider.autoDispose.family<Expense?, int>(
  (ref, id) => ref.watch(expensesRepoProvider).watch(id),
);

/// Total per pocket in a range (all pockets): pocketId -> total.
final pocketTotalsProvider =
    StreamProvider.autoDispose.family<Map<int, int>, DayRangeKey>(
  (ref, k) => ref.watch(expensesRepoProvider).watchPocketTotals(k.from, k.to),
);
