import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/photo_store.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import 'receipt_photo.dart';
import 'shots.dart';

/// Id of the sample expense on TODAY (Health, "Doctor visit", 1,180).
const int doctorVisitId = 1266;

/// A temporary folder removed after the test.
Directory tempFolder(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// Lets photo files load and decode (real I/O), then settles.
Future<void> settleImages(WidgetTester tester) async {
  // Each file step (open, read, close) and the decode continue in the
  // test's zone, so alternate real time with pumps.
  for (var i = 0; i < 16; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
  }
  await settle(tester);
}

/// Adds the pockets of the mockup's Pockets row: Business and Family trip
/// (Personal is the default). Returns their ids.
Future<({int business, int trip})> addSamplePockets(WidgetTester tester, AppDatabase db) async {
  final ids = await tester.runAsync(() async {
    final repo = PocketsRepo(db);
    final business = await repo.add(name: 'Business', emoji: '\u{1F4BC}');
    final trip = await repo.add(name: 'Family trip', emoji: '\u{1F3D6}\u{FE0F}');
    return (business: business, trip: trip);
  });
  return ids!;
}

/// The app's provider container (after `pumpApp`).
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

/// The [PhotoStore] the app under test uses (a temp folder of `pumpApp`).
PhotoStore appPhotoStore(WidgetTester tester) => appContainer(tester).read(photoStoreProvider);

/// Opens [location] on top of what is showing, like `context.push`.
Future<void> pushRoute(WidgetTester tester, String location) async {
  unawaited(appContainer(tester).read(routerProvider).push<Object?>(location));
  await settle(tester);
}

/// Writes the receipt photo into the app's photo store and attaches it to
/// [expenseId]. Returns the stored file name.
Future<String> attachReceipt(
  WidgetTester tester,
  AppDatabase db, {
  int expenseId = doctorVisitId,
}) async {
  final store = appPhotoStore(tester);
  final temp = tempFolder('stb_receipt_');
  final name = await tester.runAsync(() async {
    final source = await writeReceiptPhoto(temp);
    final name = await store.savePicked(source.path);
    final repo = ExpensesRepo(db);
    final expense = await repo.get(expenseId);
    await repo.update(expense!.copyWith(photoPath: Value(name)));
    return name;
  });
  return name!;
}

/// Hides the keyboard (drops focus), as tapping Done would.
Future<void> hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester);
}

/// [closeApp], then lets file work started by the screens (photo loads,
/// clean-up of unsaved photos) finish, so the temp folders can be removed.
Future<void> closeAppWithFiles(WidgetTester tester, AppDatabase db) async {
  await closeApp(tester, db);
  // File work runs on real I/O but continues in the test's zone, so it
  // needs both real time and pumps to finish.
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
}
