import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../data/maintenance.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import '../home/home_state.dart' show homeMonthProvider;

/// "First day of the week" sheet (Monday, Saturday, Sunday).
Future<void> pickFirstDayOfWeek(BuildContext context, WidgetRef ref) async {
  final current = ref.read(settingsProvider).firstDayOfWeek;
  final picked = await showOptionSheet<FirstDayOfWeek>(
    context,
    title: 'First day of the week',
    message: 'Used by the calendar and the weekly chart.',
    options: [
      for (final d in FirstDayOfWeek.values)
        SheetOption(value: d, label: d.label),
    ],
    current: current,
  );
  if (picked != null) {
    await ref.read(settingsProvider.notifier).setFirstDayOfWeek(picked);
  }
}

/// The styles the Number format sheet lists: all five with the thousands
/// separator on, only the two decimal styles with it off.
List<NumberStyle> numberStyleChoices({required bool separator}) => separator
    ? NumberStyle.values
    : const [NumberStyle.comma, NumberStyle.dotComma];

/// The ticked row: with the separator off, the style with the same decimal
/// mark as the saved one.
NumberStyle numberStyleShown(NumberStyle saved, {required bool separator}) {
  if (separator) return saved;
  return saved.decimal == ',' ? NumberStyle.dotComma : NumberStyle.comma;
}

/// "Number format" sheet.
Future<void> pickNumberFormat(BuildContext context, WidgetRef ref) async {
  final s = ref.read(settingsProvider);
  final sep = s.thousandsSeparator;
  final picked = await showOptionSheet<NumberStyle>(
    context,
    title: 'Number format',
    message: 'How amounts are written across the app.',
    options: [
      for (final style in numberStyleChoices(separator: sep))
        SheetOption(
          value: style,
          label: style.sample(separator: sep),
          note: sep && style.note.isNotEmpty ? style.note : null,
          tabular: true,
        ),
    ],
    current: numberStyleShown(s.numberStyle, separator: sep),
  );
  if (picked != null) {
    await ref.read(settingsProvider.notifier).setNumberStyle(picked);
  }
}

/// "Calculator keys" sheet, each option showing which of + − × ÷ it has.
Future<void> pickCalcKeys(BuildContext context, WidgetRef ref) async {
  final picked = await showOptionSheet<CalcKeys>(
    context,
    title: 'Calculator keys',
    message: 'Math keys on the Add expense keypad.',
    options: [
      for (final k in CalcKeys.values)
        SheetOption(
          value: k,
          label: k.label,
          trailing: _CalcChips(allFour: k == CalcKeys.allFour),
        ),
    ],
    current: ref.read(settingsProvider).calcKeys,
  );
  if (picked != null) {
    await ref.read(settingsProvider.notifier).setCalcKeys(picked);
  }
}

class _CalcChips extends StatelessWidget {
  const _CalcChips({required this.allFour});

  final bool allFour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const glyphs = ['+', '−', '×', '÷'];
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < glyphs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Opacity(
              opacity: i < 2 || allFour ? 1 : 0.3,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  glyphs[i],
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 17,
                    height: 28 / 17,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Delete all data?" with its tick box. Erases every pocket, then the app
/// starts again with one empty pocket and the starting categories, and goes
/// Home on this month (the PopDeleteAll board's "Delete all" leads Home).
Future<void> confirmDeleteAll(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final ok = await showAppDialog(
    context,
    title: 'Delete all data?',
    boldLine: 'All pockets, expenses, categories and photos',
    quietLine:
        'The app starts fresh with Personal and the default categories. '
        "This can't be undone.",
    extra: Builder(
      builder: (dialog) => DialogLinkRow(
        label: 'Save a copy first',
        actionLabel: 'Export',
        onTap: () {
          Navigator.of(dialog).pop(false);
          router.push(Routes.export);
        },
      ),
    ),
    tickLabel: 'Yes, erase everything',
    actionLabel: 'Delete all',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  // Wipe first, then go Home. Reading the pocket in use here brings it (and
  // what follows it) up to date before Home builds: left for Home's first
  // build to recompute, it would notify other providers during that build
  // ("setState() called during build"). The toast lives in the root
  // overlay, so it stays when the screen changes.
  await ref.read(dataActionsProvider).deleteAllData();
  if (!context.mounted) return;
  ref.read(currentPocketIdProvider);
  ref.read(homeMonthProvider.notifier).followToday();
  showToast(context, 'Everything was erased');
  router.go(Routes.home);
}

/// Clear cache: no pop-up; says how much space was freed.
Future<void> clearCacheNow(BuildContext context, WidgetRef ref) async {
  final freed = await ref.read(dataActionsProvider).clearCache();
  if (!context.mounted) return;
  showToast(
    context,
    freed > 0 ? '${formatBytes(freed)} freed' : 'Nothing to clear',
  );
}

/// "Spent in October".
String spentInLabel(int today) => 'Spent in ${monthName(monthOfDay(today))}';
