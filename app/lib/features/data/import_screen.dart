import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'data_parts.dart';
import 'data_providers.dart';
import 'import_table.dart';

/// Picks a file, reads it and starts the import session. Returns false
/// when the user cancelled or the file could not be used (a pop-up says
/// why and offers to choose another).
Future<bool> chooseImportFile(BuildContext context, WidgetRef ref) async {
  while (true) {
    final picked = await ref.read(importFilePickerProvider)();
    if (picked == null || !context.mounted) return false;
    String? problem;
    try {
      final table = readImportTable(picked.name, picked.bytes);
      if (table.rows.isEmpty) {
        problem = 'It has column names but no rows under them.';
      } else {
        ref.read(importSessionProvider.notifier).start(table);
        return true;
      }
    } on ImportFileError catch (e) {
      problem = e.message;
    }
    final again = await showAppDialog(
      context,
      title: "Can't use this file",
      boldLine: picked.name,
      quietLine: problem,
      actionLabel: 'Choose another',
    );
    if (!again || !context.mounted) return false;
  }
}

/// Import, step 1 of 3 (board "Import: step 1").
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pocket = ref.watch(currentPocketProvider);
    return DataPage(
      header: SubHeader(title: 'Import', subtitle: stepSubtitle(1, pocket)),
      dock: DataDock(
        label: 'Choose a file',
        hint: 'Nothing is added until the last step.',
        onPressed: () async {
          if (await chooseImportFile(context, ref) && context.mounted) {
            await context.push(Routes.importColumns);
          }
        },
      ),
      children: [
        PlainCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const IconTile(icon: Symbols.upload_file_rounded, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add expenses from a file',
                      style: AppText.screenTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CSV, Excel or JSON files',
                      style: AppText.body.copyWith(color: c.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        BandCard(
          title: 'How it works',
          child: Column(
            children: [
              for (final (i, step) in _steps.indexed)
                BottomHairline.afterTile(
                  show: i < _steps.length - 1,
                  child: ListRow(
                    title: step.$1,
                    subtitle: step.$2,
                    height: 64,
                    divider: false,
                    leading: SizedBox(
                      width: 44,
                      child: Center(
                        child: _StepDot(number: i + 1, current: i == 0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        BandCard(
          title: 'What the file needs',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BottomHairline(
                child: ListRow(
                  title: 'Date and amount',
                  subtitle: 'In every row',
                  height: 60,
                  divider: false,
                  trailing: SmallChip(label: 'Needed', color: c.accent),
                ),
              ),
              ListRow(
                title: 'Category and title',
                subtitle: 'Blank ones go to Miscellaneous',
                height: 60,
                divider: false,
                trailing: SmallChip(label: 'Optional', color: c.text3),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TopHairline(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
                    child: Text(
                      'A file exported from this app works as it is.',
                      textAlign: TextAlign.center,
                      style: AppText.sub.copyWith(color: c.text3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const List<(String, String)> _steps = [
  ('Choose a file', 'From your phone or a cloud drive'),
  ('Check the columns', 'Confirm which column is which'),
  ('Review and import', 'See what will be added before it is saved'),
];

class _StepDot extends StatelessWidget {
  const _StepDot({required this.number, required this.current});

  final int number;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: current ? c.accent : c.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: AppText.segment.copyWith(
          fontWeight: FontWeight.w800,
          color: current ? c.onAccent : c.accent,
        ),
      ),
    );
  }
}
