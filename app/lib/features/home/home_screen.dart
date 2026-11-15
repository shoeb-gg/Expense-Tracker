import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../data/db.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import '../expense/delete_expense.dart';
import 'hero_card.dart';
import 'home_list.dart';
import 'home_state.dart';
import 'pocket_button.dart';
import 'pocket_switch.dart';
import 'quick_menu.dart';

/// Home (tab, `/`), the PocketHome board: the pocket button, the eye and
/// calendar buttons, the month card with the total, and the pocket's
/// expenses of the month grouped by day.
///
/// A finger moving left to right shows the previous month, right to left the
/// next one; the month chip opens the month pop-up.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey _pocketButtonKey = GlobalKey();
  YearMonth? _lastMonth;
  bool _forward = true;

  void _step(int delta) {
    final shown = ref.read(homeShownMonthProvider);
    ref.read(homeMonthProvider.notifier).show(stepMonth(shown, delta));
  }

  void _onSwipe(SwipeEvent e) {
    if (e.axis != Axis.horizontal) return;
    _step(e.next ? 1 : -1);
  }

  Future<void> _pickMonth(YearMonth shown) async {
    final picked = await showMonthPicker(
      context,
      year: shown.year,
      month: shown.month,
    );
    if (picked == null || !mounted) return;
    ref.read(homeMonthProvider.notifier).show((
      year: picked.$1,
      month: picked.$2,
    ));
  }

  Rect? _boxOf(BuildContext? ctx) {
    final object = ctx?.findRenderObject();
    if (object is! RenderBox || !object.attached) return null;
    return object.localToGlobal(Offset.zero) & object.size;
  }

  Future<void> _openPocketSwitch(Pocket current) async {
    final rect = _boxOf(_pocketButtonKey.currentContext);
    if (rect == null) return;
    final choice = await showPocketSwitch(
      context,
      buttonRect: rect,
      current: current,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case SwitchToPocket(:final pocketId):
        await ref.read(dataActionsProvider).switchPocket(pocketId);
      case AddPocketChoice():
        unawaited(context.push(Routes.newPocket));
      case ManagePocketsChoice():
        unawaited(context.push(Routes.pockets));
    }
  }

  Future<void> _onRow(
    Expense expense,
    BuildContext rowContext, {
    required bool held,
  }) async {
    if (!held) {
      if (SwipeArea.swipedRecently(rowContext)) return;
      unawaited(context.push(Routes.expense(expense.id)));
      return;
    }
    final rect = _boxOf(rowContext);
    if (rect == null) return;
    final category = ref.read(categoriesByIdProvider)[expense.categoryId];
    final fmt = ref.read(amountFormatProvider);
    final action = await showQuickMenu(
      context,
      rowRect: rect,
      row: HomeExpenseRow(
        expense: expense,
        category: category,
        format: fmt,
        divider: false,
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case QuickAction.edit:
        unawaited(context.push(Routes.editExpense(expense.id)));
      case QuickAction.details:
        unawaited(context.push(Routes.expense(expense.id)));
      case QuickAction.delete:
        await deleteExpenseWithUndo(context, ref, expense);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pocket = ref.watch(currentPocketProvider);
    final month = ref.watch(homeShownMonthProvider);
    final showTotal = ref.watch(
      settingsProvider.select((s) => s.showMonthlyTotal),
    );
    final showCalendar = ref.watch(
      settingsProvider.select((s) => s.showCalendarButton),
    );
    final hidden = ref.watch(homeTotalHiddenProvider);
    final fmt = ref.watch(amountFormatProvider);
    final today = ref.watch(todayProvider);
    final thisMonth = yearMonthOfDay(today);

    final last = _lastMonth;
    if (last != null && last != month) {
      _forward = monthIndex(month) > monthIndex(last);
    }
    _lastMonth = month;

    final from = monthStart(month.year, month.month);
    final to = monthEnd(month.year, month.month);
    final expenses = pocket == null
        ? null
        : ref
              .watch(
                expensesInRangeProvider((
                  pocketId: pocket.id,
                  from: from,
                  to: to,
                )),
              )
              .value;

    final monthWord = monthName(month.month);
    final String caption;
    final String value;
    String? unit;
    if (showTotal) {
      caption = 'Spent in $monthWord';
      value = expenses == null
          ? ''
          : hidden
          ? maskedAmount
          : fmt.format(totalOf(expenses));
    } else {
      // A count, so it must not read as money: "In October / 33 expenses"
      // with the word in a smaller type.
      caption = 'In $monthWord';
      value = expenses == null ? '' : fmt.count(expenses.length);
      unit = expenses?.length == 1 ? 'expense' : 'expenses';
    }
    final spoken = unit == null ? value : '$value $unit';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              leading: pocket == null
                  ? const SizedBox(height: 40)
                  : Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: PocketButton(
                        key: _pocketButtonKey,
                        pocket: pocket,
                        onTap: () => _openPocketSwitch(pocket),
                      ),
                    ),
              actions: [
                if (showTotal)
                  RoundIconButton(
                    icon: hidden
                        ? Symbols.visibility_off_rounded
                        : Symbols.visibility_rounded,
                    semanticLabel: hidden ? 'Show total' : 'Hide total',
                    onTap: () =>
                        ref.read(homeTotalHiddenProvider.notifier).toggle(),
                  ),
                if (showCalendar)
                  RoundIconButton(
                    icon: Symbols.calendar_month_rounded,
                    semanticLabel: 'Calendar',
                    onTap: () => context.push(
                      Routes.calendar(
                        day:
                            monthIndex(month) ==
                                monthIndex(yearMonthOfDay(today))
                            ? null
                            : from,
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SwipeArea(
                    onSwipe: _onSwipe,
                    child: Builder(
                      builder: (inner) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: HeroCard(
                              month: month,
                              caption: caption,
                              value: value,
                              unit: unit,
                              valueSemanticLabel: showTotal && hidden
                                  ? '$caption: hidden. See all-time spending'
                                  : '$caption: $spoken. See all-time spending',
                              onMonthTap: () {
                                if (SwipeArea.swipedRecently(inner)) return;
                                unawaited(_pickMonth(month));
                              },
                              onValueTap: () {
                                if (SwipeArea.swipedRecently(inner)) return;
                                context.go(Routes.reports);
                              },
                            ),
                          ),
                          Expanded(
                            child: pocket == null
                                ? const SizedBox.shrink()
                                : SlideSwitcher(
                                    pageKey: month,
                                    forward: _forward,
                                    child: HomeMonthList(
                                      key: ValueKey<int>(pocket.id),
                                      pocket: pocket,
                                      month: month,
                                      expenses: expenses,
                                      onRow: _onRow,
                                      onSeePrevious: () => _step(-1),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Hangs over the lower edge of the month card, at its right:
                  // the one free spot (the header holds the pocket button and
                  // two round buttons, the card is full). The ring in the
                  // page colour sets it apart from the card's own turquoise.
                  Positioned(
                    top: heroCardHeight - 16 - NowPill.ringWidth,
                    right: 16 - NowPill.ringWidth,
                    child: NowPill(
                      visible: month != thisMonth,
                      label: 'This month',
                      semanticLabel: 'Back to this month',
                      ringColor: c.bg,
                      onTap: () =>
                          ref.read(homeMonthProvider.notifier).followToday(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
