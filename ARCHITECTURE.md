# Architecture

Decisions for the Expense Tracker app. The app is called "Spill the Bills". Scope lives in BUILD_LIST.md.

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

## Pockets
- **Expenses are stored per pocket.** Each expense carries the pocket it belongs to. There is always a Default pocket.
- **Stored once for the whole app:** categories, the words type to add has learned, and settings.
- **Receipt photos** belong to their expense and are removed with it. Deleting a pocket removes its expenses and their photos.
- **Combined view of all pockets (later):** the storage must allow it without changes to existing data.

## Charts
- **fl_chart**, plus custom-painted touches where needed (for example the ring chart center).
- Why: free and open source, light, fully restylable (gradients, rounded segments, glow), built-in touch handling and animations.
- Interactions: tap a ring slice to pop it out, tap a column to see its value, animated transitions when switching periods.
- Process: chart design mockups go to the user for approval before building.
- Alternatives considered: Syncfusion Flutter Charts (closed source, corporate look), fully hand-drawn (most effort).

## Backup (built 2026-11-19)
- **Google Drive only.** A copy on the phone was dropped: it is lost with the phone.
- **What:** one zip per backup, a `VACUUM INTO` snapshot of the whole database (expenses, pockets, categories, budgets, learned words, settings) plus the receipt photos expenses use, and a manifest (format, schema, counts).
- **Where:** a "Spill the Bills backups" folder in the user's own Drive. The app asks only for `drive.file`, so it sees nothing but its own files. Plain HTTPS calls to the Drive v3 API; no Google client library.
- **When:** once a day when the app opens or comes back (signed in, not yet today, at least one expense, never with Google's screens), plus "Back up now". The newest 10 are kept.
- **Restore:** download, check (refuses damaged files and backups from a newer app), upgrade an older backup's schema, then copy every table into the live database in one transaction. Settings starting with `backup.` stay as they are on this phone.
- **Sign-in:** google_sign_in 7 (Credential Manager) for the account, and authorization tokens for `drive.file` by email, so the daily backup needs no UI. Any Google account works; Change account and Sign out are on the backup screen.
- **Google Cloud:** project `spill-the-bills`; an Android OAuth client (package name + the release key's SHA-1) and a Web client used as the server client. Only builds signed with the permanent key can sign in.

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
- **Receipt photos:** stored compressed in the app's private folder on the phone. Included in Drive backups.
- **Analytics / tracking / crash services:** none. Nothing leaves the phone except the user's own Drive backup.
- **Internet:** not required. The app works fully offline; the optional Google Drive backup is the only online part.
- **Testing:** automated unit tests for totals, date grouping and type-to-add parsing; widget tests for key screens. Bug fixes start with a failing test.
