import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/app.dart';
import 'package:spill_the_bills/data/settings_store.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/app_theme.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/shots.dart' show closeApp, pumpApp;
import '../support/test_db.dart';

/// The brightness the app is drawn in, read from the Home screen's theme.
Brightness drawn(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(HomeScreen))).brightness;

AppColors tokensOf(WidgetTester tester) =>
    tester.element(find.byType(HomeScreen)).colors;

/// The system bar style the app has set over Home (the nearest region).
SystemUiOverlayStyle barsOf(WidgetTester tester) {
  final regions = find
      .ancestor(
        of: find.byType(HomeScreen),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      )
      .evaluate()
      .map((e) => e.widget as AnnotatedRegion<SystemUiOverlayStyle>);
  return regions.first.value;
}

void setPhoneBrightness(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

void main() {
  group('the theme mode setting', () {
    test('Dark is the default', () {
      expect(const AppSettings().themeMode, AppThemeMode.dark);
      expect(AppSettings.fromEntries(const {}).themeMode, AppThemeMode.dark);
    });

    test('is saved, reloaded and falls back to Dark when broken', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final container = ProviderContainer.test(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final notifier = container.read(settingsProvider.notifier);
      for (final mode in AppThemeMode.values) {
        await notifier.setThemeMode(mode);
        expect(container.read(settingsProvider).themeMode, mode);
        final loaded = await AppSettings.load(SettingsStore(db));
        expect(loaded.themeMode, mode, reason: mode.name);
      }
      expect(
        AppSettings.fromEntries({AppSettings.kThemeMode: 'sepia'}).themeMode,
        AppThemeMode.dark,
      );
    });

    test('maps to the Flutter theme modes', () {
      expect(themeModeOf(AppThemeMode.dark), ThemeMode.dark);
      expect(themeModeOf(AppThemeMode.light), ThemeMode.light);
      expect(themeModeOf(AppThemeMode.system), ThemeMode.system);
    });
  });

  group('the app theme', () {
    testWidgets('is dark by default, whatever the phone says', (tester) async {
      setPhoneBrightness(tester, Brightness.light);
      final db = openTestDatabase();
      await pumpApp(tester, db: db);
      expect(drawn(tester), Brightness.dark);
      expect(tokensOf(tester).bg, AppColors.of(Mood.aqua).bg);
      expect(tokensOf(tester).brightness, Brightness.dark);
      await closeApp(tester, db);
    });

    for (final mood in Mood.values) {
      testWidgets('Light is light in ${mood.label}, whatever the phone says', (
        tester,
      ) async {
        setPhoneBrightness(tester, Brightness.dark);
        final db = openTestDatabase();
        await pumpApp(
          tester,
          db: db,
          settings: AppSettings(mood: mood, themeMode: AppThemeMode.light),
        );
        expect(drawn(tester), Brightness.light);
        final c = tokensOf(tester);
        expect(c.brightness, Brightness.light);
        expect(c.mood, mood);
        expect(c.bg, AppColors.of(mood, brightness: Brightness.light).bg);
        expect(
          Theme.of(tester.element(find.byType(HomeScreen))).scaffoldBackgroundColor,
          c.bg,
        );
        await closeApp(tester, db);
      });
    }

    testWidgets('System follows the phone, both ways, also while open', (
      tester,
    ) async {
      setPhoneBrightness(tester, Brightness.light);
      final db = openTestDatabase();
      await pumpApp(
        tester,
        db: db,
        settings: const AppSettings(themeMode: AppThemeMode.system),
      );
      expect(drawn(tester), Brightness.light);
      expect(
        tokensOf(tester).bg,
        AppColors.of(Mood.aqua, brightness: Brightness.light).bg,
      );

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(drawn(tester), Brightness.dark);
      expect(tokensOf(tester).bg, AppColors.of(Mood.aqua).bg);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(drawn(tester), Brightness.light);
      await closeApp(tester, db);
    });

    testWidgets('changing the setting changes the theme at once', (
      tester,
    ) async {
      setPhoneBrightness(tester, Brightness.dark);
      final db = openTestDatabase();
      await pumpApp(tester, db: db);
      expect(drawn(tester), Brightness.dark);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await tester.runAsync(
        () => container
            .read(settingsProvider.notifier)
            .setThemeMode(AppThemeMode.light),
      );
      await tester.pumpAndSettle();
      expect(drawn(tester), Brightness.light);
      await closeApp(tester, db);
    });
  });

  group('the system bars', () {
    test('light icons on dark, dark icons on light', () {
      final dark = systemBarsStyle(Mood.aqua);
      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(dark.systemNavigationBarIconBrightness, Brightness.light);
      expect(dark.systemNavigationBarColor, AppColors.of(Mood.aqua).nav);
      for (final mood in Mood.values) {
        final light = systemBarsStyle(mood, brightness: Brightness.light);
        expect(light.statusBarIconBrightness, Brightness.dark);
        expect(light.systemNavigationBarIconBrightness, Brightness.dark);
        expect(light.statusBarBrightness, Brightness.light);
        expect(
          light.systemNavigationBarColor,
          AppColors.of(mood, brightness: Brightness.light).nav,
        );
      }
    });

    testWidgets('follow the theme the app is drawn in, System included', (
      tester,
    ) async {
      setPhoneBrightness(tester, Brightness.dark);
      final db = openTestDatabase();
      await pumpApp(
        tester,
        db: db,
        settings: const AppSettings(themeMode: AppThemeMode.system),
      );
      expect(barsOf(tester).statusBarIconBrightness, Brightness.light);
      expect(barsOf(tester).systemNavigationBarIconBrightness, Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(barsOf(tester).statusBarIconBrightness, Brightness.dark);
      expect(barsOf(tester).systemNavigationBarIconBrightness, Brightness.dark);
      expect(
        barsOf(tester).systemNavigationBarColor,
        AppColors.of(Mood.aqua, brightness: Brightness.light).nav,
      );
      await closeApp(tester, db);
    });
  });
}
