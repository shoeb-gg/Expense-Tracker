import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'headers.dart' show titleWidth;
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
                  Expanded(child: _titleLine(c)),
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

  /// The title with [trailingText] on its baseline. When the two do not fit
  /// on one line (large text), the title keeps its room and the text wraps,
  /// right-aligned, to a second line beside it (two lines fit the band)
  /// instead of the title ending in "...".
  Widget _titleLine(AppColors c) {
    final noteStyle = AppText.sub.copyWith(color: c.text3);
    Widget oneLine() => Row(
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
              Text(trailingText!, style: noteStyle),
            ],
          ],
        );
    final note = trailingText;
    if (note == null || titleWidget != null) return oneLine();
    return LayoutBuilder(
      builder: (context, box) {
        final titleW = titleWidth(context, title, AppText.cardTitle);
        final noteW = titleWidth(context, note, noteStyle);
        if (!box.maxWidth.isFinite || titleW + 12 + noteW <= box.maxWidth) {
          return oneLine();
        }
        // The title gets what it needs, the note at least 96 px.
        final titleRoom = math.min(titleW + 1, box.maxWidth - 12 - math.min(noteW, 96));
        return Row(
          children: [
            SizedBox(
              width: titleRoom,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.cardTitle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                note,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: noteStyle,
              ),
            ),
          ],
        );
      },
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

/// A centred message on a card (radius 20, `surface`, padding 24 16): a
/// 44 px accent tile with [icon], the 15/20 w800 [title] and a 13.5/20
/// text3 [message]. Home's empty month card (PocketHome board) and the
/// app's "not found" state ([NotFoundCard]). As wide as it is allowed and
/// only as tall as its content.
class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon: icon, background: c.accentSoft, iconColor: c.accent),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.cardTitle.copyWith(color: c.text),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: c.text3),
          ),
        ],
      ),
    );
  }
}

/// The body of a screen whose item does not exist (a bad link, or it was
/// deleted): a [MessageCard] "<[thing]> not found" / "It may have been
/// deleted." at the top, 2 px under the header with 16 px gutters (where a
/// sub-screen's first card sits). Put it where the screen's content goes
/// (e.g. in the `Expanded` under a `SubHeader`).
class NotFoundCard extends StatelessWidget {
  const NotFoundCard({super.key, required this.thing, required this.icon});

  /// "Expense", "Pocket", "Category".
  final String thing;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: MessageCard(
          icon: icon,
          title: '$thing not found',
          message: 'It may have been deleted.',
        ),
      ),
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
/// With [wrap] that is the least height: the title and the subtitle wrap
/// instead of ending in "…", and the row grows to hold them (10 px of room
/// above and below the text), so large text shows in full. Text that fits
/// one line leaves the row as it was.
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
    this.wrap = false,
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

  /// Let the title and the subtitle wrap and the row grow (see above)
  /// instead of cutting them to one line.
  final bool wrap;

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
          maxLines: wrap ? null : 1,
          overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
          style: (titleStyle ?? AppText.rowTitle)
              .copyWith(color: titleColor ?? c.text),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: wrap ? null : 1,
            overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
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
    final content = Row(
      children: [
        Expanded(child: texts),
        if (right != null) ...[const SizedBox(width: 12), right],
      ],
    );
    final body = Container(
      height: wrap ? null : h,
      constraints: wrap ? BoxConstraints(minHeight: h) : null,
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: c.line)))
          : null,
      // Wrapped text keeps 10 px from the row's edges; the row is at least
      // [h] high, so one line of text sits where it always did.
      child: wrap
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: content,
            )
          : content,
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
