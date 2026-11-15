import 'package:flutter/material.dart';

import '../theme/symbols.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// 40 px round button on `surface` with a 22 px icon (back, eye, calendar).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.size = 40,
    this.iconSize = 22,
    this.background,
    this.color,
    this.fill = 0,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double size;
  final double iconSize;

  /// Defaults to `surface`.
  final Color? background;

  /// Icon colour; defaults to `text`.
  final Color? color;

  /// Icon fill, 0 or 1.
  final double fill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: size,
      child: Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        color: background ?? c.surface,
        borderRadius: BorderRadius.circular(size / 2),
        child: Center(
          child: Icon(icon, size: iconSize, color: color ?? c.text, fill: fill),
        ),
      ),
    );
  }
}

/// The round back button of sub-screens (arrow_back). Pops by default.
class BackRoundButton extends StatelessWidget {
  const BackRoundButton({super.key, this.onTap, this.semanticLabel = 'Back'});

  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return RoundIconButton(
      icon: Symbols.arrow_back_rounded,
      semanticLabel: semanticLabel,
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
    );
  }
}

enum PillTone {
  /// `surface` fill, `text`, weight 700 (Cancel).
  neutral,

  /// `accent` fill, `onAccent`, weight 800 (Save). Disabled: surface2/text3.
  accent,

  /// `accentSoft` fill, `text` (pocket pill on Add expense).
  soft,
}

/// 36 px pill button (radius 18, 14/20 text). [width] null = auto width with
/// 14 px side padding; the form header uses width 80.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = PillTone.neutral,
    this.width,
    this.leading,
    this.trailing,
    this.height = 36,
    this.semanticLabel,
  });

  final String label;

  /// Null disables the pill (an accent pill turns surface2/text3).
  final VoidCallback? onTap;
  final PillTone tone;
  final double? width;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    final (Color bg, Color fg, FontWeight fw) = switch (tone) {
      PillTone.neutral => (c.surface, enabled ? c.text : c.text3, FontWeight.w700),
      PillTone.accent => enabled
          ? (c.accent, c.onAccent, FontWeight.w800)
          : (c.surface2, c.text3, FontWeight.w800),
      PillTone.soft => (c.accentSoft, c.text, FontWeight.w700),
    };
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.pill.copyWith(color: fg, fontWeight: fw),
    );
    return SizedBox(
      width: width,
      height: height,
      child: Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        color: bg,
        borderRadius: BorderRadius.circular(height / 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width == null ? 14 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Flexible(child: text),
              if (trailing != null) ...[const SizedBox(width: 2), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

enum ButtonTone {
  /// `accent` fill, `onAccent` text. Disabled: surface2/text3.
  accent,

  /// `surface2` fill, `text`.
  quiet,

  /// `surface2` fill, `bad` text (Delete on Details).
  danger,

  /// `bad` fill, `onBad` text (confirmed destructive action).
  destructive,
}

/// The big 52 px button (radius 18, 15/20 w800), e.g. "Export 214 expenses",
/// "Add category", Edit/Delete on Details. [glow] adds the accent glow used
/// by floating buttons.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = ButtonTone.accent,
    this.glow = false,
    this.height = 52,
    this.radius = 18,
    this.fontSize = 15,
    this.iconSize = 20,
    this.semanticLabel,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonTone tone;
  final bool glow;
  final double height;
  final double radius;
  final double fontSize;
  final double iconSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final (Color bg, Color fg) = switch (tone) {
      ButtonTone.accent =>
        enabled ? (c.accent, c.onAccent) : (c.surface2, c.text3),
      ButtonTone.quiet => (c.surface2, enabled ? c.text : c.text3),
      ButtonTone.danger => (c.surface2, enabled ? c.bad : c.text3),
      ButtonTone.destructive => enabled
          ? (c.bad, c.onBad)
          : (mix(c.bad, c.surface2, 0.14), mix(c.bad, c.surface2, 0.5)),
    };
    return SizedBox(
      height: height,
      child: Pressable(
        onTap: onPressed,
        semanticLabel: semanticLabel,
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        shadows: glow && enabled && tone == ButtonTone.accent
            ? [accentGlowShadow(c.accentGlow)]
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: iconSize, color: fg),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.tabular(
                  AppText.button.copyWith(fontSize: fontSize, color: fg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 48 px Cancel + action pair at the bottom of pop-ups (two equal
/// columns, gap 12, radius 16, as on every board). Cancel sits on `tile`.
///
/// Long labels and large text sizes never clip: a label keeps at least
/// [minSidePadding] on each side. When one does not fit its half, the
/// buttons share the row by need (the room left over split evenly); when
/// the two cannot share a row, they stack, full width, the action on top.
class PopupButtons extends StatelessWidget {
  const PopupButtons({
    super.key,
    required this.onCancel,
    required this.onAction,
    this.cancelLabel = 'Cancel',
    this.actionLabel = 'Confirm',
    this.destructive = false,
  });

  final VoidCallback onCancel;

  /// Null shows the action locked (faded; rose when [destructive]).
  final VoidCallback? onAction;
  final String cancelLabel;
  final String actionLabel;

  /// Action in `bad` with dark text (Delete).
  final bool destructive;

  /// Least room between a label and its button's sides.
  static const double minSidePadding = 12;
  static const double _gap = 12;
  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onAction != null;
    final (Color bg, Color fg) = destructive
        ? (enabled
            ? (c.bad, c.onBad)
            : (mix(c.bad, c.surface2, 0.14), mix(c.bad, c.surface2, 0.5)))
        : (enabled ? (c.accent, c.onAccent) : (c.tile, c.text3));
    final cancelStyle = AppText.buttonQuiet.copyWith(color: c.text);
    final actionStyle = AppText.button.copyWith(color: fg);
    final scaler = MediaQuery.textScalerOf(context);

    Widget button(String label, TextStyle style, Color color, VoidCallback? onTap) =>
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _height),
          child: Pressable(
            onTap: onTap,
            color: color,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              // Only a label too long even for the full width wraps; then
              // the button grows instead of clipping it.
              padding: const EdgeInsets.symmetric(
                horizontal: minSidePadding,
                vertical: 8,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(label, textAlign: TextAlign.center, style: style),
              ),
            ),
          ),
        );

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final half = (width - _gap) / 2;
        final needCancel =
            _labelWidth(cancelLabel, cancelStyle, scaler) + 2 * minSidePadding;
        final needAction =
            _labelWidth(actionLabel, actionStyle, scaler) + 2 * minSidePadding;
        final cancel = button(cancelLabel, cancelStyle, c.tile, onCancel);
        final action = button(actionLabel, actionStyle, bg, onAction);
        if (needCancel + _gap + needAction > width) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [action, const SizedBox(height: _gap), cancel],
          );
        }
        final double cancelWidth;
        final double actionWidth;
        if (needCancel <= half && needAction <= half) {
          cancelWidth = half;
          actionWidth = half;
        } else {
          final spare = (width - _gap - needCancel - needAction) / 2;
          cancelWidth = needCancel + spare;
          actionWidth = needAction + spare;
        }
        return Row(
          children: [
            SizedBox(width: cancelWidth, height: _height, child: cancel),
            const SizedBox(width: _gap),
            SizedBox(width: actionWidth, height: _height, child: action),
          ],
        );
      },
    );
  }

  static double _labelWidth(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w.ceilToDouble();
  }
}

/// A value on the right of a settings row: 14/20 w500 text3 and a chevron
/// ("Sunday ›").
class RowValue extends StatelessWidget {
  const RowValue(this.text, {super.key, this.chevron = true, this.tabular = false});

  final String text;
  final bool chevron;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppText.value.copyWith(color: c.text3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: tabular ? AppText.tabular(style) : style),
        if (chevron) ...[
          const SizedBox(width: 2),
          const RowChevron(),
        ],
      ],
    );
  }
}

/// The 20 px chevron at the end of a row (text3, pulled 6 px right).
class RowChevron extends StatelessWidget {
  const RowChevron({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(6, 0),
      child: Icon(
        Symbols.chevron_right_rounded,
        size: 20,
        color: color ?? context.colors.text3,
      ),
    );
  }
}
