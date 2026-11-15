@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/shots.dart';

void main() {
  setUpAll(loadShotFonts);

  // Home's pocket button next to the eye and calendar buttons, at the
  // default and the largest text size, with short and long pocket names.
  for (final (:name, :scale, :pocket) in [
    (name: 'personal_default', scale: 1.0, pocket: 'Personal'),
    (name: 'personal_largest', scale: textScaleSteps.last, pocket: 'Personal'),
    (name: 'trip_largest', scale: textScaleSteps.last, pocket: 'Test trip'),
    (
      name: 'long_largest',
      scale: textScaleSteps.last,
      pocket: 'Weekend in the mountains with the cousins',
    ),
  ]) {
    testWidgets('Home pocket button: $name', (tester) async {
      final db = await sampleDatabase(tester);
      final id = (await tester.runAsync(
        () => PocketsRepo(db).add(name: pocket, emoji: '\u{1F9F3}'),
      ))!;
      await pumpApp(
        tester,
        db: db,
        settings: AppSettings(currentPocketId: id, textScale: scale),
      );
      await takeShot(tester, 'home_pocket_button_$name');
      await closeApp(tester, db);
    });
  }
}
