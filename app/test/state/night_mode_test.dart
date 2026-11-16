import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/app.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/features/home/home_screen.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/shots.dart' show closeApp, pumpApp;
import '../support/test_db.dart';

/// A [NightModeBridge] that only writes down what it is told.
class RecordingNightMode implements NightModeBridge {
  final List<AppThemeMode> told = [];

  @override
  Future<void> apply(AppThemeMode mode) async => told.add(mode);
}

const MethodChannel _channel = MethodChannel(MethodChannelNightMode.channelName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the channel to MainActivity', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('sends setNightMode with dark, light or system', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return null;
          });
      for (final mode in AppThemeMode.values) {
        await const MethodChannelNightMode().apply(mode);
      }
      expect(calls.map((c) => c.method), everyElement('setNightMode'));
      expect(calls.map((c) => c.arguments), ['dark', 'light', 'system']);
    });

    test('the platform side is never needed: no handler, or an error', () async {
      // No handler (not Android): ignored.
      await const MethodChannelNightMode().apply(AppThemeMode.light);
      // The platform says no: ignored too.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            throw PlatformException(code: 'bad_mode');
          });
      await const MethodChannelNightMode().apply(AppThemeMode.dark);
    });
  });

  group('the app tells Android its choice', () {
    Future<(RecordingNightMode, AppDatabase)> open(
      WidgetTester tester,
      AppThemeMode mode,
    ) async {
      final fake = RecordingNightMode();
      final db = openTestDatabase();
      await pumpApp(
        tester,
        db: db,
        settings: AppSettings(themeMode: mode),
        overrides: [nightModeProvider.overrideWithValue(fake)],
      );
      return (fake, db);
    }

    for (final mode in AppThemeMode.values) {
      testWidgets('at start-up: the saved ${mode.name} choice', (tester) async {
        final (fake, db) = await open(tester, mode);
        expect(fake.told, [mode]);
        await closeApp(tester, db);
      });
    }

    testWidgets('and again at every change, once each, not on other settings', (
      tester,
    ) async {
      final (fake, db) = await open(tester, AppThemeMode.dark);
      expect(fake.told, [AppThemeMode.dark]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final settings = container.read(settingsProvider.notifier);

      await tester.runAsync(() => settings.setThemeMode(AppThemeMode.light));
      await tester.pumpAndSettle();
      expect(fake.told, [AppThemeMode.dark, AppThemeMode.light]);

      // Another setting is not a theme change.
      await tester.runAsync(() => settings.setMood(Mood.coral));
      await tester.runAsync(() => settings.setTextSizeIndex(3));
      await tester.pumpAndSettle();
      expect(fake.told, [AppThemeMode.dark, AppThemeMode.light]);

      await tester.runAsync(() => settings.setThemeMode(AppThemeMode.system));
      await tester.pumpAndSettle();
      await tester.runAsync(() => settings.setThemeMode(AppThemeMode.dark));
      await tester.pumpAndSettle();
      expect(fake.told, [
        AppThemeMode.dark,
        AppThemeMode.light,
        AppThemeMode.system,
        AppThemeMode.dark,
      ]);
      await closeApp(tester, db);
    });

    testWidgets('System still follows the phone (the app is not pinned)', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final (fake, db) = await open(tester, AppThemeMode.system);
      Brightness drawn() =>
          Theme.of(tester.element(find.byType(HomeScreen))).brightness;
      expect(fake.told, [AppThemeMode.system]);
      expect(drawn(), Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(drawn(), Brightness.light);
      expect(fake.told, [AppThemeMode.system], reason: 'nothing more to tell');
      await closeApp(tester, db);
    });
  });

  test('the start-up brightness is the choice, or the phone for System', () {
    for (final phone in Brightness.values) {
      expect(startBrightness(AppThemeMode.dark, phone), Brightness.dark);
      expect(startBrightness(AppThemeMode.light, phone), Brightness.light);
      expect(startBrightness(AppThemeMode.system, phone), phone);
    }
  });
}
