/// Review pictures of Reports and the Charts summary card on a 360 x 791 dp
/// phone, at the default and the largest text size, with the mockup data and
/// with big figures (1,234,567 spent, "100% more").
///
/// Nothing is written in a normal `flutter test` run: the tests are skipped
/// unless a folder is given, from the `app` folder:
///
/// ```
/// flutter test --dart-define=REPORTS_FIT_DIR=<folder> \
///   --dart-define=REPORTS_FIT_LABEL=before test/shots/reports_fit_shots_test.dart
/// ```
///
/// The label (default `after`) ends each file name, so two runs sit side by
/// side.
@Tags(['shots'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/board.dart';
import '../support/shots.dart';
import '../support/text_fit.dart';

/// The folder the pictures go to; empty skips the tests.
const String _outDir = String.fromEnvironment('REPORTS_FIT_DIR');

/// Ends each file name.
const String _label = String.fromEnvironment(
  'REPORTS_FIT_LABEL',
  defaultValue: 'after',
);

/// Writes the current frame to [_outDir]/[name]_[_label].png.
Future<void> _save(WidgetTester tester, String name) async {
  final file = await takeShot(tester, 'reports_fit/$name');
  final target = File(p.join(_outDir, '${name}_$_label.png'))
    ..createSync(recursive: true);
  file.copySync(target.path);
  file.deleteSync();
}

void main() {
  setUpAll(loadShotFonts);

  // Without REPORTS_FIT_DIR the tests are skipped and nothing is written.
  final skip = _outDir.isEmpty;

  final sizes = <(String, double)>[
    ('default', 1.0),
    ('largest', textScaleSteps.last),
  ];
  final scenes = <(String, Future<AppDatabase> Function(WidgetTester))>[
    ('mockup', sampleDatabase),
    (
      'big',
      (tester) => bigSpendDatabase(
        tester,
        spent: 1234567,
        spentCents: 89,
        before: 617284,
        monthly: 1234567,
      ),
    ),
  ];

  for (final (scene, open) in scenes) {
    for (final (size, scale) in sizes) {
      testWidgets('reports, $scene data, $size text', (tester) async {
        final db = await open(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.reports,
          settings: AppSettings(textScale: scale),
        );
        // The phone, then the whole page on a tall board.
        await boardHeight(tester, 791);
        await _save(tester, 'reports_${scene}_$size');
        await boardHeight(tester, 2200);
        await _save(tester, 'reports_${scene}_${size}_tall');
        await closeApp(tester, db);
      }, skip: skip);

      testWidgets('charts, $scene data, $size text', (tester) async {
        final db = await open(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.charts,
          settings: AppSettings(textScale: scale),
        );
        await boardHeight(tester, 791);
        await _save(tester, 'charts_${scene}_$size');
        if (scene == 'mockup') {
          await tester.tap(find.text('Year'));
          await settle(tester);
          await _save(tester, 'charts_${scene}_year_$size');
        }
        await closeApp(tester, db);
      }, skip: skip);
    }
  }
}
