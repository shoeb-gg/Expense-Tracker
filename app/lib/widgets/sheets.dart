import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// Shows a bottom sheet over the app's scrim. Build it with [AppSheet].
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final c = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: c.scrim,
    elevation: 0,
    showDragHandle: false,
    builder: builder,
  );
}

/// The sheet body: top radius 28, `surface2`, padding 10 16 24, a 40 x 4
/// grabber, a 17/24 w800 [title], an optional 13.5/20 text2 [message], an
/// optional [headerTrailing] (e.g. a receipt thumbnail) and the [children]
/// 16 px below (rows 8 px apart).
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    this.message,
    this.headerTrailing,
    required this.children,
    this.gap = 8,
  });

  final String title;
  final String? message;
  final Widget? headerTrailing;
  final List<Widget> children;

  /// Space between [children].
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: AppText.screenTitle),
        if (message != null) ...[
          const SizedBox(height: 2),
          Text(message!, style: AppText.body.copyWith(color: c.text2)),
        ],
      ],
    );
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [sheetShadow],
        ),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 24 + inset),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: c.text),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.popGrab,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: headerTrailing == null
                    ? header
                    : Row(
                        children: [
                          Expanded(child: header),
                          const SizedBox(width: 12),
                          headerTrailing!,
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice of [showOptionSheet].
class SheetOption<T> {
  const SheetOption({
    required this.value,
    required this.label,
    this.note,
    this.trailing,
    this.tabular = false,
    this.semanticLabel,
  });

  final T value;
  final String label;

  /// Grey text before the tick ("Lakh, crore").
  final String? note;

  /// Any widget before the tick (the + − × ÷ strip of Calculator keys).
  final Widget? trailing;

  /// Tabular figures for the label (number samples).
  final bool tabular;
  final String? semanticLabel;
}

/// A choice sheet (First day of the week, Number format, Calculator keys):
/// option rows of 56 px; the [current] one is tinted, ringed in accent and
/// ticked. A tap chooses and closes; returns the chosen value (null when
/// dismissed).
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<SheetOption<T>> options,
  required T? current,
}) {
  return showAppSheet<T>(
    context,
    builder: (ctx) => AppSheet(
      title: title,
      message: message,
      children: [
        for (final o in options)
          OptionRow(
            label: o.label,
            selected: o.value == current,
            note: o.note,
            trailing: o.trailing,
            tabular: o.tabular,
            semanticLabel: o.semanticLabel,
            onTap: () => Navigator.of(ctx).pop(o.value),
          ),
      ],
    ),
  );
}

/// A 56 px choice row (radius 16). Selected: `accentSoft` tint, 2 px accent
/// ring, w800 label, accent circle with a check. Else: `tile`, w600, an
/// empty circle with a popStub ring.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.note,
    this.trailing,
    this.tabular = false,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? note;
  final Widget? trailing;
  final bool tabular;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var style = AppText.rowTitle.copyWith(
      color: c.text,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
    );
    if (tabular) style = AppText.tabular(style);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: semanticLabel,
      child: SizedBox(
        height: 56,
        child: Pressable(
          onTap: onTap,
          selected: selected,
          color: selected ? c.accentSoft : c.tile,
          borderRadius: BorderRadius.circular(16),
          border: selected ? Border.all(color: c.accent, width: 2) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, maxLines: 1, softWrap: false, style: style),
                ),
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(note!, style: AppText.sub.copyWith(color: c.text3)),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border:
                        selected ? null : Border.all(color: c.popStub, width: 2),
                  ),
                  child: selected
                      ? Icon(Symbols.check_rounded, size: 18, color: c.onAccent)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An action row of a sheet (Receipt photo: View photo, Take a new photo,
/// Choose from gallery, Remove photo): 56 px, radius 16, `tile`, a 22 px
/// icon (accent) and a 15/20 w600 label. [destructive] colours label and
/// icon `bad` (w700); add 8 px extra space above it.
class SheetActionRow extends StatelessWidget {
  const SheetActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 56,
      child: Pressable(
        onTap: onTap,
        color: c.tile,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: destructive ? c.bad : c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppText.rowTitle.copyWith(
                    color: destructive ? c.bad : c.text,
                    fontWeight: destructive ? FontWeight.w700 : FontWeight.w600,
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
