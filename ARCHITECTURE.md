# Architecture

Decisions for the Expense Tracker app. Scope lives in BUILD_LIST.md.

## Platform
- Android first, iPhone later. Must be cross-platform.

## Framework and language
- **Flutter, written in Dart.**
- Why: snappiest touch, scroll and swipe response out of the box. Own rendering engine (Impeller) gives smooth animations and charts at the phone's full refresh rate. Pixel-identical on Android and iOS.
- iPhone builds from Windows through a cloud build service (for example Codemagic). No Mac needed.
- Alternatives considered: React Native + Expo (TypeScript), Kotlin Multiplatform.

## Database
- **Drift (SQLite), stored on the phone only.** No server, no sign-in.
- Why: reports and charts need totals by day, month and category, which SQL handles natively. Reactive queries refresh the UI as soon as data changes. Backup is a single database file.
- Alternatives considered: ObjectBox, Hive, Isar (original Hive/Isar authors stopped maintaining them).

## Charts
- **fl_chart**, plus custom-painted touches where needed (for example the ring chart center).
- Why: free and open source, light, fully restylable (gradients, rounded segments, glow), built-in touch handling and animations.
- Interactions: tap a ring slice to pop it out, tap a column to see its value, animated transitions when switching periods.
- Process: chart design mockups go to the user for approval before building.
- Alternatives considered: Syncfusion Flutter Charts (closed source, corporate look), fully hand-drawn (most effort).

## Backup (later phase, not in first build)
- **Both:** daily automatic backup to the phone, plus a copy in the hidden Google Drive app-data folder.
- Restore from either. Google Drive also works on iPhone later.
- Needs a one-time Google account pick (not an app account).

## Import
- **First build:** CSV, Excel and JSON. User maps columns once (date, amount, category, note), sees a preview, then imports.
- **AI phase:** photos and PDFs (receipts, bank statements). Text reading without AI is unreliable, so it moves there.

## Export
- **First build:** Excel (.xlsx) and CSV for a chosen date range. CSV re-imports cleanly.
- **Later:** PDF monthly report with charts, once chart design is final.

## Distribution
- **During development:** install directly over USB (adb). Free and instant.
- **Later (optional):** Google Play private/internal testing track for automatic updates. iPhone later needs an Apple Developer account.

## Internals
- **State management:** Riverpod. Totals and charts update instantly across screens.
- **Navigation:** go_router.
- **Receipt photos:** stored compressed in the app's private folder on the phone. Included in backups later.
- **Analytics / tracking / crash services:** none. Nothing leaves the phone.
- **Internet:** not required. Fully offline (Google Drive backup is the only online part, later).
- **Testing:** automated unit tests for totals, date grouping and type-to-add parsing; widget tests for key screens. Bug fixes start with a failing test.
