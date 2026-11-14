import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/format.dart';
import '../../data/db.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import '../home/pocket_switch.dart' show InUseBadge;

/// Pockets (`/pockets`), the PocketList board: every pocket with its emoji,
/// name and number of expenses, a bin and a pencil; the default pocket has a
/// lock and "Can't be deleted". "Add pocket" floats at the bottom. The bin
/// opens the delete warning (PocketDelete board).
class PocketsScreen extends ConsumerWidget {
  const PocketsScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Pocket pocket,
    int count,
  ) async {
    final c = context.colors;
    final fmt = ref.read(amountFormatProvider);
    final expenses = expenseCount(count, fmt);
    final empty = count == 0;
    final ok = await showAppDialog(
      context,
      title: 'Delete ${pocket.name}?',
      titleWidget: Row(
        children: [
          Text('Delete', style: AppText.screenTitle.copyWith(color: c.text)),
          const SizedBox(width: 6),
          Text(pocket.emoji, style: AppText.emoji.copyWith(fontSize: 17)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${pocket.name}?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.screenTitle.copyWith(color: c.text),
            ),
          ),
        ],
      ),
      boldLine: empty
          ? 'This pocket is empty.'
          : 'Also deletes $expenses and photos',
      quietLine: empty ? 'It will simply be removed.' : 'This can’t be undone.',
      extra: empty
          ? null
          : DialogLinkRow(
              label: 'Save a copy first',
              actionLabel: 'Export',
              onTap: () => unawaited(context.push(Routes.export)),
            ),
      tickLabel: empty ? null : 'Yes, delete $expenses',
      actionLabel: 'Delete pocket',
      destructive: true,
    );
    if (!ok) return;
    final wasCurrent = ref.read(currentPocketIdProvider) == pocket.id;
    final pockets = ref.read(pocketsRepoProvider);
    await pockets.delete(pocket.id);
    if (wasCurrent) {
      final fallback = await pockets.defaultPocket();
      await ref.read(dataActionsProvider).switchPocket(fallback.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pockets = ref.watch(pocketsProvider).value;
    final counts =
        ref.watch(pocketExpenseCountsProvider).value ?? const <int, int>{};
    final currentId = ref.watch(currentPocketIdProvider);
    final fmt = ref.watch(amountFormatProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SubHeader(title: 'Pockets'),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
                        children: [
                          if (pockets != null)
                            BandCard(
                              title: pockets.length == 1
                                  ? '1 pocket'
                                  : '${pockets.length} pockets',
                              child: Padding(
                                padding: BandCard.listPadding,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < pockets.length; i++)
                                      _PocketRow(
                                        pocket: pockets[i],
                                        note: expenseCount(
                                          counts[pockets[i].id] ?? 0,
                                          fmt,
                                        ),
                                        inUse: pockets[i].id == currentId,
                                        divider: i < pockets.length - 1,
                                        onEdit: () => context.push(
                                          Routes.editPocket(pockets[i].id),
                                        ),
                                        onDelete: () => _delete(
                                          context,
                                          ref,
                                          pockets[i],
                                          counts[pockets[i].id] ?? 0,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          BandCard(
                            title: 'How pockets work',
                            bodyPadding: const EdgeInsets.fromLTRB(
                              16,
                              14,
                              16,
                              16,
                            ),
                            child: Text(
                              'Each pocket keeps its own expenses. Home, '
                              'Calendar, Charts and Reports show the pocket '
                              'you are in.',
                              style: AppText.body.copyWith(color: c.text2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FadeDock(
                      child: PrimaryButton(
                        label: 'Add pocket',
                        icon: Symbols.add_rounded,
                        iconSize: 22,
                        glow: true,
                        onPressed: () => context.push(Routes.newPocket),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PocketRow extends StatelessWidget {
  const _PocketRow({
    required this.pocket,
    required this.note,
    required this.inUse,
    required this.divider,
    required this.onEdit,
    required this.onDelete,
  });

  final Pocket pocket;
  final String note;
  final bool inUse;
  final bool divider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final locked = pocket.isDefault;
    final sub = AppText.tabular(AppText.sub).copyWith(color: c.text3);
    return SizedBox(
      height: locked ? 80 : 68,
      child: Row(
        children: [
          const SizedBox(width: 16),
          EmojiTile(emoji: pocket.emoji),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: double.infinity,
              // Like the mockup's inset shadow: drawn over, takes no room.
              foregroundDecoration: divider
                  ? BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.line)),
                    )
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                pocket.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.rowTitle.copyWith(color: c.text),
                              ),
                            ),
                            if (inUse) ...[
                              const SizedBox(width: 8),
                              InUseBadge(background: c.surface2),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(note, style: sub),
                        if (locked) ...[
                          const SizedBox(height: 2),
                          Text('Can’t be deleted', style: sub),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    height: 36,
                    child: locked
                        ? Semantics(
                            container: true,
                            label:
                                '${pocket.name} is the default pocket '
                                'and cannot be deleted',
                            child: Opacity(
                              opacity: 0.6,
                              child: Icon(
                                Symbols.lock_rounded,
                                size: 20,
                                color: c.text3,
                              ),
                            ),
                          )
                        : _IconAction(
                            icon: Symbols.delete_rounded,
                            semanticLabel: 'Delete ${pocket.name}',
                            onTap: onDelete,
                          ),
                  ),
                  // The pencil sits 5 px into the row's right margin.
                  SizedBox(
                    width: 25,
                    height: 36,
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: 30,
                      maxWidth: 30,
                      child: _IconAction(
                        icon: Symbols.edit_rounded,
                        semanticLabel: 'Edit ${pocket.name}',
                        onTap: onEdit,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 30,
      height: 36,
      child: Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        borderRadius: BorderRadius.circular(16),
        child: Center(child: Icon(icon, size: 20, color: c.text3)),
      ),
    );
  }
}
