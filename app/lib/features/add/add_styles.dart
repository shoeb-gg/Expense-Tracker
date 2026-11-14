import 'package:flutter/widgets.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/pressable.dart' show cssShadow;

/// A text style in the app font, written the way the mockup writes CSS:
/// font size, line height and weight (letter spacing 0 unless given).
TextStyle boardText(
  double size,
  double lineHeight,
  FontWeight weight, {
  double letterSpacing = 0,
  bool tabular = false,
  Color? color,
}) => TextStyle(
  fontFamily: kFontFamily,
  fontSize: size,
  height: lineHeight / size,
  fontWeight: weight,
  letterSpacing: letterSpacing,
  color: color,
  leadingDistribution: TextLeadingDistribution.even,
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
);

/// Fill of a selected category tile: 15% accent over the neutral tile.
Color litTileColor(AppColors c) => mix(c.accent, c.tile, 0.15);

/// Ring and glow of a selected category tile, CSS
/// `0 0 0 3px bg, 0 0 0 5px accent, 0 0 18px 7px accent/0x96`
/// (Flutter paints the list bottom-up, so the order is reversed).
List<BoxShadow> selectedTileShadows(AppColors c) => [
  cssShadow(blur: 18, spread: 7, color: c.accent.withAlpha(0x96)),
  BoxShadow(color: c.accent, spreadRadius: 5),
  BoxShadow(color: c.bg, spreadRadius: 3),
];

/// Emoji text at a given size, drawn by the phone's emoji font.
///
/// The family is the emoji font's name, not the app font: Plus Jakarta Sans
/// has a plain ▶ (U+25B6), which would otherwise win over the colour emoji
/// ▶️ of "Online Subscriptions". When the name is not found, the phone's
/// own fallback (or the test emoji font) draws the emoji.
TextStyle emojiText(double size) =>
    AppText.emoji.copyWith(fontSize: size, fontFamily: emojiFontFamily);

/// Family name of the colour emoji font on Android.
const String emojiFontFamily = 'Noto Color Emoji';

/// A rounded square with an emoji in the middle (category and pocket tiles).
class EmojiBox extends StatelessWidget {
  const EmojiBox({
    super.key,
    required this.emoji,
    required this.background,
    this.size = 44,
    this.radius = 14,
    this.emojiSize = 22,
  });

  final String emoji;
  final Color background;
  final double size;
  final double radius;
  final double emojiSize;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
        child: Text(emoji, textAlign: TextAlign.center, style: emojiText(emojiSize)),
      ),
    );
  }
}
