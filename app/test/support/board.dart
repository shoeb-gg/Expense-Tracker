import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';

import 'shots.dart';

/// Makes the test phone as tall as a mockup board (360 x [height]) so a
/// long screen can be compared with the board in one picture.
Future<void> boardHeight(WidgetTester tester, double height) async {
  tester.view.physicalSize = Size(720, height * 2);
  await settle(tester);
}

/// Scrolls the screen's list until [finder] sits well inside the view (not
/// under the bottom bar), so it can be tapped.
Future<void> revealRow(WidgetTester tester, Finder finder) async {
  final list = find.byType(Scrollable).first;
  await tester.drag(list, const Offset(0, 4000));
  await settle(tester);
  await tester.scrollUntilVisible(finder, 200, scrollable: list);
  await settle(tester);
  final view = tester.getRect(list);
  final y = tester.getCenter(finder).dy;
  final aim = view.top + view.height * 0.4;
  if ((y - aim).abs() > 40) {
    await tester.drag(list, Offset(0, aim - y));
    await settle(tester);
  }
}

/// Settles until [finder] finds something (database work runs on real
/// time), at most [tries] rounds.
Future<void> settleUntil(
  WidgetTester tester,
  Finder finder, {
  int tries = 20,
}) async {
  for (var i = 0; i < tries && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await settle(tester);
  }
}

/// Lets database work finish: [rounds] short real-time waits with settles.
Future<void> settleFor(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await settle(tester);
  }
}

/// The two extra pockets of the "Pockets" mockup row.
Future<void> addMockupPockets(WidgetTester tester, AppDatabase db) async {
  await tester.runAsync(() async {
    final repo = PocketsRepo(db);
    await repo.add(name: 'Business', emoji: '\u{1F4BC}');
    await repo.add(name: 'Family trip', emoji: '\u{1F3D6}\u{FE0F}');
  });
}
