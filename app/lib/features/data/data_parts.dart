import 'package:flutter/material.dart';

import '../../data/db.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';

/// "👛 Personal" for a header subtitle; long names are cut with "…" so the
/// subtitle stays on one line.
String pocketLabel(Pocket? pocket) {
  if (pocket == null) return '';
  final name = pocket.name.characters.length > 16
      ? '${pocket.name.characters.take(15)}…'
      : pocket.name;
  return '${pocket.emoji} $name';
}

/// "Step 2 of 3 · 👛 Personal": the step and the pocket the import goes to.
String stepSubtitle(int step, Pocket? pocket) {
  final where = pocketLabel(pocket);
  return where.isEmpty ? 'Step $step of 3' : 'Step $step of 3 · $where';
}

/// The page frame of Export and the import steps: header, a scrolling
/// column of cards (2 px top, 12 px gaps) and a docked button.
class DataPage extends StatelessWidget {
  const DataPage({
    super.key,
    required this.header,
    required this.children,
    required this.dock,
  });

  final Widget header;
  final List<Widget> children;
  final Widget dock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            header,
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
            dock,
          ],
        ),
      ),
    );
  }
}

/// The docked action of these screens: a 52 px button (15.5 px label) and
/// a hint under it.
class DataDock extends StatelessWidget {
  const DataDock({
    super.key,
    required this.label,
    required this.onPressed,
    required this.hint,
  });

  final String label;
  final VoidCallback? onPressed;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return DockedBar(
      hint: hint,
      child: PrimaryButton(label: label, onPressed: onPressed, fontSize: 15.5),
    );
  }
}

/// A plain card (radius 20, `surface`).
class PlainCard extends StatelessWidget {
  const PlainCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// A two-line choice (Export's file type), at least 64 px high: tinted with a
/// 2 px accent ring and a ticked circle when chosen. Large text wraps and the
/// row grows to hold it.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: '$title. $subtitle',
        color: selected ? c.accentSoft : c.tile,
        borderRadius: BorderRadius.circular(16),
        border: selected ? Border.all(color: c.accent, width: 2) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.rowTitle.copyWith(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.sub.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? c.accent : null,
                  shape: BoxShape.circle,
                  border: selected
                      ? null
                      : Border.all(color: mix(c.text3, c.tile, 0.5), width: 2),
                ),
                child: selected
                    ? Icon(Symbols.check_rounded, size: 18, color: c.onAccent)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 56 px date field ("From   Oct 1, 2026 📅") that opens the date pop-up.
class DateFieldRow extends StatelessWidget {
  const DateFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 56,
      child: Pressable(
        onTap: onTap,
        semanticLabel: '$label $value. Tap to change',
        color: c.tile,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
          child: Row(
            children: [
              Text(label, style: AppText.segment.copyWith(color: c.text2)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: AppText.rowAmount,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Symbols.calendar_month_rounded, size: 20, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small `tile` button with a 13 px label ("Change").
class SmallTileButton extends StatelessWidget {
  const SmallTileButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 32,
      child: Pressable(
        onTap: onTap,
        color: c.tile,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppText.label.copyWith(
                fontSize: 13,
                height: 16 / 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The column picker of "Check the columns": at least 124 px wide and 40 px
/// high. A long label wraps and the button grows to hold it.
class ColumnButton extends StatelessWidget {
  const ColumnButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.semanticLabel,
    this.tone = ColumnButtonTone.found,
  });

  final String label;
  final VoidCallback onTap;
  final String semanticLabel;
  final ColumnButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = switch (tone) {
      ColumnButtonTone.found => AppText.label,
      ColumnButtonTone.missing => AppText.label.copyWith(
        color: c.accent,
        fontWeight: FontWeight.w700,
      ),
      ColumnButtonTone.unused => AppText.label.copyWith(color: c.text3),
    };
    // As wide as its label needs, at least the board's 124 px.
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 124,
          maxWidth: 176,
          minHeight: 40,
        ),
        child: Pressable(
          onTap: onTap,
          semanticLabel: semanticLabel,
          color: c.tile,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                Expanded(child: Text(label, style: style)),
                const SizedBox(width: 4),
                Icon(Symbols.expand_more_rounded, size: 20, color: c.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum ColumnButtonTone { found, missing, unused }

/// The "Needed" / "Optional" chip of Import step 1.
class SmallChip extends StatelessWidget {
  const SmallChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// The small "New" badge beside a category that the import creates.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      // As wide as the word, also where the line gives it all the room
      // (a Container's `alignment` would stretch it across the line).
      child: Center(
        widthFactor: 1,
        child: Text(
          'New',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 11,
            height: 16 / 11,
            fontWeight: FontWeight.w800,
            color: c.accent,
          ),
        ),
      ),
    );
  }
}

/// A 1 px `line` over the bottom edge of [child] that takes no space (the
/// boards' inset box-shadow), [left] and [right] in from the sides. Use it
/// with `ListRow(divider: false)` so the row's text stays centred like the
/// board's.
class BottomHairline extends StatelessWidget {
  const BottomHairline({
    super.key,
    required this.child,
    this.show = true,
    this.left = 16,
    this.right = 16,
  });

  /// Divider under a row with a 44 px leading tile (starts at the text).
  const BottomHairline.afterTile({
    super.key,
    required this.child,
    this.show = true,
  }) : left = 72,
       right = 16;

  final Widget child;
  final bool show;
  final double left;
  final double right;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      children: [
        child,
        Positioned(
          left: left,
          right: right,
          bottom: 0,
          height: 1,
          child: IgnorePointer(child: ColoredBox(color: context.colors.line)),
        ),
      ],
    );
  }
}

/// A 1 px `line` drawn over the top edge of [child] without taking space
/// (CSS inset box-shadow).
class TopHairline extends StatelessWidget {
  const TopHairline({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      foregroundDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.line)),
      ),
      child: child,
    );
  }
}
