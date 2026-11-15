import 'package:flutter/foundation.dart';

import '../../core/calculator.dart';
import '../../core/days.dart';
import '../../core/format.dart';
import '../../core/type_to_add.dart';
import '../../data/db.dart';

/// What the check key at the bottom right of the keypad shows.
enum CheckKey {
  /// "Save", ready (an amount above zero, no operator).
  save,

  /// "Save", greyed out (nothing to save yet).
  saveDisabled,

  /// "=" (the expression has an operator).
  equals,

  /// "=", greyed out: the expression has no result (divide by zero ...).
  equalsDisabled,
}

/// What the amount block and the check key show for a keypad expression.
@immutable
class KeypadView {
  const KeypadView({
    required this.amountText,
    required this.isPlaceholder,
    required this.checkKey,
    this.expressionText,
    this.amount,
    this.noResult = false,
  });

  /// The big number.
  final String amountText;

  /// True when the big number is the grey "0" (nothing typed or no result).
  final bool isPlaceholder;

  /// The small line above the big number, only while an operator is typed.
  final String? expressionText;

  /// The amount to save in minor units, null when Save is not possible.
  final int? amount;

  final CheckKey checkKey;

  /// The expression cannot be worked out (divide by zero, below zero, too big).
  final bool noResult;
}

/// Builds the keypad display for [expr] (as made by `applyKeypadKey`).
KeypadView keypadView(String expr, AmountFormat format) {
  if (expr.isEmpty) {
    return const KeypadView(amountText: '0', isPlaceholder: true, checkKey: CheckKey.saveDisabled);
  }
  if (hasOperator(expr)) {
    final result = evaluateExpression(expr);
    final line = expressionLine(expr, format);
    if (result == null) {
      return KeypadView(
        amountText: '0',
        isPlaceholder: true,
        expressionText: line,
        checkKey: CheckKey.equalsDisabled,
        noResult: true,
      );
    }
    return KeypadView(
      amountText: format.format(result),
      isPlaceholder: false,
      expressionText: line,
      checkKey: CheckKey.equals,
    );
  }
  final amount = evaluateExpression(expr);
  final canSave = amount != null && amount > 0;
  return KeypadView(
    amountText: format.typed(expr),
    isPlaceholder: false,
    amount: canSave ? amount : null,
    checkKey: canSave ? CheckKey.save : CheckKey.saveDisabled,
  );
}

/// The expression with each number in the user's number style and a space
/// on each side of every operator: "1200+80" -> "1,200 + 80".
String expressionLine(String expr, AmountFormat format) {
  final out = StringBuffer();
  final number = StringBuffer();
  void flush() {
    if (number.isNotEmpty) out.write(format.typed(number.toString()));
    number.clear();
  }

  for (final rune in expr.runes) {
    final ch = String.fromCharCode(rune);
    if (isOperatorKey(ch)) {
      flush();
      out.write(' $ch ');
    } else {
      number.write(ch);
    }
  }
  flush();
  return out.toString().trim();
}

/// Short date for the date key and the preview card:
/// Today, Yesterday, Tomorrow, "Oct 12", or "Oct 12, 2025" in another year.
String shortDayLabel(int day, int today) {
  if (day == today) return 'Today';
  if (day == today - 1) return 'Yesterday';
  if (day == today + 1) return 'Tomorrow';
  return sameYear(day, today) ? monthDay(day) : mediumDate(day);
}

/// The stage of the type to add card.
enum QuickStage {
  /// Nothing typed: "Select a category".
  empty,

  /// Words but no amount yet: "Now add the amount".
  wordOnly,

  /// An amount and a category: the preview, ready to add.
  matched,

  /// An amount but no category: "No category" and the panel above.
  unknown,
}

/// Everything the type to add area shows, worked out from the typed text.
@immutable
class QuickView {
  const QuickView({
    required this.text,
    required this.parsed,
    required this.stage,
    this.categoryId,
    this.byHand = false,
  });

  /// The text as typed.
  final String text;
  final TypedExpense parsed;
  final QuickStage stage;

  /// The category in use: the user's pick, else the guessed one.
  final int? categoryId;

  /// True when the user picked the category on the grid.
  final bool byHand;

  /// Words to remember for the picked category when the expense is added.
  List<String> get wordsToLearn =>
      byHand && categoryId != null ? learnableWords(parsed.titleWords) : const [];

  /// The confirmation inside the card after a pick by hand. It names the
  /// words that are really learned ([wordsToLearn]), never the whole title:
  /// Next time, “saree” goes to Gifts. / Next time, “taxi” and “uber” go to
  /// Transportation.
  String? hint(String categoryName) {
    final words = wordsToLearn;
    if (words.isEmpty) return null;
    final quoted = [for (final w in words) '“$w”'];
    final names = quoted.length == 1
        ? quoted.single
        : '${quoted.sublist(0, quoted.length - 1).join(', ')} and ${quoted.last}';
    final verb = quoted.length == 1 ? 'goes' : 'go';
    return 'Next time, $names $verb to $categoryName.';
  }
}

/// Works out the type to add state. [manualPick] is the category the user
/// tapped on the grid for this typed expense (ignored if it no longer
/// exists in [validIds]).
QuickView quickView({
  required String text,
  required TypedExpense parsed,
  required Set<int> validIds,
  int? manualPick,
}) {
  final pick = manualPick != null && validIds.contains(manualPick) ? manualPick : null;
  final categoryId = pick ?? parsed.categoryId;
  final QuickStage stage;
  if (text.trim().isEmpty) {
    stage = QuickStage.empty;
  } else if (!parsed.hasAmount) {
    stage = QuickStage.wordOnly;
  } else {
    stage = categoryId == null ? QuickStage.unknown : QuickStage.matched;
  }
  return QuickView(
    text: text,
    parsed: parsed,
    stage: stage,
    categoryId: stage == QuickStage.empty ? null : categoryId,
    byHand: pick != null,
  );
}

final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _digit = RegExp(r'\d');

/// The title words worth remembering: at least two characters, with a
/// letter, no digits, and not a small linking word ("with", "of" ...).
List<String> learnableWords(List<String> titleWords) {
  final out = <String>[];
  for (final w in titleWords) {
    final word = w.trim().toLowerCase();
    if (word.length < 2) continue;
    if (!_letter.hasMatch(word) || _digit.hasMatch(word)) continue;
    if (stopWords.contains(word) || out.contains(word)) continue;
    out.add(word);
  }
  return out;
}

/// Whether leaving Add / Edit expense would throw away something the user
/// entered or changed (then Cancel and Back ask first).
///
/// A new expense counts as changed once there is an amount or calculation
/// ([expr]), a [title], a [categoryId], a [photo], words in the typing bar
/// ([typed]), a [day] other than [initialDay], or a [pocketId] other than
/// [currentPocketId] (the pocket the user is in). Editing an [original]
/// counts any difference from it: the amount (what [expr] works out to), the
/// title, the category, the photo, the day or the pocket ([pocketId] null:
/// not touched).
bool hasUnsavedInput({
  Expense? original,
  required String expr,
  required String title,
  required int? categoryId,
  required String? photo,
  required int day,
  required int initialDay,
  required int? pocketId,
  required int? currentPocketId,
  required String typed,
}) {
  if (original != null) {
    return evaluateExpression(expr) != original.amount ||
        title.trim() != original.note.trim() ||
        categoryId != original.categoryId ||
        photo != original.photoPath ||
        day != original.day ||
        (pocketId ?? original.pocketId) != original.pocketId;
  }
  return expr.isNotEmpty ||
      title.trim().isNotEmpty ||
      categoryId != null ||
      photo != null ||
      typed.trim().isNotEmpty ||
      day != initialDay ||
      (pocketId != null && pocketId != currentPocketId);
}
