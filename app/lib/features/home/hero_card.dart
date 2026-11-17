import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';

/// The height of [HeroCard].
const double heroCardHeight = 92;

/// Home's turquoise card (PocketHome board): the month chip on the left and
/// the month's total on the right, 92 px tall, radius 24.
///
/// [caption] sits over [value] ("Spent in October" over "34,555"). With a
/// [unit] the value is a count, not money: "33 expenses", the word in a
/// smaller type on the number's baseline (monthly total off). Tapping the
/// chip calls [onMonthTap]; tapping the rest calls [onValueTap].
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.month,
    required this.caption,
    required this.value,
    required this.onMonthTap,
    required this.onValueTap,
    this.unit,
    this.valueSemanticLabel,
  });

  final YearMonth month;
  final String caption;
  final String value;

  /// Word after a count ("expenses"), or null for an amount.
  final String? unit;
  final VoidCallback onMonthTap;
  final VoidCallback onValueTap;
  final String? valueSemanticLabel;

  /// The [unit] word: 18 px w700 (the number is 32 px w800).
  static final TextStyle _unitStyle = AppText.heroNumber.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: heroCardHeight,
      child: CustomPaint(
        painter: _HeroPainter(
          fill: c.accentFill,
          sheen: c.sheen,
          ring: c.ring,
          ringSoft: c.ringSoft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                child: SizedBox(
                  width: 80,
                  child: _MonthChip(month: month, onTap: onMonthTap),
                ),
              ),
              Expanded(
                child: Pressable(
                  onTap: onValueTap,
                  semanticLabel: valueSemanticLabel,
                  child: ExcludeSemantics(
                    excluding: valueSemanticLabel != null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.overline.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.onFillDim,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: 36,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: unit == null || value.isEmpty
                                        ? Text(
                                            value,
                                            maxLines: 1,
                                            style: AppText.heroNumber.copyWith(
                                              color: c.onFill,
                                            ),
                                          )
                                        : Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: value,
                                                  style: AppText.heroNumber
                                                      .copyWith(
                                                        color: c.onFill,
                                                      ),
                                                ),
                                                TextSpan(
                                                  text: ' $unit',
                                                  style: _unitStyle.copyWith(
                                                    color: c.onFill,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // A big total shrinks to fit, so keep air between
                          // it and the arrow.
                          const SizedBox(width: 10),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.onFill,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Symbols.north_east_rounded,
                              size: 18,
                              color: c.onInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dark "2026 / Oct ˅" chip that opens the month pop-up.
///
/// The chip is a fixed 80 x 76 box, so its content scales down to fit when
/// the text size makes it bigger (it never clips): at the default size it is
/// laid out at its own size, exactly as drawn.
class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.month, required this.onTap});

  final YearMonth month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      color: c.onFill,
      borderRadius: BorderRadius.circular(16),
      semanticLabel: 'Choose month, ${monthYear(month.year, month.month)}',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: Padding(
            // 4 px at the sides keep the chevron (it paints 4 px past its
            // box) inside the chip when the content is scaled to the width.
            padding: const EdgeInsets.fromLTRB(4, 11, 4, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${month.year}',
                  style: AppText.overline.copyWith(color: c.pillDim),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      monthShortName(month.month),
                      maxLines: 1,
                      softWrap: false,
                      style: AppText.pageTitle.copyWith(
                        fontSize: 22,
                        height: 36 / 22,
                        color: c.onInk,
                      ),
                    ),
                    // The chevron overlaps the text box by 4 px (margin -4),
                    // so the group centres as "Oct˅" in the mockup.
                    SizedBox(
                      width: 16,
                      height: 22,
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: 20,
                        maxWidth: 20,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Symbols.expand_more_rounded,
                            size: 20,
                            color: c.accentFill,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The card fill, its 1 px inner top highlight and the two quarter rings in
/// the bottom-right corner.
class _HeroPainter extends CustomPainter {
  const _HeroPainter({
    required this.fill,
    required this.sheen,
    required this.ring,
    required this.ringSoft,
  });

  final Color fill;
  final Color sheen;
  final Color ring;
  final Color ringSoft;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );
    canvas
      ..save()
      ..clipRRect(rrect)
      ..drawRRect(rrect, Paint()..color = fill);

    // Two quarter rings centred on the bottom-right corner (CSS: 56 px and
    // 92 px boxes with a 1.5 px top+left border and a full top-left radius).
    final corner = Offset(size.width, size.height);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas
      ..drawArc(
        Rect.fromCircle(center: corner, radius: 56 - 0.75),
        math.pi,
        math.pi / 2,
        false,
        stroke..color = ring,
      )
      ..drawArc(
        Rect.fromCircle(center: corner, radius: 92 - 0.75),
        math.pi,
        math.pi / 2,
        false,
        stroke..color = ringSoft,
      );

    // inset 0 1px 0 sheen: the card shape minus itself moved down 1 px.
    final shape = Path()..addRRect(rrect);
    canvas
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          shape,
          shape.shift(const Offset(0, 1)),
        ),
        Paint()..color = sheen,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_HeroPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      sheen != oldDelegate.sheen ||
      ring != oldDelegate.ring ||
      ringSoft != oldDelegate.ringSoft;
}
