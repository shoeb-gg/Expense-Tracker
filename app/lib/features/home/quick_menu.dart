import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';

/// The choices of the menu shown when an expense is held on Home.
enum QuickAction { edit, delete, details }

/// Holding an expense on Home (NewQuickMenu board): the row lifts above a
/// light scrim and a 200 px menu with Edit, Delete and Details opens under
/// it, right-aligned with the row (above it when there is no room below).
/// [rowRect] is the row's box on screen and [row] draws its lifted copy.
Future<QuickAction?> showQuickMenu(
  BuildContext context, {
  required Rect rowRect,
  required Widget row,
}) {
  final c = context.colors;
  return showGeneralDialog<QuickAction>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: c.scrim.withValues(alpha: 0.68),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, _) => _QuickMenuLayer(rowRect: rowRect, row: row),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

const double _menuWidth = 200;
const double _menuHeight = 6 + 48 * 3 + 6;

class _QuickMenuLayer extends StatelessWidget {
  const _QuickMenuLayer({required this.rowRect, required this.row});

  final Rect rowRect;
  final Widget row;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = MediaQuery.of(context);
    final screen = media.size;
    final bottomLimit = screen.height - media.viewPadding.bottom - 16;
    final below = rowRect.bottom + 8;
    final top = below + _menuHeight <= bottomLimit
        ? below
        : rowRect.top - 8 - _menuHeight;
    return Stack(
      children: [
        Positioned.fromRect(
          rect: rowRect,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  cssShadow(y: 10, blur: 28, color: const Color(0x73000000)),
                ],
              ),
              child: ExcludeSemantics(child: row),
            ),
          ),
        ),
        Positioned(
          top: top,
          left: rowRect.right - _menuWidth,
          width: _menuWidth,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: 'Expense actions',
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [popupShadow],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MenuItem(
                      icon: Symbols.edit_rounded,
                      label: 'Edit',
                      onTap: () => Navigator.of(context).pop(QuickAction.edit),
                    ),
                    _MenuItem(
                      icon: Symbols.delete_rounded,
                      label: 'Delete',
                      destructive: true,
                      onTap: () =>
                          Navigator.of(context).pop(QuickAction.delete),
                    ),
                    _MenuItem(
                      icon: Symbols.info_rounded,
                      label: 'Details',
                      onTap: () =>
                          Navigator.of(context).pop(QuickAction.details),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
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
      height: 48,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: destructive ? c.bad : c.text3),
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
