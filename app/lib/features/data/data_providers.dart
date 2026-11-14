import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../state/providers.dart';
import 'import_logic.dart';
import 'import_table.dart';

/// A file the user picked for import.
typedef PickedImportFile = ({String name, Uint8List bytes});

/// Opens the phone's file picker (CSV, Excel, JSON). Null when cancelled.
/// Tests override this.
final importFilePickerProvider = Provider<Future<PickedImportFile?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'json', 'txt'],
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  },
);

/// Opens the phone's share / save sheet for an exported file. Tests
/// override this.
final exportSharerProvider =
    Provider<Future<void> Function(File file, String mimeType)>(
      (ref) => (file, mimeType) async {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: mimeType)],
            fileNameOverrides: [file.uri.pathSegments.last],
          ),
        );
      },
    );

/// Expense count of a pocket in a day range (Export's "33 expenses").
final exportCountProvider = StreamProvider.autoDispose.family<int, PocketRange>(
  (ref, key) {
    return ref
        .watch(expensesRepoProvider)
        .watchCount(key.pocketId, from: key.from, to: key.to);
  },
);

/// The import in progress, shared by its three steps.
class ImportSession {
  const ImportSession({
    required this.table,
    required this.mapping,
    required this.scan,
    required this.order,
    required this.decimalMark,
  });

  factory ImportSession.start(ImportTable table) {
    final mapping = guessColumns(table);
    final scan = scanDates(table, mapping[ImportField.date]);
    return ImportSession(
      table: table,
      mapping: mapping,
      scan: scan,
      order: scan.settled ?? DateOrder.dayFirst,
      decimalMark: detectDecimalMark(table, mapping[ImportField.amount]),
    );
  }

  final ImportTable table;
  final ColumnMapping mapping;
  final DateScan scan;
  final DateOrder order;
  final String decimalMark;

  bool get ready =>
      mapping.containsKey(ImportField.date) &&
      mapping.containsKey(ImportField.amount);

  int get foundCount => mapping.length;

  ImportSettings get settings =>
      ImportSettings(mapping: mapping, order: order, decimalMark: decimalMark);

  ImportSession withColumn(ImportField field, int? column) {
    final next = <ImportField, int>{...mapping};
    if (column == null) {
      next.remove(field);
    } else {
      // A column feeds one field only.
      next.removeWhere((f, c) => c == column);
      next[field] = column;
    }
    final frozen = Map<ImportField, int>.unmodifiable(next);
    final scan = scanDates(table, frozen[ImportField.date]);
    return ImportSession(
      table: table,
      mapping: frozen,
      scan: scan,
      order: scan.settled ?? order,
      decimalMark: detectDecimalMark(table, frozen[ImportField.amount]),
    );
  }

  ImportSession withOrder(DateOrder order) => ImportSession(
    table: table,
    mapping: mapping,
    scan: scan,
    order: order,
    decimalMark: decimalMark,
  );
}

class ImportSessionNotifier extends Notifier<ImportSession?> {
  @override
  ImportSession? build() => null;

  void start(ImportTable table) => state = ImportSession.start(table);

  void setColumn(ImportField field, int? column) {
    final s = state;
    if (s != null) state = s.withColumn(field, column);
  }

  void setOrder(DateOrder order) {
    final s = state;
    if (s != null) state = s.withOrder(order);
  }

  void clear() => state = null;
}

final importSessionProvider =
    NotifierProvider<ImportSessionNotifier, ImportSession?>(
      ImportSessionNotifier.new,
    );

/// The plan of step 3, recomputed when the session or the pocket changes.
final importPlanProvider = FutureProvider.autoDispose<ImportPlan?>((ref) async {
  final session = ref.watch(importSessionProvider);
  final pocketId = ref.watch(currentPocketIdProvider);
  if (session == null || pocketId == null || !session.ready) return null;
  return planImport(
    table: session.table,
    settings: session.settings,
    pocketId: pocketId,
    categories: ref.watch(categoriesRepoProvider),
    expenses: ref.watch(expensesRepoProvider),
  );
});
