import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// Height of the bottom bar (without the system navigation inset).
const double kNavBarHeight = 72;

/// The app shell of the four tabs: the tab content, the bottom bar and the
/// floating plus button that overlaps the bar by 16 px and opens Add
/// expense. Tab screens do not pad for the bar: their area already ends at
/// the bar's top edge (the plus button may overlap the last 16 px).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.onAdd,
  });

  final StatefulNavigationShell navigationShell;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            bottom: kNavBarHeight + inset,
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: navigationShell,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: kNavBarHeight + inset,
            child: AppNavBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            // Top-aligned in the bar and lifted 16 px: its bottom edge sits
            // 72 - (58 - 16) = 30 px above the bar's bottom.
            bottom: inset + kNavBarHeight - 42,
            child: Center(child: AddFab(onTap: onAdd)),
          ),
        ],
      ),
    );
  }
}

/// One tab of [AppNavBar].
class NavTab {
  const NavTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The four tabs in branch order. The plus button sits between Charts and
/// Reports.
const List<NavTab> kNavTabs = [
  NavTab('Home', Symbols.home_rounded),
  NavTab('Charts', Symbols.donut_small_rounded),
  NavTab('Reports', Symbols.bar_chart_rounded),
  NavTab('Settings', Symbols.tune_rounded),
];

/// The 72 px bottom bar: `nav` fill, a 1 px `line` on top, five equal
/// columns (Home, Charts, [plus], Reports, Settings). The active tab has a
/// 48 x 28 accentSoft pill behind a filled icon and an accent w700 label;
/// the others are text2 w600 with outlined icons.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tab(int i) {
      final t = kNavTabs[i];
      final on = i == currentIndex;
      final color = on ? c.accent : c.text2;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: t.label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: SizedBox(
              height: kNavBarHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 28,
                    decoration: BoxDecoration(
                      color: on ? c.accentSoft : c.accentSoft.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(t.icon, size: 24, color: color, fill: on ? 1 : 0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.label,
                    maxLines: 1,
                    style: AppText.navLabel.copyWith(
                      color: color,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.nav,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: Row(
          children: [
            tab(0),
            tab(1),
            const Expanded(child: SizedBox(height: kNavBarHeight)),
            tab(2),
            tab(3),
          ],
        ),
      ),
    );
  }
}

/// The 58 px round plus button (accent, 30 px add icon, glow).
class AddFab extends StatelessWidget {
  const AddFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: 58,
      child: Pressable(
        onTap: onTap,
        semanticLabel: 'Add expense',
        color: c.accent,
        borderRadius: BorderRadius.circular(29),
        shadows: [
          accentGlowShadow(c.accentGlow),
          cssShadow(y: 2, blur: 6, color: const Color(0x59000000)),
        ],
        child: Center(
          child: Icon(Symbols.add_rounded, size: 30, color: c.onAccent),
        ),
      ),
    );
  }
}
