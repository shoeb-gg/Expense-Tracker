@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/board.dart';
import '../support/shots.dart';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('reports (board Reports)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.reports);
    await boardHeight(tester, 1474);
    expect(find.text('2% more'), findsOneWidget);
    expect(find.text('vs Sep 1–18'), findsOneWidget);
    expect(
      find.text('Dashed line = 2026 monthly average 51,006'),
      findsOneWidget,
    );
    expect(find.text('1,090,360'), findsOneWidget);
    expect(find.text('50,276'), findsOneWidget);
    await takeShot(tester, 'reports_default');
    await closeApp(tester, db);
  });

  testWidgets('reports: 2025 with December selected, then June', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.reports);
    await boardHeight(tester, 1580);
    await tester.tap(find.text('2025'));
    await settle(tester);
    // Like the board: the pill keeps its full copy and "December 2025"
    // wraps to two lines beside it.
    expect(find.text('11% more than November'), findsOneWidget);
    expect(tester.getSize(find.text('December 2025')).height, 32);
    // The amount (also in Month by month, further down) stays on one line.
    expect(tester.getSize(find.text('54,085').first).height, 28);
    expect(
      find.text('Dashed line = 2025 monthly average 49,729'),
      findsOneWidget,
    );
    await takeShot(tester, 'reports_2025');
    await tester.tap(find.text('June'));
    await settle(tester);
    expect(find.text('June 2025'), findsOneWidget);
    expect(tester.getSize(find.text('June 2025')).height, 16);
    expect(find.text('1% more than May'), findsOneWidget);
    await takeShot(tester, 'reports_2025_june');
    await closeApp(tester, db);
  });

  testWidgets('reports: an empty pocket, Iris', (tester) async {
    final db = await sampleDatabase(tester);
    await addMockupPockets(tester, db);
    await pumpApp(
      tester,
      db: db,
      location: Routes.reports,
      settings: const AppSettings(mood: Mood.iris, currentPocketId: 2),
    );
    await boardHeight(tester, 1100);
    expect(find.text('Nothing spent yet'), findsOneWidget);
    // The year chart keeps the placeholder scale of Charts' empty
    // "Over time" chart instead of a lone "0".
    for (final tick in ['250', '500', '750', '1,000']) {
      expect(find.text(tick), findsOneWidget);
    }
    // Month by month says why it has no rows instead of bare headings.
    // (Charts' empty column chart says "Each month you spend in gets a
    // column.")
    expect(find.text('Each month you spend in gets a row.'), findsOneWidget);
    expect(find.text('vs previous'), findsNothing);
    await takeShot(tester, 'reports_empty');
    await closeApp(tester, db);
  });
}
