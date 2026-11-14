import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../data/db.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'data_parts.dart';
import 'data_providers.dart';
import 'export_logic.dart';

/// The quick choices of "Which expenses".
enum ExportPreset {
  month('This month'),
  year('This year'),
  all('Everything');

  const ExportPreset(this.label);

  final String label;
}

/// Where Export opens: the pocket in use, or (`?pocket=<id>`) another one,
/// e.g. "Save a copy first" before deleting that pocket.
String exportLocation({int? pocketId}) =>
    pocketId == null ? Routes.export : '${Routes.export}?pocket=$pocketId';

/// Export (board "Export"): which expenses of the pocket in use (or the
/// pocket named in the link), Excel or CSV, then the phone's own save /
/// share sheet.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key, this.pocketId});

  /// The pocket to export; null reads `?pocket=` from the link, and without
  /// one Export uses the pocket in use.
  final int? pocketId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

/// The `?pocket=` of the current link, if any.
int? _linkedPocket(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return null;
  return int.tryParse(
    GoRouterState.of(context).uri.queryParameters['pocket'] ?? '',
  );
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportPreset? _preset = ExportPreset.month;
  int? _from;
  int? _to;
  ExportFormat _format = ExportFormat.xlsx;
  bool _busy = false;

  ({int from, int to}) _range(int today, DaySpan span) {
    switch (_preset) {
      case ExportPreset.month:
        return (from: monthStartOfDay(today), to: today);
      case ExportPreset.year:
        return (from: yearStart(yearOfDay(today)), to: today);
      case ExportPreset.all:
        final first = span.first ?? today;
        final last = span.last ?? today;
        return (
          from: first < today ? first : today,
          to: last > today ? last : today,
        );
      case null:
        return (from: _from ?? today, to: _to ?? today);
    }
  }

  Future<void> _pick({
    required bool from,
    required ({int from, int to}) range,
  }) async {
    final picked = await showDayPicker(
      context,
      initialDay: from ? range.from : range.to,
      label: from ? 'First day to export' : 'Last day to export',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preset = null;
      var a = from ? picked : range.from;
      var b = from ? range.to : picked;
      if (a > b) {
        if (from) {
          b = a;
        } else {
          a = b;
        }
      }
      _from = a;
      _to = b;
    });
  }

  Future<void> _export(Pocket pocket, ({int from, int to}) range) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final expenses = await ref
          .read(expensesRepoProvider)
          .listRange(pocket.id, range.from, range.to);
      final cats = {
        for (final c in await ref.read(categoriesRepoProvider).all()) c.id: c,
      };
      final bytes = encodeExport(exportRows(expenses, cats), _format);
      final name = exportFileName(
        pocketName: pocket.name,
        from: range.from,
        to: range.to,
        format: _format,
      );
      final cache = await ref.read(cacheDirProvider)();
      final file = await writeExportFile(
        cacheDir: cache,
        fileName: name,
        bytes: bytes,
      );
      await ref.read(exportSharerProvider)(file, _format.mimeType);
    } on Object {
      if (mounted) showToast(context, "Couldn't export. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The pocket asked for in the link (if it still exists), else the
  /// pocket in use.
  Pocket? _pocket(BuildContext context) {
    final asked = widget.pocketId ?? _linkedPocket(context);
    if (asked != null) {
      final pockets = ref.watch(pocketsProvider).value;
      final found = pockets?.where((p) => p.id == asked).firstOrNull;
      if (found != null) return found;
    }
    return ref.watch(currentPocketProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final pocket = _pocket(context);
    final pocketId = pocket?.id;
    final fmt = ref.watch(amountFormatProvider);
    final span = pocketId == null
        ? (first: null, last: null)
        : ref.watch(daySpanProvider(pocketId)).value ??
              (first: null, last: null);
    final range = _range(today, span);
    final count = pocketId == null
        ? null
        : ref
              .watch(
                exportCountProvider((
                  pocketId: pocketId,
                  from: range.from,
                  to: range.to,
                )),
              )
              .value;
    final words = count == null ? '' : expenseCount(count, fmt);
    final canExport = pocket != null && count != null && count > 0 && !_busy;
    return DataPage(
      header: SubHeader(
        title: 'Export',
        subtitle: pocket == null ? null : pocketLabel(pocket),
      ),
      dock: DataDock(
        label: count == 0 ? 'Nothing to export' : 'Export $words',
        onPressed: canExport ? () => _export(pocket, range) : null,
        hint: count == 0
            ? 'No expenses in these dates. Try other dates.'
            : 'Next, you choose where to save or share it.',
      ),
      children: [
        BandCard(
          title: 'Which expenses',
          trailingText: words,
          bodyPadding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSegmented<ExportPreset?>(
                trackColor: c.bg,
                segments: [
                  for (final p in ExportPreset.values) Segment(p, p.label),
                ],
                value: _preset,
                onChanged: (p) => setState(() => _preset = p),
              ),
              const SizedBox(height: 12),
              DateFieldRow(
                label: 'From',
                value: mediumDate(range.from),
                onTap: () => _pick(from: true, range: range),
              ),
              const SizedBox(height: 8),
              DateFieldRow(
                label: 'To',
                value: mediumDate(range.to),
                onTap: () => _pick(from: false, range: range),
              ),
            ],
          ),
        ),
        BandCard(
          title: 'File type',
          bodyPadding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChoiceRow(
                title: 'Excel (.xlsx)',
                subtitle: 'Opens in Excel and Google Sheets',
                selected: _format == ExportFormat.xlsx,
                onTap: () => setState(() => _format = ExportFormat.xlsx),
              ),
              const SizedBox(height: 8),
              ChoiceRow(
                title: 'CSV (.csv)',
                subtitle: 'Plain text, opens in almost any app',
                selected: _format == ExportFormat.csv,
                onTap: () => setState(() => _format = ExportFormat.csv),
              ),
              const SizedBox(height: 12),
              Text(
                'One row per expense. Photos are left out.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(
                  fontSize: 13,
                  height: 20 / 13,
                  color: c.text3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
