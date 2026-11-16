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

/// Fill of a selected category tile: 15% accent over the neutral tile (on
/// light, a soft tint of the deeper accent).
Color litTileColor(AppColors c) => c.litTile;

/// Ring and glow of a selected category tile, CSS
/// `0 0 0 3px bg, 0 0 0 5px accent, 0 0 18px 7px accent/0x96`
/// (Flutter paints the list bottom-up, so the order is reversed). On light
/// there is no glow (it turns into a grey haze): the tile gets a 2 px ring
/// inside its edge instead, see [selectedTileRing].
List<BoxShadow> selectedTileShadows(AppColors c) =>
    c.brightness == Brightness.light
    ? const []
    : [
        cssShadow(blur: 18, spread: 7, color: c.accent.withAlpha(0x96)),
        BoxShadow(color: c.accent, spreadRadius: 5),
        BoxShadow(color: c.bg, spreadRadius: 3),
      ];

/// Light theme: the 2 px accent ring drawn inside a selected tile. Null on
/// dark, which has the outside ring and glow of [selectedTileShadows].
BoxBorder? selectedTileRing(AppColors c) => c.brightness == Brightness.light
    ? Border.all(color: c.accent, width: 2)
    : null;

/// Emoji text at a given size ([AppText.emoji], the phone's emoji font).
TextStyle emojiText(double size) => AppText.emoji.copyWith(fontSize: size);

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
