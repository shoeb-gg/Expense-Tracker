import 'package:flutter/material.dart';

import '../../data/db.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';

/// Home's pocket button at the top-left (PocketHome board): the pocket's
/// emoji in a dark disc, its name (cut with "…") and a turquoise arrow, on a
/// 40 px tinted pill. [open] draws it as it looks above the "Your pockets"
/// panel: solid tint and the arrow pointing up.
class PocketButton extends StatelessWidget {
  const PocketButton({
    super.key,
    required this.pocket,
    required this.onTap,
    this.open = false,
  });

  final Pocket pocket;
  final VoidCallback? onTap;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 40,
      child: Pressable(
        onTap: onTap,
        color: open ? Color.alphaBlend(c.accentSoft, c.bg) : c.accentSoft,
        borderRadius: BorderRadius.circular(20),
        semanticLabel:
            'You are in the pocket ${pocket.name}. Tap to switch pocket',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.bg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    pocket.emoji,
                    style: AppText.emoji.copyWith(fontSize: 17),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    pocket.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.pageTitle.copyWith(
                      fontSize: 19,
                      height: 24 / 19,
                      color: c.text,
                    ),
                  ),
                ),
                // 8 px gap with a -4 px margin on the arrow.
                const SizedBox(width: 4),
                Icon(
                  open
                      ? Symbols.expand_less_rounded
                      : Symbols.expand_more_rounded,
                  size: 24,
                  color: c.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
