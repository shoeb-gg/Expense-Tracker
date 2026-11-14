/// Type to add: turns "coffee 120" into an amount, a category and a title.
///
/// Rules (BUILD_LIST, "How type to add picks a category"):
/// * The first number is the amount ("1,200" is 1200 in the comma style).
///   Later numbers stay in the title.
/// * Currency names and symbols ("tk", "taka", "\$", "৳" ...) are ignored.
/// * A word picks a category when the user taught it before (learned words,
///   shared by all pockets) or when it is the start (3+ letters) of a word in
///   a category name ("snack" -> Snacks, "elec" -> Electric Bill).
///   A learned word wins over a name match for that word.
/// * A word that starts more than one category name ("bill") is ambiguous and
///   does not vote on its own.
/// * If several words point to different categories, the category with the
///   most words wins; a tie goes to the category named first in the text.
/// * The remaining words become the title, first letter capitalised, the
///   user's own case kept otherwise. Words that matched the winning category
///   by its NAME are left out of the title ("snacks 555" has no title);
///   learned words stay in it ("saree 1200" keeps the title "Saree").
/// * There is NO built-in word list for categories.
library;

import 'package:flutter/foundation.dart';

import 'format.dart';

/// A category as the parser sees it.
typedef CategoryRef = ({int id, String name});

/// The result of [parseTypeToAdd].
@immutable
class TypedExpense {
  const TypedExpense({
    this.amount,
    this.categoryId,
    this.title = '',
    this.categoryWords = const [],
    this.titleWords = const [],
    this.byLearnedWord = false,
  });

  /// Minor units, or null when the text has no amount yet.
  final int? amount;

  /// The guessed category, or null when no word points to one.
  final int? categoryId;

  /// The title built from the remaining words ('' when none).
  final String title;

  /// Lower-case words that pointed to [categoryId].
  final List<String> categoryWords;

  /// Lower-case words of [title]. When the user picks or changes the
  /// category by hand, learn these words for that category.
  final List<String> titleWords;

  /// Whether the category came from a learned word (not a name match).
  final bool byLearnedWord;

  /// Whether an amount above zero was typed (the preview card shows then).
  bool get hasAmount => (amount ?? 0) > 0;

  @override
  String toString() =>
      'TypedExpense(amount: $amount, categoryId: $categoryId, title: "$title", '
      'categoryWords: $categoryWords, titleWords: $titleWords)';
}

const Set<String> _currencyWords = {
  'tk', 'taka', 'takas', 'bdt', 'rs', 'inr', 'rupee', 'rupees', 'usd', //
  'dollar', 'dollars', 'eur', 'euro', 'euros', 'gbp', 'pound', 'pounds',
};

final RegExp _space = RegExp(r'\s+');
final RegExp _edgePunctuation =
    RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true);
final RegExp _currencySymbols = RegExp('^[\$€£₹৳¥]+|[\$€£₹৳¥]+\$');
final RegExp _currencyAffix =
    RegExp(r'^(tk|bdt|rs|inr|usd)\.?(?=\d)|(?<=\d)(tk|bdt|rs|inr|usd)\.?$',
        caseSensitive: false);

class _Word {
  _Word(this.original, this.key);
  final String original;
  final String key;
  Set<int> candidates = const {};
  bool learned = false;
}

/// Parses type-to-add [text]. [learned] maps lower-case words to category
/// ids. [format] decides which grouping and decimal marks the amount uses.
TypedExpense parseTypeToAdd(
  String text, {
  required List<CategoryRef> categories,
  Map<String, int> learned = const {},
  AmountFormat format = const AmountFormat(),
}) {
  final tokens = text.trim().split(_space).where((t) => t.isNotEmpty);
  int? amount;
  final words = <_Word>[];
  for (final token in tokens) {
    if (amount == null) {
      final bare = token
          .replaceAll(_currencySymbols, '')
          .replaceAll(_currencyAffix, '');
      final value = format.parse(bare);
      if (value != null) {
        amount = value;
        continue;
      }
    }
    final key = token.toLowerCase().replaceAll(_edgePunctuation, '');
    if (key.isEmpty || _currencyWords.contains(key)) continue;
    if (RegExp(r'^[$€£₹৳¥]+$').hasMatch(token)) continue;
    words.add(_Word(token, key));
  }

  final ids = {for (final c in categories) c.id};
  final nameParts = {
    for (final c in categories)
      c.id: c.name.toLowerCase().split(_space).where((p) => p.isNotEmpty).toList(),
  };

  // Each word votes for one category, or is ambiguous, or says nothing.
  final votes = <int, int>{};
  final firstVote = <int, int>{};
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final taught = learned[w.key];
    if (taught != null && ids.contains(taught)) {
      w
        ..candidates = {taught}
        ..learned = true;
    } else if (w.key.length >= 3) {
      w.candidates = {
        for (final c in categories)
          if (nameParts[c.id]!.any((p) => p.startsWith(w.key))) c.id,
      };
    }
    if (w.candidates.length == 1) {
      final id = w.candidates.first;
      votes[id] = (votes[id] ?? 0) + 1;
      firstVote.putIfAbsent(id, () => i);
    }
  }

  int? winner;
  if (votes.isNotEmpty) {
    final ranked = votes.keys.toList()
      ..sort((a, b) {
        final byCount = votes[b]!.compareTo(votes[a]!);
        return byCount != 0 ? byCount : firstVote[a]!.compareTo(firstVote[b]!);
      });
    winner = ranked.first;
  }

  final titleParts = <_Word>[];
  final categoryWords = <String>[];
  var byLearned = false;
  for (final w in words) {
    final pointsToWinner = winner != null && w.candidates.contains(winner);
    if (pointsToWinner) {
      categoryWords.add(w.key);
      if (w.learned) byLearned = true;
    }
    if (pointsToWinner && !w.learned) continue;
    titleParts.add(w);
  }

  var title = titleParts.map((w) => w.original).join(' ');
  if (title.isNotEmpty) {
    title = title[0].toUpperCase() + title.substring(1);
  }
  return TypedExpense(
    amount: amount,
    categoryId: winner,
    title: title,
    categoryWords: List.unmodifiable(categoryWords),
    titleWords: List.unmodifiable(titleParts.map((w) => w.key)),
    byLearnedWord: byLearned,
  );
}
