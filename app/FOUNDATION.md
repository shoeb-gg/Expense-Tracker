# Spill the Bills: foundation guide for feature work

Read this before building a screen. Everything here is built, compiled and
tested. Scope: `../BUILD_LIST.md` (the "Design decisions" section wins).
Look: the mockup boards in `../design/mockup/project/*.dc.html` (sizes are
CSS px on a 360 px phone = Flutter logical px).

## Rules

- No `dynamic`, no untyped code. `flutter analyze` must stay at "No issues".
- Do NOT edit without reporting back: `lib/data/db.dart` (schema),
  `lib/router.dart`, anything in `lib/widgets/`, `lib/theme/`, `lib/core/`,
  `lib/state/`. Need a change? Say what and why.
- Feature-specific queries go in your feature's own files, using the
  database API (`ref.watch(databaseProvider)` + Drift), or a small repo class
  in your feature folder. Reuse the shared providers first.
- No new packages without saying so.
- No currency symbols anywhere. No scrollbars (use `ScrollConfiguration` /
  `scrollbars: false` if one appears).
- Your screen file replaces the placeholder at the path listed in
  "Routes"; keep the class name and constructor.

## Commands (run in `app/`)

| What | Command |
|---|---|
| All tests | `flutter test` |
| Only screenshots | `flutter test test/shots` (PNGs in `build/shots/`) |
| One file | `flutter test test/core/format_test.dart` |
| Analyzer | `flutter analyze` |
| Regenerate Drift code | `dart run build_runner build --delete-conflicting-outputs --force-jit` |
| Test SQLite DLL (once) | `powershell -ExecutionPolicy Bypass -File tool/get_sqlite_dll.ps1` |
| Debug APK | `flutter build apk --debug` |
| Release APK + icon check | `dart run tool/check_release_icons.dart` (builds `flutter build apk --release`, then checks it) |
| Regenerate the icon font | `dart run tool/icon_font.dart` (after editing `lib/theme/symbols.dart`) |

`--force-jit` is required: without it build_runner tries an AOT compile that
fails because some plugins (jni, objective_c) use build hooks.
The DLL goes to `test/native/sqlite3.dll` (git-ignored); without it tests use
Windows' own `winsqlite3.dll`. `test/flutter_test_config.dart` wires it up.

## Folder layout

```
lib/
  main.dart            opens DB, loads settings, ProviderScope, runApp
  app.dart             MaterialApp.router, theme, text scale, system bars
  router.dart          every route (Routes.*), shell with the bottom bar
  core/                pure Dart: days, format, calculator, type_to_add
  data/                db.dart (+ db.g.dart), repositories, PhotoStore, maintenance
  state/               providers.dart (all providers), settings.dart
  theme/               tokens.dart (AppColors), text.dart (AppText), app_theme.dart,
                       symbols.dart (Symbols: every icon the app uses)
  widgets/             shared UI kit; import 'widgets/kit.dart' for all of it
  features/<area>/     one file per screen (placeholders now)
test/
  core/ data/ app/ widgets/   unit and widget tests
  shots/               screenshot tests (tag: shots)
  support/             test_db.dart, sample_data.dart, shots.dart, sqlite.dart
  tool/                icon_font_test.dart (the icon font survives tree shaking)
tool/
  get_sqlite_dll.ps1
  icon_font.dart             regenerates assets/fonts/MaterialSymbolsRounded.ttf
  check_release_icons.dart   release build + icon check
  src/ttf.dart               font reading/checking shared by the two above
```

## Conventions

- **Day** = `int`, the local calendar date as days since 1970-01-01
  (`dayOf(2026, 10, 18) == 20744`). Months are **1-based** in Dart. Ranges
  are **inclusive** `from..to`. Never store `DateTime` for a date.
- **Amount** = `int` minor units (amount x 100). `12.50` is `1250`.
- **Today** = `ref.watch(todayProvider)` (never `DateTime.now()` in UI; tests
  pin the clock to 18 Oct 2026 10:18 with `Clock.fixed(mockupNow)`).
- Text colour defaults to `colors.text`. Letter spacing defaults to 0 (CSS).
- Icons: `Symbols.<name>_rounded` from `lib/theme/symbols.dart` (never import
  `package:material_symbols_icons` in lib/; see "Icon font" below).
  The theme sets weight 500, optical size 24, fill 0; pass `fill: 1` for a
  filled icon. Icon size = the mockup's `font-size`.
- Emojis are plain `Text` (`AppText.emoji`), drawn by the phone's font.
- Every screen: `Scaffold(backgroundColor: c.bg, body: SafeArea(bottom: false, child: ...))`.
  Tab screens start with `PageHeader`; sub-screens with `SubHeader`.
  Tab screens need no bottom padding for the bar (the shell handles it).
  Bottom bars of sub-screens (`DockedBar`, `FadeDock`) add the system inset.

## Theme: `lib/theme/`

`final c = context.colors;` (an `AppColors` ThemeExtension, computed exactly
like the mockup's `theme(mood)`, for `Mood.aqua` (default), `coral`, `iris`).

| Token | Use |
|---|---|
| `bg` `nav` `surface` `surface2` `line` | page, bottom bar, cards, bands/pop-ups, hairlines |
| `text` `text2` `text3` | main, secondary, tertiary text |
| `accent` `onAccent` `accentSoft` `accentGlow` `wash` `onAccentDim` | accent and its tints |
| `tile` | neutral tile (surface*0.87+33) behind emojis, pop-up buttons |
| `ink` | darkest mood tone |
| `other` `barSoft` `barDim` `ramp[5]` `tip` `stub` `track` `heat[4]` `dim` | charts, calendar heat, sliders |
| `good` `bad` `onBad` | green, rose, text on rose |
| `pillDim` `sheen` `ring` `ringSoft` | Home hero card |
| `switchOff` `popDim` `popGrab` `popStub` `scrim` | switch track off, pop-up faint/grabber/rings, scrim |

`mix(a, b, w)` is the mockup's colour mixer. `CategoryColor` (enum): blue,
green, violet, amber, cyan, pink, orange, coral with `.label`, `.color`,
`.argb` (what `Categories.color` stores) and `CategoryColor.fromArgb(int)`.
`cssShadow(x:, y:, blur:, spread:, color:)` converts a CSS box-shadow;
`popupShadow`, `sheetShadow`, `accentGlowShadow(c.accentGlow)` are ready-made.

`AppText` (no colour; add `.copyWith(color: c.text3)`):

| Style | Size/line, weight | Use |
|---|---|---|
| `pageTitle` | 21/28 w800 -0.3 | tab screen title |
| `screenTitle` | 17/24 w800 -0.2 | sub-screen, dialog, sheet title |
| `cardTitle` | 15/20 w800 | band title |
| `rowTitle` / `rowAmount` | 15/20 w600 / w700 tabular | list rows |
| `sub` | 12.5/16 w500 | sub-lines (text3) |
| `value` | 14/20 w500 | settings row value (text3) |
| `body` / `bodyStrong` / `label` | 13.5/20 w500 / 14/20 w700 / 14/20 w600 | dialog lines |
| `overline` / `caption` | 12.5/16 w600 / 12/16 w500 | labels, hints |
| `popHeading` | 20/28 w800 -0.3 | pop-up heading |
| `button` / `buttonQuiet` / `pill` | 15/20 w800 / w700 / 14/20 w700 | buttons |
| `segment` / `segmentSmall` / `navLabel` | 13.5/20, 12.5/16, 11.5/14 w600 | controls |
| `heroNumber` / `keypadNumber` | 32/36, 34/40 w800 -0.8 tabular | big numbers |
| `dayTotal` / `dayTitle` / `badgeNumber` | 16/20, 15/20, 17/20 w800 | Home day card |
| `pickerDay` / `pickerTile` / `weekdayLetter` | 14.5/36, 15/20, 12/20 | calendars |
| `emoji` | 22, height 1 | emoji text |

`AppText.tabular(style)` adds tabular figures.

## Widget kit: `import '../../widgets/kit.dart';`

| Widget | Constructor (defaults) |
|---|---|
| `PageHeader` | `({String? title, Widget? leading, List<Widget> actions = []})` 64 px tab header |
| `SubHeader` | `({required String title, String? subtitle, Widget? leading, Widget? trailing, bool showBack = true, VoidCallback? onBack})` 60 px, 88/1fr/88 |
| `SubHeader.form` | `({required title, required VoidCallback onCancel, required VoidCallback? onSave, cancelLabel = 'Cancel', saveLabel = 'Save'})` 80x36 pills; null onSave = disabled |
| `SubHeader.cancel` | `({required title, required onCancel, Widget? trailing, cancelLabel})` auto-width Cancel (Add/Edit expense) |
| `RoundIconButton` | `({required IconData icon, required VoidCallback? onTap, String? semanticLabel, size = 40, iconSize = 22, Color? background, Color? color, double fill = 0})` |
| `BackRoundButton` | `({VoidCallback? onTap, semanticLabel = 'Back'})` pops by default |
| `Pill` | `({required String label, required VoidCallback? onTap, PillTone tone = neutral, double? width, Widget? leading, Widget? trailing, height = 36})` tones: neutral, accent, soft |
| `PrimaryButton` | `({required String label, required VoidCallback? onPressed, IconData? icon, ButtonTone tone = accent, bool glow = false, height = 52, radius = 18, fontSize = 15, iconSize = 20})` tones: accent, quiet, danger (rose text), destructive (rose fill) |
| `PopupButtons` | `({required onCancel, required VoidCallback? onAction, cancelLabel = 'Cancel', actionLabel = 'Confirm', destructive = false})` 48 px pair, equal halves; a label keeps 12 px each side, so a long one gets a wider button, and a pair too wide for one row stacks (action on top) |
| `RowValue` / `RowChevron` | `RowValue(String text, {chevron = true, tabular = false})` "Sunday ›" |
| `BandCard` | `({required String title, IconData? icon, String? trailingText, Widget? trailing, Widget? child, bandHeight = 48, bodyPadding = EdgeInsets.zero, Widget? titleWidget})`; `BandCard.tallBand` = 56, `BandCard.listPadding` = 4 px top/bottom |
| `EmojiTile` | `({required String emoji, size = 44, radius = 14, emojiSize = 22, Color? background, Color? dotColor, Color? ringColor, BoxBorder? border, List<BoxShadow>? shadows})` dot = category colour |
| `IconTile` | `({required IconData icon, size = 44, radius = 14, iconSize = 22, Color? background, Color? iconColor, fill = 0})` |
| `MessageCard` | `({required IconData icon, required String title, required String message})` centred card: 44 px accent tile, title, text3 line (Home's empty month card) |
| `NotFoundCard` | `({required String thing, required IconData icon})` "<thing> not found" / "It may have been deleted." `MessageCard` at the top of a sub-screen body (16 2 16 0); every not-found state uses it |
| `ListRow` | `({required String title, String? subtitle, Widget? leading, Widget? trailing, String? trailingText, divider = true, onTap, onLongPress, double? height, TextStyle? titleStyle, Color? titleColor, Color? subtitleColor})` height 68 with subtitle or leading, else 56; divider starts at the text |
| `AppSegmented<T>` | `({required List<Segment<T>> segments, required T value, required ValueChanged<T> onChanged, SegmentedSize size = regular, Color? trackColor, double? segmentWidth, double? fontSize, tabular = false})` regular 40/32, compact 36/30; track = surface (on page/band) or bg (on a card) |
| `AppSwitch` | `({required bool value, required ValueChanged<bool>? onChanged, String? semanticLabel})` 48x28 |
| `DockedBar` | `({required Widget child, String? hint, padding = 12 16 14})`; `DockedBar.twoButtonPadding` |
| `FadeDock` | `({required Widget child})` floating bottom action over a fade (put in a Stack, list gets 96 px bottom padding) |
| `Pressable` | `({required Widget child, onTap, onLongPress, color, borderRadius, BoxBorder? border, shadows, semanticLabel, selected})` base of every button (subtle accent splash) |
| `AppShell`, `AppNavBar`, `AddFab` | the shell (used by the router only) |
| `SwipeArea` | `({required child, required ValueChanged<SwipeEvent> onSwipe, threshold = 24})`; `SwipeEvent.next` / `.axis`; taps inside check `SwipeArea.swipedRecently(context)` |
| `SlideSwitcher` | `({required Object pageKey, required bool forward, required Widget child, axis = horizontal})` slide between months |
| `NowPill` | `({required bool visible, required String label, required String semanticLabel, required VoidCallback onTap, Color? ringColor})` the "back to now" pill: 32 px accent `Pill` with a calendar icon that fades and scales in over 200 ms while `visible` and leaves the tree when gone. Home "This month" (hangs over the month card, ring `bg`), Calendar "Today" and Charts "This week/month/year" (right of the header), the three pop-ups |
| `NowPillOverCard` | `({required NowPill pill, required Widget child})` a pop-up card with the pill hanging over the right end of its top edge; the card stays centred (26 px added above and below) |

Swipe rule (Calendar screen too): finger left-to-right or top-to-bottom shows
the PREVIOUS month (`next == false`); right-to-left or bottom-to-top the NEXT.
Swiping, the arrows and the pop-ups never stop: no first month with data and
no "this month" limit, back or forward (Home, Calendar, Charts, the pop-ups).

### Pop-ups

| Function | Returns |
|---|---|
| `showDayPicker(context, {required int initialDay, label = 'Date of this expense'})` | `Future<int?>` day, null on Cancel |
| `showMonthPicker(context, {required int year, required int month, label = 'Month to show'})` | `Future<(int year, int month)?>` |
| `showAppDialog(context, {required title, required actionLabel, Widget? titleWidget, String? boldLine, String? quietLine, Widget? extra, cancelLabel, destructive = false, String? tickLabel})` | `Future<bool>` true = action. `tickLabel` = tick box that unlocks the action (Delete all, Delete pocket) |
| `showOptionSheet<T>(context, {required title, String? message, required List<SheetOption<T>> options, required T? current})` | `Future<T?>`; `SheetOption({value, label, note, trailing, tabular})` |
| `showAppSheet<T>(context, {required WidgetBuilder builder})` + `AppSheet({title, message, headerTrailing, children})` + `SheetActionRow({icon, label, onTap, destructive})` | any sheet (Receipt photo) |
| `showAppPopup<T>(context, {required builder})` + `AppPopupCard({child, padding = 20, width = 312})` | any centred pop-up (Custom range) |
| `showToast(context, message, {VoidCallback? onUndo, Duration? duration, double bottom = 88})`, `hideToast()` | toast with optional Undo (4 s / 6 s) |
| `DialogLinkRow({label, actionLabel, onTap})`, `TickBoxRow({label, value, onChanged})`, `OptionRow(...)` | parts |

Pickers read the first day of the week from settings and today from the clock.
In widget tests, pump past a toast's duration (it uses a Timer).

## Core helpers: `lib/core/`

**days.dart**: `dayOf(y, m, d)`, `dayFromDate(DateTime)`, `dateOfDay(day)` (UTC
DateTime with the calendar fields), `localDateTimeOfDay(day, {hour, minute})`,
`weekdayOfDay` (1 Mon..7 Sun), `yearOfDay`, `monthOfDay`, `dayOfMonth`,
`monthStart/monthEnd(y, m)`, `daysInMonth`, `monthStartOfDay/monthEndOfDay(day)`,
`yearStart/yearEnd(y)`, `YearMonth` = `({int year, int month})`,
`yearMonthOfDay(day)`, `addMonths(y, m, delta)`, `addMonthsToDay(day, delta)`
(clamped), `sameMonth`, `sameYear`, `FirstDayOfWeek {monday, saturday, sunday}`
(`.weekday`, `.label`), `weekStart/weekEnd(day, first)`, `weekdayOrder(first)`,
`sixWeekGrid(y, m, first)` (42 days), `Clock` / `Clock.fixed(t)` (`now()`,
`today()`), `mockupNow` = 18 Oct 2026 10:18.

**format.dart**: `NumberStyle {comma, dotComma, spaceDot, spaceComma, lakh}`
(`.group`, `.decimal`, `.sample({separator})`, `.note`); `AmountFormat`
(`ref.watch(amountFormatProvider)`): `format(minor)` ("1,180" / "12.50"),
`formatWhole(minor)`, `count(n)`, `short(minor)` (calendar: 835, 1.7K, 15K),
`typed(raw)` (keypad display of "1234.5"), `parse(text)` -> minor or null,
`group(int)`. `parseDotDecimal(s)`, `minorToKeypad(minor)`. Spaces are
U+00A0. Date words: `dayLabel(day, today)` (Today / Yesterday / Thursday),
`daySubLabel(day, today)` (weekday / "2 days ago"), `longDate` ("Sunday,
October 18, 2026"), `weekdayDate` ("Sun, Oct 18, 2026"), `mediumDate` ("Oct
18, 2026"), `monthDay` ("Oct 18"), `weekdayMonthDay` ("Sun, Oct 18"),
`longMonthDay(day, {currentYear})`, `dayOrToday(day, today)` ("Today, Oct
18"), `monthYear(y, m)` ("October 2026"), `shortMonthYear`, `dayRangeLabel`
("Oct 12 – Oct 18"), `timeOfDay(DateTime)` ("10:18 AM"), `addedLabel`,
`expenseCount(n, fmt)` ("1,266 expenses"), name lists `monthNames`,
`monthShortNames`, `weekdayNames`, `weekdayShortNames`, `weekdayInitials`,
`monthName(m)`, `monthShortName(m)`, `weekdayName(day)`, `weekdayShortName(day)`.

**calculator.dart**: operators `opPlus` `opMinus` (U+2212) `opTimes` (U+00D7)
`opDivide` (U+00F7); `plusMinusOperators`, `allOperators`;
`evaluateExpression(expr)` -> minor or null (divide by zero, negative, >= 1e15;
trailing operator ignored; × ÷ first); `applyKeypadKey(expr, key)` (keys
'0'-'9', '.', operators, 'del', '='; 9 digits, 2 decimals);
`hasOperator(expr)`, `displayExpression(expr)` ("120 × 3 + 50").

**type_to_add.dart**: `parseTypeToAdd(text, {required List<CategoryRef>
categories, Map<String, int> learned, AmountFormat format})` -> `TypedExpense
{int? amount, int? categoryId, String title, List<String> categoryWords,
List<String> titleWords, bool byLearnedWord, bool hasAmount}`.
`CategoryRef` = `({int id, String name})`. Rules (also in the file): first
number = amount; currency words/symbols ignored; learned word or name prefix
(3+ letters) votes; a word that starts several names does not vote alone;
most votes wins, ties go to the first named; name-matched words leave the
title, learned words stay; title = rest, first letter upper-case; no built-in
word list. When the user picks/changes the category by hand, learn
`titleWords` for it (`learnedWordsRepoProvider.learnAll`).

## Data: `lib/data/`

Tables (Dart data classes in brackets): `Pockets` [`Pocket`]: id, name, emoji,
sortOrder, isDefault, createdAt. `Categories` [`ExpenseCategory`, not
`Category`, which Flutter already has]: id, name, emoji, color (ARGB int),
sortOrder, isMisc, createdAt. `Expenses` [`Expense`]: id, pocketId, categoryId,
amount, note ('' = no title), day, createdAt, updatedAt, photoPath (file name
or null); index (pocketId, day). `LearnedWords` [`LearnedWord`]: word (PK,
lower-case), categoryId, updatedAt. `SettingsEntries` [`SettingsEntry`]: key,
value. Seed: "Personal" 👛 (default) and the 15 `defaultCategories`
(Miscellaneous last, `isMisc`). Foreign keys are on.

**ExpensesRepo** (`expensesRepoProvider`): `add({pocketId, categoryId, amount,
day, note = '', photoPath})` -> id; `addAll(List<ExpenseDraft>)` -> ids;
`update(Expense)` (all fields, bumps updatedAt); `delete(id)` -> deleted row
or null (photo file kept for Undo); `restore(Expense)`; `deleteMany(ids)`;
`moveToPocket(id, pocketId)`; `get(id)`, `watch(id)`; `watchRange(pocketId,
from, to, {categoryId})` / `listRange(...)` newest first; `watchDayTotals` ->
`Map<day, minor>`; `watchCategoryTotals` -> `List<CategoryTotal{categoryId,
total, count}>` biggest first; `watchMonthTotals` -> `List<MonthTotal{year,
month, total, count}>`; `watchTotal(pocketId, from, to)`;
`watchAllTimeTotal(pocketId)`; `watchDaySpan(pocketId)` -> `({int? first, int?
last})`; `watchCount(pocketId, {from, to})`, `count(...)`;
`watchPocketTotals(from, to)` -> `Map<pocketId, minor>`; `exists({pocketId,
day, amount, categoryId, note})` (import duplicates); `photoNames()`.

**CategoriesRepo** (`categoriesRepoProvider`): `watchAll()`, `all()`,
`get(id)`, `misc()`, `findByName(name)`, `nameExists(name, {exceptId})`,
`add({name, emoji, color})` -> id (goes just before Miscellaneous),
`update(ExpenseCategory)` (name, emoji, colour), `reorder(List<int> ids)`,
`delete(id)` -> moved count (expenses in EVERY pocket move to Miscellaneous;
its learned words are forgotten; throws `StateError` for Miscellaneous),
`countExpenses(id)`, `watchExpenseCounts()`.

**PocketsRepo** (`pocketsRepoProvider`): `watchAll()`, `all()`, `get(id)`,
`defaultPocket()`, `nameExists(name, {exceptId})`, `add({name, emoji})` -> id,
`update(Pocket)` (name, emoji), `reorder(ids)`, `delete(id)` -> deleted
expense count (also deletes their photo files; throws `StateError` for the
default pocket), `countExpenses(id)`, `watchExpenseCounts()`.

**LearnedWordsRepo** (`learnedWordsRepoProvider`): `learn(word, categoryId)`,
`learnAll(words, categoryId)`, `lookup(words)` -> `Map<word, id>`,
`watchAll()`, `forget(word)`, `forgetCategory(categoryId)`.

**PhotoStore** (`photoStoreProvider`): `savePicked(sourcePath)` -> file name
(JPEG quality 80, short edge >= 1200, so a 4:3 photo is about 1600x1200, in
`<documents>/photos/`), `file(name)` -> `File`, `delete(name)`,
`purgeExcept(keep)`, `deleteAll()`, `folder()`.

**DataMaintenance** (`maintenanceProvider`): `deleteAllData()` -> new default
pocket id, `clearCache()` -> bytes freed (cache folder + photos no expense uses),
`purgeOrphanPhotos()`. `formatBytes(bytes)` ("12.3 MB"). Prefer
`ref.read(dataActionsProvider)`: `deleteAllData()` (also switches to the new
pocket), `clearCache()`, `switchPocket(id)`. Write export files to the cache
folder (`ref.read(cacheDirProvider)()`), so Clear cache removes them.

## Providers: `lib/state/providers.dart` (Riverpod 3, exports settings.dart)

| Provider | Type |
|---|---|
| `databaseProvider` | `Provider<AppDatabase>` (overridden in main/tests) |
| `clockProvider`, `todayProvider` | `Provider<Clock>`, `Provider<int>` |
| `documentsDirProvider`, `cacheDirProvider` | `Provider<Future<Directory> Function()>` |
| `fontFallbackProvider` | `Provider<List<String>>` (tests only) |
| `photoStoreProvider`, `expensesRepoProvider`, `categoriesRepoProvider`, `pocketsRepoProvider`, `learnedWordsRepoProvider`, `settingsStoreProvider`, `maintenanceProvider`, `dataActionsProvider` | repositories |
| `initialSettingsProvider` | `Provider<AppSettings>` (loaded before runApp) |
| `settingsProvider` | `NotifierProvider<SettingsNotifier, AppSettings>` |
| `amountFormatProvider` | `Provider<AmountFormat>` |
| `pocketsProvider` | `StreamProvider<List<Pocket>>` |
| `currentPocketProvider`, `currentPocketIdProvider` | `Provider<Pocket?>`, `Provider<int?>` (null only while loading; deleted pocket falls back to default) |
| `categoriesProvider` | `StreamProvider<List<ExpenseCategory>>` (user order) |
| `categoriesByIdProvider`, `miscCategoryProvider` | `Provider<Map<int, ExpenseCategory>>`, `Provider<ExpenseCategory?>` |
| `learnedWordsProvider` | `StreamProvider<Map<String, int>>` |
| `categoryExpenseCountsProvider`, `pocketExpenseCountsProvider` | `StreamProvider<Map<int, int>>` |
| `expensesInRangeProvider(PocketRange)` | `List<Expense>` |
| `categoryExpensesProvider(CategoryRange)` | `List<Expense>` |
| `dayTotalsProvider(PocketRange)` | `Map<int, int>` |
| `categoryTotalsProvider(PocketRange)` | `List<CategoryTotal>` |
| `monthTotalsProvider(PocketRange)` | `List<MonthTotal>` |
| `rangeTotalProvider(PocketRange)` | `int` |
| `allTimeTotalProvider(pocketId)`, `daySpanProvider(pocketId)`, `expenseCountProvider(pocketId)` | `int`, `DaySpan`, `int` |
| `expenseProvider(id)` | `Expense?` |
| `pocketTotalsProvider(DayRangeKey)` | `Map<int, int>` |

Family keys are records: `PocketRange = ({int pocketId, int from, int to})`,
`CategoryRange = ({int pocketId, int categoryId, int from, int to})`,
`DayRangeKey = ({int from, int to})`. Families are auto-dispose streams.
Riverpod 3 notes: `AsyncValue.value` is nullable (no `valueOrNull`);
`ProviderScope(retry: (_, _) => null)` is set (no silent retries); widgets
in hidden tabs pause their subscriptions; `StateProvider` is not used.

```dart
final pocketId = ref.watch(currentPocketIdProvider);
if (pocketId == null) return const SizedBox.shrink();
final today = ref.watch(todayProvider);
final ym = yearMonthOfDay(today);
final total = ref.watch(rangeTotalProvider(
    (pocketId: pocketId, from: monthStart(ym.year, ym.month), to: today)));
final fmt = ref.watch(amountFormatProvider);
Text(total.value == null ? '' : fmt.format(total.value!));
```

### Settings: `ref.watch(settingsProvider)` / `ref.read(settingsProvider.notifier).setX(v)`

| Field (default) | Setter | Board wording |
|---|---|---|
| `mood` (aqua) | `setMood(Mood)` | Color theme: Aqua, Coral, Iris |
| `themeMode` (dark) | `setThemeMode(AppThemeMode)` | Theme: Dark, Light, System (only Dark is built) |
| `textScale` (1.0) | `setTextScale(double)`, `setTextSizeIndex(0-4)` | Text size: `textScaleNames` Smallest..Largest = `textScaleSteps` 13/15, 14/15, 1, 17/15, 19/15; `textSizeIndex` |
| `showMonthlyTotal` (true) | `setShowMonthlyTotal` | Monthly total on Home |
| `privacyMask` (false) | `setPrivacyMask` | Privacy hide: mask the total until you tap the eye |
| `showCalendarButton` (true) | `setShowCalendarButton` | Calendar button |
| `calendarAmounts` (true) | `setCalendarAmounts` | Amounts in calendar days |
| `firstDayOfWeek` (sunday) | `setFirstDayOfWeek` | First day of the week (sheet order Monday, Saturday, Sunday) |
| `numberStyle` (comma) | `setNumberStyle` | Number format (5 styles; separator off lists only 1234567.89 / 1234567,89) |
| `thousandsSeparator` (true) | `setThousandsSeparator` | Thousands separator |
| `calcKeys` (plusMinus) | `setCalcKeys(CalcKeys)` | Calculator keys: "Plus and minus" / "All four keys" (`.label`) |
| `currentPocketId` (null) | `setCurrentPocketId(int?)` | pocket in use |
| `lastCustomRange` (null) | `setLastCustomRange(({int from, int to})?)` | Charts custom range (null: last 30 days) |

`settings.amountFormat` gives the formatter. The text scale replaces the
phone's own scale (`MediaQuery.textScaler`), so layouts see 0.87x to 1.27x.

## Routes: `lib/router.dart` (do not edit)

| Path | Builder (`Routes.*`) | Screen file / class |
|---|---|---|
| `/` tab | `Routes.home` | `features/home/home_screen.dart` `HomeScreen()` |
| `/charts` tab | `Routes.charts` | `features/charts/charts_screen.dart` `ChartsScreen()` |
| `/reports` tab | `Routes.reports` | `features/reports/reports_screen.dart` `ReportsScreen()` |
| `/settings` tab | `Routes.settings` | `features/settings/settings_screen.dart` `SettingsScreen()` |
| `/add?day=` | `Routes.add({day})` | `features/add/add_screen.dart` `AddScreen({int? day, int? expenseId})` |
| `/expense/:id` | `Routes.expense(id)` | `features/expense/details_screen.dart` `ExpenseDetailsScreen({required expenseId})` |
| `/expense/:id/edit` | `Routes.editExpense(id)` | `AddScreen(expenseId: id)` |
| `/expense/:id/photo` | `Routes.expensePhoto(id)` | `features/expense/photo_screen.dart` `PhotoScreen({required expenseId})` |
| `/calendar?day=` | `Routes.calendar({day})` | `features/calendar/calendar_screen.dart` `CalendarScreen({int? day})` |
| `/category/:id?from=&to=` | `Routes.category(id, {from, to})` | `features/charts/category_screen.dart` `CategoryScreen({required categoryId, int? from, int? to})` |
| `/settings/categories` | `Routes.categories` | `features/categories/categories_screen.dart` `CategoriesScreen()` |
| `/settings/categories/new` | `Routes.newCategory` | `features/categories/category_form_screen.dart` `CategoryFormScreen()` |
| `/settings/categories/:id` | `Routes.editCategory(id)` | `CategoryFormScreen(categoryId: id)` |
| `/pockets` | `Routes.pockets` | `features/pockets/pockets_screen.dart` `PocketsScreen()` |
| `/pockets/new` | `Routes.newPocket` | `features/pockets/pocket_form_screen.dart` `PocketFormScreen()` |
| `/pockets/:id` | `Routes.editPocket(id)` | `PocketFormScreen(pocketId: id)` |
| `/settings/export` | `Routes.export` | `features/data/export_screen.dart` `ExportScreen()` |
| `/settings/import` | `Routes.importStart` | `features/data/import_screen.dart` `ImportScreen()` |
| `/settings/import/columns` | `Routes.importColumns` | `features/data/import_columns_screen.dart` `ImportColumnsScreen()` |
| `/settings/import/review` | `Routes.importReview` | `features/data/import_review_screen.dart` `ImportReviewScreen()` |

- Tabs: `context.go(Routes.charts)`. Everything else: `context.push(...)`
  (opens above the shell, no bottom bar; Back and the system back gesture
  return). Close with `context.pop([result])`; `await context.push<T>(...)`
  gets the result. An invalid `:id` arrives as -1: show a "not found" state.
- The plus button in the shell pushes `Routes.add()`.
- Share state between the three import steps with a provider in
  `features/data/`, not with `extra`.

## Icon font (release builds)

`flutter build apk --release` tree-shakes icon fonts with Flutter's
`font-subset`. For variable fonts it packs each glyph's `gvar` variation data
back to back but may store the offsets as 16-bit "offset / 2". Material
Symbols has odd-length glyph data, so every glyph whose data starts on an odd
byte got an offset one byte early and drew blank on the phone (the + button,
calendar, Settings tab, receipt...). Which icons broke depended on the byte
sizes of the others. Debug builds, widget tests and screenshots never
tree-shake, so none of them showed it.

The fix: the app ships its own `assets/fonts/MaterialSymbolsRounded.ttf`,
made by `tool/icon_font.dart` from the `material_symbols_icons` package (now a
dev dependency, so its own 34 MB of fonts are not bundled). The tool pads
every glyph's variation data to an even length (offsets stay exact however
font-subset stores them) and trims the font to the icons in
`lib/theme/symbols.dart` (outlines identical to the package's).

Adding an icon:

1. Copy its line from the package's `lib/symbols.dart` into
   `lib/theme/symbols.dart` (keep `matchTextDirection`, drop `fontPackage`).
2. `dart run tool/icon_font.dart`
3. `flutter test test/tool` (fails if the font lacks an icon, is unpadded, or
   breaks when run through font-subset).

Before handing over a release APK: `dart run tool/check_release_icons.dart`.
It runs `flutter build apk --release`, opens the APK, and fails if any icon
used in lib/ is missing from the shaken font or any glyph's variation data is
corrupt (`--no-build` checks the last build, `--apk <path>` another APK).
Never use `--no-tree-shake-icons` (74 MB instead of ~62 MB).

## Screenshot tests

```dart
@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import '../support/shots.dart';

void main() {
  setUpAll(loadShotFonts);
  testWidgets('calendar default', (tester) async {
    final db = await sampleDatabase(tester);              // mockup data
    await pumpApp(tester, db: db, location: '/calendar'); // 360x780 @2x
    await takeShot(tester, 'calendar_default');           // build/shots/calendar_default.png
    await closeApp(tester, db);                           // always last
  });
}
```

`pumpApp(tester, {required db, location = '/', AppSettings settings, List<Override> overrides})`;
`settle(tester)` after taps; open pop-ups with `unawaited(showX(tester.element(find.byType(MyScreen)), ...))`.
Fonts: Plus Jakarta Sans and Material Symbols Rounded from assets, colour
emoji from `C:\Windows\Fonts\seguiemj.ttf` (Segoe UI Emoji,
COLR; drawn in colour; glyph style differs from the phone's Noto). Real
shadows are on. Today is 18 Oct 2026 10:18. Compare with the mockup render:
`cd ../design/headertest && node measure_any.js <Board> <name>` writes
`g_<Board>_<name>.png` (pop-ups: `node measure_pop.js`, `p_...png`; state as
JSON: `node measure_pop.js PopDeleteAll ticked '{"popOk":true}'`).
Sample data (`test/support/sample_data.dart`): `fillSampleData(db, {pocketId})`,
`generateSampleExpenses()`, `sampleToday`, `MockupRandom`. October 2026 =
34,555; Oct 18 = 1,180 (Health, "Doctor visit"); 1266 expenses; notes kept,
except Oct 17's snack (135), which has no title as on the Home boards.

Unit tests of repositories: `openTestDatabase()` (in-memory, seeded).
Provider tests: `ProviderContainer.test(retry: (_, _) => null, overrides: [databaseProvider.overrideWithValue(db), clockProvider.overrideWithValue(Clock.fixed(mockupNow))])`.

## Decisions taken here (not spelled out in BUILD_LIST)

- Deleting a category forgets its learned words (the app asks again next time).
- Deleting an expense keeps its photo file until Clear cache or the next app
  start, so Undo can restore it.
- A new category is inserted just before Miscellaneous.
- The date pop-up's month name opens month tiles (and from there years) in
  the same pop-up; its height never changes.
- Toast (not in the mockup): `tile` card, radius 16, Undo in accent.
- Calendar short form under 1,000 shows the whole number rounded.
- Type to add ignores currency words/symbols (tk, taka, $, ৳ ...) and keeps
  the user's capitalisation in the title.
