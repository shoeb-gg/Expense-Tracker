import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

/// The app: dark theme in the chosen colour theme, the user's text size,
/// and the router.
class SpillTheBillsApp extends ConsumerWidget {
  const SpillTheBillsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(settingsProvider.select((s) => s.mood));
    final scale = ref.watch(settingsProvider.select((s) => s.textScale));
    final fallback = ref.watch(fontFallbackProvider);
    final router = ref.watch(routerProvider);
    final theme = buildAppTheme(mood, fontFamilyFallback: fallback);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsStyle(mood),
      child: MaterialApp.router(
        title: 'Spill the Bills',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: theme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
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
