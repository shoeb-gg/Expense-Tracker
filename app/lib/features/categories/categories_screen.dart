import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db.dart';
import '../../router.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';

/// Categories (board "Categories"): every category with a bin, a pencil and
/// a drag handle, and "Add category" fixed at the bottom.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  /// The order just dragged, shown until the database catches up.
  List<int>? _pendingOrder;

  List<ExpenseCategory> _ordered(List<ExpenseCategory> cats) {
    final order = _pendingOrder;
    if (order == null || order.length != cats.length) return cats;
    final byId = {for (final c in cats) c.id: c};
    if (!order.every(byId.containsKey)) return cats;
    return [for (final id in order) byId[id]!];
  }

  Future<void> _reorder(List<ExpenseCategory> cats, int from, int to) async {
    final ids = [for (final c in cats) c.id];
    final moved = ids.removeAt(from);
    ids.insert(to > from ? to - 1 : to, moved);
    setState(() => _pendingOrder = ids);
    await ref.read(categoriesRepoProvider).reorder(ids);
  }

  Future<void> _delete(ExpenseCategory cat) async {
    final repo = ref.read(categoriesRepoProvider);
    final fmt = ref.read(amountFormatProvider);
    final n = await repo.countExpenses(cat.id);
    if (!mounted) return;
    final ok = await showAppDialog(
      context,
      title: 'Delete ${cat.name}?',
      boldLine: n == 0
          ? '${cat.name} has no expenses.'
          : n == 1
          ? '1 expense moves to Miscellaneous.'
          : '${fmt.count(n)} expenses move to Miscellaneous.',
      quietLine: n == 0 ? 'It will simply be removed.' : 'Nothing is lost.',
      actionLabel: 'Delete',
      destructive: true,
    );
    if (ok) await repo.delete(cat.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loaded = ref.watch(categoriesProvider).value;
    if (loaded != null &&
        _pendingOrder != null &&
        listEquals([for (final cat in loaded) cat.id], _pendingOrder)) {
      _pendingOrder = null;
    }
    final cats = loaded == null ? const <ExpenseCategory>[] : _ordered(loaded);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SubHeader(title: 'Categories'),
            Expanded(
              child: Stack(
                children: [
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
                          sliver: SliverMainAxisGroup(
                            slivers: [
                              SliverToBoxAdapter(
                                child: _Band(count: cats.length),
                              ),
                              DecoratedSliver(
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(20),
                                  ),
                                ),
                                sliver: SliverPadding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  sliver: SliverReorderableList(
                                    itemCount: cats.length,
                                    onReorder: (from, to) =>
                                        _reorder(cats, from, to),
                                    proxyDecorator: (child, index, animation) =>
                                        _DragProxy(child: child),
                                    itemBuilder: (context, i) => _CategoryRow(
                                      key: ValueKey(cats[i].id),
                                      index: i,
                                      category: cats[i],
                                      last: i == cats.length - 1,
                                      onDelete: () => _delete(cats[i]),
                                      onEdit: () => context.push(
                                        Routes.editCategory(cats[i].id),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FadeDock(
                      child: PrimaryButton(
                        label: 'Add category',
                        icon: Symbols.add_rounded,
                        iconSize: 22,
                        glow: true,
                        onPressed: () => context.push(Routes.newCategory),
                      ),
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

/// The card's title band: "15 categories" and the drag hint, on one
/// baseline, then the 4 px list padding.
class _Band extends StatelessWidget {
  const _Band({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hint = AppText.sub.copyWith(color: c.text3);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              count == 1 ? '1 category' : '$count categories',
              maxLines: 1,
              style: AppText.cardTitle,
            ),
            const SizedBox(width: 12),
            // The hint gives way first on narrow screens or large text.
            Expanded(
              child: Text.rich(
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  children: [
                    const TextSpan(text: 'Hold'),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Symbols.drag_indicator_rounded,
                          size: 16,
                          color: c.text3,
                        ),
                      ),
                    ),
                    const TextSpan(text: 'and drag to reorder'),
                  ],
                ),
                maxLines: 1,
                style: hint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One 60 px row: emoji tile with its colour dot, the name, and the bin
/// (a lock on Miscellaneous), pencil and drag handle.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.index,
    required this.category,
    required this.last,
    required this.onDelete,
    required this.onEdit,
  });

  final int index;
  final ExpenseCategory category;
  final bool last;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final misc = category.isMisc;
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          const SizedBox(width: 16),
          EmojiTile(emoji: category.emoji, dotColor: context.categoryColor(category.color)),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              children: [
                if (!last)
                  Positioned(
                    left: 0,
                    right: 10,
                    bottom: 0,
                    height: 1,
                    child: ColoredBox(color: c.line),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.rowTitle,
                          ),
                          if (misc)
                            Text(
                              "Can't be deleted",
                              maxLines: 1,
                              style: AppText.sub.copyWith(color: c.text3),
                            ),
                        ],
                      ),
                    ),
                    _RowButton(
                      icon: misc
                          ? Symbols.lock_rounded
                          : Symbols.delete_rounded,
                      label: misc
                          ? '${category.name} cannot be deleted'
                          : 'Delete ${category.name}',
                      dim: misc,
                      onTap: misc ? null : onDelete,
                    ),
                    _RowButton(
                      icon: Symbols.edit_rounded,
                      label: 'Edit ${category.name}',
                      onTap: onEdit,
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Semantics(
                        label: 'Drag to reorder',
                        child: SizedBox(
                          width: 30,
                          height: 36,
                          child: Icon(
                            Symbols.drag_indicator_rounded,
                            size: 22,
                            color: c.text3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dim = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 36,
      child: Opacity(
        opacity: dim ? 0.6 : 1,
        child: Pressable(
          onTap: onTap,
          semanticLabel: label,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Icon(icon, size: 20, color: context.colors.text3),
          ),
        ),
      ),
    );
  }
}

/// The row being dragged: lifted on `surface2` with a soft shadow.
class _DragProxy extends StatelessWidget {
  const _DragProxy({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [popupShadow(context.colors)],
        ),
        child: child,
      ),
    );
  }
}
