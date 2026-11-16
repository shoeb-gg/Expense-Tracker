import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'cards.dart' show CenteredNote;

/// A bar docked at the bottom of a sub-screen (Export, Import, Details):
/// `nav` background, 1 px `line` on top, padding 12 16 14 plus the system
/// navigation inset, an optional centred [hint] under the [child] (gap 8).
///
/// Two buttons side by side: pass a `Row` with two `Expanded`
/// `PrimaryButton`s 12 px apart and `padding: DockedBar.twoButtonPadding`.
class DockedBar extends StatelessWidget {
  const DockedBar({
    super.key,
    required this.child,
    this.hint,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 14),
  });

  /// Padding of the Details Edit/Delete bar.
  static const EdgeInsets twoButtonPadding = EdgeInsets.fromLTRB(16, 12, 16, 16);

  final Widget child;
  final String? hint;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.nav,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Padding(
        padding: padding.copyWith(bottom: padding.bottom + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            child,
            if (hint != null) ...[
              const SizedBox(height: 8),
              CenteredNote(hint!, style: AppText.sub.copyWith(color: c.text3)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A floating bottom action over a fade (Categories "Add category",
/// Pockets "Add pocket"): put it in a `Stack` as
/// `Positioned(left: 0, right: 0, bottom: 0, child: FadeDock(...))` and give
/// the list [listRoom] of bottom padding. Use a `PrimaryButton(glow: true)`
/// inside.
class FadeDock extends StatelessWidget {
  const FadeDock({super.key, required this.child});

  /// Bottom padding for the list under the dock, so its end scrolls clear of
  /// the fade and the button: 96 px plus the phone's bottom bar (a gesture
  /// bar or the three-button bar lifts the dock by its height).
  static double listRoom(BuildContext context) => 96 + MediaQuery.viewPaddingOf(context).bottom;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [c.bg, c.bg, c.bg.withValues(alpha: 0)],
          stops: const [0, 0.62, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + inset),
        child: child,
      ),
    );
  }
}
