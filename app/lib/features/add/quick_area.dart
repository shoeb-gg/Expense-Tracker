import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/db.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'add_styles.dart';
import 'dashed_box.dart';
import 'keypad_panel.dart';

/// The bottom of Add expense while no category is chosen: a card (the
/// guide, or the preview of a typed expense) above the typing bar.
class QuickArea extends StatelessWidget {
  const QuickArea({super.key, required this.card, required this.bar, required this.bottomInset});

  final Widget card;
  final Widget bar;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.bg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [card, const SizedBox(height: 10), bar],
        ),
      ),
    );
  }
}

/// "Select a category / Tap one above, or just type below", or, with a word
/// typed, "Now add the amount / Like “coffee 120”".
class GuideCard extends StatelessWidget {
  const GuideCard({super.key, required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          IconTile(icon: icon, iconSize: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sub.copyWith(color: c.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The preview of a typed expense: category (or "No category"), the title
/// and date, the amount, and after a pick by hand the "Next time" line.
class PreviewCard extends StatelessWidget {
  const PreviewCard({
    super.key,
    required this.category,
    required this.subtitle,
    required this.amount,
    required this.onCategoryTap,
    this.hint,
  });

  /// Null when the app does not know the category yet.
  final ExpenseCategory? category;
  final String subtitle;
  final String amount;
  final VoidCallback onCategoryTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cat = category;
    final tile = cat == null
        ? DashedBox(
            size: 44,
            radius: 14,
            color: c.accent,
            child: Text('?', style: boardText(20, 24, FontWeight.w800, color: c.accent)),
          )
        : EmojiBox(emoji: cat.emoji, background: c.tile);
    final name = cat == null
        ? Text(
            'No category',
            maxLines: 1,
            style: boardText(15, 20, FontWeight.w700, color: c.text2),
          )
        : Text(
            cat.name,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: AppText.rowTitle,
          );
    final hintText = hint;
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: cat == null
                        ? 'No category. Select a category above'
                        : 'Category ${cat.name}. Tap a tile above to change it',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onCategoryTap,
                      child: ExcludeSemantics(
                        child: Row(
                          children: [
                            tile,
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  name,
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.sub.copyWith(color: c.text3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(amount, maxLines: 1, style: boardText(17, 24, FontWeight.w800, tabular: true)),
              ],
            ),
          ),
          if (hintText != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.only(top: 8, bottom: 11),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Text(hintText, style: AppText.sub.copyWith(color: c.text3)),
            ),
        ],
      ),
    );
  }
}

/// What the Add button in the typing bar can do.
enum AddButtonState {
  /// Hidden: nothing typed yet.
  hidden,

  /// Grey: not ready (no amount, or no category).
  waiting,

  /// Accent: adds the typed expense.
  ready,
}

/// The typing bar: keyboard icon, the text field, the camera button (or the
/// receipt thumbnail) and, once something is typed, the Add button.
class TypingBar extends StatelessWidget {
  const TypingBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.photoButton,
    required this.addState,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final Widget photoButton;
  final AddButtonState addState;

  /// Called for a ready or a grey Add (a grey Add points at the grid).
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ready = addState == AddButtonState.ready;
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(28)),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(Symbols.keyboard_rounded, size: 22, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: BoardTextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              hint: 'Type it, like coffee 120',
              semanticLabel: 'Type to add an expense',
            ),
          ),
          const SizedBox(width: 10),
          photoButton,
          if (addState != AddButtonState.hidden) ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 40,
              child: Pressable(
                onTap: onAdd,
                semanticLabel: ready ? 'Add' : 'Add, choose a category first',
                color: ready ? c.accent : c.surface2,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    widthFactor: 1,
                    child: ExcludeSemantics(
                      child: Text(
                        'Add',
                        style: boardText(
                          14.5,
                          20,
                          FontWeight.w800,
                          color: ready ? c.onAccent : c.text3,
                        ),
                      ),
                    ),
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

/// The tinted panel under the grid when a typed word has no category yet.
class SelectCategoryBanner extends StatelessWidget {
  const SelectCategoryBanner({super.key, required this.word, required this.onTap});

  /// The typed title in lower case, or empty.
  final String word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sub = word.isEmpty
        ? 'So the app knows where this goes'
        : 'So the app knows where “$word” goes';
    return Semantics(
      liveRegion: true,
      label: 'Select a category above. $sub',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: c.accent.withAlpha(0x1F),
              borderRadius: BorderRadius.circular(20),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.accent.withAlpha(0x8C), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent.withAlpha(0x33),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Symbols.arrow_upward_rounded, size: 26, color: c.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select a category above',
                        maxLines: 1,
                        style: boardText(
                          17,
                          22,
                          FontWeight.w800,
                          letterSpacing: -0.2,
                          color: c.accent,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        sub,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sub.copyWith(color: c.text2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
