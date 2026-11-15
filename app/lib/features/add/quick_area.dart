import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../data/db.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'add_styles.dart';
import 'dashed_box.dart';
import 'keypad_panel.dart';

/// The bottom of Add expense while no category is chosen: a card (the
/// guide, or the preview of a typed expense) above the typing bar.
///
/// The card grows with large text (a hint that wraps), so the area reports
/// its height through [onHeight] (without [bottomInset]) and the screen keeps
/// the grid clear of it.
class QuickArea extends StatelessWidget {
  const QuickArea({
    super.key,
    required this.card,
    required this.bar,
    required this.bottomInset,
    this.onHeight,
  });

  final Widget card;
  final Widget bar;
  final double bottomInset;

  /// Told the area's height, less [bottomInset], after a layout that changed it.
  final ValueChanged<double>? onHeight;

  @override
  Widget build(BuildContext context) {
    final area = ColoredBox(
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
    final report = onHeight;
    if (report == null) return area;
    return HeightReporter(onHeight: (height) => report(height - bottomInset), child: area);
  }
}

/// Tells [onHeight] its child's height after the frame in which that height
/// changed (and after the first layout).
class HeightReporter extends SingleChildRenderObjectWidget {
  const HeightReporter({super.key, required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHeightReporter).onHeight = onHeight;
  }
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
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
                // Wraps onto a second line in large text (the card grows, see
                // QuickArea); ends in "..." only after two lines.
                Text(
                  subtitle,
                  maxLines: 2,
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
///
/// Without a [category] the card also carries the prompt "Select a category
/// above" as a tinted strip along its top, so it shows right above the
/// keyboard, in the same place as the rest of the card.
class PreviewCard extends StatelessWidget {
  const PreviewCard({
    super.key,
    required this.category,
    required this.subtitle,
    required this.amount,
    required this.onCategoryTap,
    this.word = '',
    this.hint,
  });

  /// Null when the app does not know the category yet.
  final ExpenseCategory? category;
  final String subtitle;
  final String amount;
  final VoidCallback onCategoryTap;

  /// The typed title in lower case, or empty (read out with the prompt).
  final String word;
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
      foregroundDecoration: cat == null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.accent.withAlpha(0x8C), width: 1.5),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cat == null) _SelectCategoryStrip(word: word, onTap: onCategoryTap),
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
          _AddSlot(state: addState, onAdd: onAdd),
        ],
      ),
    );
  }
}

/// The Add button's place at the end of the typing bar. It does not jump
/// in: over 180 ms its slot widens (the field narrows and the camera slides
/// left) while the button grows from the bar's end and fades in; clearing
/// the bar plays it backwards. Hidden, it takes no room (the empty bar's
/// layout); shown, it is the 10 px gap and the 40 px pill.
class _AddSlot extends StatefulWidget {
  const _AddSlot({required this.state, required this.onAdd});

  final AddButtonState state;
  final VoidCallback onAdd;

  @override
  State<_AddSlot> createState() => _AddSlotState();
}

class _AddSlotState extends State<_AddSlot> with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 180);

  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: _duration,
    value: _visible ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _shown,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// What the button shows; kept while it animates out.
  late AddButtonState _drawn = widget.state;

  bool get _visible => widget.state != AddButtonState.hidden;

  @override
  void didUpdateWidget(_AddSlot old) {
    super.didUpdateWidget(old);
    if (_visible) {
      _drawn = widget.state;
      _shown.forward();
    } else {
      _shown.reverse();
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        if (_shown.isDismissed) return const SizedBox.shrink();
        final t = _curve.value;
        // The slot is t of the gap + pill wide; the pill is drawn t of its
        // size from its right end, so it always fits the slot exactly (no
        // clipping, nothing over the camera) and grows from the bar's end.
        return SizedBox(
          height: 40,
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: t,
            child: Opacity(
              opacity: t,
              child: Transform.scale(
                scale: t,
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 10),
          _AddButton(
            ready: _drawn == AddButtonState.ready,
            onTap: _visible ? widget.onAdd : null,
          ),
        ],
      ),
    );
  }
}

/// The 40 px "Add" pill of the typing bar: accent when ready, grey while
/// it still needs an amount or a category.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.ready, required this.onTap});

  final bool ready;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 40,
      child: Pressable(
        onTap: onTap,
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
    );
  }
}

/// "Select a category above": the tinted strip along the top of the preview
/// card while a typed word has no category yet. Tapping it flashes the tiles.
class _SelectCategoryStrip extends StatelessWidget {
  const _SelectCategoryStrip({required this.word, required this.onTap});

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: c.accent.withAlpha(0x1F),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(Symbols.arrow_upward_rounded, size: 18, color: c.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select a category above',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: boardText(
                      14,
                      18,
                      FontWeight.w800,
                      letterSpacing: -0.1,
                      color: c.accent,
                    ),
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
