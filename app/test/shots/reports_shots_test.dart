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
    // "December 2025" and "11% more than November" do not fit side by
    // side, so the pill keeps the short form.
    expect(find.text('11% more'), findsOneWidget);
    expect(
      find.text('Dashed line = 2025 monthly average 49,729'),
      findsOneWidget,
    );
    await takeShot(tester, 'reports_2025');
    await tester.tap(find.text('June'));
    await settle(tester);
    expect(find.text('June 2025'), findsOneWidget);
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
    await takeShot(tester, 'reports_empty');
    await closeApp(tester, db);
  });
}
