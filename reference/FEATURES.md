# Money Tracker (com.freeman.moneymanager) - Feature and UI Inventory

App version observed: **1.1.147 (357)** (About us screen). Captured over ADB on a 1080x2374 phone on 2026-10-18 (app date = Oct 18 2026, a Sunday). Theme in use: **Dark**. Currency: **BDT (Bangladeshi Taka)**, amounts shown with no decimals and comma thousands grouping. UI is Jetpack Compose (labels are content descriptions).

All screenshots are in `reference\screens\` (PNG plus the UI dump XML with the same base name). Pixel sizes below are in the 1080-px-wide capture space.

---

## 1. Navigation map

```
App (single activity, bottom nav + center FAB)
|
+-- HOME (tab 1)
|    +-- Top bar: [Menu] "Money Tracker" [AI-Assistant / search glyph] [Calendar]
|    |    +-- Menu -> Cashbook switcher dropdown (panel over the list)
|    |    |     +-- Default (Personal Cashbook) [checked]
|    |    |     +-- Split Cashbook ("Split expenses with others")
|    |    |     +-- Project Cashbook [VIP]  Team Cashbook [VIP]  Business Cashbook [VIP]
|    |    |     +-- [Add] -> "Create Cash Book" form   [Join] -> "Join the Cash Book" dialog
|    |    +-- AI Assistant screen (chat, suggestion chips, history search)
|    |    +-- Calendar screen -> tap a day -> that day's list (+ Add FAB)
|    +-- Month chip "2026 / Oct v" -> Month/Year picker dialog (year grid 2018-2029, month grid)
|    +-- Summary card (Expenses / Income / Balance) -> "Balance overview" screen
|    |     +-- Year filter dropdown (All, 2026, 2025, ... Other)
|    |     +-- Gear -> "Home page settings" (Balance, Balance display mode, Hide total [VIP])
|    |     +-- Month table grouped by year (Month | Expenses | Income | Balance)
|    +-- Day-grouped transaction list (scroll) -> end-of-list "<- Sep 2026" previous-month pill
|    |     +-- tap row -> Details (Edit | Delete)
|    |     +-- long-press row -> popup menu: Edit / Delete / Details
|    +-- (FAB) Add
|
+-- CHARTS (tab 2)
|    +-- Expenses | Income toggle
|    +-- Period menu (calendar icon): Week | Month | Year | Period (custom range)
|    +-- Period tab strip (e.g. Jul 2026, Aug 2026, Last Month, This Month)
|    +-- 3-page swipe carousel: donut by category / donut by day / daily line chart
|    +-- Category list (bar + %) -> Category detail (line chart, Sort by amount/date, item list)
|
+-- ADD (center FAB, full-screen, "Cancel" to leave)
|    +-- Schedule icon -> Recurring Transactions -> Add recurring form
|    +-- Tabs: Expense | Income | Transfer
|    |     +-- category grid (+ "Settings" tile -> Category settings)
|    |     +-- after picking category: amount panel (account, note, camera, date, calculator keys)
|    |           +-- Currency icon (top right) -> Currency sheet (+ edit-rates mode, search)
|    |           +-- Account button -> Accounts sheet (+ -> Add account form)
|    |           +-- Date button -> date-picker dialog
|    |           +-- Camera -> in-app camera (shutter, gallery, flash)
|    +-- Bottom AI bar: text field -> full-screen "Tap to speak / type" smart-entry screen
|         (mic, text box, Cancel X / Confirm check), plus Voice, Photos, Close icons
|
+-- REPORTS (tab 4)
|    +-- Analytics | Accounts toggle
|    +-- Analytics: Monthly Statistics card -> Balance overview (same as Home summary tap)
|    |              Monthly Budget card -> Budget screen -> Budget Settings -> per-item budget keypad
|    +-- Accounts: Net Worth, Assets, Liabilities, [Add Account], [Manage Accounts]
|
+-- PROFILE (tab 5)
     +-- Avatar / name / ID header
     +-- Premium Member -> "Go Premium" paywall (BDT 599.00/Year)
     +-- Recommend to friends -> system share sheet
     +-- Block Ads -> same "Go Premium" paywall
     +-- Garden -> "Lucky garden" mini-game (ad-reward driven)
     +-- Settings (long list, see section 2.9)
     +-- Our Other Apps -> cross-promo list of the developer's other apps
```

---

## 2. Screens

### 2.0 Global visual design

| Item | Value |
|---|---|
| Overall look | Flat, dark, high-contrast, generous spacing; no shadows on cards except the FAB's soft halo |
| App background (lists, cards) | `#181818` |
| Top bar / bottom nav / summary header bg | `#1E1E1E` |
| Deep panel (Add keypad panel, forms pages, budget editor) | `#111111` |
| Input fields / keypad keys / chips | `#282828` (keys ~`#2A2A2A`) |
| Calendar empty cell | `#212121`; calendar cell with data `#22362D` (dark green) |
| Accent (FAB, selected tab icon/label, check button, selected tile, tab underline, section bars on forms) | **`#FFD946`** (warm yellow). Text on accent is near-black |
| Primary text | `#FFFFFF`; secondary labels `#A5A5A5`; day-group header text `#D1D1D1` |
| Expense colour (calendar, red text) | `#F44336`; income colour (calendar) `#4CAF50` |
| Month chip | rounded rect `#595959` with white "2026" small over "Oct v" larger |
| Selected segmented tab | white filled pill-rect, near-black text; unselected = outlined (1 px light border, white text) |
| Typography | Rounded geometric sans (Google-Sans/Product-Sans-like), Regular for body, SemiBold/Bold for titles and big numbers. Summary figures ~34 sp, row titles ~20 sp, secondary ~15 sp |
| Icons | Outline/line style, 2 px stroke; category icons are white glyphs inside solid coloured circles (see palette). Toolbar icons: hamburger-with-short-lines (menu), calendar-grid icon, magnifier/cat mascot, back arrow |
| Corner radii | Cards ~28 px, inputs ~24 px, buttons ~28-40 px (primary pill buttons yellow), keypad keys ~18 px |
| Bottom nav | 5 slots: Home (list-lines icon), Charts (pie icon), **center yellow circular FAB with +** (about 130 px diameter, overlaps nav top, soft glow), Reports (scroll/report icon), Profile (user icon). Active = yellow icon + label; inactive = `#A5A5A5` |
| Status handling | "No records" empty state = grey scroll-with-lines illustration + "No records" text |
| Number format | `1,234,568` style (setting offers 3 more formats). Expense rows show `-(amount)`; income rows show the plain number `333` (no plus sign) |

**Category colour palette (16 swatches in the add-category form, exact):**
`#FF6B6B #EB776A #D39689 #FF771C #FFB781` / `#E3AF36 #CCB328 #82B21E #3ACC28 #28CC94 #66C4CC` / `#4AABD8 #588EFE #9A93FD #C081DC #F57699`
Observed uses: Groceries `#E3AF36`, Snacks `#4AABD8`, Transportation `#D39689`, Phone `#F57699`, Income "Others" `#FF771C`; new-category default `#FFB781`; most other categories are `#E3AF36`.

**Chart palette:** donut slices `#DEC459`, `#42ABC9`, `#DF7086`, `#4AB09C`, `#6FBC6F` (soft, desaturated versions); line-chart points cycle through the 16-colour palette; category progress bars use the category colour.

### 2.1 Home  (`01_home.png`, `01b_home_bottom.png`, `04_home_sep2026.png`, `95_home_after_cleanup.png`)

- **Purpose:** monthly ledger for the active cashbook.
- **Top bar (y~164):** hamburger "Menu" (left, opens cashbook switcher), title "Money Tracker" (centre, bold), **AI Assistant button** (an animated icon that alternates between a lucky-cat mascot holding a coin and a plain magnifier glyph; accessibility name is always "AI Assistant"; opens the AI chat), Calendar icon (opens Calendar screen). The Calendar icon can be hidden via Settings > Calendar > Show Calendar; the AI icon via AI Settings.
- **Month chip** (left of summary, `#595959` rounded): small year over large month with a small chevron. Tap opens the month picker.
- **Summary strip** (`#1E1E1E`): three columns "Expenses", "Income", "Balance" (grey 24 sp labels, white 34 sp bold numbers). Balance = Income - Expenses (negative shown with "-"). The whole strip is tappable (-> Balance overview).
- **List:** scrolling, grouped by day (newest first). Day header row: left "Oct 15   Thursday" (date + weekday), right "Expenses: (amount)" and, if present on that day, "Income: 333" beside it. Rows: 70 px coloured circle with white category glyph, title, right-aligned amount; thin inset divider between rows within a day. Row title = the **note if one exists, else the category name** (the test rows showed "ZZTEST_1" instead of "Groceries").
- **End of list:** outlined pill button "Sep 2026 <-" which jumps to the previous month.
- **Row tap** -> Details. **Row long-press** -> small popup menu with **Edit, Delete, Details** (backing out without choosing leaves everything unchanged).
- **Month/Year picker** (`03_home_month_picker.png`, `03b_home_year_picker.png`): modal dialog on `#181818`; title "October 2026" (bold, centred); row with "2026 v" year dropdown (opens a 3-column grid 2018-2029) and prev/next chevrons; 4x3 month grid Jan-Dec with the selected month as a yellow rounded pill; text buttons **Cancel / Confirm** in yellow.
- **Cashbook switcher** (`11_home_menu_drawer.png`): drop-down panel under the top bar listing cashbooks with a notebook-with-$ icon, name + subtitle, check on the active one, "VIP" yellow pill badges on Project/Team/Business. Buttons **Add** and **Join** (dark rounded). Create form: `11c_cashbook_add.png` (name, type radio Split / General [VIP], currency dropdown, note). Join dialog: `11d_cashbook_join.png` (Invitation Code, note with 0/60 counter, Submit). Tapping a VIP entry opens the Create form pre-filled (e.g. "Project Cashbook", currency USD, note "Track expenses by project").
- **Detail screen** (`06_txn_detail_existing.png`, `34_txn_detail_with_note.png`, `92_income_detail.png`): title "Details"; big category circle + name; label/value rows **Type, Amount, Date** (with grey sub-line "( (date and time) Add )" = created timestamp), **Note** (only if set). A native ad (WebView) sits in the empty space. Bottom: two yellow pill buttons **Edit** and **Delete**.
- **Delete flow** (`93_delete_confirm.png`): centred dialog, orange-red text "Are you sure you want to delete?", buttons **Cancel / Confirm**. Confirm returns straight to Home with totals refreshed.
- **Edit screen** (`07_txn_edit_existing.png`): same as the Add amount-entry layout (2.3) with title "Edit".
- **Balance overview** (`05_home_summary_card_tap.png`, `05b`, `05c`, `05d`, `05e`, `96_overview_after_cleanup.png`): back arrow, year-filter dropdown top-right ("All v": All / 2026 / 2025 / 2024 / 2023 / 2022 / Other), "Total balance" (large, e.g. (total)) with a gear icon, Expenses and Income all-time totals, then a table (Month | Expenses | Income | Balance) grouped under year headings; rows are tappable (no visible navigation was observed). Gear -> **Home page settings**: *Balance* (Default >; sheet Show / Hide), *Balance display mode* (Monthly balance / Total balance sheet), *Hide total amount on homepage* (toggle, **VIP**).
- **Calendar** (`14_calendar.png`, `14b_calendar_day_selected.png`, `91_calendar_with_tests.png`): title "Calendar" + month dropdown "Oct 2026 v" (same month picker). Week header Sun-Sat (start day configurable). 7-column grid of rounded squares (~106x150 px): day number (white), below it the day's expense total in red `#F44336` and, if any, income total in green `#4CAF50` above the expense; cells with data have a dark green fill. Tapping a day opens a day screen titled "Oct 15, 2026" showing that day's group and an Add FAB. An ad slot appears below the grid; yellow Add FAB bottom-right.
- **AI Assistant** (`13_ai_assistant.png`): back arrow, title, history icon (top right), search field "Search", mascot hero, "AI Assistant" heading, greeting "Hi! I can help analyze spending, look up transactions, and answer how-to questions.", "Try asking" chips (each with a small yellow icon tile and a diagonal arrow): "How much did I spend this month?", "What percentage of my spending is dining?", "How much budget is left?", "How do I set a budget?". Bottom pill input "Ask about your finances or how to use the app..." with mic on the left and a circular send arrow on the right. **No messages were sent.**

### 2.2 Add - category selection  (`02_add_expense.png`, `16_add_income_tab.png`, `17_add_transfer_tab.png`)

- Full-screen modal over the app, no bottom nav. Top bar: text button **Cancel** (left), title "Add", **Schedule icon** (right; calendar-with-check-and-clock) -> Recurring Transactions.
- **Tabs** (3-segment control): Expense / Income / Transfer. The app **remembers the last used tab** (reopening Add after using Income starts on Income).
- **Expense tab:** 4-column grid of circular dark tiles (`#282828` circle, ~110 px, grey outline glyph) with the label below (long names wrap mid-word, e.g. "Transportat/ion"). Order observed: Groceries, Snacks, Transportation, Shopping, Miscellaneous, Phone, Online Subscriptions, (custom category), (custom category), Gas, House Rent, Self Care, Electric Bill, Health, Internet Bill, Gym, Gifts, and a "+" tile labelled **Settings** (opens Category settings, 2.8). Selecting a tile fills it yellow and slides up the amount panel.
- **Income tab:** Salary, Investments, Part-Time, Bonus, Others, a user-created one ("(custom category)"), and the **Settings** tile.
- **Transfer tab:** two large cards "+ Select" (from) and "+ Select" (to) joined by an arrow; requires accounts (none exist in this data set, so Transfer could not be completed).
- **Bottom AI bar:** rounded outlined input "What is it for & how much?" with Voice (mic), Photos (camera) and Close (x) icons.
  - Tapping the field opens a **full-screen smart-entry screen** (`31_add_nl_typing.png`, `32_add_nl_text.png`): dark page, big yellow circle with crossed-out mic ("Tap to speak"; mic permission was off), text box with a trash/clear icon, two round buttons bottom: **X** (cancel, dark) and **check** (confirm, yellow). Confirm **saves immediately** (no review step): "ZZTEST snacks 555" created an **expense of 555 dated today, note "snacks", category auto-matched to Snacks (blue icon)**. The unknown token "ZZTEST" was dropped from the note. (`33_nl_result.png`)
  - Photos icon opens an in-app **camera** (X close, gallery button bottom-left, white shutter, flash toggle) - used for receipt capture. It opened directly without a permission prompt. (Screenshot deleted on purpose because it showed the live room.)

### 2.3 Add - amount entry panel  (`20_add_amount_keypad.png`, `21_add_note_typing.png`, `22_add_date_picker.png`, `24_date_picker_day12.png`, `25_add_ready_to_save.png`, `26_calc_plus.png`, `27_add_income_ready.png`, `29_date_picker_sep.png`)

Layout after a category is chosen (the grid shrinks to the top part, a `#111111` panel fills the lower ~45%):
1. Top bar changes: right icon becomes **Currency** (EUR/USD swap arrows).
2. Row: **Account button** (card icon, left) and the **amount display** (right-aligned, ~52 sp white; shows expressions like "222 + 1").
3. **Note field** `#282828`: label "Note :" + "Enter a note...", camera icon at right.
4. **Keypad 4x4:** `7 8 9 [date]` / `4 5 6 +` / `1 2 3 -` / `. 0 backspace [check]`. The date key shows **"Today"** (yellow, calendar-edit icon) or the chosen date as "Oct 12 / 2026". Checkmark key is yellow `#FFD946` (disabled grey while amount = 0). When an operator is pending the check key becomes **"="**. Calculator operators are `+` and `-` only here (Settings > Calculator can enable x and divide).
5. Typing in the note brings up the system keyboard which pushes the panel up and covers the keypad; hide it with back, then press the check key.
6. **Date picker** (dialog): header "Sun, Oct 18, 2026"; "October 2026 v" month-year dropdown, prev/next chevrons, S-M-T-W-T-F-S grid (Sunday first, follows the calendar-start-day setting); selected day = yellow filled circle, today = yellow outline ring; **Cancel / Confirm** yellow text buttons.
7. **Save** = check key. After saving, the app returns to Home **in the month of the saved transaction** (saving a September item switched Home to Sep).
8. **Currency sheet** (`08_edit_currency_icon.png`, `08b_currency_edit_mode.png`): slide-up sheet, header with back, title "Currency", pencil (edit rates) and search icons. Row "Default currency  BDT (৳) Bangladeshi Taka >". Then radio list of currencies with manual rates: BDT (checked), USD "1 = BDT 123.1224", EUR 138.0262, GBP 163.2653, CNY 18.3688, JPY 0.7791, CAD 86.7303, AUD 85.1789, HKD 15.6863 ... Pencil enters an edit mode with a pencil per row to change the rate.
9. **Account sheet** (`09_account_picker.png`): bottom sheet "Accounts" with X and "+"; empty state "No records". "+" -> **Add account** form (`09b_account_add_form.png`, `09c_account_type_dropdown.png`): Account name; Type dropdown (**Default, Cash, Debit card, Credit card (Liabilities), Virtual account, Investment, Owes me / Receivables, I owe / Payables (Liabilities)**); Currency dropdown; Amount (opening balance, default 0); Icon grid (15 outline icons: cash stack, card with %, cards, $, GBP, EUR, PayPal, Bitcoin, money bag %, bank, chart %, phone wallet, wallet, piggy bank, safe) with the selected one yellow; **Exclude from totals** switch. Nothing was saved.

### 2.4 Recurring Transactions  (`15_schedule_screen.png`, `15b`-`15f`)

- Reached from the Add screen's schedule icon and from Settings > Recurring Transactions. Empty state "No records", yellow full-width "+ Add" button.
- **Add form** (yellow vertical bar before each label; fields on `#282828` rounded inputs; top-right check = Confirm): **Transaction name** ("Please enter the transaction name"); **Type** (Income / Expense / Transfer); **Category**; **Transaction frequency** (Daily, Weekly, Every two weeks, **Monthly** default, Every two months, Every three months, Every four months, Every six months - list scrolls, possibly more); **Transaction start date** (default today) with a preview line "Transaction date: Oct 18, 2026 . Nov 18, 2026 . Dec 18, 2026..."; helper text "Data is added automatically only on the transaction date you set. If you have allowed notification permission, you will receive reminder notifications as well."; **Amount (Every time)**; **Number of transactions** (Unlimited, 3, 6, 12, 18, 24, Customized); **Note**.

### 2.5 Charts  (`40_charts_default.png`, `41_charts_page2.png`, `42_charts_page3.png`, `43_chart_category_detail.png`, `44`-`48`)

- **Top:** centred 2-segment toggle **Expenses | Income** and, at right, a calendar-wave icon that opens the **period menu** (popup: Week, Month, Year, Period). The icon's accessibility name is the current period ("Month", "Week", "Year").
- **Period tab strip** (horizontally scrollable, yellow underline under the active tab, active text white, others grey): Month -> `..., Jul 2026, Aug 2026, Last Month, This Month`; Week -> `Week 40, Week 41, Last Week, This Week (Oct 18 - Oct 24)` (weeks start Sunday); Year -> `2022, 2023, 2024, Last Year, This Year`. **Period** opens a dialog "Start Time / End Time" (rows with chevrons, defaults Oct 1 - Oct 31, 2026, Cancel/Confirm) and then a dedicated page with back arrow, the same toggle, and a range header "Oct 1, 2026 ~ Oct 31, 2026".
- **Chart area (swipe carousel, 3 pages, dots below):**
  1. **Donut by category**: ring ~58 px thick, white 4 px gaps, total in the centre; legend at right: top 4 categories + "Other" with ring-style dots and %.
  2. **Donut by day**: same style, legend = top days ("Oct 7  (amount)") + "Other".
  3. **Line chart**: header "Total: (total) / Average: (average)" (average = total / days or months in period), Y axis auto-scaled (0 to (amount)), X labels "Oct 1, 15, 29" (month) or "Apr 2026, Aug, Dec" (year), thin grey axes, straight segments between daily points, every point is a filled dot in a cycling palette colour; page 3 is the one remembered when switching periods.
- **Category list below** (scrolls with the page): icon circle, name, amount (right), horizontal rounded progress bar in the category colour with the percentage right after the bar, hairline separators. Sorted by amount desc.
- **Category detail** (tap a list row; `43_chart_category_detail.png`): back arrow, category name, "Oct 2026 v" month dropdown; "Total: (total) / Average: (average)"; line chart for that category; section "Expenses" with a **Sort by amount | Sort by date** segmented control; list of the individual transactions (icon, category name, amount, bar + %, date line "Oct 4, 2026").
- Income toggle uses the same layout with income categories (Year 2026 showed Others (percent) and a pre-existing "(custom category)" (amount)).
- Month view donut/legend/list recalculated correctly when test data was added (Oct total (total) with tests, back to (total) after cleanup).

### 2.6 Reports  (`50_reports_default.png`, `51`-`57`)

- Top toggle **Analytics | Accounts**.
- **Analytics tab:** two rounded outlined cards (`#1E1E1E`, 1 px border): **Monthly Statistics - Oct** (Expenses / Income / Balance, chevron >) and **Monthly Budget** (Budget : 0, Expenses :, dashed divider, Remaining :, and a circular progress ring at right with "-- Budget Settings"). Statistics card opens the Balance overview (2.1). Budget card opens **Budget** (`53_budget_screen.png`): back arrow, "Oct 2026 v" month dropdown, a card with pencil icon, the same Budget/Expenses/Remaining numbers and ring, bottom yellow pill "+ Budget Settings".
- **Budget Settings** (`54_budget_settings_form.png`): list "Monthly Budget" then one row per expense category (icon, name, "Edit >"), each with a trash icon at the left. Tapping a row opens a **bottom keypad sheet** (`55_budget_monthly_edit.png`): label, outlined yellow-ish amount field "0", digit keys, a down-arrow key (hide), a trash key (clear), backspace, and a yellow check key. Nothing was saved.
- **Accounts tab** (`56_reports_accounts.png`): "Net Worth" big number with a faint money-bag illustration, two stat cards "Assets" and "Liabilities" (yellow bar label), buttons **Add Account** / **Manage Accounts** (-> list screen, empty "No records" + "Add").

### 2.7 Profile  (`60_profile.png`, `61_premium_page.png`, `63_garden.png`, `86_other_apps.png`, `87_recommend.png`)

- Header: round avatar, nickname (bold), "ID:(hidden)".
- Card 1: **Premium Member** (gold crown icon, bold) -> paywall. Card 2 rows (yellow line icons, chevrons): **Recommend to friends** (thumbs up; opens the Android share sheet with text "[Money Tracker] [Google Play] link / [App Store] link"), **Block Ads** (AD-crossed icon; same paywall), **Garden** (clover icon), **Settings** (hexagon-ring icon), **Our Other Apps** (APP icon, red dot badge).
- **Paywall "Go Premium"** (`61_premium_page.png`): dark sheet with illustration (coins, money bag, rising arrow), white card "Go Premium / Help you reach your financial goals faster" with three yellow check bullets ("Unlock everything and ad-free", "More beautiful themes, customizable", "Make your life easier"), price line **"BDT 599.00/Year  Cancel Anytime"**, big orange pill **Continue**, "Resume purchase", Terms of Use / Privacy Policy. Nothing was purchased.
- **Garden / "Lucky garden"** (`63_garden.png`): full-screen cartoon game (sky-blue gradient), counters for gems and suns, "+100 Ad reward" button, one active soil plot and two locked plots, a coin counter (amount) and watering can; eye-off and "?" icons top right. Ad-reward / engagement mini-game; irrelevant to a clone.
- **Our Other Apps:** vertical list of promo cards (iTask, MarketLens, Magic Quotes, Daily Horoscope).

### 2.8 Category settings  (`18_category_settings.png`, `18b_category_topright.png`, `18c`, `19_category_add_form.png`)

- Title "Category settings", top-right hierarchy icon -> **Subcategory Settings** (single switch "Subcategory", **VIP**). Segmented toggle **Expense | Income**. List rows: icon circle, name (ellipsised), grey "(Customized)" tag where the default was renamed/changed, **trash** icon, **pencil** icon, **drag handle** (reorder). Bottom yellow pill **+ Add category**. (Nothing edited or deleted.)
- **Add category form** (`19_category_add_form.png`): Cancel / "Add category" / check; radios **Expense | Income**; a coloured preview circle + name input "Please enter the category name..."; 16-colour swatch grid (see palette, selected has a white check); then icon pickers in titled sections: **Entertainment, Food, Shopping, Life, Personal, Education, Festival, Sports, Office, Transportation, Health, Travel, Finance, Others** (6 per row, ~110 px circular tiles; selected = filled with the chosen colour).

### 2.9 Settings  (`64_settings.png`, `64b`, `64c`, `64d`, `65`-`85`)

Grouped list (yellow line icons at left, chevrons at right, VIP pills where gated). Items in order:

| # | Item | What it does (verified by opening) | Gate |
|---|---|---|---|
| 1 | My Profile | Avatar, ID, Nickname, Gender, **Sign Out**, **Delete account** (not touched) | |
| 2 | Data Sharing | Explainer card; "Enter Invitation Code" + **Accept Invitation**; **Send Invitation**; tips | Send = VIP |
| 3 | Category settings | see 2.8 | Subcategory VIP |
| 4 | Default currency | opens Currency list (BDT; per-currency manual rates, see 2.3) | |
| 5 | Reminder | List (empty) + Add form: name (default "Reminder"), frequency (Daily...), start date, time (default 20:15), note default "Don't forget to add your spending for today." | |
| 6 | Recurring Transactions | see 2.4 | |
| 7 | Monthly Start Date | screen with row "Monthly Start Date = 1" (day-of-month a month starts) | **VIP** |
| 8 | Themes | 2-column preview cards: Follow the System, Default (yellow), **Dark (current, check)**, Orange, Blue, Green, Pink, Purple | colour themes **VIP** |
| 9 | Font Size | slider with 4 "A" stops, current 100 % | |
| 10 | Home page settings | see 2.1 | Hide total = VIP |
| 11 | My Cash Books | list of cashbooks, "No records", Add / Join | |
| 12 | Accounts | accounts list (empty) | |
| 13 | Budget | same as Reports budget | |
| 14 | Export Data | Start Time (default Oct 1), End Time (default today), **Export Data** button (not pressed) | |
| 15 | Import Transactions | "Supports CSV, Excel, PDF, JSON, and images"; share-to-app hint; **Choose file or image** | **VIP** |
| 16 | Auto Entry from Notifications | switch "Enable this feature - Monitors transaction alerts from other apps. After you confirm, AI parses and books them."; Blacklist button | **VIP** |
| 17 | Password | passcode lock switch | **VIP** |
| 18 | Notification Shortcut | switch (on) - ongoing-notification quick add | |
| 19 | Sound Effect | switch (on) | |
| 20 | Thousands separator | switch (on) | |
| 21 | Number display format | `1,234,568` / `1.234.567,89` / `1 234 567.89` / `1 234 567,89` | |
| 22 | Calculator | `+ -` or `+ - x /` | |
| 23 | Calendar | Calendar Settings: Show Calendar (switch), "Amount of daily income and expenditure" (switch), **Start day of the week** (Sunday current; options Monday / Saturday / Sunday) | |
| 24 | Icon | "Icon Style": two category-icon styles (pastel gradient vs solid saturated - solid is selected); "Add page icon styles": Monochrome (selected) / Colorful | |
| 25 | AI Settings | switches "AI Toolbar - Show AI shortcut on the Add Transaction page" and "AI Assistant - Show AI Assistant on the Home page" | |
| 26 | Delete all data | destructive (not touched) | |
| 27 | Automatically backed up data | status row with timestamp ("(date and time)") - an auto-backup runs (cloud/local not determined) | |
| 28 | Language | Follow the System, English, Chinese (Simplified/Traditional), Japanese, Korean, Russian, Albanian, Arabic, Spanish, Estonian ... (long list) | |
| 29 | API (Developer Tools) | opens the paywall | **VIP** |
| 30 | Help | opens the AI Assistant chat | |
| 31 | Terms of Use / Privacy Policy | web pages (not opened) | |
| 32 | About us | "Money Tracker - Version 1.1.147(357)" | |
| 33 | Feedback | modal "Feedback" with text area, **Submit**, **No, thanks** | |
| 34 | Clear cache | (not touched) | |

---

## 3. Feature checklist

**Transactions**
- [x] Add expense / income / transfer (transfer needs two accounts)
- [x] Category grid picker per type, "+" jump to category settings
- [x] Amount keypad with calculator (+, -; optional x, /), decimal point, backspace
- [x] Note (free text), photo/receipt capture (camera + gallery)
- [x] Per-transaction date via calendar dialog (default Today, can be past/future)
- [x] Per-transaction currency (top-right currency sheet with custom exchange rates)
- [x] Per-transaction account (optional, default account "Default")
- [x] Natural-language / voice smart entry (parses amount, category, note; saves immediately)
- [x] Edit and delete (detail screen buttons, long-press menu); delete confirm dialog
- [x] Created-at timestamp stored and shown in details
- [x] Recurring transactions (daily ... every six months, count limit, start date, reminder notifications)
- [x] Reminders (daily nudge, time, note)
- [ ] Split / shared cashbooks (Split free, others VIP) - only forms viewed
**Home / navigation**
- [x] Month navigation (picker + "previous month" pill), month summary strip, day-grouped list with per-day totals
- [x] Multi-cashbook switcher (Default, Split, Project, Team, Business; join by invitation code)
- [x] Total-balance overview with year filter and per-month table
- [x] Calendar view with per-day income/expense totals and day drill-down
- [x] AI Assistant chat (analyse spending, look up transactions, how-to)
**Analysis**
- [x] Charts: Expenses/Income, Week/Month/Year/custom Period, previous-period tabs, donut by category, donut by day, daily/monthly line chart, average, category ranking with %, category drill-down with sort by amount/date
- [x] Budgets: monthly total and per-category, remaining, ring gauge
- [x] Accounts report: net worth, assets, liabilities; account types incl. credit card/payables as liabilities; exclude-from-totals flag
**Data & settings**
- [x] Export (date range), import (CSV/Excel/PDF/JSON/images, VIP), automatic backup, delete all data
- [x] Currency list with custom rates, number-format options, thousands separator, font size, themes, icon styles, language (many), calendar start day, calculator mode, sound, notification shortcut
- [x] Passcode (VIP), auto-entry from notifications (VIP), data sharing between two users (VIP to send)
- [x] Sign out / delete account, profile (avatar, nickname, gender, ID)

---

## 4. Inferred data model

```
Transaction
  id, cashbookId
  type: EXPENSE | INCOME | TRANSFER
  amount: decimal (>0; sign derived from type), currencyCode (default BDT), exchangeRate? 
  categoryId (EXPENSE/INCOME)      | fromAccountId, toAccountId (TRANSFER)
  accountId? (optional, default "Default")
  date: date (user chosen)         | createdAt: timestamp ("Oct 18, 2026 01:24:04 Add")
  note?: string                    | photos[]?: attachment refs
  recurringId?: ref to Recurring item that generated it
Category
  id, type: EXPENSE|INCOME, name, colorHex (16 swatches), iconKey (grouped by section),
  sortOrder (drag handle), isCustomized (shows "(Customized)"), parentId? (subcategories, VIP)
Account
  id, name, type: DEFAULT|CASH|DEBIT_CARD|CREDIT_CARD(liability)|VIRTUAL|INVESTMENT|RECEIVABLE|PAYABLE(liability),
  currencyCode, openingBalance, iconKey, excludeFromTotals: bool
Budget
  id, month (yyyy-MM), scope: TOTAL | CATEGORY(categoryId), amount, (derived) spent, remaining
RecurringTransaction
  id, name, type: INCOME|EXPENSE|TRANSFER, categoryId, frequency: DAILY|WEEKLY|BIWEEKLY|MONTHLY|EVERY_2/3/4/6_MONTHS,
  startDate, amount, occurrences: UNLIMITED|3|6|12|18|24|CUSTOM, note, nextRunDate
Reminder
  id, name, frequency, startDate, timeOfDay (HH:mm, default 20:15), note, enabled
Currency
  code, symbol, name, rateToDefault (manual), isDefault
Cashbook
  id, name, type: PERSONAL|SPLIT|GENERAL(project/team/business templates), currency, note, memberIds[], invitationCode
UserSettings
  theme (system/default/dark/orange/blue/green/pink/purple), fontScale (100 %), language, defaultCurrency,
  numberFormat, thousandsSeparator, calculatorMode (+- | +-x/), weekStartDay (Sun/Mon/Sat), monthStartDay (1, VIP),
  showCalendar, showDailyTotalsOnCalendar, homeBalanceMode (monthly|total), hideTotal (VIP),
  categoryIconStyle (2 options), addPageIconStyle (mono|colour), aiToolbar, aiAssistant, soundEffect,
  notificationShortcut, passcode (VIP), autoEntryFromNotifications (VIP), lastUsedAddTab
Profile
  userId, nickname, gender, avatar
```

Computation rules observed: Home Balance = Income - Expenses for the month; Budget remaining = Budget - Expenses; line-chart average = total / days (month view) or / months (year view); category % = category total / period total (2 decimals).

---

## 5. Premium / ad-related items

**VIP (premium) gated** (yellow "VIP" pill): Hide total amount on homepage; Project / Team / Business cashbooks and "General Cashbook" type; Subcategory; Monthly Start Date; non-default themes (Orange, Blue, Green, Pink, Purple); Import Transactions; Auto Entry from Notifications; Password; Data Sharing > Send Invitation; API (Developer Tools) (opens paywall). Paywall = "Go Premium", **BDT 599.00 / year**, "Unlock everything and ad-free", orange Continue button, Resume purchase.

**Ads / monetisation:** native/banner ad in Transaction Details (WebView, bottom), banner ad in Calendar, "Block Ads" row in Profile, "Garden" mini-game with "Ad reward +100", "Our Other Apps" cross-promotion with a red-dot badge, "Recommend to friends" share. A clone does not need any of these.

---

## 6. Test-data log and cleanup proof

All test items were created through the app's own UI and deleted one by one after verifying the open item matched the log (type, category, amount, date, note, created-at time). Created at Oct 18 2026 ~01:24-01:27 phone time.

| # | Type | Category | Amount | Date | Note | How created | Deleted |
|---|---|---|---|---|---|---|---|
| T1 | Expense | Groceries | 111 | Oct 18 2026 | ZZTEST_1 | Add > Groceries tile > keypad 1-1-1 > note > check | yes |
| T2 | Expense | Gas | 222 | Oct 12 2026 | ZZTEST_2 | tile > 222 > date picker (12) > note; also exercised "222 + 1" then backspaced | yes |
| T3 | Income | Others | 333 | Oct 18 2026 | ZZTEST_3 | Income tab > Others > 333 > note | yes |
| T4 | Expense | Health | 444 | Sep 20 2026 | ZZTEST_4 | tile > 444 > date picker prev-month > Sep 20 > note | yes |
| T5 | Expense | Snacks (auto) | 555 | Oct 18 2026 | "snacks" (ZZTEST token dropped by parser) | bottom AI bar > "ZZTEST snacks 555" > Confirm | yes |

No Transfer was created (no accounts exist; none were created).

**Baseline (recorded before any test item was created):**
- Oct 2026: Expenses **(total)**, Income **(total)**, Balance **(total)**. Day groups: Oct 15 (amount), 14 (amount), 13 (amount), 11 (amount), 10 (amount), 8 (amount), 7 (amount), 6 (amount), 5 (amount), 4 (amount), 3 (amount), 2 (amount), 1 (amount). No Oct 18 or Oct 12 group existed.
- Sep 2026: Expenses **(total)**, Income **(total)**, Balance **(total)**; Sep 20 group expenses = (amount) (derived: (total) with T4 minus 444).
- All-time Balance overview: Total balance **(total)**, Expenses **(total)**, Income **(total)**.

**With all five test items present:** Oct (total) / (total) / (total); Sep (total) / (total) / (total); all-time (total) / (total) / (total).

**After cleanup (verified on screen):**
- Oct 2026: **(total) / (total) / (total)** (day groups identical, no Oct 18/12 groups) - `95_home_after_cleanup.png`
- Sep 2026: **(total) / (total) / (total)**, Sep 20 group back to **(amount)**, no ZZTEST row.
- All-time: **(total) / (total) / (total)** - `96_overview_after_cleanup.png`

One near-miss: while locating T4 the list auto-scrolled and a tap opened a pre-existing item (Transportation (amount), Sep 15). It was left immediately with Back and not edited or deleted; Sep totals confirm nothing changed.

Other things changed on the phone: none intentionally. Charts period was switched to Year/Period and restored to Month/Expenses; Home month was switched to Sep and back to Oct; no settings, categories, accounts or budgets were saved or changed.

---

## 7. Not reached or not verified

- Transfer between accounts and account creation (no accounts exist; forms viewed only, nothing saved). Account detail/balance screens therefore unseen.
- Cashbook creation/join and the "Split Cashbook" flows (forms only); Project/Team/Business templates.
- Voice input (mic permission off), the Add screen's bottom "Close (x)" icon (might toggle the AI toolbar setting, so not pressed), the camera-captured receipt flow after a photo is taken, the gallery picker.
- VIP-gated screens beyond their landing page: themes other than Dark, Monthly Start Date options, subcategories, passcode set-up, import preview, notification auto-entry blacklist, send-invitation flow.
- Terms of Use / Privacy Policy web pages, Help content (opens the AI chat; no questions were sent), AI answers, feedback submission.
- Light/"Default" (yellow) theme appearance (only seen as a swatch).
- Recurring-frequency list may have more entries than the eight seen (list scrolls); per-category budget edit forms (same keypad sheet as the monthly one); "Number of transactions > Customized" input.
- Backup/restore screens: only an "Automatically backed up data" status row exists in Settings; no backup/restore UI was opened.
- Garden mini-game mechanics, sign out, delete account, delete all data, clear cache (deliberately not touched).
- Home's animated AI/search icon: both states have the same label and opened the AI Assistant; whether the magnifier state ever opens a transaction search was not confirmed.
- Charts week view was only read via the UI dump (`45_charts_week.png` not inspected visually), same layout assumed.
