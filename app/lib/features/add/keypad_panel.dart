import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/calculator.dart';
import '../../data/db.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import 'add_logic.dart';
import 'add_styles.dart';

/// Key value for backspace, as `applyKeypadKey` expects it.
const String keyDelete = 'del';

/// Key value for "=".
const String keyEquals = '=';

/// The keypad panel of Add and Edit expense: the chosen category and the
/// amount, the title field with the photo buttons, and the keys.
class KeypadPanel extends StatelessWidget {
  const KeypadPanel({
    super.key,
    required this.category,
    required this.view,
    required this.note,
    required this.noteFocus,
    required this.photoButtons,
    required this.fourKeys,
    required this.dateLabel,
    required this.onChip,
    required this.onKey,
    required this.onClear,
    required this.onDate,
    required this.onSave,
    required this.bottomInset,
  });

  final ExpenseCategory category;
  final KeypadView view;
  final TextEditingController note;
  final FocusNode noteFocus;

  /// The camera (or receipt thumbnail) and gallery buttons.
  final List<Widget> photoButtons;

  /// "All four keys": five columns with × and ÷.
  final bool fourKeys;
  final String dateLabel;
  final VoidCallback onChip;
  final ValueChanged<String> onKey;
  final VoidCallback onClear;
  final VoidCallback onDate;
  final VoidCallback onSave;

  /// Extra space under the keys (the phone's navigation bar).
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // CSS: inset 0 1px 0 line (a hairline along the rounded top edge),
    // 0 -12px 32px rgba(0,0,0,.35).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.line,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [cssShadow(y: -12, blur: 32, color: const Color(0x59000000))],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.nav,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 11, 16, 16 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: _CategoryChip(category: category, onTap: onChip),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 210),
                        child: _AmountBlock(view: view),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _TitleField(controller: note, focusNode: noteFocus, buttons: photoButtons),
                const SizedBox(height: 12),
                _Keys(
                  fourKeys: fourKeys,
                  view: view,
                  dateLabel: dateLabel,
                  onKey: onKey,
                  onClear: onClear,
                  onDate: onDate,
                  onSave: onSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});

  final ExpenseCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 44,
      child: Pressable(
        onTap: onTap,
        semanticLabel: 'Category: ${category.name}',
        color: c.surface2,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.tile, shape: BoxShape.circle),
                  child: Text(category.emoji, style: emojiText(18)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: boardText(14.5, 20, FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Symbols.expand_more_rounded, size: 20, color: c.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({required this.view});

  final KeypadView view;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final expression = view.expressionText;
    final small = boardText(12.5, 16, FontWeight.w600, tabular: true, color: c.text3);
    return Semantics(
      liveRegion: true,
      label: view.noResult ? 'No result' : 'Amount ${view.amountText}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (expression != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: expression),
                      if (view.noResult)
                        TextSpan(
                          text: '  ·  no result',
                          style: TextStyle(color: c.bad),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  style: small,
                ),
              ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                view.amountText,
                maxLines: 1,
                style: AppText.keypadNumber.copyWith(color: view.isPlaceholder ? c.text3 : c.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller, required this.focusNode, required this.buttons});

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 48,
      padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: BoardTextField(
              controller: controller,
              focusNode: focusNode,
              hint: 'Add a title (optional)',
              semanticLabel: 'Title, optional',
              capitalization: TextCapitalization.sentences,
            ),
          ),
          for (final b in buttons) ...[const SizedBox(width: 2), b],
        ],
      ),
    );
  }
}

/// A borderless one-line text field in the board's 15 px semibold, with
/// the hint in white at 55%. Done hides the keyboard.
class BoardTextField extends StatelessWidget {
  const BoardTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.semanticLabel,
    this.onChanged,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String semanticLabel;
  final ValueChanged<String>? onChanged;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = TextStyle(
      fontFamily: kFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: c.text,
    );
    return Semantics(
      label: semanticLabel,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: style,
        maxLines: 1,
        textCapitalization: capitalization,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => focusNode.unfocus(),
        inputFormatters: [LengthLimitingTextInputFormatter(120)],
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: style.copyWith(color: c.text.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}

class _Keys extends StatelessWidget {
  const _Keys({
    required this.fourKeys,
    required this.view,
    required this.dateLabel,
    required this.onKey,
    required this.onClear,
    required this.onDate,
    required this.onSave,
  });

  final bool fourKeys;
  final KeypadView view;
  final String dateLabel;
  final ValueChanged<String> onKey;
  final VoidCallback onClear;
  final VoidCallback onDate;
  final VoidCallback onSave;

  static const double _gap = 8;
  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = fourKeys ? 5 : 4;
        final w = (box.maxWidth - _gap * (cols - 1)) / cols;
        final wide = w * 2 + _gap;
        Widget digit(String d) =>
            _Key(width: w, label: d, onTap: () => onKey(d), child: _digitText(d));
        Widget op(String o, String name) =>
            _Key(width: w, label: name, onTap: () => onKey(o), child: _OpText(o));
        final date = _DateKey(width: fourKeys ? wide : w, label: dateLabel, onTap: onDate);
        final check = _CheckKey(
          width: fourKeys ? wide : w,
          view: view,
          onKey: onKey,
          onSave: onSave,
        );
        final del = _Key(
          width: w,
          label: 'Delete',
          onTap: () => onKey(keyDelete),
          onLongPress: onClear,
          child: Builder(
            builder: (context) =>
                Icon(Symbols.backspace_rounded, size: 22, color: context.colors.text),
          ),
        );
        final rows = fourKeys
            ? [
                [digit('7'), digit('8'), digit('9'), date],
                [digit('4'), digit('5'), digit('6'), op(opTimes, 'Times'), op(opPlus, 'Plus')],
                [digit('1'), digit('2'), digit('3'), op(opDivide, 'Divide'), op(opMinus, 'Minus')],
                [digit('.'), digit('0'), del, check],
              ]
            : [
                [digit('7'), digit('8'), digit('9'), date],
                [digit('4'), digit('5'), digit('6'), op(opPlus, 'Plus')],
                [digit('1'), digit('2'), digit('3'), op(opMinus, 'Minus')],
                [digit('.'), digit('0'), del, check],
              ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              SizedBox(
                height: _height,
                child: Row(
                  children: [
                    for (var k = 0; k < rows[r].length; k++) ...[
                      if (k > 0) const SizedBox(width: _gap),
                      rows[r][k],
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static Widget _digitText(String d) => Builder(
    builder: (context) => Text(
      d,
      style: boardText(21, 21, FontWeight.w700, tabular: true, color: context.colors.text),
    ),
  );
}

class _OpText extends StatelessWidget {
  const _OpText(this.op);

  final String op;

  @override
  Widget build(BuildContext context) {
    return Text(
      op,
      style: boardText(25, 25, FontWeight.w600, tabular: true, color: context.colors.accent),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.width,
    required this.label,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.color,
  });

  final double width;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 48,
      child: Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: label,
        color: color ?? context.colors.surface2,
        borderRadius: BorderRadius.circular(14),
        child: ExcludeSemantics(child: Center(child: child)),
      ),
    );
  }
}

class _DateKey extends StatelessWidget {
  const _DateKey({required this.width, required this.label, required this.onTap});

  final double width;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Key(
      width: width,
      label: 'Date of this expense: $label',
      onTap: onTap,
      color: c.accentSoft,
      child: Padding(
        // The top 2 px lines the label up with the board (Flutter's text
        // box sits 1 px higher than Chrome's here).
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.calendar_month_rounded, size: 18, color: c.accent),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: boardText(11.5, 11.5, FontWeight.w800, color: c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckKey extends StatelessWidget {
  const _CheckKey({
    required this.width,
    required this.view,
    required this.onKey,
    required this.onSave,
  });

  final double width;
  final KeypadView view;
  final ValueChanged<String> onKey;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return switch (view.checkKey) {
      CheckKey.equals => _Key(
        width: width,
        label: 'Equals',
        onTap: () => onKey(keyEquals),
        color: c.accent,
        child: Text(
          '=',
          style: boardText(25, 25, FontWeight.w700, tabular: true, color: c.onAccent),
        ),
      ),
      CheckKey.equalsDisabled => _Key(
        width: width,
        label: 'Equals, no result',
        onTap: null,
        child: Text('=', style: boardText(25, 25, FontWeight.w700, tabular: true, color: c.text3)),
      ),
      CheckKey.save => _Key(
        width: width,
        label: 'Save',
        onTap: onSave,
        color: c.accent,
        child: Text('Save', style: boardText(15, 20, FontWeight.w800, color: c.onAccent)),
      ),
      CheckKey.saveDisabled => _Key(
        width: width,
        label: 'Save',
        onTap: null,
        child: Text('Save', style: boardText(15, 15, FontWeight.w800, color: c.text3)),
      ),
    };
  }
}
