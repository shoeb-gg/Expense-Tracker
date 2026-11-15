@Tags(['shots'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/pocket_samples.dart';
import '../support/shots.dart';

void main() {
  setUpAll(loadShotFonts);

  // PocketList board.
  testWidgets('Pockets, the list', (tester) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(() => addMockupPockets(db));
    await pumpApp(tester, db: db, location: Routes.pockets);
    await takeShot(tester, 'pockets_list');
    await closeApp(tester, db);
  });

  // PocketDelete board, then ticked, then the Family trip variant.
  testWidgets('Pockets, delete a pocket', (tester) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(() => addMockupPockets(db));
    await pumpApp(tester, db: db, location: Routes.pockets);
    await tester.tap(find.bySemanticsLabel('Delete Business'));
    await settle(tester);
    await takeShot(tester, 'pockets_delete');
    await tester.tap(find.text('Yes, delete 214 expenses'));
    await settle(tester);
    await takeShot(tester, 'pockets_delete_ticked');
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Delete Family trip'));
    await settle(tester);
    await takeShot(tester, 'pockets_delete_trip');
    await closeApp(tester, db);
  });

  // Not drawn (only in the board's code): deleting an empty pocket.
  testWidgets('Pockets, delete an empty pocket', (tester) async {
    final db = await sampleDatabase(tester);
    await tester.runAsync(
      () => PocketsRepo(db).add(name: 'Savings', emoji: '💰'),
    );
    await pumpApp(tester, db: db, location: Routes.pockets);
    await tester.tap(find.bySemanticsLabel('Delete Savings'));
    await settle(tester);
    await takeShot(tester, 'pockets_delete_empty');
    await closeApp(tester, db);
  });

  // Not drawn: only the default pocket.
  testWidgets('Pockets, one pocket', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.pockets);
    await takeShot(tester, 'pockets_single');
    await closeApp(tester, db);
  });

  // PocketEdit board.
  testWidgets('Pockets, edit Business', (tester) async {
    final db = await sampleDatabase(tester);
    final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
    await pumpApp(tester, db: db, location: Routes.editPocket(ids.business));
    await takeShot(tester, 'pockets_edit');
    await closeApp(tester, db);
  });

  // PocketAdd board, empty and then named.
  testWidgets('Pockets, add a pocket', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.newPocket);
    await takeShot(tester, 'pockets_add');
    await tester.enterText(find.byType(EditableText).first, 'Holiday fund');
    await tester.tap(find.bySemanticsLabel('🎉'));
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await takeShot(tester, 'pockets_add_named');
    await closeApp(tester, db);
  });

  // Not in the boards: the prompt after saving a new pocket, and the toast
  // after switching. Default size and the largest, with a long name.
  for (final (:name, :scale, :pocket, :from) in [
    (name: 'default', scale: 1.0, pocket: 'Holiday fund', from: Routes.home),
    (
      name: 'largest',
      scale: textScaleSteps.last,
      pocket: 'Test trip',
      from: Routes.home,
    ),
    (
      name: 'long_largest',
      scale: textScaleSteps.last,
      pocket: 'Weekend in the mountains with the cousins',
      from: Routes.pockets,
    ),
  ]) {
    testWidgets('Pockets, the prompt after adding ($name)', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: from,
        settings: AppSettings(textScale: scale),
      );
      unawaited(
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
            .read(routerProvider)
            .push<Object?>(Routes.newPocket),
      );
      await settle(tester);
      await tester.enterText(find.byType(EditableText).first, pocket);
      await tester.tap(find.bySemanticsLabel('🎉'));
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      await takeShot(tester, 'pockets_added_prompt_$name');
      await tester.tap(find.textContaining('Switch to ').last);
      await settle(tester);
      await takeShot(tester, 'pockets_added_switched_$name');
      await tester.pump(const Duration(seconds: 5));
      await closeApp(tester, db);
    });
  }

  // Not drawn: Edit pocket for a pocket that is gone.
  testWidgets('Pockets, pocket not found', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.editPocket(999));
    await takeShot(tester, 'pockets_not_found');
    await closeApp(tester, db);
  });
}
