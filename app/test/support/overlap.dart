import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails when any visible text or icon outside [pill] overlaps it: a pill
/// that lives in free space covers nothing. Text is compared by its line
/// box, so a pass means a clear margin, not just clear ink.
void expectNothingUnder(WidgetTester tester, Finder pill) {
  final box = tester.getRect(pill);
  expect(box.isEmpty, isFalse, reason: 'the pill is on screen');
  final own = <Element>{
    ...find.descendant(of: pill, matching: find.byType(Text)).evaluate(),
    ...find.descendant(of: pill, matching: find.byType(Icon)).evaluate(),
  };
  for (final finder in [find.byType(Text), find.byType(Icon)]) {
    for (final element in finder.evaluate()) {
      if (own.contains(element)) continue;
      final r = tester.getRect(find.byElementPredicate((e) => e == element));
      expect(
        r.overlaps(box),
        isFalse,
        reason: '${element.widget} at $r is under the pill at $box',
      );
    }
  }
}
