import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/features/add/add_screen.dart';
import 'package:spill_the_bills/features/calendar/calendar_screen.dart';
import 'package:spill_the_bills/features/categories/categories_screen.dart';
import 'package:spill_the_bills/features/categories/category_form_screen.dart';
import 'package:spill_the_bills/features/charts/category_screen.dart';
import 'package:spill_the_bills/features/charts/charts_screen.dart';
import 'package:spill_the_bills/features/data/export_screen.dart';
import 'package:spill_the_bills/features/data/import_columns_screen.dart';
import 'package:spill_the_bills/features/data/import_review_screen.dart';
import 'package:spill_the_bills/features/data/import_screen.dart';
import 'package:spill_the_bills/features/expense/details_screen.dart';
import 'package:spill_the_bills/features/expense/photo_screen.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/features/pockets/pocket_form_screen.dart';
import 'package:spill_the_bills/features/pockets/pockets_screen.dart';
import 'package:spill_the_bills/features/reports/reports_screen.dart';
import 'package:spill_the_bills/features/settings/settings_screen.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../support/shots.dart' show closeApp, pumpApp;
import '../support/test_db.dart';

void main() {
  testWidgets('every route opens its screen above the shell', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    ).read(routerProvider);
    expect(find.byType(AppNavBar), findsOneWidget);

    Future<T> open<T extends Widget>(String location) async {
      unawaited(router.push<Object?>(location));
      await tester.pumpAndSettle();
      final w = tester.widget<T>(find.byType(T));
      // Sub-screens cover the shell: its bar is no longer hit-testable.
      expect(find.byType(AppNavBar).hitTestable(), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      return w;
    }

    expect((await open<AddScreen>(Routes.add())).day, isNull);
    expect((await open<AddScreen>(Routes.add(day: 20744))).day, 20744);
    final edit = await open<AddScreen>(Routes.editExpense(5));
    expect(edit.expenseId, 5);
    expect((await open<ExpenseDetailsScreen>(Routes.expense(5))).expenseId, 5);
    expect((await open<PhotoScreen>(Routes.expensePhoto(5))).expenseId, 5);
    expect((await open<CalendarScreen>(Routes.calendar())).day, isNull);
    expect((await open<CalendarScreen>(Routes.calendar(day: 20744))).day, 20744);
    final cat = await open<CategoryScreen>(
      Routes.category(3, from: dayOf(2026, 10, 1), to: dayOf(2026, 10, 18)),
    );
    expect((cat.categoryId, cat.from, cat.to), (3, 20727, 20744));
    await open<CategoriesScreen>(Routes.categories);
    expect((await open<CategoryFormScreen>(Routes.newCategory)).categoryId, isNull);
    expect((await open<CategoryFormScreen>(Routes.editCategory(4))).categoryId, 4);
    await open<PocketsScreen>(Routes.pockets);
    expect((await open<PocketFormScreen>(Routes.newPocket)).pocketId, isNull);
    expect((await open<PocketFormScreen>(Routes.editPocket(2))).pocketId, 2);
    await open<ExportScreen>(Routes.export);
    await open<ImportScreen>(Routes.importStart);
    await open<ImportColumnsScreen>(Routes.importColumns);
    await open<ImportReviewScreen>(Routes.importReview);
    expect(find.byType(HomeScreen), findsOneWidget);

    await closeApp(tester, db);
  });

  testWidgets('tabs switch in the shell; plus opens Add expense',
      (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db);
    await tester.tap(find.text('Charts'));
    await tester.pumpAndSettle();
    expect(find.byType(ChartsScreen), findsOneWidget);
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Add expense'));
    await tester.pumpAndSettle();
    expect(find.byType(AddScreen), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    final ctx = tester.element(find.byType(SettingsScreen));
    ctx.go(Routes.home);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the system back button closes a sub-screen', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db);
    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    await closeApp(tester, db);
  });

  backTests();
}

/// Counts the "leave the app" requests of the system back button: Back with
/// nothing left to close ends up in `SystemNavigator.pop`.
class _AppExits {
  _AppExits(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'SystemNavigator.pop') count++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  int count = 0;
}

/// A tab label in the bottom bar (the plus button covers the bar's centre,
/// so the bar itself is never "hit-testable" at its middle).
Finder _barTab(String label) => find.descendant(
  of: find.byType(AppNavBar),
  matching: find.text(label),
);

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void backTests() {
  group('system Back on the tabs', () {
    const tabs = {
      'Charts': ChartsScreen,
      'Reports': ReportsScreen,
      'Settings': SettingsScreen,
    };
    for (final MapEntry(key: label, value: type) in tabs.entries) {
      testWidgets('$label: Back goes to Home, not out of the app', (
        tester,
      ) async {
        final db = openTestDatabase();
        await pumpApp(tester, db: db);
        final exits = _AppExits(tester);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(type), findsOneWidget);

        await back(tester);
        expect(exits.count, 0, reason: 'the app stays open');
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(type).hitTestable(), findsNothing);
        final bar = tester.widget<AppNavBar>(find.byType(AppNavBar));
        expect(bar.currentIndex, 0);

        await back(tester);
        expect(exits.count, 1, reason: 'Back on Home leaves the app');
        await closeApp(tester, db);
      });
    }

    testWidgets('Back on Home leaves the app', (tester) async {
      final db = openTestDatabase();
      await pumpApp(tester, db: db);
      final exits = _AppExits(tester);
      await back(tester);
      expect(exits.count, 1);
      await closeApp(tester, db);
    });

    testWidgets('a screen pushed above a tab closes before the tab does', (
      tester,
    ) async {
      final db = openTestDatabase();
      await pumpApp(tester, db: db, location: Routes.settings);
      final exits = _AppExits(tester);
      final router = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(routerProvider);

      for (final path in [
        Routes.categories,
        Routes.pockets,
        Routes.export,
        Routes.calendar(),
        Routes.category(1),
        Routes.expense(1),
      ]) {
        unawaited(router.push<Object?>(path));
        await tester.pumpAndSettle();
        expect(_barTab('Charts').hitTestable(), findsNothing, reason: path);

        await back(tester);
        expect(find.byType(SettingsScreen), findsOneWidget, reason: path);
        expect(_barTab('Charts').hitTestable(), findsOneWidget, reason: path);
        expect(exits.count, 0, reason: path);
      }

      await back(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(exits.count, 0);
      await closeApp(tester, db);
    });

    testWidgets('Back from a sub-screen of Settings goes one step at a time', (
      tester,
    ) async {
      final db = openTestDatabase();
      await pumpApp(tester, db: db, location: Routes.settings);
      final exits = _AppExits(tester);
      final router = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(routerProvider);
      unawaited(router.push<Object?>(Routes.categories));
      await tester.pumpAndSettle();
      unawaited(router.push<Object?>(Routes.editCategory(2)));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormScreen), findsOneWidget);

      await back(tester);
      expect(find.byType(CategoriesScreen), findsOneWidget);
      await back(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await back(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(exits.count, 0);
      await closeApp(tester, db);
    });
  });
}
