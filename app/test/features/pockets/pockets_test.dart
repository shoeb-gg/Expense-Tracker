import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/features/data/export_screen.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/features/home/pocket_button.dart';
import 'package:spill_the_bills/features/pockets/pocket_emojis.dart';
import 'package:spill_the_bills/features/pockets/pocket_form_screen.dart';
import 'package:spill_the_bills/features/pockets/pockets_screen.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/pocket_samples.dart';
import '../../support/shots.dart';
import '../../support/text_cut.dart';

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(HomeScreen, skipOffstage: false)),
);

/// Opens the app on Home, then pushes [location] the way the app does.
Future<void> _open(
  WidgetTester tester,
  AppDatabase db,
  String location, {
  AppSettings settings = const AppSettings(),
}) async {
  await pumpApp(tester, db: db, settings: settings);
  unawaited(_container(tester).read(routerProvider).push<Object?>(location));
  await settle(tester);
}

Future<List<Pocket>> _pockets(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.select(db.pockets).get()))!;

Future<int> _expensesIn(
  WidgetTester tester,
  AppDatabase db,
  int pocketId,
) async => (await tester.runAsync(
  () =>
      (db.select(db.expenses)..where((e) => e.pocketId.equals(pocketId))).get(),
))!.length;

/// The dialog's action button ("Delete pocket"), as a PopupButtons child.
Finder _deletePocketButton() => find.descendant(
  of: find.byType(PopupButtons),
  matching: find.text('Delete pocket'),
);

void main() {
  group('emoji helpers', () {
    test('a new pocket starts with the first emoji nobody uses', () {
      expect(firstUnusedEmoji(['👛']), '💰');
      expect(firstUnusedEmoji(['👛', '💰', '🏠']), '🛒');
      expect(firstUnusedEmoji(const []), '👛');
      final all = [for (final g in pocketEmojiGroups) ...g.emojis];
      expect(firstUnusedEmoji(all), '👛');
    });

    test('four groups of six', () {
      expect(pocketEmojiGroups.map((g) => g.title), [
        'Everyday',
        'Work',
        'Trips and events',
        'Everything else',
      ]);
      expect(pocketEmojiGroups.every((g) => g.emojis.length == 6), isTrue);
    });

    test('lastEmoji keeps only an emoji typed last', () {
      expect(lastEmoji('🐱'), '🐱');
      expect(lastEmoji('ab🎈'), '🎈');
      expect(lastEmoji('👍🏽'), '👍🏽');
      expect(lastEmoji('🇮🇳'), '🇮🇳');
      expect(lastEmoji('❤️'), '❤️');
      expect(lastEmoji('a'), isNull);
      expect(lastEmoji('7'), isNull);
      expect(lastEmoji(''), isNull);
    });
  });

  group('Pockets list', () {
    testWidgets('lists every pocket with its count and the default lock', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await tester.runAsync(() => addMockupPockets(db));
      await _open(tester, db, Routes.pockets);
      expect(find.text('3 pockets'), findsOneWidget);
      expect(find.text('1,266 expenses'), findsOneWidget);
      expect(find.text('214 expenses'), findsOneWidget);
      expect(find.text('37 expenses'), findsOneWidget);
      expect(find.text('Can’t be deleted'), findsOneWidget);
      expect(find.text('In use'), findsOneWidget);
      expect(find.bySemanticsLabel('Delete Personal'), findsNothing);
      expect(
        find.bySemanticsLabel(
          'Personal is the default pocket and cannot be deleted',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Delete Business'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('one pocket reads "1 pocket"', (tester) async {
      final db = await sampleDatabase(tester);
      await _open(tester, db, Routes.pockets);
      expect(find.text('1 pocket'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('deleting a pocket asks, needs the tick, removes expenses', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await _open(tester, db, Routes.pockets);
      await tester.tap(find.bySemanticsLabel('Delete Business'));
      await settle(tester);
      expect(find.text('Also deletes 214 expenses and photos'), findsOneWidget);
      expect(find.text('This can’t be undone.'), findsOneWidget);
      expect(find.text('Save a copy first'), findsOneWidget);
      expect(find.text('Yes, delete 214 expenses'), findsOneWidget);

      // Locked until ticked.
      await tester.tap(_deletePocketButton());
      await settle(tester);
      expect(find.text('Yes, delete 214 expenses'), findsOneWidget);

      await tester.tap(find.text('Yes, delete 214 expenses'));
      await settle(tester);
      await tester.tap(_deletePocketButton());
      await settle(tester);
      expect(find.text('Business'), findsNothing);
      expect(find.text('2 pockets'), findsOneWidget);
      expect(await _expensesIn(tester, db, ids.business), 0);
      expect(await _expensesIn(tester, db, ids.trip), 37);
      await closeApp(tester, db);
    });

    testWidgets('"Save a copy first" exports that pocket and deletes nothing', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await _open(tester, db, Routes.pockets);
      await tester.tap(find.bySemanticsLabel('Delete Business'));
      await settle(tester);
      await tester.tap(find.text('Export'));
      await settle(tester);
      expect(
        _container(tester).read(routerProvider).state.uri.toString(),
        exportLocation(pocketId: ids.business),
      );
      expect(find.byType(ExportScreen), findsOneWidget);
      // The warning closed without deleting; Back returns to Pockets.
      expect(find.byType(AppDialog), findsNothing);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Business'), findsOneWidget);
      expect(await _expensesIn(tester, db, ids.business), 214);
      await closeApp(tester, db);
    });

    testWidgets('deleting a pocket also deletes its receipt photos', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await _open(tester, db, Routes.pockets);
      final store = _container(tester).read(photoStoreProvider);
      final photo = (await tester.runAsync(() async {
        final dir = await store.folder();
        final file = File('${dir.path}${Platform.pathSeparator}receipt.jpg');
        await file.writeAsBytes(const [1, 2, 3]);
        await ExpensesRepo(db).add(
          pocketId: ids.business,
          categoryId: 4,
          amount: 4500,
          day: dayOf(2026, 10, 18),
          photoPath: 'receipt.jpg',
        );
        return file;
      }))!;
      await settle(tester);
      expect(await tester.runAsync(photo.exists), isTrue);
      await tester.tap(find.bySemanticsLabel('Delete Business'));
      await settle(tester);
      await tester.tap(find.text('Yes, delete 215 expenses'));
      await settle(tester);
      await tester.tap(_deletePocketButton());
      await settle(tester);
      expect(await tester.runAsync(photo.exists), isFalse);
      expect(await _expensesIn(tester, db, ids.business), 0);
      await closeApp(tester, db);
    });

    testWidgets('Cancel keeps the pocket', (tester) async {
      final db = await sampleDatabase(tester);
      await tester.runAsync(() => addMockupPockets(db));
      await _open(tester, db, Routes.pockets);
      await tester.tap(find.bySemanticsLabel('Delete Family trip'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Family trip'), findsOneWidget);
      expect(find.text('3 pockets'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('an empty pocket is removed without a tick box', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await tester.runAsync(
        () => PocketsRepo(db).add(name: 'Savings', emoji: '💰'),
      );
      await _open(tester, db, Routes.pockets);
      await tester.tap(find.bySemanticsLabel('Delete Savings'));
      await settle(tester);
      expect(find.text('This pocket is empty.'), findsOneWidget);
      expect(find.text('It will simply be removed.'), findsOneWidget);
      expect(find.byType(TickBoxRow), findsNothing);
      expect(find.text('Save a copy first'), findsNothing);
      await tester.tap(_deletePocketButton());
      await settle(tester);
      expect(find.text('Savings'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('deleting the pocket in use moves to the default pocket', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await _open(
        tester,
        db,
        Routes.pockets,
        settings: AppSettings(currentPocketId: ids.trip),
      );
      final container = _container(tester);
      expect(container.read(currentPocketIdProvider), ids.trip);
      await tester.tap(find.bySemanticsLabel('Delete Family trip'));
      await settle(tester);
      await tester.tap(find.text('Yes, delete 37 expenses'));
      await settle(tester);
      await tester.tap(_deletePocketButton());
      await settle(tester);
      final personal = (await _pockets(
        tester,
        db,
      )).firstWhere((p) => p.isDefault);
      expect(container.read(currentPocketIdProvider), personal.id);
      expect(container.read(settingsProvider).currentPocketId, personal.id);
      await closeApp(tester, db);
    });

    testWidgets('the pencil opens Edit pocket', (tester) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await _open(tester, db, Routes.pockets);
      await tester.tap(find.bySemanticsLabel('Edit Business'));
      await settle(tester);
      final form = tester.widget<PocketFormScreen>(
        find.byType(PocketFormScreen),
      );
      expect(form.pocketId, ids.business);
      expect(find.text('Edit pocket'), findsOneWidget);
      await closeApp(tester, db);
    });
  });

  group('Add and Edit pocket', () {
    testWidgets('Add starts empty with an unused emoji and saves', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await _open(tester, db, Routes.newPocket);
      expect(find.text('Add pocket'), findsOneWidget);
      expect(
        find.text(
          'A new pocket starts empty. Your categories and settings are '
          'already in it.',
        ),
        findsOneWidget,
      );
      // Save is off while the name is empty.
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect((await _pockets(tester, db)).length, 1);

      await tester.enterText(find.byType(TextField).first, '  Holiday fund ');
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('🎉'));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Switch to 🎉 Holiday fund now?'), findsOneWidget);
      await tester.tap(find.text('Stay in Personal'));
      await settle(tester);
      final pockets = await _pockets(tester, db);
      expect(pockets.length, 2);
      expect(pockets.last.name, 'Holiday fund');
      expect(pockets.last.emoji, '🎉');
      await closeApp(tester, db);
    });

    testWidgets('Save asks whether to switch; the pocket is saved already', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await _open(tester, db, Routes.newPocket);
      await tester.enterText(find.byType(TextField).first, 'Savings');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Pocket added'), findsOneWidget);
      expect(find.text('Switch to 💰 Savings now?'), findsOneWidget);
      expect(find.text('Stay in Personal'), findsOneWidget);
      expect(find.text('Switch to Savings'), findsOneWidget);
      final pockets = await _pockets(tester, db);
      expect(pockets.last.name, 'Savings');
      expect(pockets.last.emoji, '💰');
      expect(
        _container(tester).read(currentPocketIdProvider),
        pockets.first.id,
        reason: 'nothing switches before the user chooses',
      );
      // The form waits behind the prompt.
      expect(find.byType(PocketFormScreen), findsOneWidget);
      await tester.tap(find.text('Stay in Personal'));
      await settle(tester);
      await closeApp(tester, db);
    });

    testWidgets('"Switch to" moves to the new pocket and says so', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await _open(tester, db, Routes.newPocket);
      await tester.enterText(find.byType(TextField).first, 'Savings');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      await tester.tap(find.text('Switch to Savings'));
      await settle(tester);
      final pockets = await _pockets(tester, db);
      expect(
        _container(tester).read(currentPocketIdProvider),
        pockets.last.id,
      );
      expect(
        _container(tester).read(settingsProvider).currentPocketId,
        pockets.last.id,
      );
      expect(find.byType(PocketFormScreen), findsNothing);
      expect(find.byType(AppDialog), findsNothing);
      expect(find.text('Switched to Savings'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Nothing in Savings yet'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await closeApp(tester, db);
    });

    testWidgets('"Stay in" keeps the pocket in use and leaves the form', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await _open(tester, db, Routes.newPocket);
      await tester.enterText(find.byType(TextField).first, 'Savings');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      await tester.tap(find.text('Stay in Personal'));
      await settle(tester);
      final pockets = await _pockets(tester, db);
      expect(pockets.length, 2);
      expect(
        _container(tester).read(currentPocketIdProvider),
        pockets.first.id,
      );
      expect(find.byType(PocketFormScreen), findsNothing);
      expect(find.byType(AppDialog), findsNothing);
      expect(find.textContaining('Switched to'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('the prompt names the pocket in use, not the first one', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await _open(
        tester,
        db,
        Routes.newPocket,
        settings: AppSettings(currentPocketId: ids.business),
      );
      await tester.enterText(find.byType(TextField).first, 'Savings');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Stay in Business'), findsOneWidget);
      await tester.tap(find.text('Stay in Business'));
      await settle(tester);
      expect(_container(tester).read(currentPocketIdProvider), ids.business);
      await closeApp(tester, db);
    });

    testWidgets('closing the prompt (outside tap or Back) counts as Stay', (
      tester,
    ) async {
      for (final byBack in [false, true]) {
        final db = await sampleDatabase(tester);
        await _open(tester, db, Routes.newPocket);
        await tester.enterText(find.byType(TextField).first, 'Savings');
        await settle(tester);
        await tester.tap(find.text('Save'));
        await settle(tester);
        expect(find.byType(AppDialog), findsOneWidget);
        if (byBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(const Offset(8, 8));
        }
        await settle(tester);
        final pockets = await _pockets(tester, db);
        expect(pockets.length, 2, reason: 'saved either way');
        expect(
          _container(tester).read(currentPocketIdProvider),
          pockets.first.id,
        );
        expect(find.byType(AppDialog), findsNothing);
        expect(find.byType(PocketFormScreen), findsNothing);
        expect(find.textContaining('Switched to'), findsNothing);
        await closeApp(tester, db);
      }
    });

    testWidgets('a name that is already taken saves nothing and asks nothing', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await _open(tester, db, Routes.newPocket);
      await tester.enterText(find.byType(TextField).first, 'Personal');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.byType(AppDialog), findsNothing);
      expect(find.byType(PocketFormScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await closeApp(tester, db);
    });

    testWidgets('Pockets, Add pocket: the same prompt; Switch stays on the list', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await _open(tester, db, Routes.pockets);
      await tester.tap(find.text('Add pocket'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Savings');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Pocket added'), findsOneWidget);
      await tester.tap(find.text('Switch to Savings'));
      await settle(tester);
      final pockets = await _pockets(tester, db);
      expect(
        _container(tester).read(currentPocketIdProvider),
        pockets.last.id,
      );
      expect(find.byType(PocketFormScreen), findsNothing);
      expect(find.byType(PocketsScreen), findsOneWidget);
      expect(find.text('Switched to Savings'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await closeApp(tester, db);
    });

    testWidgets('Home pocket menu, Add pocket: the same prompt', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      await pumpApp(tester, db: db);
      await tester.tap(find.byType(PocketButton));
      await settle(tester);
      await tester.tap(find.text('Add pocket'));
      await settle(tester);
      expect(find.byType(PocketFormScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Savings');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Pocket added'), findsOneWidget);
      await tester.tap(find.text('Switch to Savings'));
      await settle(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget, reason: 'pocket button');
      expect(find.text('Switched to Savings'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await closeApp(tester, db);
    });

    testWidgets('editing a pocket asks nothing', (tester) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await _open(tester, db, Routes.editPocket(ids.business));
      await tester.enterText(find.byType(TextField).first, 'Work');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.byType(AppDialog), findsNothing);
      expect(find.byType(PocketFormScreen), findsNothing);
      expect(find.textContaining('Switched to'), findsNothing);
      await closeApp(tester, db);
    });

    testWidgets('two pockets cannot share a name', (tester) async {
      final db = await sampleDatabase(tester);
      await _open(tester, db, Routes.newPocket);
      await tester.enterText(find.byType(TextField).first, 'personal');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(
        find.text('You already have a pocket called personal'),
        findsOneWidget,
      );
      expect(find.byType(PocketFormScreen), findsOneWidget);
      expect((await _pockets(tester, db)).length, 1);
      await tester.pump(const Duration(seconds: 5));
      await closeApp(tester, db);
    });

    testWidgets('Edit renames and changes the emoji', (tester) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await _open(tester, db, Routes.editPocket(ids.business));
      expect(find.text('Edit pocket'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Work');
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('🏢'));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final edited = (await _pockets(
        tester,
        db,
      )).firstWhere((p) => p.id == ids.business);
      expect(edited.name, 'Work');
      expect(edited.emoji, '🏢');
      await closeApp(tester, db);
    });

    testWidgets('Edit keeps its own name', (tester) async {
      final db = await sampleDatabase(tester);
      final ids = (await tester.runAsync(() => addMockupPockets(db)))!;
      await _open(tester, db, Routes.editPocket(ids.business));
      await tester.tap(find.bySemanticsLabel('💻'));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final edited = (await _pockets(
        tester,
        db,
      )).firstWhere((p) => p.id == ids.business);
      expect(edited.name, 'Business');
      expect(edited.emoji, '💻');
      await closeApp(tester, db);
    });

    testWidgets('the default pocket can be renamed', (tester) async {
      final db = await sampleDatabase(tester);
      final personal = (await _pockets(tester, db)).single;
      await _open(tester, db, Routes.editPocket(personal.id));
      await tester.enterText(find.byType(TextField).first, 'Me');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect((await _pockets(tester, db)).single.name, 'Me');
      await closeApp(tester, db);
    });

    testWidgets('an unknown pocket shows "Pocket not found"', (tester) async {
      final db = await sampleDatabase(tester);
      await _open(tester, db, Routes.editPocket(999));
      expect(find.byType(NotFoundCard), findsOneWidget);
      expect(find.text('Pocket not found'), findsOneWidget);
      expect(noteText('It may have been deleted.'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await closeApp(tester, db);
    });
  });
}
