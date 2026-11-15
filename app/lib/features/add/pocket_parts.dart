import 'package:flutter/material.dart';

import '../../data/db.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'add_styles.dart';

/// The small pocket pill at the top right of Add and Edit expense (only
/// with two or more pockets).
class PocketPill extends StatelessWidget {
  const PocketPill({
    super.key,
    required this.pocket,
    required this.onTap,
    required this.semanticLabel,
  });

  final Pocket pocket;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 100),
      child: SizedBox(
        height: 36,
        child: Pressable(
          onTap: onTap,
          semanticLabel: semanticLabel,
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(pocket.emoji, style: emojiText(15)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      pocket.name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: boardText(12, 20, FontWeight.w700, color: c.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Save in another pocket" (Add expense, [move] false) or "Move to another
/// pocket" (Edit expense, [move] true). Returns the picked pocket id, or
/// null when dismissed.
Future<int?> showPocketSheet(
  BuildContext context, {
  required List<Pocket> pockets,
  required int? current,
  required bool move,
}) {
  return showAppSheet<int>(
    context,
    builder: (ctx) {
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.55;
      return AppSheet(
        title: move ? 'Move to another pocket' : 'Save in another pocket',
        message: move
            ? 'Tap the pocket this expense should go to.'
            : 'Tap the pocket this expense should go in.',
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(ctx).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < pockets.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      PocketOptionRow(
                        pocket: pockets[i],
                        selected: pockets[i].id == current,
                        note: move ? 'Now in this pocket' : 'It will be saved here',
                        onTap: () => Navigator.of(ctx).pop(pockets[i].id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// One pocket on the sheet: emoji tile, name (and, when selected, the
/// note under it) and the round tick.
class PocketOptionRow extends StatelessWidget {
  const PocketOptionRow({
    super.key,
    required this.pocket,
    required this.selected,
    required this.note,
    required this.onTap,
  });

  final Pocket pocket;
  final bool selected;

  /// Second line, shown on the selected row only.
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: SizedBox(
        height: 64,
        child: Pressable(
          onTap: onTap,
          selected: selected,
          semanticLabel: pocket.name,
          color: selected ? c.accentSoft : c.tile,
          borderRadius: BorderRadius.circular(16),
          border: selected ? Border.all(color: c.accent, width: 2) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                EmojiBox(emoji: pocket.emoji, background: c.surface),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pocket.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.rowTitle.copyWith(
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 2),
                        Text(note, style: AppText.sub.copyWith(color: c.text3)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: selected ? null : Border.all(color: c.popStub, width: 2),
                  ),
                  child: selected ? Icon(Symbols.check_rounded, size: 18, color: c.onAccent) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
