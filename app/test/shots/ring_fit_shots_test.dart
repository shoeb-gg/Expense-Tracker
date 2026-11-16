/// Review pictures of the Charts ring centre on a 360 x 791 dp phone, at the
/// default and the largest text size: the mockup data, a big total
/// (1,234,567.89), and a tapped slice with the longest category name and a big
/// amount.
///
/// Nothing is written in a normal `flutter test` run: the tests are skipped
/// unless a folder is given, from the `app` folder:
///
/// ```
/// flutter test --dart-define=RING_FIT_DIR=<folder> \
///   --dart-define=RING_FIT_LABEL=before test/shots/ring_fit_shots_test.dart
/// ```
///
/// The label (default `after`) ends each file name, so two runs sit side by
/// side.
@Tags(['shots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/board.dart';
import '../support/shots.dart';
import '../support/text_fit.dart';

/// The folder the pictures go to; empty skips the tests.
const String _outDir = String.fromEnvironment('RING_FIT_DIR');

/// Ends each file name.
const String _label = String.fromEnvironment(
  'RING_FIT_LABEL',
  defaultValue: 'after',
);

/// Writes the current frame to [_outDir]/[name]_[_label].png.
Future<void> _save(WidgetTester tester, String name) async {
  final file = await takeShot(tester, 'ring_fit/$name');
  final target = File(p.join(_outDir, '${name}_$_label.png'))
    ..createSync(recursive: true);
  file.copySync(target.path);
  file.deleteSync();
}

void main() {
  setUpAll(loadShotFonts);

  // Without RING_FIT_DIR the tests are skipped and nothing is written.
  final skip = _outDir.isEmpty;

  final sizes = <(String, double)>[
    ('default', 1.0),
    ('largest', textScaleSteps.last),
  ];

  /// Opens Charts, then taps the row named [tap] if given.
  Future<void> shoot(
    WidgetTester tester,
    String name,
    Future<AppDatabase> Function(WidgetTester) open,
    AppSettings settings, {
    String? tap,
  }) async {
    final db = await open(tester);
    await pumpApp(tester, db: db, location: Routes.charts, settings: settings);
    await boardHeight(tester, 791);
    if (tap != null) {
      final row = find.text(tap);
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pump();
      await tester.tap(row);
      await settle(tester);
      // Back to the top, so the ring is in the picture.
      await Scrollable.ensureVisible(
        tester.element(find.text('Total spent')),
        alignment: 0,
      );
      await settle(tester);
    }
    await _save(tester, name);
    await closeApp(tester, db);
  }

  for (final (size, scale) in sizes) {
    final plain = AppSettings(textScale: scale);

    testWidgets('ring centre, mockup data, $size text', (tester) async {
      await shoot(tester, 'ring_mockup_$size', sampleDatabase, plain);
    }, skip: skip);

    testWidgets('ring centre, mockup data, Online Subscriptions tapped, $size '
        'text', (tester) async {
      await shoot(
        tester,
        'ring_mockup_online_$size',
        sampleDatabase,
        plain,
        tap: 'Online Subscriptions',
      );
    }, skip: skip);

    for (final name in ['Groceries', 'Health', 'Transportation']) {
      testWidgets('ring centre, mockup data, $name tapped, $size text', (
        tester,
      ) async {
        await shoot(
          tester,
          'ring_mockup_${name.toLowerCase()}_$size',
          sampleDatabase,
          plain,
          tap: name,
        );
      }, skip: skip);
    }

    testWidgets('ring centre, big total, $size text', (tester) async {
      await shoot(tester, 'ring_big_total_$size', sampleWithBigTotal, plain);
    }, skip: skip);

    testWidgets('ring centre, long name and big amount, $size text', (
      tester,
    ) async {
      await shoot(
        tester,
        'ring_long_name_$size',
        sampleWithBigCategory,
        plain,
        tap: longestCategoryName,
      );
    }, skip: skip);

    testWidgets('ring centre, 12,34,567.89 style, $size text', (tester) async {
      await shoot(
        tester,
        'ring_lakh_total_$size',
        sampleWithBigTotal,
        AppSettings(textScale: scale, numberStyle: NumberStyle.lakh),
      );
    }, skip: skip);
  }
}
