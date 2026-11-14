// The links between areas, tapped through the whole app on the mockup's
// sample data (today 18 Oct 2026).
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/add/add_screen.dart';
import 'package:spill_the_bills/features/calendar/calendar_screen.dart';
import 'package:spill_the_bills/features/categories/categories_screen.dart';
import 'package:spill_the_bills/features/charts/category_screen.dart';
import 'package:spill_the_bills/features/expense/details_screen.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/features/reports/reports_screen.dart';
import 'package:spill_the_bills/router.dart';

import '../support/add_support.dart';
import '../support/shots.dart';

String _location(WidgetTester tester) =>
    appContainer(tester).read(routerProvider).state.uri.toString();

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

/// The system back gesture.
Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
}

Future<int> _categoryId(WidgetTester tester, AppDatabase db, String name) async {
  final rows = await tester.runAsync(
    () => (db.select(db.categories)..where((c) => c.name.equals(name))).get(),
  );
  return rows!.single.id;
}

void main() {
  testWidgets('Home total opens Reports', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await _tap(
      tester,
      find.bySemanticsLabel('Spent in October: 34,555. See all-time spending'),
    );
    expect(_location(tester), Routes.reports);
    expect(find.byType(ReportsScreen), findsOneWidget);
    await _tap(tester, find.text('Home'));
    expect(_location(tester), Routes.home);
    await closeApp(tester, db);
  });

  testWidgets('Home calendar button → Calendar → "Add expense on" that day; '
      'saving shows its month on Home', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await _tap(tester, find.bySemanticsLabel('Calendar'));
    expect(_location(tester), Routes.calendar());
    expect(find.byType(CalendarScreen), findsOneWidget);

    // Finger left to right: the previous month, opened on its last day.
    await tester.dragFrom(const Offset(180, 300), const Offset(200, 0));
    await settle(tester);
    expect(find.text('September 2026'), findsOneWidget);
    final sep30 = dayOf(2026, 9, 30);
    await _tap(tester, find.text('Add expense on Sep 30'));
    expect(_location(tester), Routes.add(day: sep30));
    expect(tester.widget<AddScreen>(find.byType(AddScreen)).day, sep30);

    await _tap(tester, find.text('Gifts'));
    for (final k in ['5', '0', '0']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await settle(tester);
    await _tap(tester, find.text('Save'));
    expect(find.byType(AddScreen), findsNothing);
    expect(_location(tester), Routes.calendar());

    await _back(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Spent in September'), findsOneWidget);
    expect(find.text('45,720'), findsOneWidget); // 45,220 + 500
    await closeApp(tester, db);
  });

  testWidgets('Charts Details opens the category drill-down', (tester) async {
    final db = await sampleDatabase(tester);
    final health = await _categoryId(tester, db, 'Health');
    await pumpApp(tester, db: db);
    await _tap(tester, find.text('Charts'));
    expect(_location(tester), Routes.charts);
    await _tap(tester, find.text('Health'));
    await _tap(tester, find.text('Details'));
    expect(
      _location(tester),
      Routes.category(
        health,
        from: dayOf(2026, 10, 1),
        to: dayOf(2026, 10, 31),
      ),
    );
    expect(find.byType(CategoryScreen), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets("Add's Manage tile opens Categories", (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await _tap(tester, find.bySemanticsLabel('Add expense'));
    expect(find.byType(AddScreen), findsOneWidget);
    await _tap(tester, find.text('Manage'));
    expect(_location(tester), Routes.categories);
    expect(find.byType(CategoriesScreen), findsOneWidget);
    await _back(tester);
    expect(find.byType(AddScreen), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('a Home row → Details → Edit → back to Details → back Home', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    await _tap(tester, find.text('Doctor visit'));
    expect(_location(tester), Routes.expense(doctorVisitId));
    expect(find.byType(ExpenseDetailsScreen), findsOneWidget);

    await _tap(tester, find.text('Edit'));
    expect(_location(tester), Routes.editExpense(doctorVisitId));
    expect(find.byType(AddScreen), findsOneWidget);

    await _back(tester);
    expect(_location(tester), Routes.expense(doctorVisitId));
    expect(find.byType(ExpenseDetailsScreen), findsOneWidget);

    await _back(tester);
    expect(_location(tester), Routes.home);
    expect(find.text('Spent in October'), findsOneWidget);
    await closeApp(tester, db);
  });
}
