import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

/// The Flutter [ThemeMode] of a stored [AppThemeMode]. System follows the
/// phone's own dark or light setting.
ThemeMode themeModeOf(AppThemeMode mode) => switch (mode) {
  AppThemeMode.dark => ThemeMode.dark,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.system => ThemeMode.system,
};

/// The brightness the app starts in: its own choice, or the phone's
/// ([phone]) for System. Used for the system bars before the first frame.
Brightness startBrightness(AppThemeMode mode, Brightness phone) =>
    switch (mode) {
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.light => Brightness.light,
      AppThemeMode.system => phone,
    };

/// The app: the chosen colour theme in a dark and a light version (Dark,
/// Light, or System, which follows the phone), the user's text size, and
/// the router.
class SpillTheBillsApp extends ConsumerStatefulWidget {
  const SpillTheBillsApp({super.key});

  @override
  ConsumerState<SpillTheBillsApp> createState() => _SpillTheBillsAppState();
}

class _SpillTheBillsAppState extends ConsumerState<SpillTheBillsApp> {
  @override
  void initState() {
    super.initState();
    // Tell Android the app's choice at start-up, so the launch screen of the
    // next cold start matches it (changes are sent in build).
    unawaited(
      ref.read(nightModeProvider).apply(ref.read(settingsProvider).themeMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(settingsProvider.select((s) => s.mood));
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final scale = ref.watch(settingsProvider.select((s) => s.textScale));
    final fallback = ref.watch(fontFallbackProvider);
    final router = ref.watch(routerProvider);
    ref.listen(settingsProvider.select((s) => s.themeMode), (_, next) {
      unawaited(ref.read(nightModeProvider).apply(next));
    });
    return MaterialApp.router(
      title: 'Spill the Bills',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        mood,
        brightness: Brightness.light,
        fontFamilyFallback: fallback,
      ),
      darkTheme: buildAppTheme(
        mood,
        brightness: Brightness.dark,
        fontFamilyFallback: fallback,
      ),
      themeMode: themeModeOf(mode),
      routerConfig: router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        // The builder sits below the theme, so this is the brightness the
        // app is really drawn in (System has been resolved by now): the
        // status and navigation bar icons follow it.
        value: systemBarsStyle(
          mood,
          brightness: Theme.of(context).brightness,
        ),
        child: MediaQuery(
          // The app's own text size setting replaces the phone's scale: the
          // layouts are designed at fixed sizes for the five steps.
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
