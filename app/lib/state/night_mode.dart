/// Tells Android which night mode this app is in, so the start-up (launch)
/// screen matches the app's own Dark / Light / System choice and not only the
/// phone's setting.
///
/// Android 12 (API 31) and later can keep a night mode per app
/// (`UiModeManager.setApplicationNightMode`): Dark is night, Light is day,
/// System follows the phone. The system keeps it between runs, so the next
/// cold start draws the right `values` or `values-night` launch background.
/// Below Android 12 nothing happens on the Kotlin side and the launch screen
/// keeps following the phone.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

/// Sends the app's theme choice to the platform. Tests fake it.
abstract interface class NightModeBridge {
  /// Tells the platform that the app is in [mode]. Never throws: a platform
  /// without the feature simply ignores it.
  Future<void> apply(AppThemeMode mode);
}

/// The [NightModeBridge] of the app: a method channel to `MainActivity`.
class MethodChannelNightMode implements NightModeBridge {
  const MethodChannelNightMode();

  /// Name of the channel `MainActivity` listens on.
  static const String channelName = 'app.spillthebills/night_mode';

  /// The one method of the channel.
  static const String method = 'setNightMode';

  static const MethodChannel _channel = MethodChannel(channelName);

  /// The argument sent for [mode]: `dark`, `light` or `system`
  /// (`MODE_NIGHT_YES`, `MODE_NIGHT_NO` and `MODE_NIGHT_AUTO` on Android).
  static String argumentFor(AppThemeMode mode) => mode.name;

  @override
  Future<void> apply(AppThemeMode mode) async {
    try {
      await _channel.invokeMethod<void>(method, argumentFor(mode));
    } on MissingPluginException {
      // Not Android (or a test without a handler): nothing to tell.
    } on PlatformException {
      // The launch screen then keeps following the phone.
    }
  }
}

/// The bridge the app uses. Overridden in tests with a fake.
final nightModeProvider = Provider<NightModeBridge>(
  (ref) => const MethodChannelNightMode(),
);
