import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/text_wrap.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'data_parts.dart';
import 'data_providers.dart';
import 'import_logic.dart';
import 'import_screen.dart';

/// Import, step 2 of 3: "Check the columns" (board "Import: step 2").
class ImportColumnsScreen extends ConsumerWidget {
  const ImportColumnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final session = ref.watch(importSessionProvider);
    final pocket = ref.watch(currentPocketProvider);
    final fmt = ref.watch(amountFormatProvider);
    final header = SubHeader(
      title: 'Check the columns',
      subtitle: stepSubtitle(2, pocket),
    );
    if (session == null) return NoImportFile(header: header);
    final table = session.table;
    return DataPage(
      header: header,
      dock: DataDock(
        label: 'Next',
        hint: 'Nothing is added until the last step.',
        onPressed: session.ready
            ? () => context.push(Routes.importReview)
            : null,
      ),
      children: [
        PlainCard(
          child: ListRow(
            // A file name has no spaces: it breaks after "_", "-" or ".",
            // takes two lines at most and then ends in "…".
            title: breakableFileName(table.fileName),
            titleMaxLines: 2,
            subtitle: table.rows.length == 1
                ? '1 row'
                : '${fmt.count(table.rows.length)} rows',
            divider: false,
            wrap: true,
            leading: IconTile(
              icon: Symbols.description_rounded,
              iconSize: 24,
              iconColor: c.text2,
            ),
            trailing: SmallTileButton(
              label: 'Change',
              onTap: () => chooseImportFile(context, ref),
            ),
          ),
        ),
        BandCard(
          title: 'Your columns',
          trailingText:
              '${session.foundCount} of ${ImportField.values.length} found',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'In the app',
                        style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.text3,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 124,
                      child: Text(
                        'Column in your file',
                        style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.text3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final field in ImportField.values)
                _FieldRow(
                  field: field,
                  session: session,
                  last: field == ImportField.values.last,
                ),
            ],
          ),
        ),
        if (session.scan.ambiguous)
          BandCard(
            title: 'How dates are written',
            bodyPadding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSegmented<DateOrder>(
                  trackColor: c.bg,
                  segments: const [
                    Segment(DateOrder.dayFirst, 'Day first'),
                    Segment(DateOrder.monthFirst, 'Month first'),
                  ],
                  value: session.order,
                  onChanged: ref.read(importSessionProvider.notifier).setOrder,
                ),
                const SizedBox(height: 10),
                _ReadAs(example: session.scan.example!, order: session.order),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReadAs extends StatelessWidget {
  const _ReadAs({required this.example, required this.order});

  final String example;
  final DateOrder order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final day = parseDateText(example, order);
    final style = AppText.tabular(AppText.sub.copyWith(color: c.text3));
    // The last two words stay together (one space changes, so the bold part
    // starts where it did).
    final lead = '$example is read as ';
    final line = keepLastWordsTogether(
      '$lead${day == null ? 'no date' : fullDate(day)}',
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: line.substring(0, lead.length)),
          TextSpan(
            text: line.substring(lead.length),
            style: TextStyle(fontWeight: FontWeight.w800, color: c.text),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: style,
    );
  }
}

class _FieldRow extends ConsumerWidget {
  const _FieldRow({
    required this.field,
    required this.session,
    required this.last,
  });

  final ImportField field;
  final ImportSession session;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final col = session.mapping[field];
    final sample = col == null ? null : session.table.sample(col);
    final String sub;
    final String label;
    final ColumnButtonTone tone;
    if (col != null) {
      sub = sample == null ? 'Empty in this file' : 'e.g. $sample';
      label = session.table.headers[col];
      tone = ColumnButtonTone.found;
    } else if (field.required) {
      sub = 'Not found in the file';
      label = 'Choose a column';
      tone = ColumnButtonTone.missing;
    } else {
      sub = field == ImportField.category
          ? 'All go to Miscellaneous'
          : 'Left blank';
      label = 'None';
      tone = ColumnButtonTone.unused;
    }
    // At least 64 px high; large text wraps and the row grows to hold it.
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      foregroundDecoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, style: AppText.rowTitle),
                const SizedBox(height: 2),
                Text(
                  sub,
                  // A sample from the file is cut after two lines; the
                  // app's own words always show in full.
                  maxLines: sample == null ? null : 2,
                  overflow: sample == null
                      ? TextOverflow.clip
                      : TextOverflow.ellipsis,
                  style: AppText.tabular(AppText.sub.copyWith(color: c.text3)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ColumnButton(
            label: label,
            tone: tone,
            semanticLabel: col == null
                ? '${field.label}: choose a column'
                : '${field.label} comes from the column $label. Tap to change',
            onTap: () => _choose(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final table = session.table;
    final current = session.mapping[field];
    final picked = await showAppSheet<int>(
      context,
      builder: (sheet) {
        final maxH = MediaQuery.sizeOf(sheet).height * 0.6;
        final rows = <Widget>[
          for (var i = 0; i < table.columnCount; i++)
            OptionRow(
              label: table.headers[i],
              note: _short(table.sample(i)),
              selected: i == current,
              onTap: () => Navigator.of(sheet).pop(i),
            ),
          if (!field.required)
            OptionRow(
              label: 'Not in this file',
              selected: current == null,
              onTap: () => Navigator.of(sheet).pop(-1),
            ),
        ];
        return AppSheet(
          title: field.label,
          message:
              'Which column of your file holds the ${field.label.toLowerCase()}?',
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => rows[i],
              ),
            ),
          ],
        );
      },
    );
    if (picked == null) return;
    ref
        .read(importSessionProvider.notifier)
        .setColumn(field, picked < 0 ? null : picked);
  }
}

String? _short(String? s) {
  if (s == null) return null;
  final chars = s.characters;
  return chars.length > 14 ? '${chars.take(13)}…' : s;
}

/// Shown when a step is opened without a file (e.g. after the app was
/// closed in between).
class NoImportFile extends StatelessWidget {
  const NoImportFile({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CenteredNote(
                    'Choose a file first.',
                    style: AppText.body.copyWith(color: c.text2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
