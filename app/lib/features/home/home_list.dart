import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../data/db.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'home_state.dart';

/// Called when an expense row is tapped ([held] false) or held ([held] true).
/// [rowContext] is the row's own context, for finding where it sits.
typedef ExpenseRowAction =
    void Function(
      Expense expense,
      BuildContext rowContext, {
      required bool held,
    });

/// The scrolling part of Home for one month: a card per day, then the
/// "See September" button. [expenses] is null while loading.
class HomeMonthList extends ConsumerWidget {
  const HomeMonthList({
    super.key,
    required this.pocket,
    required this.month,
    required this.expenses,
    required this.onRow,
    required this.onSeePrevious,
  });

  final Pocket pocket;
  final YearMonth month;
  final List<Expense>? expenses;
  final ExpenseRowAction onRow;
  final VoidCallback onSeePrevious;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = expenses;
    if (list == null) return const SizedBox.expand();
    final today = ref.watch(todayProvider);
    final fmt = ref.watch(amountFormatProvider);
    final categories = ref.watch(categoriesByIdProvider);
    final span = ref.watch(daySpanProvider(pocket.id)).value;
    final first = span?.first;
    final hasEarlier =
        first != null && first < monthStart(month.year, month.month);
    final groups = groupByDay(list);
    final previous = stepMonth(month, -1);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (groups.isEmpty)
            EmptyMonthCard(
              title: span != null && first == null
                  ? 'Nothing in ${pocket.name} yet'
                  : 'Nothing spent in ${monthName(month.month)}',
              message: span != null && first == null
                  ? 'Tap + to add its first expense.'
                  : monthIndex(month) == monthIndex(yearMonthOfDay(today))
                  ? 'Tap + to add an expense.'
                  : 'Swipe or pick another month.',
            ),
          for (final g in groups)
            DayCard(
              group: g,
              today: today,
              format: fmt,
              categories: categories,
              onRow: onRow,
            ),
          if (hasEarlier)
            SeeMonthButton(
              label: previous.year == month.year
                  ? 'See ${monthName(previous.month)}'
                  : 'See ${monthYear(previous.year, previous.month)}',
              onTap: onSeePrevious,
            ),
        ],
      ),
    );
  }
}

/// One day on Home (PocketHome board): a 60 px strip with the date badge,
/// "Today" / weekday, the day total, then the day's expenses.
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.group,
    required this.today,
    required this.format,
    required this.categories,
    required this.onRow,
  });

  final DayGroup group;
  final int today;
  final AmountFormat format;
  final Map<int, ExpenseCategory> categories;
  final ExpenseRowAction onRow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final day = group.day;
    final isToday = day == today;
    final date = dateOfDay(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: c.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                label:
                    '${weekdayName(day)}, ${monthName(date.month)} '
                    '${date.day}, total ${format.format(group.total)}',
                child: ExcludeSemantics(
                  child: Container(
                    height: 60,
                    color: c.surface2,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday ? c.accent : c.accentSoft,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            '${date.day}',
                            style: AppText.badgeNumber.copyWith(
                              color: isToday ? c.onAccent : c.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StripTexts(
                            top: Text(
                              dayLabel(day, today),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.dayTitle.copyWith(color: c.text),
                            ),
                            bottom: Text(
                              daySubLabel(day, today),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sub.copyWith(color: c.text3),
                            ),
                            alignEnd: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StripTexts(
                          top: Text(
                            format.format(group.total),
                            style: AppText.dayTotal.copyWith(color: c.accent),
                          ),
                          bottom: Text(
                            'Total',
                            style: AppText.sub.copyWith(color: c.text3),
                          ),
                          alignEnd: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: BandCard.listPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < group.expenses.length; i++)
                      Builder(
                        builder: (rowContext) {
                          final e = group.expenses[i];
                          return HomeExpenseRow(
                            expense: e,
                            category: categories[e.categoryId],
                            format: format,
                            divider: i < group.expenses.length - 1,
                            onTap: () => onRow(e, rowContext, held: false),
                            onLongPress: () => onRow(e, rowContext, held: true),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two stacked lines of the day strip (20 px, 3 px gap, 16 px), lifted 1 px
/// as in the mockup.
class _StripTexts extends StatelessWidget {
  const _StripTexts({
    required this.top,
    required this.bottom,
    required this.alignEnd,
  });

  final Widget top;
  final Widget bottom;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [top, const SizedBox(height: 3), bottom],
      ),
    );
  }
}

/// An expense on Home: the category's emoji tile, the title (or the category
/// when there is no title) with the category under it, and the amount.
class HomeExpenseRow extends StatelessWidget {
  const HomeExpenseRow({
    super.key,
    required this.expense,
    required this.category,
    required this.format,
    this.divider = true,
    this.onTap,
    this.onLongPress,
  });

  final Expense expense;
  final ExpenseCategory? category;
  final AmountFormat format;
  final bool divider;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The row's title: the expense title, else the category name.
  static String titleOf(Expense e, ExpenseCategory? category) {
    final note = e.note.trim();
    return note.isNotEmpty ? note : (category?.name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final note = expense.note.trim();
    final categoryName = category?.name ?? '';
    return ListRow(
      title: note.isNotEmpty ? note : categoryName,
      subtitle: note.isNotEmpty ? categoryName : null,
      leading: EmojiTile(emoji: category?.emoji ?? ''),
      trailingText: format.format(expense.amount),
      divider: divider,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// The "‹ See September" pill at the end of the list (previous month).
class SeeMonthButton extends StatelessWidget {
  const SeeMonthButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Center(
        child: SizedBox(
          height: 40,
          child: Pressable(
            onTap: onTap,
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.chevron_left_rounded, size: 20, color: c.text),
                  const SizedBox(width: 4),
                  Text(label, style: AppText.segment.copyWith(color: c.text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Home with no expenses in the month (not drawn in the mockup): a day-card
/// sized card with a receipt icon, a bold line and a quiet line.
class EmptyMonthCard extends StatelessWidget {
  const EmptyMonthCard({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: MessageCard(
        icon: Symbols.receipt_long_rounded,
        title: title,
        message: message,
      ),
    );
  }
}
