/// Small helpers that decide where a text may break into lines.
library;

/// No-break space: looks like a space, never starts a new line.
const String noBreakSpace = '\u00A0';

/// [text] with the space before its last word turned into a no-break space,
/// so a note that wraps never leaves one word alone on the last line (the
/// last two words move down together). Text with fewer than two words, and
/// the wording itself, stay as they are.
String keepLastWordsTogether(String text) {
  final end = text.trimRight().length;
  final gap = end == 0 ? -1 : text.lastIndexOf(' ', end - 1);
  if (gap <= 0) return text;
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
