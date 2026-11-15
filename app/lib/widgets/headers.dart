import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// The 64 px title row of the four tab screens: a 21/28 w800 title (or any
/// [leading] widget, e.g. the pocket button) and round buttons on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
  }) : assert(title != null || leading != null);

  final String? title;

  /// Replaces the title (Home's pocket button).
  final Widget? leading;

  /// Right side, 8 px apart (usually [RoundIconButton]s).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: leading ??
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.pageTitle,
                    ),
              ),
            ),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// The 60 px header of sub-screens: three columns (88 | title | 88).
/// Left: a 40 px round back button by default. Centre: 17/24 w800 title.
///
/// * `SubHeader(title: 'Categories')` - back button, title.
/// * `SubHeader.form(...)` - Cancel and Save pills (80 x 36), used by the
///   category and pocket forms.
/// * `SubHeader.cancel(...)` - an auto-width Cancel pill (Add/Edit expense)
///   and an optional right widget (the pocket pill).
/// * [subtitle] - a second line under the title ("Step 1 of 3"); the side
///   columns become 48 px.
class SubHeader extends StatelessWidget {
  const SubHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.showBack = true,
    this.onBack,
  });

  /// Cancel and Save pills. [onSave] null shows Save disabled.
  factory SubHeader.form({
    Key? key,
    required String title,
    required VoidCallback onCancel,
    required VoidCallback? onSave,
    String cancelLabel = 'Cancel',
    String saveLabel = 'Save',
  }) =>
      SubHeader(
        key: key,
        title: title,
        leading: Pill(label: cancelLabel, onTap: onCancel, width: 80),
        trailing: Pill(
          label: saveLabel,
          onTap: onSave,
          width: 80,
          tone: PillTone.accent,
        ),
      );

  /// An auto-width Cancel pill on the left (Add / Edit expense).
  factory SubHeader.cancel({
    Key? key,
    required String title,
    required VoidCallback onCancel,
    Widget? trailing,
    String cancelLabel = 'Cancel',
  }) =>
      SubHeader(
        key: key,
        title: title,
        leading: Pill(label: cancelLabel, onTap: onCancel),
        trailing: trailing,
      );

  final String title;
  final String? subtitle;

  /// Replaces the back button.
  final Widget? leading;
  final Widget? trailing;
  final bool showBack;

  /// Back action; defaults to popping the route.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final side = subtitle == null ? 88.0 : 48.0;
    final left = leading ?? (showBack ? BackRoundButton(onTap: onBack) : null);
    final titleStyle = subtitle == null
        ? AppText.screenTitle
        : AppText.screenTitle.copyWith(height: 22 / 17);
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: side,
              child: Align(
                alignment: Alignment.centerLeft,
                child: left ?? const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // A title too wide for its column (large text) scales
                  // down instead of ending in "...".
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: titleStyle,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: AppText.overline.copyWith(color: c.text3),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: side,
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing ?? const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
