import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/format.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'data_parts.dart';
import 'data_providers.dart';
import 'import_columns_screen.dart';
import 'import_logic.dart';

/// Import, step 3 of 3: "Review and import" (board "Import: step 3").
/// Nothing is saved before "Import N expenses"; afterwards Home shows
/// "N expenses added" with Undo.
class ImportReviewScreen extends ConsumerStatefulWidget {
  const ImportReviewScreen({super.key});

  @override
  ConsumerState<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends ConsumerState<ImportReviewScreen> {
  bool _busy = false;

  Future<void> _import(ImportPlan plan, int pocketId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final categories = ref.read(categoriesRepoProvider);
    final expenses = ref.read(expensesRepoProvider);
    final fmt = ref.read(amountFormatProvider);
    final router = GoRouter.of(context);
    final session = ref.read(importSessionProvider.notifier);
    try {
      final result = await applyImport(
        plan: plan,
        pocketId: pocketId,
        categories: categories,
        expenses: expenses,
      );
      if (!mounted) {
        session.clear();
        return;
      }
      final n = result.count;
      showToast(
        context,
        n == 1 ? '1 expense added' : '${fmt.count(n)} expenses added',
        onUndo: () => undoImport(
          result: result,
          categories: categories,
          expenses: expenses,
        ),
      );
      router.go(Routes.home);
      session.clear();
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, "Couldn't import. Nothing was added.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = ref.watch(importSessionProvider);
    final pocket = ref.watch(currentPocketProvider);
    final pocketId = ref.watch(currentPocketIdProvider);
    final fmt = ref.watch(amountFormatProvider);
    final header = SubHeader(
      title: 'Review and import',
      subtitle: stepSubtitle(3, pocket),
    );
    if (session == null) return NoImportFile(header: header);
    final plan = ref.watch(importPlanProvider).value;
    if (plan == null) {
      return DataPage(
        header: header,
        dock: const DataDock(
          label: 'Import',
          onPressed: null,
          hint: 'Adds to your expenses. Nothing is replaced.',
        ),
        children: const [],
      );
    }
    final adding = plan.toAdd.length;
    final cats = ref.watch(categoriesByIdProvider);
    final first = plan.firstDay;
    final last = plan.lastDay;
    return DataPage(
      header: header,
      dock: DataDock(
        label: adding == 0
            ? 'Nothing to import'
            : 'Import ${expenseCount(adding, fmt)}',
        onPressed: adding == 0 || _busy || pocketId == null
            ? null
            : () => _import(plan, pocketId),
        hint: adding == 0
            ? 'Go back to check the columns, or choose another file.'
            : 'Adds to your expenses. Nothing is replaced.',
      ),
      children: [
        _ReadyCard(
          count: expenseCount(adding, fmt),
          total: fmt.format(plan.total),
          span: first == null || last == null
              ? 'Nothing new in this file'
              : importSpan(first, last),
        ),
        BandCard(
          title: 'What happens',
          trailingText: plan.rowCount == 1
              ? '1 row in the file'
              : '${fmt.count(plan.rowCount)} rows in the file',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _outcomes(plan, fmt, c),
          ),
        ),
        if (adding > 0)
          BandCard(
            title: 'A first look',
            trailingText:
                '${plan.toAdd.length < 3 ? plan.toAdd.length : 3} of ${fmt.count(adding)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, e) in plan.toAdd.take(3).indexed)
                  _PreviewRow(
                    expense: e,
                    emoji: e.categoryId == null
                        ? importedCategoryEmoji
                        : cats[e.categoryId]?.emoji ?? importedCategoryEmoji,
                    amount: fmt.format(e.amount),
                    divider: i < (adding < 3 ? adding : 3) - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _outcomes(ImportPlan plan, AmountFormat fmt, AppColors c) {
    final rows = <({IconData icon, Color color, String title, String sub})>[
      (
        icon: Symbols.add_circle_rounded,
        color: c.good,
        title: plan.toAdd.length == 1
            ? '1 new expense'
            : '${fmt.count(plan.toAdd.length)} new expenses',
        sub: plan.toAdd.isEmpty ? 'Nothing to add' : 'Will be added',
      ),
      if (plan.skipped > 0)
        (
          icon: Symbols.content_copy_rounded,
          color: c.text2,
          title: '${fmt.count(plan.skipped)} already in the app',
          sub: 'Skipped, so nothing is counted twice',
        ),
      if (plan.bad.isNotEmpty)
        (
          icon: Symbols.error_rounded,
          color: c.bad,
          title: plan.bad.length == 1
              ? '1 row can’t be read'
              : '${fmt.count(plan.bad.length)} rows can’t be read',
          sub: badRowsLine(plan.bad),
        ),
      if (plan.newCategories.isNotEmpty)
        (
          icon: Symbols.category_rounded,
          color: c.accent,
          title: plan.newCategories.length == 1
              ? '1 new category'
              : '${plan.newCategories.length} new categories',
          sub: newCategoriesLine(plan.newCategories),
        ),
    ];
    return [
      for (final (i, r) in rows.indexed)
        BottomHairline.afterTile(
          show: i < rows.length - 1,
          child: ListRow(
            title: r.title,
            subtitle: r.sub,
            titleStyle: AppText.tabular(AppText.rowTitle),
            divider: false,
            leading: IconTile(icon: r.icon, iconColor: r.color),
          ),
        ),
    ];
  }
}

/// The accent summary card: "Ready to add / 298 expenses / 412,560 in total".
class _ReadyCard extends StatelessWidget {
  const _ReadyCard({
    required this.count,
    required this.total,
    required this.span,
  });

  final String count;
  final String total;
  final String span;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dim = c.onAccentDim;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ready to add',
            style: AppText.overline.copyWith(
              fontSize: 13,
              height: 16 / 13,
              fontWeight: FontWeight.w700,
              color: dim,
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            children: [
              Text(
                count,
                style: AppText.heroNumber.copyWith(
                  fontSize: 30,
                  height: 38 / 30,
                  letterSpacing: -0.6,
                  color: c.onAccent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total,
                      style: AppText.badgeNumber.copyWith(color: c.onAccent),
                    ),
                    Text(
                      'in total',
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 14 / 12,
                        color: dim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            span,
            style: AppText.tabular(AppText.overline.copyWith(color: dim)),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.expense,
    required this.emoji,
    required this.amount,
    required this.divider,
  });

  final PlannedExpense expense;
  final String emoji;
  final String amount;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sub = AppText.sub.copyWith(color: c.text3);
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          const SizedBox(width: 16),
          EmojiTile(emoji: emoji),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
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
                        Text(
                          expense.title.isEmpty
                              ? expense.categoryName
                              : expense.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.rowTitle,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                expense.categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: sub,
                              ),
                            ),
                            if (expense.newCategory) ...[
                              const SizedBox(width: 4),
                              const NewBadge(),
                            ],
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '· ${mediumDate(expense.day)}',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: sub,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(amount, style: AppText.rowAmount),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
