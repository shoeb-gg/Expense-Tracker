/// Small helpers that decide where a text may break into lines.
library;

/// No-break space: looks like a space, never starts a new line.
const String noBreakSpace = '\u00A0';

/// The most characters the last two words may take together for
/// [keepLastWordsTogether] to join them (about what one line of the narrowest
/// phone holds).
const int lastWordsMaxLength = 18;

bool _isSpace(int unit) =>
    unit == 0x20 || unit == 0xA0 || (unit >= 0x09 && unit <= 0x0D);

/// [text] with the space before its last word turned into a no-break space,
/// so a note that wraps never leaves one word alone on the last line (the
/// last two words move down together). It only joins when it is safe: the
/// text has at least three words, and the last two together are at most
/// [lastWordsMaxLength] characters, so the pair always fits a line. Anything
/// else stays as it is, and so does the wording: only one space changes.
/// For fixed app wording, never for a name or text the user typed.
String keepLastWordsTogether(String text) {
  final end = text.trimRight().length;
  var lastStart = end;
  while (lastStart > 0 && !_isSpace(text.codeUnitAt(lastStart - 1))) {
    lastStart--;
  }
  // One word, or the last two are already joined.
  if (lastStart == 0 || text[lastStart - 1] != ' ') return text;
  final gap = lastStart - 1;
  var prevStart = gap;
  while (prevStart > 0 && !_isSpace(text.codeUnitAt(prevStart - 1))) {
    prevStart--;
  }
  // A third word before the pair; the pair short enough to share a line.
  if (prevStart == gap || text.substring(0, prevStart).trim().isEmpty) return text;
  if (end - prevStart > lastWordsMaxLength) return text;
  return text.replaceRange(gap, gap + 1, noBreakSpace);
}

/// Zero-width space: invisible, but a line may break after it.
const String zeroWidthSpace = '\u200B';

final RegExp _afterSeparator = RegExp(r'([_\-.])(?=[^\s\u200B])');

/// [name] (a file name such as "expenses_export_2026.csv") with an invisible
/// break mark after each "_", "-" and "." that has more name after it. A name
/// has no spaces, so without the marks a long one is cut anywhere; with them
/// it breaks only after a separator (or at a space). For showing only: the
/// file itself keeps its name.
String breakableFileName(String name) =>
    name.replaceAllMapped(_afterSeparator, (m) => '${m[1]}$zeroWidthSpace');
