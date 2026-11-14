import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../data/db.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import '../add/add_styles.dart';
import 'delete_expense.dart';
import 'receipt.dart';

/// Expense details (`/expense/:id`): the category and amount on an accent
/// card, the title (if any), the date with the time it was added, the
/// receipt photo, a link to the category's month, and Edit / Delete.
class ExpenseDetailsScreen extends ConsumerStatefulWidget {
  const ExpenseDetailsScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  ConsumerState<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends ConsumerState<ExpenseDetailsScreen> {
  /// Kept while the screen closes after Delete, so it does not flash
  /// "gone" for a frame.
  Expense? _shown;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(expenseProvider(widget.expenseId));
    final live = async.value;
    if (live != null) _shown = live;
    final expense = _deleting ? _shown : live;

    Widget body;
    if (expense == null) {
      body = async.isLoading && !async.hasValue ? const SizedBox.expand() : const MissingExpense();
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SubHeader(title: 'Details'),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    final category = ref.watch(categoriesByIdProvider)[expense.categoryId];
    final fmt = ref.watch(amountFormatProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SubHeader(title: 'Details'),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                  children: [
                    _HeroCard(
                      emoji: category?.emoji ?? '',
                      name: category?.name ?? '',
                      amount: fmt.format(expense.amount),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(expense: expense),
                    const SizedBox(height: 12),
                    _MonthLink(expense: expense, categoryName: category?.name ?? ''),
                  ],
                ),
              ),
            ),
            DockedBar(
              padding: DockedBar.twoButtonPadding,
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Edit',
                      icon: Symbols.edit_rounded,
                      onPressed: () => context.push(Routes.editExpense(expense.id)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Delete',
                      icon: Symbols.delete_rounded,
                      tone: ButtonTone.danger,
                      onPressed: () => _delete(expense),
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

  Future<void> _delete(Expense expense) async {
    await deleteExpenseWithUndo(
      context,
      ref,
      expense,
      onConfirmed: () => setState(() => _deleting = true),
    );
    // Close once confirmed (also when the expense was already gone).
    if (!_deleting || !mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.emoji, required this.name, required this.amount});

  final String emoji;
  final String name;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.onAccent, borderRadius: BorderRadius.circular(20)),
            child: ExcludeSemantics(child: Text(emoji, style: emojiText(32))),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: boardText(15, 20, FontWeight.w700, color: c.onAccentDim),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              maxLines: 1,
              style: boardText(40, 48, FontWeight.w800, letterSpacing: -0.8, color: c.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends ConsumerWidget {
  const _InfoCard({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final photo = expense.photoPath;
    final rows = <_InfoRowData>[
      if (expense.note.isNotEmpty)
        _InfoRowData(icon: Symbols.notes_rounded, label: 'Title', value: expense.note, height: 68),
      _InfoRowData(
        icon: Symbols.calendar_month_rounded,
        label: 'Date',
        value: longDate(expense.day),
        extra: addedLabel(expense.createdAt),
        height: 88,
      ),
      if (photo != null)
        _InfoRowData(
          icon: Symbols.photo_camera_rounded,
          label: 'Photo',
          value: 'Receipt, tap to view',
          height: 68,
          trailing: ReceiptThumb(fileName: photo, size: 44, radius: 12),
          onTap: () => context.push(Routes.expensePhoto(expense.id)),
        ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _InfoRow(data: rows[i], divider: i < rows.length - 1),
        ],
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
    required this.height,
    this.extra,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final double height;
  final String? extra;
  final Widget? trailing;
  final VoidCallback? onTap;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data, required this.divider});

  final _InfoRowData data;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = SizedBox(
      height: data.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 16),
          Center(
            child: IconTile(icon: data.icon, iconColor: c.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              foregroundDecoration: divider
                  ? BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.line)),
                    )
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.label, style: AppText.sub.copyWith(color: c.text3)),
                        const SizedBox(height: 2),
                        Text(
                          data.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.rowTitle,
                        ),
                        if (data.extra != null) ...[
                          const SizedBox(height: 2),
                          Text(data.extra!, style: AppText.sub.copyWith(color: c.text3)),
                        ],
                      ],
                    ),
                  ),
                  if (data.trailing != null) ...[const SizedBox(width: 12), data.trailing!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (data.onTap == null) return row;
    return Pressable(onTap: data.onTap, semanticLabel: '${data.label}: ${data.value}', child: row);
  }
}

/// "See all Health in October / 1 expense so far", opening the category's
/// drill-down for that month.
class _MonthLink extends ConsumerWidget {
  const _MonthLink({required this.expense, required this.categoryName});

  final Expense expense;
  final String categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final fmt = ref.watch(amountFormatProvider);
    final from = monthStartOfDay(expense.day);
    final to = monthEndOfDay(expense.day);
    final totals = ref.watch(
      categoryTotalsProvider((pocketId: expense.pocketId, from: from, to: to)),
    );
    var count = 0;
    for (final t in totals.value ?? const <CategoryTotal>[]) {
      if (t.categoryId == expense.categoryId) count = t.count;
    }
    final ym = yearMonthOfDay(expense.day);
    final month = sameYear(expense.day, today) ? monthName(ym.month) : monthYear(ym.year, ym.month);
    final current = sameMonth(expense.day, today);
    final sub = totals.hasValue ? '${expenseCount(count, fmt)}${current ? ' so far' : ''}' : '';
    return Pressable(
      color: c.surface,
      borderRadius: BorderRadius.circular(20),
      semanticLabel: 'See all $categoryName in $month',
      onTap: () => context.push(Routes.category(expense.categoryId, from: from, to: to)),
      child: ConstrainedBox(
        // 76 px; a long category name wraps to a second line instead of
        // being cut off.
        constraints: const BoxConstraints(minHeight: 76),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const IconTile(icon: Symbols.donut_small_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'See all $categoryName in $month',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(sub, style: AppText.sub.copyWith(color: c.text3)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const RowChevron(),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
