import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// A card (radius 20, `surface`) with a title band (`surface2`, 48 px; 56 px
/// when it holds a segmented control) and a body.
///
/// Band content, left to right: optional accent [icon] (20 px, gap 8), the
/// 15/20 w800 [title], then [trailingText] (12.5/16 w500 text3, on the
/// title's baseline) or any [trailing] widget.
class BandCard extends StatelessWidget {
  const BandCard({
    super.key,
    required this.title,
    this.icon,
    this.trailingText,
    this.trailing,
    this.child,
    this.bandHeight = 48,
    this.bodyPadding = EdgeInsets.zero,
    this.titleWidget,
  });

  /// Use `bandHeight: BandCard.tallBand` for a band with a segmented control.
  static const double tallBand = 56;

  /// Padding of a list body (4 px above and below the rows).
  static const EdgeInsets listPadding = EdgeInsets.symmetric(vertical: 4);

  final String title;
  final IconData? icon;
  final String? trailingText;
  final Widget? trailing;
  final Widget? child;
  final double bandHeight;
  final EdgeInsets bodyPadding;

  /// Replaces the title text.
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: c.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: bandHeight,
              color: c.surface2,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: c.accent),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: titleWidget ??
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.cardTitle,
                              ),
                        ),
                        if (trailingText != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            trailingText!,
                            style: AppText.sub.copyWith(color: c.text3),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
            if (child != null) Padding(padding: bodyPadding, child: child),
          ],
        ),
      ),
    );
  }
}

/// A 44 px emoji tile (radius 14, `tile`). With [dotColor] it shows the
/// category's colour dot at the bottom-right with a ring in [ringColor]
/// (the card colour, `surface` by default), as on the Categories board.
/// For the 28 px peek tiles use `size: 28, radius: 9, emojiSize: 15`.
class EmojiTile extends StatelessWidget {
  const EmojiTile({
    super.key,
    required this.emoji,
    this.size = 44,
    this.radius = 14,
    this.emojiSize = 22,
    this.background,
    this.dotColor,
    this.ringColor,
    this.border,
    this.shadows,
  });

  final String emoji;
  final double size;
  final double radius;
  final double emojiSize;

  /// Defaults to `tile`.
  final Color? background;

  /// Category colour dot (12 px), or null for none.
  final Color? dotColor;

  /// Ring around the dot (2.5 px); defaults to `surface`.
  final Color? ringColor;

  /// Optional ring around the tile (selected state on Add expense).
  final BoxBorder? border;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? c.tile,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadows,
      ),
      child: Text(
        emoji,
        textAlign: TextAlign.center,
        style: AppText.emoji.copyWith(fontSize: emojiSize),
      ),
    );
    if (dotColor == null) return ExcludeSemantics(child: tile);
    const dot = 12.0;
    const ring = 2.5;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            tile,
            Positioned(
              right: -3 - ring,
              bottom: -3 - ring,
              child: Container(
                width: dot + ring * 2,
                height: dot + ring * 2,
                decoration: BoxDecoration(
                  color: ringColor ?? c.surface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
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

/// A 44 px tile (radius 14, `tile`) with a 22 px icon in [iconColor]
/// (accent by default).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.radius = 14,
    this.iconSize = 22,
    this.background,
    this.iconColor,
    this.fill = 0,
  });

  final IconData icon;
  final double size;
  final double radius;
  final double iconSize;

  /// Defaults to `tile`.
  final Color? background;

  /// Defaults to `accent`.
  final Color? iconColor;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? c.tile,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: iconColor ?? c.accent, fill: fill),
    );
  }
}

/// A list row inside a card.
///
/// * With a [leading] tile (44 px): 16 px left padding, 12 px gap, and the
///   divider starts at the text (x = 72 inside the card, x = 88 on screen).
/// * Without: 16 px margins and a full-width divider (Settings rows).
///
/// Height: [height], else 68 with a [subtitle] or a [leading] tile, else 56.
/// [divider] draws a 1 px `line` at the bottom (leave it off on the last row).
/// Right side: [trailing] widget, or [trailingText] as a 15/20 w700 amount.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.trailingText,
    this.divider = true,
    this.onTap,
    this.onLongPress,
    this.height,
    this.titleStyle,
    this.titleColor,
    this.subtitleColor,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? trailingText;
  final bool divider;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? height;

  /// Defaults to [AppText.rowTitle].
  final TextStyle? titleStyle;
  final Color? titleColor;

  /// Defaults to `text3`.
  final Color? subtitleColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = height ?? (subtitle != null || leading != null ? 68.0 : 56.0);
    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (titleStyle ?? AppText.rowTitle)
              .copyWith(color: titleColor ?? c.text),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.sub.copyWith(color: subtitleColor ?? c.text3),
          ),
        ],
      ],
    );
    final right = trailing ??
        (trailingText == null
            ? null
            : Text(
                trailingText!,
                style: AppText.rowAmount.copyWith(color: c.text),
              ));
    final body = Container(
      height: h,
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: c.line)))
          : null,
      child: Row(
        children: [
          Expanded(child: texts),
          if (right != null) ...[const SizedBox(width: 12), right],
        ],
      ),
    );
    final row = leading == null
        ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: body)
        : Row(
            children: [
              const SizedBox(width: 16),
              leading!,
              const SizedBox(width: 12),
              Expanded(child: body),
              const SizedBox(width: 16),
            ],
          );
    if (onTap == null && onLongPress == null) {
      return Semantics(label: semanticLabel, child: row);
    }
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      child: row,
    );
  }
}
