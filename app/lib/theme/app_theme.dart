/// The dark ThemeData built from the colour tokens of a mood.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text.dart';
import 'tokens.dart';

/// Builds the app theme for [mood]. [fontFamilyFallback] is empty in the app
/// (the phone draws emojis with its own font); screenshot tests pass the name
/// of the emoji font they load.
ThemeData buildAppTheme(
  Mood mood, {
  List<String> fontFamilyFallback = const [],
}) {
  final c = AppColors.of(mood);
  final scheme = ColorScheme.dark(
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    surface: c.surface,
    onSurface: c.text,
    surfaceContainerHighest: c.surface2,
    error: c.bad,
    onError: c.onBad,
    outline: c.line,
    outlineVariant: c.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    fontFamilyFallback: fontFamilyFallback.isEmpty ? null : fontFamilyFallback,
  );
  // Letter spacing 0 everywhere, like the mockup's CSS (Material's text
  // theme adds 0.1 - 0.5 px per letter otherwise).
  final textTheme = base.textTheme
      .apply(bodyColor: c.text, displayColor: c.text, fontFamily: kFontFamily)
      .merge(
        TextTheme(
          displayLarge: const TextStyle(letterSpacing: 0),
          displayMedium: const TextStyle(letterSpacing: 0),
          displaySmall: const TextStyle(letterSpacing: 0),
          headlineLarge: const TextStyle(letterSpacing: 0),
          headlineMedium: const TextStyle(letterSpacing: 0),
          headlineSmall: const TextStyle(letterSpacing: 0),
          titleLarge: const TextStyle(letterSpacing: 0),
          titleMedium: const TextStyle(letterSpacing: 0),
          titleSmall: const TextStyle(letterSpacing: 0),
          bodyLarge: const TextStyle(letterSpacing: 0),
          bodyMedium: const TextStyle(letterSpacing: 0),
          bodySmall: const TextStyle(letterSpacing: 0),
          labelLarge: const TextStyle(letterSpacing: 0),
          labelMedium: const TextStyle(letterSpacing: 0),
          labelSmall: const TextStyle(letterSpacing: 0),
        ),
      );
  return base.copyWith(
    extensions: [c],
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.line,
    textTheme: textTheme.copyWith(
      bodyMedium: textTheme.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 20 / 15,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    ),
    // Subtle accent splash instead of the stock grey ripple.
    splashFactory: InkRipple.splashFactory,
    splashColor: c.accent.withValues(alpha: 0.12),
    highlightColor: c.accent.withValues(alpha: 0.06),
    hoverColor: Colors.transparent,
    focusColor: c.accent.withValues(alpha: 0.12),
    iconTheme: IconThemeData(
      color: c.text,
      size: 24,
      weight: 500,
      fill: 0,
      grade: 0,
      opticalSize: 24,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.35),
      selectionHandleColor: c.accent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.surface2),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// System bar colours: status bar over the page background, navigation bar
/// on the nav colour, light icons on both.
SystemUiOverlayStyle systemBarsStyle(Mood mood) {
  final c = AppColors.of(mood);
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: c.nav,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );
}
