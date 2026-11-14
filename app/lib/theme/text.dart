/// Text styles matching the mockup. Family Plus Jakarta Sans (500-800).
///
/// The styles carry no colour: text is `colors.text` by default (from the
/// theme). Add a colour with `.copyWith(color: c.text3)` or the helpers
/// below. Line heights are CSS line heights (`height` = lineHeight / size)
/// with even leading, so a 15/20 style is 20 px tall like in the mockup.
library;

import 'package:flutter/painting.dart';

/// Font family name declared in pubspec.yaml.
const String kFontFamily = 'PlusJakartaSans';

/// Family of the phone's colour emoji font (Android), asked for first by
/// [AppText.emoji] so the app font never draws an emoji: Plus Jakarta Sans
/// has a plain ▶ (U+25B6) that would win over the colour ▶️ of "Online
/// Subscriptions". When the name is not found, the phone's own fallback
/// (in screenshot tests the loaded emoji font) draws the emoji.
const String kEmojiFontFamily = 'Noto Color Emoji';

TextStyle _s(
  double size,
  double lineHeight,
  FontWeight weight, {
  double? letterSpacing,
  bool tabular = false,
}) =>
    TextStyle(
      fontFamily: kFontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      // CSS default is 0; never inherit Material's 0.25 from bodyMedium.
      letterSpacing: letterSpacing ?? 0,
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );

/// The app's text styles. Sizes are logical px (= CSS px on the 360 board).
abstract final class AppText {
  /// Tab screen title (Home, Charts, Reports, Settings): 21/28 w800 -0.3.
  static final TextStyle pageTitle =
      _s(21, 28, FontWeight.w800, letterSpacing: -0.3);

  /// Sub-screen header title, dialog and sheet titles: 17/24 w800 -0.2.
  static final TextStyle screenTitle =
      _s(17, 24, FontWeight.w800, letterSpacing: -0.2);

  /// Card band title: 15/20 w800.
  static final TextStyle cardTitle = _s(15, 20, FontWeight.w800);

  /// List row title: 15/20 w600.
  static final TextStyle rowTitle = _s(15, 20, FontWeight.w600);

  /// List row amount: 15/20 w700, tabular figures.
  static final TextStyle rowAmount =
      _s(15, 20, FontWeight.w700, tabular: true);

  /// Sub-line under a row title (colour text3): 12.5/16 w500.
  static final TextStyle sub = _s(12.5, 16, FontWeight.w500);

  /// Value on the right of a settings row (colour text3): 14/20 w500.
  static final TextStyle value = _s(14, 20, FontWeight.w500);

  /// Body line in dialogs and sheets (colour text2): 13.5/20 w500.
  static final TextStyle body = _s(13.5, 20, FontWeight.w500);

  /// Bold line in dialogs: 14/20 w700.
  static final TextStyle bodyStrong = _s(14, 20, FontWeight.w700);

  /// Medium label, e.g. "Save a copy first": 14/20 w600.
  static final TextStyle label = _s(14, 20, FontWeight.w600);

  /// Small label above a pop-up heading (colour text3): 12.5/16 w600.
  static final TextStyle overline = _s(12.5, 16, FontWeight.w600);

  /// Caption / hint (colour text3): 12/16 w500.
  static final TextStyle caption = _s(12, 16, FontWeight.w500);

  /// Pop-up heading ("Sun, Oct 12, 2026"): 20/28 w800 -0.3.
  static final TextStyle popHeading =
      _s(20, 28, FontWeight.w800, letterSpacing: -0.3);

  /// Big button label: 15/20 w800.
  static final TextStyle button = _s(15, 20, FontWeight.w800);

  /// Quiet button label (Cancel): 15/20 w700.
  static final TextStyle buttonQuiet = _s(15, 20, FontWeight.w700);

  /// Pill label (Cancel / Save in headers): 14/20 w700 (Save uses w800).
  static final TextStyle pill = _s(14, 20, FontWeight.w700);

  /// Segment label (40 px control): 13.5/20 w600 (selected w800).
  static final TextStyle segment = _s(13.5, 20, FontWeight.w600);

  /// Segment label (36 px control): 12.5/16 w600 (selected w800).
  static final TextStyle segmentSmall = _s(12.5, 16, FontWeight.w600);

  /// Bottom bar label: 11.5/14 w600 (selected w700).
  static final TextStyle navLabel = _s(11.5, 14, FontWeight.w600);

  /// Hero total on Home: 32/36 w800 -0.8, tabular figures.
  static final TextStyle heroNumber =
      _s(32, 36, FontWeight.w800, letterSpacing: -0.8, tabular: true);

  /// Keypad amount: 34/40 w800 -0.8, tabular figures.
  static final TextStyle keypadNumber =
      _s(34, 40, FontWeight.w800, letterSpacing: -0.8, tabular: true);

  /// Day card total (colour accent): 16/20 w800, tabular figures.
  static final TextStyle dayTotal =
      _s(16, 20, FontWeight.w800, tabular: true);

  /// Day card title: 15/20 w800.
  static final TextStyle dayTitle = _s(15, 20, FontWeight.w800);

  /// Date badge number: 17/20 w800, tabular figures.
  static final TextStyle badgeNumber =
      _s(17, 20, FontWeight.w800, tabular: true);

  /// Calendar / picker day number: 14.5/36 w600 (chosen or today w800).
  static final TextStyle pickerDay =
      _s(14.5, 36, FontWeight.w600, tabular: true);

  /// Picker tile label (months, years): 15/20 w600 (chosen w800), tabular.
  static final TextStyle pickerTile =
      _s(15, 20, FontWeight.w600, tabular: true);

  /// Weekday letters above a month grid (colour text3): 12/20 w700.
  static final TextStyle weekdayLetter = _s(12, 20, FontWeight.w700);

  /// Emoji on a 44 px tile: 22 px, line height 1, in the emoji font
  /// ([kEmojiFontFamily]).
  static const TextStyle emoji = TextStyle(
    fontFamily: kEmojiFontFamily,
    fontSize: 22,
    height: 1,
    letterSpacing: 0,
  );

  /// Any style with tabular figures.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
