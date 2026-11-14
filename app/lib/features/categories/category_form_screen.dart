import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/db.dart';
import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'category_parts.dart';

/// Add category / Edit category (boards "Add category", "Edit category"):
/// a name with a live preview tile, eight chart colours and an emoji
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
  String _emoji = newCategoryEmoji;
  int _color = newCategoryColor.argb;
  ExpenseCategory? _editing;
  bool _seeded = false;
  bool _saving = false;

  bool get _isEdit => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _seeded = !_isEdit;
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _emojiFocus.dispose();
    super.dispose();
  }

  void _seed(ExpenseCategory cat) {
    _editing = cat;
    _name.text = cat.name;
    _emoji = cat.emoji;
    _color = cat.color;
    _seeded = true;
  }

  Future<void> _save() async {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty || _saving) return;
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
      if (editing == null) {
        await repo.add(name: name, emoji: _emoji, color: _color);
      } else {
        await repo.update(
          editing.copyWith(name: name, emoji: _emoji, color: _color),
        );
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
    final canSave = _name.text.trim().isNotEmpty && !_saving;
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
                      color: Color(_color),
                      onSubmit: _save,
                    ),
                    const SizedBox(height: 12),
                    BandCard(
                      title: 'Color on charts',
                      trailingText: colorName(_color),
                      bodyPadding: const EdgeInsets.all(16),
                      child: ColorSwatches(
                        value: _color,
                        onChanged: (v) => setState(() => _color = v.argb),
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
      ),
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
