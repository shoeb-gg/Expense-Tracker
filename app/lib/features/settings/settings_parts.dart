import 'package:flutter/material.dart';

import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';

/// A value and the row chevron, laid out like the board: the chevron box is
/// 14 px wide and its 20 px glyph hangs 6 px past the row's edge, so the
/// value text ends 16 px from the edge ("Sunday ›").
class ValueChevron extends StatelessWidget {
  const ValueChevron({super.key, this.text, this.tabular = false});

  final String? text;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppText.value.copyWith(color: c.text3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text != null) ...[
          Text(
            text!,
            maxLines: 1,
            style: tabular ? AppText.tabular(style) : style,
          ),
          const SizedBox(width: 2),
        ],
        const HangingIcon(icon: Symbols.chevron_right_rounded, box: 14),
      ],
    );
  }
}

/// A 20 px icon in a narrower layout box, drawn hanging out to the right
/// (CSS negative right margin).
class HangingIcon extends StatelessWidget {
  const HangingIcon({
    super.key,
    required this.icon,
    required this.box,
    this.size = 20,
    this.color,
  });

  final IconData icon;
  final double box;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: box,
      height: size,
      child: OverflowBox(
        minWidth: size,
        maxWidth: size,
        alignment: Alignment.centerLeft,
        child: Icon(icon, size: size, color: color ?? context.colors.text3),
      ),
    );
  }
}

/// Small emoji tiles before a row's chevron (28 px, radius 9), optionally
/// ending with a "+13" chip.
class PeekTiles extends StatelessWidget {
  const PeekTiles({super.key, required this.emojis, this.more = 0});

  final List<String> emojis;
  final int more;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tiles = <Widget>[
      for (final e in emojis)
        EmojiTile(emoji: e, size: 28, radius: 9, emojiSize: 15),
      if (more > 0)
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.tile,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '+$more',
            maxLines: 1,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 10.5,
              height: 14 / 10.5,
              fontWeight: FontWeight.w800,
              color: c.text2,
            ),
          ),
        ),
    ];
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            tiles[i],
          ],
          const SizedBox(width: 6),
          const HangingIcon(icon: Symbols.chevron_right_rounded, box: 14),
        ],
      ),
    );
  }
}

/// Title on the left and a 13/16 note on the right, on one baseline
/// ("Color theme ... Aqua", "Text size ... Default").
class BlockHeader extends StatelessWidget {
  const BlockHeader({super.key, required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(title, style: AppText.rowTitle)),
        const SizedBox(width: 12),
        Text(
          note,
          style: AppText.sub.copyWith(
            fontSize: 13,
            height: 16 / 13,
            color: c.text3,
          ),
        ),
      ],
    );
  }
}

/// The three colour themes as preview tiles. Each tile is drawn in its own
/// theme's colours; the chosen one has a 2 px ring and a tick.
class MoodTiles extends StatelessWidget {
  const MoodTiles({super.key, required this.value, required this.onChanged});

  final Mood value;
  final ValueChanged<Mood> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < Mood.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _MoodTile(
              mood: Mood.values[i],
              selected: Mood.values[i] == value,
              onTap: () => onChanged(Mood.values[i]),
              labelColor: Mood.values[i] == value ? c.text : c.text2,
            ),
          ),
        ],
      ],
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.selected,
    required this.onTap,
    required this.labelColor,
  });

  final Mood mood;
  final bool selected;
  final VoidCallback onTap;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    // The preview is drawn in the brightness the app has now, so Light shows
    // the light version of each colour theme.
    final m = AppColors.of(mood, brightness: context.colors.brightness);
    const heights = [10.0, 24.0, 16.0, 20.0];
    return Semantics(
      button: true,
      selected: selected,
      label: mood.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Pressable(
              onTap: onTap,
              color: m.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? m.accent : m.line,
                width: selected ? 2 : 1,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: m.accentFill,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: selected
                          ? Icon(
                              Symbols.check_rounded,
                              size: 16,
                              color: m.onFill,
                            )
                          : null,
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 24,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < heights.length; i++) ...[
                            if (i > 0) const SizedBox(width: 3),
                            Container(
                              width: 6,
                              height: heights[i],
                              decoration: BoxDecoration(
                                color: i == 1 ? m.accent : m.barSoft,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Text(
              mood.label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: AppText.segmentSmall.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The five-step Text size slider: a 4 px track, the accent fill up to a
/// 20 px white thumb, and a 4 px dot at every step.
class TextSizeSlider extends StatelessWidget {
  const TextSizeSlider({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  static const int steps = 5;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final aStyle = AppText.caption.copyWith(
      fontWeight: FontWeight.w700,
      color: c.text3,
    );
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          ExcludeSemantics(child: Text('A', style: aStyle)),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final travel = w - 20;
                final frac = index / (steps - 1);
                int at(double dx) => ((dx - 10) / travel * (steps - 1))
                    .round()
                    .clamp(0, steps - 1);
                void pick(double dx) {
                  final i = at(dx);
                  if (i != index) onChanged(i);
                }

                return Semantics(
                  slider: true,
                  label: 'Text size',
                  value: '${index + 1} of $steps',
                  increasedValue: index < steps - 1
                      ? '${index + 2} of $steps'
                      : null,
                  decreasedValue: index > 0 ? '$index of $steps' : null,
                  onIncrease: index < steps - 1
                      ? () => onChanged(index + 1)
                      : null,
                  onDecrease: index > 0 ? () => onChanged(index - 1) : null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => pick(d.localPosition.dx),
                    onHorizontalDragStart: (d) => pick(d.localPosition.dx),
                    onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 12,
                          height: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.track,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 150),
                          left: 0,
                          top: 12,
                          height: 4,
                          width: travel * frac + 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        for (var i = 0; i < steps; i++)
                          Positioned(
                            left: travel * i / (steps - 1) + 8,
                            top: 12,
                            width: 4,
                            height: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: i <= index ? c.onAccentDim : c.dim,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 150),
                          left: travel * frac,
                          top: 4,
                          width: 20,
                          height: 20,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.thumb,
                              shape: BoxShape.circle,
                              boxShadow: [
                                cssShadow(
                                  y: 2,
                                  blur: 6,
                                  color: c.shadowSm,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: Text(
              'A',
              style: aStyle.copyWith(fontSize: 19, height: 24 / 19),
            ),
          ),
        ],
      ),
    );
  }
}
