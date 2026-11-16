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

/// Shadow of pop-up cards: 0 16px 40px rgba(0,0,0,0.5) on dark (a lighter
/// ink tone on light).
BoxShadow popupShadow(AppColors c) =>
    cssShadow(y: 16, blur: 40, color: c.shadowLg);

/// Shadow of bottom sheets: 0 -12px 40px rgba(0,0,0,0.45) on dark (a lighter
/// ink tone on light).
BoxShadow sheetShadow(AppColors c) =>
    cssShadow(y: -12, blur: 40, color: c.shadowMd);

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
