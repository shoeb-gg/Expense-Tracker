import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/db.dart';
import '../../theme/symbols.dart';
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
              child: TileLabel(
                text: category.name,
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

/// A category name under its tile: at most two lines, broken only between
/// words. A word wider than the cell is scaled down to fit (never cut in the
/// middle), and the labels of neighbouring tiles keep a gap that grows with
/// the text size (see [labelGap]).
class TileLabel extends StatelessWidget {
  const TileLabel({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final gap = labelGap(scaler, style.fontSize ?? 12);
        final width = math.max(box.maxWidth - 2 * gap, 1.0);
        final label = labelLines(
          text,
          style: style,
          scaler: scaler,
          direction: direction,
          maxWidth: width,
        );
        // Every line is as tall as an unscaled one, so a label that had to
        // shrink stays level with its neighbours' text.
        Widget line(String text, {required bool last}) {
          if (last && label.ellipsize) {
            return SizedBox(
              width: width,
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            );
          }
          return SizedBox(
            height: label.lineHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text, maxLines: 1, softWrap: false, style: style),
            ),
          );
        }

        return Padding(
          // Under two lines of large text the next row would sit right on
          // the label, so it gets some room below too (none at default size).
          padding: EdgeInsets.fromLTRB(gap, 0, gap, gap * 2.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < label.lines.length; i++)
                line(label.lines[i], last: i == label.lines.length - 1),
            ],
          ),
        );
      },
    );
  }
}

/// Room kept on each side of a label: none at the default text size (the
/// labels have the whole cell, as on the board), 12 px per whole step of text
/// size above it, so neighbours do not run together in large text.
double labelGap(TextScaler scaler, double fontSize) =>
    math.max(0, scaler.scale(fontSize) / fontSize - 1) * 12;

/// Splits [text] into at most two lines of whole words that fit [maxWidth].
/// A name with more words than two lines hold keeps the rest on the second
/// line, which then ends in "..." ([ellipsize]). [lineHeight] is the height
/// of one line at this text size.
({List<String> lines, bool ellipsize, double lineHeight}) labelLines(
  String text, {
  required TextStyle style,
  required TextScaler scaler,
  required TextDirection direction,
  required double maxWidth,
}) {
  final words = text.trim().split(RegExp(r'\s+'));
  final painter = TextPainter(textDirection: direction, textScaler: scaler, maxLines: 1);
  double widthOf(String s) {
    painter
      ..text = TextSpan(text: s, style: style)
      ..layout();
    return painter.width;
  }

  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final joined = current.isEmpty ? word : '$current $word';
    if (current.isEmpty || widthOf(joined) <= maxWidth) {
      current = joined;
    } else {
      lines.add(current);
      current = word;
    }
  }
  lines.add(current);
  widthOf(lines.first);
  final lineHeight = painter.height;
  painter.dispose();
  if (lines.length <= 2) return (lines: lines, ellipsize: false, lineHeight: lineHeight);
  return (lines: [lines.first, lines.skip(1).join(' ')], ellipsize: true, lineHeight: lineHeight);
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
