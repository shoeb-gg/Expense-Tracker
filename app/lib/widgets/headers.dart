import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// The 64 px title row of the four tab screens: a 21/28 w800 title (or any
/// [leading] widget, e.g. the pocket button) and round buttons on the right.
///
/// [subtitle] puts a small line under the title (the pocket of Charts and
/// Reports). The header stays 64 px: the title moves up so the line ends 8 px
/// above the bottom, and never closer than 7 px to the top. At the largest
/// text sizes the line scales down to the room that is left.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.title,
    this.leading,
    this.subtitle,
    this.endRoom = 0,
    this.actions = const [],
  }) : assert(title != null || leading != null),
       assert(subtitle == null || title != null);

  final String? title;

  /// Replaces the title (Home's pocket button).
  final Widget? leading;

  /// A second line under [title], in the style of [SubHeader]'s subtitle.
  /// A line too wide for the room it has scales down to one line.
  final String? subtitle;

  /// Room kept free at the right end of the [subtitle] for something drawn
  /// over the header (the back-to-now pill), so the two never touch.
  final double endRoom;

  /// Right side, 8 px apart (usually [RoundIconButton]s).
  final List<Widget> actions;

  /// The header's height.
  static const double height = 64;

  /// The room kept under the subtitle's line, so it does not crowd what is
  /// below the header.
  static const double _bottomGap = 8;

  /// The least room above the title when there is a subtitle: what the title
  /// had at the largest text size. Past it the subtitle scales down instead.
  static const double _minTop = 7;

  /// The height of one line of [style] at the current text size, as the
  /// text itself is laid out (the engine rounds it to whole pixels).
  static double _line(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final line = painter.height;
    painter.dispose();
    return line;
  }

  Widget _titleBlock(BuildContext context) {
    final c = context.colors;
    final titleLine = _line(context, AppText.pageTitle);
    final subtitleLine = _line(context, AppText.overline);
    // The title is where it is without a subtitle (centred) or higher, as far
    // as the subtitle needs to end [_bottomGap] above the bottom, but not
    // closer than [_minTop] to the top.
    final top = math.max(
      _minTop,
      math.min(
        (height - titleLine) / 2,
        height - _bottomGap - titleLine - subtitleLine,
      ),
    );
    // What is left for the subtitle between the title and the bottom gap.
    final room = height - _bottomGap - top - titleLine;
    final style = AppText.overline.copyWith(color: c.text3);
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.pageTitle,
            ),
            Padding(
              padding: EdgeInsets.only(right: endRoom),
              child: subtitleLine <= room + 0.001
                  ? FitTitle(
                      subtitle!,
                      style: style,
                      textAlign: TextAlign.start,
                    )
                  // Taller than the room left (large text): scaled down to
                  // that room, and to the width as well.
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: math.max(0, room)),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          softWrap: false,
                          style: style,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: subtitle != null
                  ? _titleBlock(context)
                  : Align(
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
///   columns become 48 px, or [sideWidth].
class SubHeader extends StatelessWidget {
  const SubHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.sideWidth,
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

  /// Width of the two side columns: 88 px, or 48 px with a [subtitle]. A
  /// screen that draws something over one side of the header (the back-to-now
  /// pill) sets it so the centred text stays clear of that.
  final double? sideWidth;

  /// Replaces the back button.
  final Widget? leading;
  final Widget? trailing;
  final bool showBack;

  /// Back action; defaults to popping the route.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final side = sideWidth ?? (subtitle == null ? 88.0 : 48.0);
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
                  FitTitle(title, style: titleStyle),
                  // Like the title: a subtitle too wide for the column (a long
                  // pocket name at large text) scales down to one line instead
                  // of wrapping out of the 60 px header.
                  if (subtitle != null)
                    FitTitle(
                      subtitle!,
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

/// A one-line, centred title that scales down to fit its width instead of
/// ending in "..." (large text). While it fits it is a plain [Text], so
/// nothing about it changes at the default size.
///
/// [minScale] is the smallest scale it may shrink to (0: any). A title that
/// would need less is drawn at [minScale] and ends in "...". [textAlign] is
/// how the plain text is aligned in its box.
///
/// Used for figures too (a total, an amount in a column, a chip's note). With
/// [resizeFont] the scaled text is a smaller font rather than a shrunk
/// picture of the text (also at [minScale], where it ends in "..."), so its
/// baseline is where the layout put it: use it when the text sits on a
/// baseline shared with other text.
class FitTitle extends StatelessWidget {
  const FitTitle(
    this.text, {
    super.key,
    required this.style,
    this.minScale = 0,
    this.textAlign = TextAlign.center,
    this.resizeFont = false,
  });

  final String text;
  final TextStyle style;
  final double minScale;
  final TextAlign textAlign;

  /// Scale by shrinking the font (the text size setting is a plain factor,
  /// see `app.dart`), not by drawing the text smaller.
  final bool resizeFont;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final natural = titleWidth(context, text, style);
        if (!box.maxWidth.isFinite || natural <= box.maxWidth) {
          return Text(
            text,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }
        if (box.maxWidth / natural < minScale) {
          // Too long even at [minScale]: that scale, and the end cut.
          if (resizeFont) {
            return Text(
              text,
              textAlign: textAlign,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.linear(
                MediaQuery.textScalerOf(context).scale(1) * minScale,
              ),
              style: style,
            );
          }
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth / minScale,
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
            ),
          );
        }
        if (resizeFont) {
          // Half a pixel short of the room, so rounding never ends it in "...".
          final scale = MediaQuery.textScalerOf(context).scale(1) *
              (box.maxWidth - 0.5) /
              natural;
          return Text(
            text,
            textAlign: textAlign,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textScaler: TextScaler.linear(scale),
            style: style,
          );
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, maxLines: 1, softWrap: false, style: style),
        );
      },
    );
  }
}

/// The height of one line of [style] at the current text size: what a
/// [FitTitle] in a slot of that height keeps when its text is drawn smaller.
double titleHeight(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'Ag', style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// The width [text] takes on one line in [style] at the current text size.
double titleWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
