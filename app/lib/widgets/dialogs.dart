import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'buttons.dart';
import 'pressable.dart';

/// Shows [builder] centred over the app's scrim (rgba(4,10,11,0.88)) on the
/// root navigator. The base of every pop-up (dialogs, date and month
/// pickers). Tapping the scrim closes it with null.
Future<T?> showAppPopup<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final c = context.colors;
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: c.scrim,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) => SafeArea(child: Center(child: builder(ctx))),
    transitionBuilder: (ctx, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The pop-up card: 312 px wide, radius 24, `surface2`, deep shadow.
/// Default padding 20 (the date and month pickers use 20 16 16).
class AppPopupCard extends StatelessWidget {
  const AppPopupCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.width = 312,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [popupShadow],
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: c.text),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A confirm dialog like the mockup's delete pop-ups.
///
/// Bold [title] (17/24 w800), then [boldLine] (14/20 w700) and [quietLine]
/// (13.5/20 text2), optional [extra] content (e.g. a [DialogLinkRow]), then
/// Cancel (on `tile`) and the action. [destructive] paints the action in
/// `bad` with dark text. With [tickLabel] a tick box row is shown and the
/// action stays faded rose until it is ticked (PopDeleteAll).
/// [titleWidget] replaces the title (e.g. with an emoji).
/// [boldTabular] draws the bold line with tabular figures (only the
/// PocketDelete board does; the others use proportional figures).
///
/// Returns true when the action was pressed, false otherwise.
Future<bool> showAppDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  Widget? titleWidget,
  String? boldLine,
  bool boldTabular = false,
  String? quietLine,
  Widget? extra,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  String? tickLabel,
}) async {
  final result = await showAppPopup<bool>(
    context,
    builder: (_) => AppDialog(
      title: title,
      titleWidget: titleWidget,
      boldLine: boldLine,
      boldTabular: boldTabular,
      quietLine: quietLine,
      extra: extra,
      cancelLabel: cancelLabel,
      actionLabel: actionLabel,
      destructive: destructive,
      tickLabel: tickLabel,
    ),
  );
  return result ?? false;
}

/// The dialog shown by [showAppDialog] (pops true / false).
class AppDialog extends StatefulWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.actionLabel,
    this.titleWidget,
    this.boldLine,
    this.boldTabular = false,
    this.quietLine,
    this.extra,
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.tickLabel,
  });

  final String title;
  final Widget? titleWidget;
  final String? boldLine;
  final bool boldTabular;
  final String? quietLine;
  final Widget? extra;
  final String cancelLabel;
  final String actionLabel;
  final bool destructive;
  final String? tickLabel;

  @override
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> {
  bool _ticked = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final locked = widget.tickLabel != null && !_ticked;
    final hasMiddle = widget.extra != null || widget.tickLabel != null;
    return AppPopupCard(
      semanticLabel: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.titleWidget ??
              Text(widget.title, style: AppText.screenTitle),
          if (widget.boldLine != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.boldLine!,
              style: widget.boldTabular
                  ? AppText.tabular(AppText.bodyStrong)
                  : AppText.bodyStrong,
            ),
          ],
          if (widget.quietLine != null)
            Text(
              widget.quietLine!,
              style: AppText.body.copyWith(color: c.text2),
            ),
          if (widget.extra != null) ...[
            const SizedBox(height: 16),
            widget.extra!,
          ],
          if (widget.tickLabel != null) ...[
            const SizedBox(height: 16),
            TickBoxRow(
              label: widget.tickLabel!,
              value: _ticked,
              onChanged: (v) => setState(() => _ticked = v),
            ),
          ],
          SizedBox(height: hasMiddle ? 16 : 20),
          PopupButtons(
            cancelLabel: widget.cancelLabel,
            actionLabel: widget.actionLabel,
            destructive: widget.destructive,
            onCancel: () => Navigator.of(context).pop(false),
            onAction: locked ? null : () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

/// The "Yes, erase everything" row: 48 px, radius 16, a 22 px tick box.
/// Unticked: transparent with a popStub ring. Ticked: faint rose tint, rose
/// ring, rose box with a dark check.
class TickBoxRow extends StatelessWidget {
  const TickBoxRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      checked: value,
      label: label,
      child: SizedBox(
        height: 48,
        child: Pressable(
          onTap: () => onChanged(!value),
          color: value ? mix(c.bad, c.surface2, 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: value ? c.bad : c.popStub, width: 1.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? c.bad : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: value ? null : Border.all(color: c.popStub, width: 2),
                  ),
                  child: value
                      ? Icon(Symbols.check_rounded, size: 18, color: c.onBad)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: AppText.label.copyWith(color: c.text)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Save a copy first ... Export ›" row of the delete pop-ups: 48 px,
/// radius 16, `tile`; [actionLabel] in accent with a chevron.
class DialogLinkRow extends StatelessWidget {
  const DialogLinkRow({
    super.key,
    required this.label,
    required this.actionLabel,
    required this.onTap,
  });

  final String label;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 48,
      child: Pressable(
        onTap: onTap,
        color: c.tile,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: AppText.label.copyWith(color: c.text)),
              ),
              const SizedBox(width: 12),
              Text(
                actionLabel,
                style: AppText.body.copyWith(
                  color: c.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Symbols.chevron_right_rounded, size: 20, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
}
