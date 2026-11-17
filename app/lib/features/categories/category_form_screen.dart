import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/db.dart';
import '../../state/budgets.dart';
import '../../state/pocket_line.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'category_parts.dart';

/// Add category / Edit category (boards "Add category", "Edit category"):
/// a name with a live preview tile, every chart color (those other
/// categories already use are marked, and a line says who) and an emoji
/// picker in six groups, plus the phone keyboard for any other emoji.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.categoryId});

  /// Null for a new category; -1 when the link was invalid.
  final int? categoryId;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _emojiFocus = FocusNode();
  final _budget = TextEditingController();
  final _budgetFocus = FocusNode();
  String _emoji = newCategoryEmoji;

  /// The color the user picked, or (edit) the category's own. Null on Add
  /// until they pick: then [_newColor] applies.
  int? _picked;

  /// A new category's starting color: the first no category has, fixed once
  /// the categories have loaded so it does not move under the user.
  int? _newColor;
  ExpenseCategory? _editing;
  bool _seeded = false;
  bool _saving = false;

  bool get _isEdit => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _budget.addListener(() => setState(() {}));
    _seeded = !_isEdit;
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _emojiFocus.dispose();
    _budget.dispose();
    _budgetFocus.dispose();
    super.dispose();
  }

  void _seed(ExpenseCategory cat) {
    _editing = cat;
    _name.text = cat.name;
    _emoji = cat.emoji;
    _picked = cat.color;
    _seeded = true;
  }

  /// Whether the budget field got the category's stored budget (Edit).
  bool _budgetSeeded = false;

  /// Edit: once the pocket and its budgets have loaded, fills the budget
  /// field with this category's budget there (after the frame, since the
  /// field's listener rebuilds the form).
  void _seedBudget() {
    final editing = _editing;
    if (_budgetSeeded || editing == null) return;
    final pocketId = ref.watch(currentPocketIdProvider);
    if (pocketId == null) return;
    final budgets = ref.watch(pocketBudgetsProvider(pocketId)).value;
    if (budgets == null) return;
    _budgetSeeded = true;
    final amount = budgets[editing.id];
    if (amount == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _budget.text.isEmpty) {
        _budget.text = budgetText(amount, ref.read(amountFormatProvider));
      }
    });
  }

  /// The typed budget in minor units: null for an empty field (no budget),
  /// [_invalidBudget] when the text is not an amount.
  int? _parsedBudget() {
    final text = _budget.text.trim();
    if (text.isEmpty) return null;
    final amount = ref.read(amountFormatProvider).parse(text);
    if (amount == null || amount <= 0) return _invalidBudget;
    // Like an expense on the keypad: at most 9 digits before the point.
    return amount > _maxBudget ? _tooBigBudget : amount;
  }

  static const int _invalidBudget = -1;
  static const int _tooBigBudget = -2;
  static const int _maxBudget = 99999999999;

  /// The color shown and saved.
  int _colorFor(List<ExpenseCategory>? all) {
    final picked = _picked;
    if (picked != null) return picked;
    if (all == null) return CategoryColor.values.first.argb;
    return _newColor ??= CategoryColor.firstFree([
      for (final c in all) c.color,
    ]).argb;
  }

  /// Who has each color, leaving out the category being edited.
  Map<int, List<ExpenseCategory>> _takenBy(List<ExpenseCategory>? all) {
    final taken = <int, List<ExpenseCategory>>{};
    for (final c in all ?? const <ExpenseCategory>[]) {
      if (c.id == _editing?.id) continue;
      taken.putIfAbsent(c.color, () => []).add(c);
    }
    return taken;
  }

  Future<void> _save() async {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final budget = _parsedBudget();
    if (name.isEmpty || _saving || (budget != null && budget < 0)) return;
    final repo = ref.read(categoriesRepoProvider);
    setState(() => _saving = true);
    try {
      if (await repo.nameExists(name, exceptId: _editing?.id)) {
        if (mounted) {
          showToast(context, 'There is already a category called $name');
        }
        return;
      }
      final editing = _editing;
      final color = _colorFor(ref.read(categoriesProvider).value);
      final int id;
      if (editing == null) {
        id = await repo.add(name: name, emoji: _emoji, color: color);
      } else {
        await repo.update(
          editing.copyWith(name: name, emoji: _emoji, color: color),
        );
        id = editing.id;
      }
      final pocketId = ref.read(currentPocketIdProvider);
      if (pocketId != null) {
        await ref.read(budgetsRepoProvider).set(pocketId, id, budget);
      }
      if (mounted) await Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = _isEdit ? 'Edit category' : 'Add category';
    if (_isEdit && !_seeded) {
      final cats = ref.watch(categoriesProvider).value;
      final found = cats?.where((x) => x.id == widget.categoryId).firstOrNull;
      if (found != null) {
        _seed(found);
      } else if (cats != null) {
        return _NotFound(title: title);
      } else {
        return Scaffold(backgroundColor: c.bg);
      }
    }
    _seedBudget();
    final budgetError = switch (_parsedBudget()) {
      _invalidBudget => 'Type an amount, like 5000 or 2500.50.',
      _tooBigBudget => 'A budget has at most 9 digits.',
      _ => null,
    };
    final canSave = _name.text.trim().isNotEmpty && !_saving && budgetError == null;
    final all = ref.watch(categoriesProvider).value;
    final pockets = ref.watch(pocketsProvider).value ?? const <Pocket>[];
    final budgetPocket = pocketWhenSeveral(pockets, ref.watch(currentPocketProvider));
    final color = _colorFor(all);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubHeader.form(
              title: title,
              onCancel: () => Navigator.of(context).maybePop(),
              onSave: canSave ? _save : null,
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    2,
                    16,
                    24 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: [
                    _NameCard(
                      controller: _name,
                      focusNode: _nameFocus,
                      emoji: _emoji,
                      color: context.categoryColor(color),
                      onSubmit: _save,
                    ),
                    const SizedBox(height: 12),
                    _BudgetCard(
                      controller: _budget,
                      focusNode: _budgetFocus,
                      pocket: budgetPocket,
                      error: budgetError,
                      onSubmit: _save,
                    ),
                    const SizedBox(height: 12),
                    BandCard(
                      title: 'Color on charts',
                      trailingText: colorName(color),
                      bodyPadding: const EdgeInsets.fromLTRB(16, 11, 16, 16),
                      child: ColorSwatches(
                        value: color,
                        takenBy: _takenBy(all),
                        onChanged: (v) => setState(() => _picked = v.argb),
                      ),
                    ),
                    const SizedBox(height: 12),
                    BandCard(
                      title: 'Emoji',
                      bodyPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Stack(
                        children: [
                          EmojiPicker(
                            value: _emoji,
                            onChanged: (e) => setState(() => _emoji = e),
                            onKeyboard: () {
                              _nameFocus.unfocus();
                              _emojiFocus.requestFocus();
                            },
                          ),
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: KeyboardEmojiCatcher(
                              focusNode: _emojiFocus,
                              onEmoji: (e) => setState(() => _emoji = e),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameCard extends StatelessWidget {
  const _NameCard({
    required this.controller,
    required this.focusNode,
    required this.emoji,
    required this.color,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String emoji;
  final Color color;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppText.rowTitle.copyWith(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w700,
      color: c.text,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: liftShadows(c),
      ),
      foregroundDecoration: edgeDecoration(c, BorderRadius.circular(20)),
      child: Row(
        children: [
          CategoryPreviewTile(emoji: emoji, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: style,
                maxLength: 40,
                maxLines: 1,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmit(),
                cursorColor: c.text,
                decoration: InputDecoration.collapsed(
                  hintText: 'Category name',
                  // text3, like "Pocket name" on Add pocket.
                  hintStyle: style.copyWith(color: c.text3),
                ).copyWith(counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stored budget as the field shows it: grouped like every amount in the
/// app, with decimals only when it has them ("5,000", "2,500.50").
String budgetText(int minor, AmountFormat fmt) {
  final whole = fmt.group(minor ~/ 100);
  final cents = minor % 100;
  return cents == 0 ? whole : '$whole.${cents.toString().padLeft(2, '0')}';
}

/// The note under the budget field: which pocket the budget is for when there
/// are two or more ([pocket]), else how a budget works. A long pocket name
/// ends in "…" and gets no full stop after it.
String budgetNote(Pocket? pocket) {
  if (pocket == null) return 'The same amount every month. Leave it empty for no budget.';
  final label = pocketLabel(pocket);
  return 'Only for $label${label.endsWith('…') ? '' : '.'} Each pocket has its own budgets.';
}

/// "Monthly budget": an optional amount for the category in the pocket in
/// use. [pocket] is that pocket when there are two or more (the band then
/// names it), else null.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.controller,
    required this.focusNode,
    required this.pocket,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Pocket? pocket;

  /// What is wrong with the typed text, shown in red in place of the note.
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppText.rowTitle.copyWith(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w700,
      color: c.text,
    );
    final error = this.error;
    final note = error ?? budgetNote(pocket);
    final invalid = error != null;
    return BandCard(
      title: 'Monthly budget',
      trailingText: 'Optional',
      bodyPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: style,
              maxLength: 15,
              maxLines: 1,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              cursorColor: c.text,
              decoration: InputDecoration.collapsed(
                hintText: 'No budget',
                hintStyle: style.copyWith(color: c.text3),
              ).copyWith(counterText: ''),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            note,
            style: AppText.body.copyWith(color: invalid ? c.bad : c.text2),
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubHeader(title: title),
            const Expanded(
              child: NotFoundCard(
                thing: 'Category',
                icon: Symbols.category_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
