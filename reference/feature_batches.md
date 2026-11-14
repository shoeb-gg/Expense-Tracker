# Money Tracker feature batches (for review)

Source: reference/FEATURES.md. 19 batches, 107 features. [VIP] = premium-locked in the original app. [AD] = ad/upsell.
Decisions are recorded in BUILD_LIST.md at the project root.

## Batch 1 - Adding a transaction
1. Add expense or income - Expense or Income tab, remembers last used tab.
2. Pick a category - Grid of categories per type, with a Settings tile to category management.
3. Amount keypad with calculator - Built-in keypad with decimals, backspace, simple + and -.
4. Note - Free-text note on any transaction.
5. Choose the date - Calendar pop-up, Today by default, past or future allowed.
6. Save and jump to that month - Check button saves, home switches to that transaction's month.

## Batch 2 - Home screen: summary, list and month navigation
1. Monthly summary - Expenses, Income, Balance for the selected month.
2. Day-by-day list - Grouped by day, newest first, day totals, note (or category) and amount per entry.
3. Month navigation - Month/year picker, plus "previous month" button at end of list.
4. Total balance overview - Tap summary for all-time balance/expenses/income plus month-by-month table, filter by year.
5. Balance display options - Show/hide home balance; monthly vs total balance.
6. Hide total on home screen [VIP] - Privacy hide of total amount.

## Batch 3 - Viewing, editing and deleting
1. Transaction details - Category, type, amount, date, note on one screen.
2. Date added - Exact creation date and time.
3. Edit a transaction - Change amount, category, note, date, etc.
4. Delete with confirmation - "Are you sure?" prompt, totals update immediately.
5. Quick menu - Long-press entry for Edit, Delete, Details.

## Batch 4 - Categories
1. Manage categories - Expense and Income categories on one screen.
2. Add a custom category - Name, colour (16 choices), icon from themed groups.
3. Edit or rename a category - Change name, colour, icon; customised ones marked.
4. Delete a category.
5. Reorder categories - Drag to reorder.
6. Subcategories [VIP].

## Batch 5 - Calendar
1. Calendar view - Month grid with daily income/expense totals, month dropdown.
2. Open a day - Tap a day to see its transactions and add one for that day.
3. Show or hide the calendar button on home.
4. Daily amounts on calendar - Toggle showing amounts per day.
5. First day of the week - Sunday, Monday or Saturday; applies to date pop-ups too.

## Batch 6 - Charts: views and periods
1. Expenses or Income toggle for the Charts tab.
2. Time range - Week, Month, Year, or custom start-to-end.
3. Previous-period tabs - Slide through earlier periods, quick "Last"/"This" tabs.
4. Ring chart by category - Total in the middle, top categories beside it.
5. Ring chart by day - Which days had the biggest totals.
6. Line chart with total and average - Daily (or monthly) amounts plotted.

## Batch 7 - Charts: category breakdown and Reports overview
1. Category ranking - Biggest first, amount, coloured bar, percentage.
2. Category drill-down - Category's own line chart, total, average, transactions.
3. Sort by amount or date within a category.
4. Reports tabs - Analytics view and Accounts view.
5. Monthly statistics card - Month's Expenses/Income/Balance on Reports; tap for full overview.

## Batch 8 - Budgets
1. Monthly budget summary - Budget, spent, remaining, progress ring on Reports.
2. Budget screen by month - Move between months.
3. Set a monthly budget - Overall limit via keypad.
4. Set category budgets - Per expense category.
5. Clear a budget - Trash option.

## Batch 9 - Accounts and transfers
1. Add and manage accounts - Name, currency, starting balance, icon; list.
2. Account types - Default, Cash, Debit card, Credit card, Virtual, Investment, Owes me, I owe.
3. Exclude from totals.
4. Pick an account per transaction (optional), or add one from the picker.
5. Transfer between accounts - Transfer tab.
6. Net worth report - Net worth, assets, liabilities on Reports Accounts tab.

## Batch 10 - Cashbooks and sharing
1. Switch cashbooks - Default "Personal"; switch from Home menu or Settings.
2. Create a cashbook - Name, type, currency, note.
3. Split cashbook - Shared cashbook for splitting expenses.
4. Project, Team and Business cashbooks [VIP].
5. Join with invitation code.
6. Data sharing between two people [VIP] - Accept free, sending is premium.

## Batch 11 - Recurring transactions
1. Recurring list - View all, add from Add screen or Settings.
2. Create recurring - Name, type (income/expense/transfer), category, amount, note.
3. Frequency - Daily, weekly, every 2 weeks, monthly, every 2/3/4/6 months.
4. Start date with preview of upcoming dates.
5. Limit repeats - Unlimited, 3, 6, 12, 18, 24, or custom.
6. Automatic entry and reminders - Auto-add on due date, reminder notification.

## Batch 12 - Currency and number formats
1. Default currency.
2. Custom exchange rates - Searchable list, set own rates.
3. Currency per transaction - Currency button on Add screen.
4. Number display format - Four styles.
5. Thousands separator on/off.

## Batch 13 - Appearance and language
1. Basic themes - Dark, Default light yellow, follow system.
2. Colour themes [VIP] - Orange, Blue, Green, Pink, Purple.
3. Font size slider.
4. Category icon style - Soft gradient or solid colour.
5. Add-page icon style - Single-colour or colourful.
6. Language - Many languages or follow phone.

## Batch 14 - Preferences, reminders and upkeep
1. Calculator mode - Plus/minus only, or also multiply/divide.
2. Sound effects on/off.
3. Notification shortcut - Quick-add from notification bar.
4. Monthly start date [VIP] - Which day the budget month starts.
5. Daily reminders - Name, frequency, start date, time, message.
6. Clear cache.

## Batch 15 - Security, backup and data
1. Passcode lock [VIP].
2. Export data for a date range.
3. Import transactions [VIP] - CSV, Excel, PDF, JSON, images.
4. Automatic backup with last-backup time.
5. Delete all data.

## Batch 16 - Profile and support
1. My profile - Avatar, nickname, gender, user ID.
2. Sign out.
3. Delete account.
4. Help via the assistant.
5. Feedback to developers.
6. About, Terms and Privacy.

## Batch 17 - AI assistant
1. Ask about your money - Chat by typing or voice: analyse spending, find transactions, app help.
2. Suggested questions - Ready-made prompts.
3. Chat history and search.
4. Assistant button on Home - Show/hide.
5. AI bar on Add screen - Show/hide.

## Batch 18 - Smart entry and premium power tools
1. Type-to-add - "snacks 555" parsed into amount, category, note, saved immediately.
2. Voice entry.
3. Receipt photo via in-app camera.
4. Photo from gallery.
5. Auto entry from notifications [VIP] - Read payment alerts after confirmation, with blacklist.
6. Developer API [VIP].

## Batch 19 - Ad/upsell stuff (likely drop)
1. Go Premium paywall [AD].
2. Block Ads [AD].
3. Ad banners [AD] - On Transaction Details and Calendar.
4. Garden mini-game [AD] - Rewards for watching ads.
5. Our Other Apps [AD].
6. Recommend to friends [AD] - Share link.
