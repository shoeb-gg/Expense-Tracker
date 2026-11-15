import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/home/pocket_button.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../../support/shots.dart';
import '../../support/test_db.dart';

/// Opens Home with a pocket called [name] in use, at [scale] text size.
Future<AppDatabase> openHomeIn(
  WidgetTester tester,
  String name, {
  double scale = 1.0,
}) async {
  final db = openTestDatabase();
  final id = (await tester.runAsync(
    () => PocketsRepo(db).add(name: name, emoji: '\u{1F9F3}'),
  ))!;
  await pumpApp(
    tester,
    db: db,
    settings: AppSettings(currentPocketId: id, textScale: scale),
  );
  return db;
}

/// Whether the pocket name on the button is cut with an ellipsis.
bool nameCut(WidgetTester tester, String name) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.byType(PocketButton),
      matching: find.text(name),
    ),
  );
  return paragraph.didExceedMaxLines;
}

void main() {
  // The real Plus Jakarta Sans: the default test font is far wider.
  setUpAll(loadShotFonts);

  group('Home pocket button at the largest text size', () {
    for (final name in ['Personal', 'Test trip', 'Family trip', 'Business']) {
      testWidgets('"$name" shows in full', (tester) async {
        final db = await openHomeIn(
          tester,
          name,
          scale: textScaleSteps.last,
        );
        expect(find.text(name), findsOneWidget);
        expect(nameCut(tester, name), isFalse);
        expect(tester.takeException(), isNull);
        await closeApp(tester, db);
      });

      testWidgets('"$name" shows in full at the default size too', (
        tester,
      ) async {
        final db = await openHomeIn(tester, name);
        expect(nameCut(tester, name), isFalse);
        await closeApp(tester, db);
      });
    }

    testWidgets('they still show in full on a narrow 320 px phone', (
      tester,
    ) async {
      for (final name in ['Personal', 'Test trip']) {
        final db = await openHomeIn(tester, name, scale: textScaleSteps.last);
        tester.view.physicalSize = const Size(640, 1560);
        await settle(tester);
        expect(nameCut(tester, name), isFalse, reason: name);
        await closeApp(tester, db);
      }
    });

    testWidgets('the button keeps its place and height', (tester) async {
      final db = await openHomeIn(tester, 'Test trip');
      final normal = tester.getRect(find.byType(PocketButton));
      await closeApp(tester, db);
      final big = await openHomeIn(
        tester,
        'Test trip',
        scale: textScaleSteps.last,
      );
      final large = tester.getRect(find.byType(PocketButton));
      expect(large.left, normal.left);
      expect(large.top, normal.top);
      expect(large.height, 40);
      await closeApp(tester, big);
    });

    testWidgets('a very long name is cut with an ellipsis, not clipped', (
      tester,
    ) async {
      const name = 'Weekend in the mountains with the cousins';
      final db = await openHomeIn(tester, name, scale: textScaleSteps.last);
      expect(nameCut(tester, name), isTrue);
      expect(tester.takeException(), isNull);
      // The button stays left of the two round buttons.
      final button = tester.getRect(find.byType(PocketButton));
      final eye = tester.getRect(find.bySemanticsLabel('Hide total'));
      expect(button.right, lessThanOrEqualTo(eye.left));
      await closeApp(tester, db);
    });
  });
}
