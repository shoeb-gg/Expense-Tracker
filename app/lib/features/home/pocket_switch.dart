import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/days.dart';
import '../../data/db.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'home_state.dart';
import 'pocket_button.dart';

/// What the user picked in the "Your pockets" panel.
sealed class PocketSwitchChoice {
  const PocketSwitchChoice();
}

/// Switch to the pocket [pocketId].
class SwitchToPocket extends PocketSwitchChoice {
  const SwitchToPocket(this.pocketId);

  final int pocketId;
}

/// "Add pocket".
class AddPocketChoice extends PocketSwitchChoice {
  const AddPocketChoice();
}

/// "Manage".
class ManagePocketsChoice extends PocketSwitchChoice {
  const ManagePocketsChoice();
}

/// Opens "Your pockets" just under the pocket button (PocketSwitch board).
/// [buttonRect] is the pocket button's box on screen; the button is drawn
/// again above the scrim with its arrow pointing up. Returns null when the
/// panel is closed without a choice.
Future<PocketSwitchChoice?> showPocketSwitch(
  BuildContext context, {
  required Rect buttonRect,
  required Pocket current,
}) {
  final c = context.colors;
  return showGeneralDialog<PocketSwitchChoice>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: c.scrim.withValues(alpha: 0.80),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) =>
        _PocketSwitchLayer(buttonRect: buttonRect, current: current),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class _PocketSwitchLayer extends StatelessWidget {
  const _PocketSwitchLayer({required this.buttonRect, required this.current});

  final Rect buttonRect;
  final Pocket current;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Stack(
      children: [
        Positioned.fromRect(
          rect: buttonRect,
          child: PocketButton(
            pocket: current,
            open: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: buttonRect.bottom + 8,
          bottom: 16 + bottomInset,
          child: const Align(
            alignment: Alignment.topCenter,
            child: PocketSwitchPanel(),
          ),
        ),
      ],
    );
  }
}

/// The panel itself: title, one radio row per pocket with this month's
/// total, then "Add pocket" and "Manage". Scrolls when there are many
/// pockets. Pops a [PocketSwitchChoice].
class PocketSwitchPanel extends ConsumerWidget {
  const PocketSwitchPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pockets = ref.watch(pocketsProvider).value ?? const <Pocket>[];
    final currentId = ref.watch(currentPocketIdProvider);
    final today = ref.watch(todayProvider);
    final ym = yearMonthOfDay(today);
    final totals =
        ref
            .watch(
              pocketTotalsProvider((
                from: monthStart(ym.year, ym.month),
                to: monthEnd(ym.year, ym.month),
              )),
            )
            .value ??
        const <int, int>{};
    final hidden = ref.watch(homeTotalHiddenProvider);
    final fmt = ref.watch(amountFormatProvider);

    String note(Pocket p) {
      if (hidden) return '$maskedAmount this month';
      final total = totals[p.id] ?? 0;
      return total == 0
          ? 'Nothing this month'
          : '${fmt.format(total)} this month';
    }

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Your pockets',
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [popupShadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your pockets',
                style: AppText.screenTitle.copyWith(color: c.text),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap one to switch to it.',
                style: AppText.body.copyWith(color: c.text2),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < pockets.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _PocketRadioRow(
                            pocket: pockets[i],
                            selected: pockets[i].id == currentId,
                            note: note(pockets[i]),
                            onTap: () => Navigator.of(
                              context,
                            ).pop(SwitchToPocket(pockets[i].id)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PanelButton(
                      label: 'Add pocket',
                      icon: Symbols.add_rounded,
                      onTap: () =>
                          Navigator.of(context).pop(const AddPocketChoice()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PanelButton(
                      label: 'Manage',
                      onTap: () => Navigator.of(
                        context,
                      ).pop(const ManagePocketsChoice()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PocketRadioRow extends StatelessWidget {
  const _PocketRadioRow({
    required this.pocket,
    required this.selected,
    required this.note,
    required this.onTap,
  });

  final Pocket pocket;
  final bool selected;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 64,
      child: Pressable(
        onTap: onTap,
        selected: selected,
        color: selected ? c.accentSoft : c.tile,
        borderRadius: BorderRadius.circular(16),
        border: selected ? Border.all(color: c.accent, width: 2) : null,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 16),
          child: Row(
            children: [
              EmojiTile(emoji: pocket.emoji, background: c.surface),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pocket.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.rowTitle.copyWith(
                              color: c.text,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          InUseBadge(background: c.surface),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.tabular(
                        AppText.sub,
                      ).copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RadioMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(Symbols.check_rounded, size: 18, color: c.onAccent),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.popStub, width: 2),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: c.accent),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.buttonQuiet.copyWith(color: c.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small "In use" label next to the pocket in use (11/18 w800 accent).
class InUseBadge extends StatelessWidget {
  const InUseBadge({super.key, required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        'In use',
        style: AppText.caption.copyWith(
          fontSize: 11,
          height: 18 / 11,
          fontWeight: FontWeight.w800,
          color: c.accent,
        ),
      ),
    );
  }
}
