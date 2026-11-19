/// App settings: immutable [AppSettings], persisted in the SettingsEntries
/// table, loaded before `runApp` so the first frame is right.
///
/// Read: `ref.watch(settingsProvider)`. Change:
/// `ref.read(settingsProvider.notifier).setMood(Mood.coral)`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/days.dart';
import '../core/format.dart';
import '../data/settings_store.dart';
import '../theme/tokens.dart';
import 'providers.dart';

/// Calculator keys on the Add expense keypad.
enum CalcKeys {
  /// "Plus and minus" (the default).
  plusMinus('Plus and minus'),

  /// "All four keys" (adds × and ÷; five-column keypad).
  allFour('All four keys');

  const CalcKeys(this.label);

  final String label;
}

/// Dark / Light / System (System follows the phone's own setting). Dark is
/// the default, so an existing install looks the same.
enum AppThemeMode {
  dark('Dark'),
  light('Light'),
  system('System');

  const AppThemeMode(this.label);

  final String label;
}

/// The five text size steps of the Settings slider (Smallest ... Largest).
/// The mockup previews them at 13, 14, 15, 17 and 19 px against 15 px.
const List<double> textScaleSteps = [13 / 15, 14 / 15, 1.0, 17 / 15, 19 / 15];

/// Names of [textScaleSteps].
const List<String> textScaleNames = [
  'Smallest', 'Small', 'Default', 'Large', 'Largest', //
];

/// A saved custom date range for Charts (inclusive day numbers).
typedef DayRangeValue = ({int from, int to});

@immutable
class AppSettings {
  const AppSettings({
    this.mood = Mood.aqua,
    this.themeMode = AppThemeMode.dark,
    this.textScale = 1.0,
    this.showMonthlyTotal = true,
    this.privacyMask = false,
    this.showCalendarButton = true,
    this.calendarAmounts = true,
    this.firstDayOfWeek = FirstDayOfWeek.sunday,
    this.numberStyle = NumberStyle.comma,
    this.showDecimals = true,
    this.calcKeys = CalcKeys.plusMinus,
    this.currentPocketId,
    this.lastCustomRange,
  });

  /// Colour theme (Aqua, Coral, Iris).
  final Mood mood;

  /// Dark / Light / System.
  final AppThemeMode themeMode;

  /// Text scale, one of [textScaleSteps]; applied app-wide.
  final double textScale;

  /// "Monthly total on Home": show the big number at the top of Home.
  final bool showMonthlyTotal;

  /// "Privacy hide": mask the Home total until the eye is tapped.
  final bool privacyMask;

  /// "Calendar button": shortcut to the calendar on Home.
  final bool showCalendarButton;

  /// "Amounts in calendar days": each day's total in its cell.
  final bool calendarAmounts;

  /// "First day of the week".
  final FirstDayOfWeek firstDayOfWeek;

  /// "Number format".
  final NumberStyle numberStyle;

  /// "Show decimals": off shows saved amounts rounded to whole units.
  final bool showDecimals;

  /// "Calculator keys".
  final CalcKeys calcKeys;

  /// The pocket in use (null: the default pocket). Use
  /// `currentPocketProvider`, which also handles deleted pockets.
  final int? currentPocketId;

  /// The last custom range used on Charts (null the first time: then the
  /// last 30 days).
  final DayRangeValue? lastCustomRange;

  /// Index of [textScale] in [textScaleSteps] (nearest step).
  int get textSizeIndex {
    var best = 0;
    for (var i = 1; i < textScaleSteps.length; i++) {
      if ((textScaleSteps[i] - textScale).abs() <
          (textScaleSteps[best] - textScale).abs()) {
        best = i;
      }
    }
    return best;
  }

  /// The amount formatter for [numberStyle] and [showDecimals].
  AmountFormat get amountFormat =>
      AmountFormat(style: numberStyle, showDecimals: showDecimals);

  AppSettings copyWith({
    Mood? mood,
    AppThemeMode? themeMode,
    double? textScale,
    bool? showMonthlyTotal,
    bool? privacyMask,
    bool? showCalendarButton,
    bool? calendarAmounts,
    FirstDayOfWeek? firstDayOfWeek,
    NumberStyle? numberStyle,
    bool? showDecimals,
    CalcKeys? calcKeys,
    ValueGetter<int?>? currentPocketId,
    ValueGetter<DayRangeValue?>? lastCustomRange,
  }) {
    return AppSettings(
      mood: mood ?? this.mood,
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      showMonthlyTotal: showMonthlyTotal ?? this.showMonthlyTotal,
      privacyMask: privacyMask ?? this.privacyMask,
      showCalendarButton: showCalendarButton ?? this.showCalendarButton,
      calendarAmounts: calendarAmounts ?? this.calendarAmounts,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      numberStyle: numberStyle ?? this.numberStyle,
      showDecimals: showDecimals ?? this.showDecimals,
      calcKeys: calcKeys ?? this.calcKeys,
      currentPocketId:
          currentPocketId != null ? currentPocketId() : this.currentPocketId,
      lastCustomRange:
          lastCustomRange != null ? lastCustomRange() : this.lastCustomRange,
    );
  }

  // Keys in the SettingsEntries table.
  static const String kMood = 'mood';
  static const String kThemeMode = 'themeMode';
  static const String kTextScale = 'textScale';
  static const String kShowMonthlyTotal = 'showMonthlyTotal';
  static const String kPrivacyMask = 'privacyMask';
  static const String kShowCalendarButton = 'showCalendarButton';
  static const String kCalendarAmounts = 'calendarAmounts';
  static const String kFirstDayOfWeek = 'firstDayOfWeek';
  static const String kNumberStyle = 'numberStyle';
  static const String kShowDecimals = 'showDecimals';
  static const String kCalcKeys = 'calcKeys';
  static const String kCurrentPocketId = 'currentPocketId';
  static const String kLastCustomRange = 'lastCustomRange';

  /// The removed "Thousands separator" setting. Only read to migrate it:
  /// "false" became the no-grouping number style.
  static const String kLegacyThousandsSeparator = 'thousandsSeparator';

  /// Every setting as stored text (null values are left out).
  Map<String, String> toEntries() => {
        kMood: mood.name,
        kThemeMode: themeMode.name,
        kTextScale: textScale.toString(),
        kShowMonthlyTotal: showMonthlyTotal.toString(),
        kPrivacyMask: privacyMask.toString(),
        kShowCalendarButton: showCalendarButton.toString(),
        kCalendarAmounts: calendarAmounts.toString(),
        kFirstDayOfWeek: firstDayOfWeek.name,
        kNumberStyle: numberStyle.name,
        kShowDecimals: showDecimals.toString(),
        kCalcKeys: calcKeys.name,
        if (currentPocketId != null) kCurrentPocketId: '$currentPocketId',
        if (lastCustomRange != null)
          kLastCustomRange: '${lastCustomRange!.from}:${lastCustomRange!.to}',
      };

  /// Settings from stored text. Unknown or broken values fall back to the
  /// defaults. Settings saved by older versions are migrated: the removed
  /// "Thousands separator" switch set to off means [NumberStyle.plain], and
  /// the removed comma-decimal styles become their dot-decimal twins.
  factory AppSettings.fromEntries(Map<String, String> e) {
    const d = AppSettings();
    T pick<T extends Enum>(List<T> values, String key, T fallback) {
      final v = e[key];
      for (final x in values) {
        if (x.name == v) return x;
      }
      return fallback;
    }

    bool flag(String key, bool fallback) {
      final v = e[key];
      return v == null ? fallback : v == 'true';
    }

    NumberStyle style() {
      if (e[kLegacyThousandsSeparator] == 'false') return NumberStyle.plain;
      return switch (e[kNumberStyle]) {
        'dotComma' => NumberStyle.comma,
        'spaceComma' => NumberStyle.spaceDot,
        _ => pick(NumberStyle.values, kNumberStyle, d.numberStyle),
      };
    }

    DayRangeValue? range() {
      final parts = e[kLastCustomRange]?.split(':');
      if (parts == null || parts.length != 2) return null;
      final from = int.tryParse(parts[0]);
      final to = int.tryParse(parts[1]);
      return from == null || to == null ? null : (from: from, to: to);
    }

    return AppSettings(
      mood: pick(Mood.values, kMood, d.mood),
      themeMode: pick(AppThemeMode.values, kThemeMode, d.themeMode),
      textScale: double.tryParse(e[kTextScale] ?? '') ?? d.textScale,
      showMonthlyTotal: flag(kShowMonthlyTotal, d.showMonthlyTotal),
      privacyMask: flag(kPrivacyMask, d.privacyMask),
      showCalendarButton: flag(kShowCalendarButton, d.showCalendarButton),
      calendarAmounts: flag(kCalendarAmounts, d.calendarAmounts),
      firstDayOfWeek:
          pick(FirstDayOfWeek.values, kFirstDayOfWeek, d.firstDayOfWeek),
      numberStyle: style(),
      showDecimals: flag(kShowDecimals, d.showDecimals),
      calcKeys: pick(CalcKeys.values, kCalcKeys, d.calcKeys),
      currentPocketId: int.tryParse(e[kCurrentPocketId] ?? ''),
      lastCustomRange: range(),
    );
  }

  /// Loads the stored settings (before runApp). Migrated number styles are
  /// written back and the removed settings' keys are deleted, so a later
  /// choice in Settings is not overruled by an old key.
  static Future<AppSettings> load(SettingsStore store) async {
    final entries = await store.load();
    final settings = AppSettings.fromEntries(entries);
    final storedStyle = entries[kNumberStyle];
    final legacy = entries.containsKey(kLegacyThousandsSeparator);
    if (legacy || (storedStyle != null && storedStyle != settings.numberStyle.name)) {
      await store.write(kNumberStyle, settings.numberStyle.name);
    }
    if (legacy) await store.remove(kLegacyThousandsSeparator);
    return settings;
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings && mapEquals(other.toEntries(), toEntries());

  @override
  int get hashCode => Object.hashAllUnordered(
        toEntries().entries.map((x) => Object.hash(x.key, x.value)),
      );
}

/// The settings loaded before `runApp`. Overridden in main() and in tests.
final initialSettingsProvider =
    Provider<AppSettings>((ref) => const AppSettings());

/// The live settings. One setter per field; each writes through to the
/// database.
final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  SettingsStore get _store => ref.read(settingsStoreProvider);

  /// Reads every setting from the database again (after a restore).
  Future<void> reload() async {
    state = await AppSettings.load(_store);
  }

  Future<void> _save(AppSettings next, String key) async {
    state = next;
    final value = next.toEntries()[key];
    if (value == null) {
      await _store.remove(key);
    } else {
      await _store.write(key, value);
    }
  }

  Future<void> setMood(Mood v) =>
      _save(state.copyWith(mood: v), AppSettings.kMood);

  Future<void> setThemeMode(AppThemeMode v) =>
      _save(state.copyWith(themeMode: v), AppSettings.kThemeMode);

  Future<void> setTextScale(double v) =>
      _save(state.copyWith(textScale: v), AppSettings.kTextScale);

  /// Sets the text size by slider step (0-4).
  Future<void> setTextSizeIndex(int i) =>
      setTextScale(textScaleSteps[i.clamp(0, textScaleSteps.length - 1)]);

  Future<void> setShowMonthlyTotal(bool v) => _save(
        state.copyWith(showMonthlyTotal: v),
        AppSettings.kShowMonthlyTotal,
      );

  Future<void> setPrivacyMask(bool v) =>
      _save(state.copyWith(privacyMask: v), AppSettings.kPrivacyMask);

  Future<void> setShowCalendarButton(bool v) => _save(
        state.copyWith(showCalendarButton: v),
        AppSettings.kShowCalendarButton,
      );

  Future<void> setCalendarAmounts(bool v) =>
      _save(state.copyWith(calendarAmounts: v), AppSettings.kCalendarAmounts);

  Future<void> setFirstDayOfWeek(FirstDayOfWeek v) =>
      _save(state.copyWith(firstDayOfWeek: v), AppSettings.kFirstDayOfWeek);

  Future<void> setNumberStyle(NumberStyle v) =>
      _save(state.copyWith(numberStyle: v), AppSettings.kNumberStyle);

  Future<void> setShowDecimals(bool v) =>
      _save(state.copyWith(showDecimals: v), AppSettings.kShowDecimals);

  Future<void> setCalcKeys(CalcKeys v) =>
      _save(state.copyWith(calcKeys: v), AppSettings.kCalcKeys);

  Future<void> setCurrentPocketId(int? v) => _save(
        state.copyWith(currentPocketId: () => v),
        AppSettings.kCurrentPocketId,
      );

  Future<void> setLastCustomRange(DayRangeValue? v) => _save(
        state.copyWith(lastCustomRange: () => v),
        AppSettings.kLastCustomRange,
      );
}
