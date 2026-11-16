/// Review pictures of the Top days legend and the Over time chart of Charts
/// on a 360 x 791 dp phone, at the default and the largest text size, with
/// the mockup data and with a day of 1,234,567.89.
///
/// Nothing is written in a normal `flutter test` run: the tests are skipped
/// unless a folder is given, from the `app` folder:
///
/// ```
/// flutter test --dart-define=CHARTS_FIT_DIR=<folder> \
///   --dart-define=CHARTS_FIT_LABEL=before test/shots/charts_fit_shots_test.dart
/// ```
///
/// The label (default `after`) ends each file name, so two runs sit side by
/// side.
@Tags(['shots'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/board.dart';
import '../support/shots.dart';
import '../support/text_fit.dart';

/// The folder the pictures go to; empty skips the tests.
const String _outDir = String.fromEnvironment('CHARTS_FIT_DIR');

/// Ends each file name.
const String _label = String.fromEnvironment(
  'CHARTS_FIT_LABEL',
  defaultValue: 'after',
);

/// Writes the current frame to [_outDir]/[name]_[_label].png.
Future<void> _save(WidgetTester tester, String name) async {
  final file = await takeShot(tester, 'charts_fit/$name');
  final target = File(p.join(_outDir, '${name}_$_label.png'))
    ..createSync(recursive: true);
  file.copySync(target.path);
  file.deleteSync();
}

void main() {
  setUpAll(loadShotFonts);

  // Without CHARTS_FIT_DIR the tests are skipped and nothing is written.
  final skip = _outDir.isEmpty;

  final sizes = <(String, double)>[
    ('default', 1.0),
    ('largest', textScaleSteps.last),
  ];

  /// Opens Charts on [view] (and [tab] of it) on a phone [height] dp tall,
  /// and writes the picture.
  Future<void> shoot(
    WidgetTester tester,
    String name,
    Future<AppDatabase> Function(WidgetTester) open,
    double scale, {
    required String view,
    String tab = 'Month',
    double height = 791,
  }) async {
    final db = await open(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.charts,
      // Weeks start on Monday: this week is Oct 12 to 18.
      settings: AppSettings(
        textScale: scale,
        firstDayOfWeek: FirstDayOfWeek.monday,
      ),
    );
    await boardHeight(tester, height);
    await tester.tap(find.text(view));
    await settle(tester);
    if (tab != 'Month') {
      await tester.tap(find.text(tab));
      await settle(tester);
    }
    await _save(tester, name);
    await closeApp(tester, db);
  }

  for (final (size, scale) in sizes) {
    testWidgets('top days, mockup data, $size text', (tester) async {
      await shoot(
        tester,
        'topdays_mockup_$size',
        sampleDatabase,
        scale,
        view: 'Top days',
        // Tall enough for the whole legend.
        height: 1000,
      );
    }, skip: skip);

    testWidgets('top days, a big day, $size text', (tester) async {
      await shoot(
        tester,
        'topdays_big_$size',
        sampleWithBigTotal,
        scale,
        view: 'Top days',
        // Tall enough for the whole legend.
        height: 1000,
      );
    }, skip: skip);

    for (final tab in ['Month', 'Week', 'Year']) {
      testWidgets('over time, mockup data, $tab, $size text', (tester) async {
        await shoot(
          tester,
          'overtime_mockup_${tab.toLowerCase()}_$size',
          sampleDatabase,
          scale,
          view: 'Over time',
          tab: tab,
        );
      }, skip: skip);
    }

    // The peak near the left edge, near the right edge, in the middle.
    for (final (tab, day) in [('Month', 2), ('Week', 18), ('Year', 5)]) {
      testWidgets('over time, a big day, $tab, $size text', (tester) async {
        await shoot(
          tester,
          'overtime_big_${tab.toLowerCase()}_$size',
          (tester) => sampleWithBigDay(tester, day: day),
          scale,
          view: 'Over time',
          tab: tab,
        );
      }, skip: skip);
    }
  }
}
