import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';

/// A titled group of the emoji picker.
typedef EmojiGroup = ({String title, List<String> emojis});

/// The 36 emojis of the Add and Edit category boards, in six groups.
const List<EmojiGroup> categoryEmojiGroups = [
  (
    title: 'Food and drink',
    emojis: [
      '\u{1F966}',
      '\u{1F357}',
      '\u{1F355}',
      '☕',
      '\u{1F370}',
      '\u{1F34E}',
    ],
  ),
  (
    title: 'Home and bills',
    emojis: ['\u{1F3E0}', '⚡', '\u{1F310}', '☎️', '\u{1F525}', '\u{1F4A7}'],
  ),
  (
    title: 'Getting around',
    emojis: ['\u{1F68D}', '\u{1F695}', '✈️', '⛽', '\u{1F6F5}', '\u{1F686}'],
  ),
  (
    title: 'Shopping',
    emojis: [
      '\u{1F6CD}️',
      '\u{1F455}',
      '\u{1F45F}',
      '\u{1F484}',
      '\u{1F381}',
      '\u{1F4F1}',
    ],
  ),
  (
    title: 'Health and care',
    emojis: [
      '\u{1F48A}',
      '\u{1F4AA}',
      '\u{1F9F4}',
      '\u{1F3E5}',
      '\u{1F9B7}',
      '\u{1FA7A}',
    ],
  ),
  (
    title: 'Fun and everything else',
    emojis: [
      '▶️',
      '\u{1F37F}',
      '\u{1F389}',
      '\u{1F4DA}',
      '\u{1F436}',
      '\u{1F9E9}',
    ],
  ),
];

/// A new category starts with the label emoji and amber.
const String newCategoryEmoji = '\u{1F3F7}️';
const CategoryColor newCategoryColor = CategoryColor.amber;

/// "Amber", or "Custom" for a colour outside the eight.
String colorName(int argb) => CategoryColor.fromArgb(argb)?.label ?? 'Custom';

/// The live preview tile of the form: 56 px, radius 18, a 28 px emoji and
/// a 16 px colour dot.
class CategoryPreviewTile extends StatelessWidget {
  const CategoryPreviewTile({
    super.key,
    required this.emoji,
    required this.color,
  });

  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const dot = 16.0;
    const ring = 2.5;
    return ExcludeSemantics(
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.tile,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(emoji, style: AppText.emoji.copyWith(fontSize: 28)),
            ),
            Positioned(
              right: -3 - ring,
              bottom: -3 - ring,
              child: Container(
                width: dot + ring * 2,
                height: dot + ring * 2,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: color,
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

/// The eight chart colours as 30 px swatches; the chosen one has a ring in
/// its own colour, a gap, and a tick.
class ColorSwatches extends StatelessWidget {
  const ColorSwatches({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<CategoryColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final color in CategoryColor.values)
          Semantics(
            button: true,
            selected: color.argb == value,
            label: color.label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(color),
              child: SizedBox(
                width: 30,
                height: 30,
                child: color.argb != value
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.color,
                          shape: BoxShape.circle,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: color.color,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2.5),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color.color,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Symbols.check_rounded,
                              size: 16,
                              color: Color(0xFF0B1517),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The six emoji groups and the keyboard button under them.
class EmojiPicker extends StatelessWidget {
  const EmojiPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onKeyboard,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onKeyboard;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in categoryEmojiGroups) ...[
          Text(g.title, style: AppText.overline.copyWith(color: c.text3)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final e in g.emojis)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Pressable(
                    onTap: () => onChanged(e),
                    selected: e == value,
                    semanticLabel: e,
                    color: e == value ? c.accentSoft : c.tile,
                    borderRadius: BorderRadius.circular(14),
                    border: e == value
                        ? Border.all(color: c.accent, width: 2)
                        : null,
                    child: Center(child: Text(e, style: AppText.emoji)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        SizedBox(
          height: 44,
          child: Pressable(
            onTap: onKeyboard,
            color: c.surface2,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Symbols.keyboard_rounded, size: 20, color: c.text3),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Pick any emoji from your keyboard',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.text2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// True when [g] (one grapheme) is an emoji rather than a letter or digit.
bool isEmojiGrapheme(String g) {
  const singles = {
    0x00A9, 0x00AE, 0x203C, 0x2049, 0x20E3, 0x2122, 0x2139, //
    0x3030, 0x303D, 0x3297, 0x3299,
  };
  return g.runes.any(
    (r) => r >= 0x1F000 || (r >= 0x2190 && r <= 0x2BFF) || singles.contains(r),
  );
}

/// The last emoji typed into [text], or null.
String? lastEmoji(String text) {
  for (final g in text.characters.toList().reversed) {
    if (isEmojiGrapheme(g)) return g;
  }
  return null;
}

/// An invisible one-character field. Focusing it opens the phone's keyboard;
/// the user taps the keyboard's emoji key and the emoji they pick arrives in
/// [onEmoji]. (Android cannot open the keyboard on its emoji page directly.)
class KeyboardEmojiCatcher extends StatefulWidget {
  const KeyboardEmojiCatcher({
    super.key,
    required this.focusNode,
    required this.onEmoji,
  });

  final FocusNode focusNode;
  final ValueChanged<String> onEmoji;

  @override
  State<KeyboardEmojiCatcher> createState() => _KeyboardEmojiCatcherState();
}

class _KeyboardEmojiCatcherState extends State<KeyboardEmojiCatcher> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final e = lastEmoji(text);
    _controller.clear();
    if (e != null) {
      widget.onEmoji(e);
      widget.focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 1,
        height: 1,
        child: Opacity(
          opacity: 0,
          child: TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            onChanged: _changed,
            keyboardType: TextInputType.text,
            enableSuggestions: false,
            autocorrect: false,
            showCursor: false,
            enableInteractiveSelection: false,
            inputFormatters: [LengthLimitingTextInputFormatter(16)],
            decoration: const InputDecoration.collapsed(hintText: ''),
          ),
        ),
      ),
    );
  }
}
