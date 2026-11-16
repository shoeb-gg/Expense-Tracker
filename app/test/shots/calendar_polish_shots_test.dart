@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/settings.dart';

import '../support/board.dart';
import '../support/shots.dart';

/// The calendar on the owner's phone (1080 x 2374 px at density 480, which is
/// 360 x 791 dp), five-week and six-week months, default and largest text.
/// Shots go to `build/shots/polish/`.
void main() {
  setUpAll(loadShotFonts);

  final months = <(String, int)>[
    ('oct', dayOf(2026, 10, 18)),
    ('aug', dayOf(2026, 8, 31)),
  ];
  final sizes = <(String, double)>[
    ('default', 1.0),
    ('largest', textScaleSteps.last),
  ];

  for (final (month, day) in months) {
    for (final (size, scale) in sizes) {
      testWidgets('calendar on a 360 x 791 phone: $month, $size text', (tester) async {
        final db = await sampleDatabase(tester);
        await pumpApp(
          tester,
          db: db,
          location: Routes.calendar(day: day),
          settings: AppSettings(textScale: scale),
        );
        await boardHeight(tester, 791);
        await takeShot(tester, 'polish/calendar_${month}_$size');
        await closeApp(tester, db);
      });
    }
  }
}
