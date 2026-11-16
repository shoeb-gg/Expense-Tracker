import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A CSS `box-shadow` as a Flutter [BoxShadow]. CSS blurs with a Gaussian
/// of sigma = blur / 2; Flutter's blurRadius maps to sigma = r * 0.57735 + 0.5,
/// so the radius is converted to match the mockup.
BoxShadow cssShadow({
  double x = 0,
  double y = 0,
  required double blur,
  double spread = 0,
  required Color color,
}) {
  final sigma = blur / 2;
  final radius = sigma <= 0.5 ? 0.0 : (sigma - 0.5) / 0.57735;
  return BoxShadow(
    offset: Offset(x, y),
    blurRadius: radius,
    spreadRadius: spread,
    color: color,
  );
}

/// Shadow of pop-up cards: 0 16px 40px rgba(0,0,0,0.5) on dark; on light a
/// shorter, softer 0 8px 32px of the mood's ink at 16%.
BoxShadow popupShadow(AppColors c) => c.brightness == Brightness.light
    ? cssShadow(y: 8, blur: 32, color: c.shadowLg)
    : cssShadow(y: 16, blur: 40, color: c.shadowLg);

/// Shadow of bottom sheets: 0 -12px 40px rgba(0,0,0,0.45) on dark; on light
/// 0 -8px 32px of the mood's ink at 16%.
BoxShadow sheetShadow(AppColors c) => c.brightness == Brightness.light
    ? cssShadow(y: -8, blur: 32, color: c.shadowLg)
    : cssShadow(y: -12, blur: 40, color: c.shadowMd);

/// Light theme: the 1 px stroke drawn inside a white card or button, so it
/// keeps its edge on the pale page. Null on dark.
BoxBorder? edgeBorder(AppColors c) =>
    c.brightness == Brightness.light ? Border.all(color: c.edge) : null;

/// Light theme: the two soft shadows that lift a white card or button off the
/// page (0 1px 2px, 0 4px 12px of the mood's ink). Null on dark.
List<BoxShadow>? liftShadows(AppColors c) => c.brightness == Brightness.light
    ? [
        cssShadow(y: 1, blur: 2, color: c.lift1),
        cssShadow(y: 4, blur: 12, color: c.lift2),
      ]
    : null;

/// Light theme: the foreground stroke of a white card built as a `Container`
/// (use as `foregroundDecoration`, with `boxShadow: liftShadows(c)` in its
/// `decoration`). Null on dark.
Decoration? edgeDecoration(AppColors c, BorderRadius radius) =>
    c.brightness == Brightness.light
    ? BoxDecoration(borderRadius: radius, border: Border.all(color: c.edge))
    : null;

/// A [ClipRRect] for a white card: on light it also gets the soft lift and the
/// 1 px inside stroke of [CardEdge]. On dark it is a plain [ClipRRect].
class CardClip extends StatelessWidget {
  const CardClip({super.key, required this.borderRadius, required this.child});

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) => CardEdge(
    radius: borderRadius,
    child: ClipRRect(borderRadius: borderRadius, child: child),
  );
}

/// Light theme: gives [child] (a white card, tile or chip) the soft lift and
/// the 1 px inside stroke of [edgeBorder] and [liftShadows]. Both are drawn
/// without any padding, so nothing moves. On dark it is [child] itself.
class CardEdge extends StatelessWidget {
  const CardEdge({
    super.key,
    required this.child,
    this.radius = BorderRadius.zero,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final BorderRadius radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (c.brightness != Brightness.light) return child;
    final round = shape == BoxShape.circle ? null : radius;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: round,
        boxShadow: liftShadows(c),
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: round,
          border: edgeBorder(c),
        ),
        child: child,
      ),
    );
  }
}

/// Glow under accent buttons: 0 8px 22px -2px accentGlow.
BoxShadow accentGlowShadow(Color glow) =>
    cssShadow(y: 8, blur: 22, spread: -2, color: glow);

/// A filled, rounded area that reacts to taps with the theme's subtle accent
/// splash. The base of every button in the kit.
class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color = Colors.transparent,
    this.borderRadius = BorderRadius.zero,
    this.border,
    this.shadows,
    this.semanticLabel,
    this.selected,
    this.button = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Fill colour.
  final Color color;
  final BorderRadius borderRadius;

  /// Drawn inside the shape (like a CSS inset ring).
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final String? semanticLabel;
  final bool? selected;
  final bool button;

  @override
  Widget build(BuildContext context) {
    Widget content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: child,
      ),
    );
    content = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        boxShadow: shadows,
      ),
      position: DecorationPosition.background,
      child: ClipRRect(borderRadius: borderRadius, child: content),
    );
    if (border != null) {
      content = DecoratedBox(
        decoration: BoxDecoration(border: border, borderRadius: borderRadius),
        position: DecorationPosition.foreground,
        child: content,
      );
    }
    return Semantics(
      button: button && (onTap != null || onLongPress != null),
      enabled: onTap != null || onLongPress != null,
      selected: selected,
      label: semanticLabel,
      child: content,
    );
  }
}
