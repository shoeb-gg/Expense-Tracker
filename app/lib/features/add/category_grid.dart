import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/db.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'add_styles.dart';
import 'dashed_box.dart';

/// The category grid at the top of Add and Edit expense: four columns of
/// emoji tiles, then the dashed "Manage" tile.
///
/// [outline] is how strongly the unselected tiles are outlined in accent,
/// 0 (none) to 1 (full accent). It is 0.45 while the app waits for a pick
/// and rises when the outlines flash.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.outline,
    required this.onTap,
    required this.onManage,
  });

  final List<ExpenseCategory> categories;
  final int? selectedId;
  final double outline;
  final ValueChanged<ExpenseCategory> onTap;
  final VoidCallback onManage;

  static const int columns = 4;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      for (final cat in categories)
        CategoryTile(
          category: cat,
          selected: cat.id == selectedId,
          outline: outline,
          onTap: () => onTap(cat),
        ),
      _ManageTile(onTap: onManage),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += columns) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = i; j < i + columns; j++)
              Expanded(child: j < cells.length ? cells[j] : const SizedBox()),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14.67, 8, 14.67, 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// One category: a 48 px emoji tile with its name under it.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    required this.selected,
    required this.outline,
    required this.onTap,
  });

  final ExpenseCategory category;
  final bool selected;
  final double outline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final showOutline = !selected && outline > 0;
    return _TileButton(
      onTap: onTap,
      selected: selected,
      label: category.name,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 84),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? litTileColor(c) : c.tile,
                borderRadius: BorderRadius.circular(15),
                boxShadow: selected ? selectedTileShadows(c) : const [],
              ),
              foregroundDecoration: showOutline
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: c.accent.withValues(alpha: outline.clamp(0, 1)),
                        width: 1.5,
                      ),
                    )
                  : null,
              child: ExcludeSemantics(child: Text(category.emoji, style: emojiText(24))),
            ),
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.navLabel.copyWith(
                  color: selected ? c.accent : c.text,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The last cell: a dashed tile with a pencil that opens Categories.
class _ManageTile extends StatelessWidget {
  const _ManageTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _TileButton(
      onTap: onTap,
      label: 'Manage categories',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 84),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DashedBox(
              size: 48,
              radius: 15,
              color: c.text3,
              child: Icon(Symbols.edit_rounded, size: 22, color: c.text2),
            ),
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: Text(
                'Manage',
                textAlign: TextAlign.center,
                style: AppText.navLabel.copyWith(color: c.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tap target of a grid cell. Unlike [Pressable] it does not clip, so the
/// glow of a selected tile can spread past the cell.
class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.onTap,
    required this.label,
    required this.child,
    this.selected = false,
  });

  final VoidCallback onTap;
  final String label;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}
