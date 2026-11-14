import 'package:flutter/widgets.dart';

/// One titled group of the pocket emoji picker.
typedef EmojiGroup = ({String title, List<String> emojis});

/// The four groups of six on the Add/Edit pocket boards.
const List<EmojiGroup> pocketEmojiGroups = [
  (title: 'Everyday', emojis: ['👛', '💰', '🏠', '🛒', '🧺', '❤️']),
  (title: 'Work', emojis: ['💼', '🏢', '💻', '🛠️', '🏪', '📦']),
  (title: 'Trips and events', emojis: ['✈️', '🏖️', '🎉', '💍', '🕌', '🎓']),
  (title: 'Everything else', emojis: ['🚗', '🐶', '🌱', '📚', '🎮', '⭐']),
];

/// The emoji a new pocket starts with: the first one in the groups that no
/// pocket uses yet (the first of all when every one is taken).
String firstUnusedEmoji(Iterable<String> used) {
  final taken = used.toSet();
  for (final group in pocketEmojiGroups) {
    for (final emoji in group.emojis) {
      if (!taken.contains(emoji)) return emoji;
    }
  }
  return pocketEmojiGroups.first.emojis.first;
}

final RegExp _pictographic = RegExp(
  // Valid with unicode: true (covered by tests); the lint doesn't know these properties.
  // ignore: valid_regexps
  r'\p{Extended_Pictographic}|\p{Regional_Indicator}',
  unicode: true,
);

/// The last emoji typed in [text] (from the keyboard's emoji page), or null
/// when the last character is not an emoji.
String? lastEmoji(String text) {
  if (text.isEmpty) return null;
  final last = text.characters.last;
  return _pictographic.hasMatch(last) ? last : null;
}
