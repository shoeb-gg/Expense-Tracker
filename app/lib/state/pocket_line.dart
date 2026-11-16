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
  final name = pocket.name.characters.length > 16
      ? '${pocket.name.characters.take(15)}…'
      : pocket.name;
  return '${pocket.emoji} $name';
}

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
