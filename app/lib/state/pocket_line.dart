/// The pocket named in a header: "👛 Personal". Shown only when the user has
/// two or more pockets, because with one there is nothing to tell apart.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import 'providers.dart';

/// "👛 Personal" for a header subtitle; long names are cut with "…" so the
/// subtitle stays on one line.
String pocketLabel(Pocket? pocket) {
  if (pocket == null) return '';
  return '${pocket.emoji} ${shortPocketName(pocket.name)}';
}

/// A pocket name short enough for one line in a header or a button: over 16
/// characters it keeps the first 15 and ends in "…".
String shortPocketName(String name) =>
    name.characters.length > 16 ? '${name.characters.take(15)}…' : name;

/// [pocket] when the user has two or more [pockets], else null. This is the
/// one rule for naming a pocket on screen (the pocket pill of Add and Edit
/// expense, and the pocket line under the title of Calendar, Charts and
/// Reports): with a single pocket nothing is shown.
Pocket? pocketWhenSeveral(List<Pocket> pockets, Pocket? pocket) =>
    pockets.length >= 2 ? pocket : null;

/// The label of the pocket in use, or null when the user has fewer than two
/// pockets: the subtitle of the Calendar, Charts and Reports headers.
final pocketLineProvider = Provider<String?>((ref) {
  final pockets = ref.watch(pocketsProvider).value ?? const <Pocket>[];
  final label = pocketLabel(
    pocketWhenSeveral(pockets, ref.watch(currentPocketProvider)),
  );
  return label.isEmpty ? null : label;
});
