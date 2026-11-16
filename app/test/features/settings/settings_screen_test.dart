import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/data/settings_store.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/features/home/home_state.dart';
import 'package:spill_the_bills/features/settings/settings_parts.dart';
import 'package:spill_the_bills/features/settings/settings_screen.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/test_db.dart';

AppSettings settingsOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(SettingsScreen)),
).read(settingsProvider);

Future<Map<String, String>> stored(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => SettingsStore(db).load()))!;

Future<AppDatabase> openSettings(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
}) async {
  final db = openTestDatabase();
  await pumpApp(tester, db: db, location: Routes.settings, settings: settings);
  return db;
}

Future<void> tapRow(WidgetTester tester, String text) async {
  await revealRow(tester, find.text(text));
  await tester.tap(find.text(text));
  await settle(tester);
}

void main() {
  /// The rows of the open Number format sheet, top to bottom.
  List<OptionRow> sheetRows(WidgetTester tester) =>
      tester.widgetList<OptionRow>(find.byType(OptionRow)).toList();

  testWidgets('the Number format sheet has four rows, the current one ticked', (
    tester,
  ) async {
    final db = await openSettings(tester);
    await tapRow(tester, 'Number format');
    expect(find.text('Number format'), findsNWidgets(2), reason: 'row + title');
    expect(
      find.text('How amounts are written across the app.'),
      findsOneWidget,
    );
    final rows = sheetRows(tester);
    expect([for (final r in rows) r.label], [
      '1,234,567.89',
      '1\u00A0234\u00A0567.89',
      '12,34,567.89',
      '1234567.89',
    ]);
    expect([for (final r in rows) r.note ?? ''], ['', '', 'Lakh, crore', '']);
    expect([for (final r in rows) r.selected], [true, false, false, false]);
    expect(find.text('Lakh, crore'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the ticked row follows the saved style', (tester) async {
    for (final style in NumberStyle.values) {
      final db = await openSettings(
        tester,
        settings: AppSettings(numberStyle: style),
      );
      await tapRow(tester, 'Number format');
      expect([for (final r in sheetRows(tester)) r.selected], [
        for (final s in NumberStyle.values) s == style,
      ], reason: style.name);
      await closeApp(tester, db);
    }
  });

  testWidgets('the Number format sheet picks a style and saves it', (
    tester,
  ) async {
    final db = await openSettings(tester);
    await tapRow(tester, 'Number format');
    await tester.tap(find.text('1234567.89'));
    await settle(tester);
    expect(settingsOf(tester).numberStyle, NumberStyle.plain);
    expect(find.text('1234567.89'), findsOneWidget, reason: 'row value');
    expect((await stored(tester, db))[AppSettings.kNumberStyle], 'plain');
    await closeApp(tester, db);
  });

  testWidgets('first day of the week, calculator keys and switches', (
    tester,
  ) async {
    final db = await openSettings(tester);
    await tapRow(tester, 'First day of the week');
    await tester.tap(find.text('Monday'));
    await settle(tester);
    expect(settingsOf(tester).firstDayOfWeek, FirstDayOfWeek.monday);
    expect(find.text('Monday'), findsOneWidget);

    await tapRow(tester, 'Calculator keys');
    await tester.tap(find.text('All four keys'));
    await settle(tester);
    expect(settingsOf(tester).calcKeys, CalcKeys.allFour);
    expect(find.text('All four keys'), findsOneWidget);

    await tapRow(tester, 'Privacy hide');
    expect(settingsOf(tester).privacyMask, isTrue);
    final saved = await stored(tester, db);
    expect(saved[AppSettings.kFirstDayOfWeek], 'monday');
    expect(saved[AppSettings.kCalcKeys], 'allFour');
    expect(saved[AppSettings.kPrivacyMask], 'true');
    await closeApp(tester, db);
  });

  testWidgets('colour theme and text size apply at once', (tester) async {
    final db = await openSettings(tester);
    await tester.tap(find.bySemanticsLabel('Coral'));
    await settle(tester);
    expect(settingsOf(tester).mood, Mood.coral);
    expect(
      tester.element(find.byType(SettingsScreen)).colors.bg,
      AppColors.of(Mood.coral).bg,
    );

    final slider = find.descendant(
      of: find.byType(TextSizeSlider),
      matching: find.byType(GestureDetector),
    );
    final box = tester.getRect(slider);
    await tester.tapAt(Offset(box.right - 4, box.center.dy));
    await settle(tester);
    expect(settingsOf(tester).textSizeIndex, 4);
    expect(find.text('Largest'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the Theme row offers Dark, Light and System; Dark is chosen', (
    tester,
  ) async {
    final db = await openSettings(tester);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Color theme'), findsOneWidget, reason: 'mood stays');
    expect(find.text('Text size'), findsOneWidget);
    for (final label in ['Dark', 'Light', 'System']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(AppSegmented<AppThemeMode>), findsOneWidget);
    expect(
      tester
          .widget<AppSegmented<AppThemeMode>>(
            find.byType(AppSegmented<AppThemeMode>),
          )
          .value,
      AppThemeMode.dark,
      reason: 'the default stays Dark',
    );
    expect(settingsOf(tester).themeMode, AppThemeMode.dark);
    await closeApp(tester, db);
  });

  testWidgets('Light, System and Dark switch the theme and are saved', (
    tester,
  ) async {
    // The phone is dark: System follows it.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final db = await openSettings(tester);
    Brightness shown() =>
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness;
    expect(shown(), Brightness.dark);

    await tester.tap(find.text('Light'));
    await settle(tester);
    expect(settingsOf(tester).themeMode, AppThemeMode.light);
    expect(shown(), Brightness.light);
    expect(
      tester.element(find.byType(SettingsScreen)).colors.bg,
      AppColors.of(Mood.aqua, brightness: Brightness.light).bg,
    );
    expect((await stored(tester, db))[AppSettings.kThemeMode], 'light');

    // System follows the (dark) phone.
    await tester.tap(find.text('System'));
    await settle(tester);
    expect(settingsOf(tester).themeMode, AppThemeMode.system);
    expect(shown(), Brightness.dark);
    expect((await stored(tester, db))[AppSettings.kThemeMode], 'system');

    await tester.tap(find.text('Dark'));
    await settle(tester);
    expect(settingsOf(tester).themeMode, AppThemeMode.dark);
    expect(shown(), Brightness.dark);
    expect((await stored(tester, db))[AppSettings.kThemeMode], 'dark');
    await closeApp(tester, db);
  });

  for (final brightness in Brightness.values) {
    testWidgets('the colour theme tiles preview each mood in ${brightness.name}', (
      tester,
    ) async {
      final db = await openSettings(
        tester,
        settings: AppSettings(
          themeMode: brightness == Brightness.light
              ? AppThemeMode.light
              : AppThemeMode.dark,
        ),
      );
      final tiles = tester
          .widgetList<Pressable>(
            find.descendant(
              of: find.byType(MoodTiles),
              matching: find.byType(Pressable),
            ),
          )
          .toList();
      expect(tiles, hasLength(Mood.values.length));
      for (var i = 0; i < Mood.values.length; i++) {
        expect(
          tiles[i].color,
          AppColors.of(Mood.values[i], brightness: brightness).surface2,
        );
      }
      await closeApp(tester, db);
    });
  }

  testWidgets('delete all data needs the tick, then starts again', (
    tester,
  ) async {
    final db = openTestDatabase();
    await tester.runAsync(() async {
      final pockets = PocketsRepo(db);
      final personal = (await pockets.defaultPocket()).id;
      await pockets.add(name: 'Business', emoji: '\u{1F4BC}');
      await ExpensesRepo(db).add(
        pocketId: personal,
        categoryId: 1,
        amount: 500,
        day: dayOf(2026, 10, 18),
      );
    });
    await pumpApp(tester, db: db, location: Routes.settings);
    await tapRow(tester, 'Delete all data');
    await tester.tap(find.text('Delete all'));
    await settle(tester);
    expect(
      find.byType(AppDialog),
      findsOneWidget,
      reason: 'locked until ticked',
    );
    await tester.tap(find.text('Yes, erase everything'));
    await settle(tester);
    await tester.tap(find.text('Delete all'));
    await settle(tester);
    expect(find.byType(AppDialog), findsNothing);
    await settleUntil(tester, find.text('Everything was erased'));
    expect(find.text('Everything was erased'), findsOneWidget);
    // Like the board, the app goes Home: one empty pocket, this month.
    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('Spent in October'), findsOneWidget);
    expect(find.text('Nothing in Personal yet'), findsOneWidget);
    final left = await tester.runAsync(() => PocketsRepo(db).all());
    expect(left!.single.isDefault, isTrue);
    final count = await tester.runAsync(
      () => ExpensesRepo(db).count(left.single.id),
    );
    expect(count, 0);
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester, db);
  });

  testWidgets('delete all from a Home that was showing another month', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db);
    // Home is built and showing March 2026; then the Settings tab.
    ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    ).read(homeMonthProvider.notifier).show((year: 2026, month: 3));
    await settle(tester);
    expect(find.text('Spent in March'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    await tapRow(tester, 'Delete all data');
    await tester.tap(find.text('Yes, erase everything'));
    await settle(tester);
    await tester.tap(find.text('Delete all'));
    await settleUntil(tester, find.text('Everything was erased'));
    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Spent in October'), findsOneWidget);
    expect(find.text('Nothing in Personal yet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester, db);
  });

  testWidgets('delete all: the warning names the pockets it erases', (
    tester,
  ) async {
    final db = await openSettings(tester);
    await tapRow(tester, 'Delete all data');
    expect(find.text('Delete all data?'), findsOneWidget);
    expect(
      find.text('All pockets, expenses, categories and photos'),
      findsOneWidget,
    );
    expect(
      find.text(
        'The app starts fresh with Personal and the default categories. '
        "This can't be undone.",
      ),
      findsOneWidget,
    );
    expect(find.text('All expenses, categories and photos'), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('delete all: "Save a copy first" opens Export', (tester) async {
    final db = await openSettings(tester);
    await tapRow(tester, 'Delete all data');
    await tester.tap(find.text('Save a copy first'));
    await settle(tester);
    expect(find.byType(AppDialog), findsNothing);
    expect(find.text('Which expenses'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('clear cache says how much was freed', (tester) async {
    final db = await openSettings(tester);
    await tapRow(tester, 'Clear cache');
    await settleUntil(
      tester,
      find.textContaining(RegExp(r'freed|Nothing to clear')),
    );
    expect(
      find.textContaining(RegExp(r'freed|Nothing to clear')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester, db);
  });
}
