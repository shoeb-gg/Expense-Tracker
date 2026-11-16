/// Review pictures of the pocket line under the title of Calendar, Charts and
/// Reports, with two pockets ("Personal" in use, and "Business"), on a
/// 360 x 791 dp phone: dark Aqua and light Iris at the default text size, and
/// dark Aqua at the largest. Two more show the back-to-now pill next to the
/// line at the largest size.
///
/// Nothing is written in a normal `flutter test` run: the tests are skipped
/// unless a folder is given, from the `app` folder:
///
/// ```
/// flutter test --dart-define=POCKET_SHOTS_DIR=<folder> test/shots/pocket_line_shots_test.dart
/// ```
@Tags(['shots'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/board.dart';
import '../support/shots.dart';

/// The folder the pictures go to; empty skips the tests.
const String _outDir = String.fromEnvironment('POCKET_SHOTS_DIR');

typedef _Look = ({String name, Mood mood, AppThemeMode mode, double scale});

final List<_Look> _looks = <_Look>[
  (name: 'dark_aqua', mood: Mood.aqua, mode: AppThemeMode.dark, scale: 1.0),
  (name: 'light_iris', mood: Mood.iris, mode: AppThemeMode.light, scale: 1.0),
  (
    name: 'dark_aqua_largest',
    mood: Mood.aqua,
    mode: AppThemeMode.dark,
    scale: textScaleSteps.last,
  ),
];

/// A screen's name and where it opens (Calendar and Charts on their current
/// period, so the back-to-now pill is hidden).
final List<(String, String)> _screens = <(String, String)>[
  ('calendar', Routes.calendar()),
  ('charts', Routes.charts),
  ('reports', Routes.reports),
];

/// Writes the current frame to [_outDir]/[name].png.
Future<void> _save(WidgetTester tester, String name) async {
  final file = await takeShot(tester, 'pocket_line/$name');
  final target = File(p.join(_outDir, '$name.png'))
    ..createSync(recursive: true);
  file.copySync(target.path);
  file.deleteSync();
}

Future<AppDatabase> _open(
  WidgetTester tester,
  String location, {
  required Mood mood,
  required AppThemeMode mode,
  required double scale,
}) async {
  final db = await sampleDatabase(tester);
  await tester.runAsync(
    () => PocketsRepo(db).add(name: 'Business', emoji: '\u{1F4BC}'),
  );
  await pumpApp(
    tester,
    db: db,
    location: location,
    settings: AppSettings(mood: mood, themeMode: mode, textScale: scale),
  );
  await boardHeight(tester, 791);
  return db;
}

void main() {
  setUpAll(loadShotFonts);

  // Without POCKET_SHOTS_DIR the tests are skipped and nothing is written.
  final skip = _outDir.isEmpty;

  for (final (screen, location) in _screens) {
    for (final look in _looks) {
      testWidgets('$screen, ${look.name}', (tester) async {
        final db = await _open(
          tester,
          location,
          mood: look.mood,
          mode: look.mode,
          scale: look.scale,
        );
        await _save(tester, '${screen}_${look.name}');
        await closeApp(tester, db);
      }, skip: skip);
    }
  }

  testWidgets('calendar with the Today pill, largest text', (tester) async {
    final db = await _open(
      tester,
      Routes.calendar(day: dayOf(2026, 9, 1)),
      mood: Mood.aqua,
      mode: AppThemeMode.dark,
      scale: textScaleSteps.last,
    );
    await _save(tester, 'calendar_dark_aqua_largest_pill');
    await closeApp(tester, db);
  }, skip: skip);

  testWidgets('charts with the This month pill, largest text', (tester) async {
    final db = await _open(
      tester,
      Routes.charts,
      mood: Mood.aqua,
      mode: AppThemeMode.dark,
      scale: textScaleSteps.last,
    );
    await tester.dragFrom(const Offset(30, 420), const Offset(300, 0));
    await settle(tester);
    await _save(tester, 'charts_dark_aqua_largest_pill');
    await closeApp(tester, db);
  }, skip: skip);
}
