# 💸 Spill the Bills

**A simple, private expense tracker for Android.**

Write down what you spend. See where your money goes. Everything stays on your own phone. No account, no ads, no internet.

<p align="center">
  <img src="docs/screenshots/home.png" width="200" alt="Home: this month's expenses, day by day">
  <img src="docs/screenshots/add.png" width="200" alt="Add expense: pick a category and type the amount on the keypad">
  <img src="docs/screenshots/calendar.png" width="200" alt="Calendar: a month with the total for each day">
  <img src="docs/screenshots/charts.png" width="200" alt="Charts: a ring of spending by category, with a ranking">
</p>
<p align="center">
  <img src="docs/screenshots/reports.png" width="200" alt="Reports: all-time total and a table of every month">
  <img src="docs/screenshots/pockets.png" width="200" alt="Pockets: switch between Personal, Business and Family trip">
  <img src="docs/screenshots/themes.png" width="200" alt="Settings: choose a colour theme and a text size">
  <!--
    LIGHT THEME PICTURE (to add later): put the new file at
    docs/screenshots/light.png, then add this line right here:
    <img src="docs/screenshots/light.png" width="200" alt="The light theme">
  -->
</p>

## ✨ What you can do

- ⚡ **Add an expense in seconds.** Pick a category, type the amount on the keypad, done. The keypad has a built-in calculator, so you can type `120 + 30`.
- ⌨️ **Or just type a sentence.** Write something like `coffee 120` or `250 taxi`. The app finds the amount, the title and the category. If it meets a new word, you pick the category once, and it remembers next time.
- 🎨 **Colourful emoji categories.** Add your own, change them, and put them in the order you like.
- 📅 **Calendar.** See the whole month with the total for each day. Tap a day to see what you spent.
- 📊 **Charts.** Look at a week, a month, a year, or any dates you choose. See your spending by category, your biggest days, or how it changes over time.
- 🧾 **Reports.** See your all-time total, your average month, and a table of every month. Pick a year to see it at a glance.
- 👛 **Pockets.** Keep money apart, for example Home, Trip and Work. Each pocket has its own expenses. You can move an expense to another pocket later.
- 📷 **Receipt photos.** Add a photo to an expense, from the camera or from your gallery.
- 📤 **Export and import.** Save your expenses as an Excel or CSV file. Bring expenses in from a CSV, Excel or JSON file.
- 🎭 **Three colour themes,** each in dark and light.
- 🔠 **Text size you can change,** so it is easy to read.
- 🙈 **Hide the total.** Turn on Privacy hide to cover the big number until you tap the eye.
- 🔢 **Numbers your way.** Choose how numbers look, like 1,234.50 or 1.234,50.

## 🔒 Private by design

- 🚫 **No account.** You never sign up or log in.
- 🧼 **No ads and no tracking.**
- 📴 **Works fully offline.** The app never connects to the internet. It does not even have permission to.
- 📱 **Your data stays on your phone.** Nobody else can see it.

## 📲 How to install

You do not need the Play Store. You download one file and open it.

1. 🌐 On your phone, open the **[Releases page](https://github.com/shoeb-gg/Expense-Tracker/releases/latest)**.
2. ⬇️ Under **Assets**, tap `Spill-the-Bills-<version>.apk` to download it. It is about 20 MB and works on most phones. (`<version>` is a number like 1.0.0.)
3. 🔁 If your phone says the app can't be installed, download `Spill-the-Bills-<version>-all-phones.apk` instead. It is about 60 MB and works on every Android phone.
4. 📂 Open the file you downloaded. Your phone may find it in the notification, in your browser's downloads, or in the Files app.
5. ✅ When Android asks, allow installs from this source (this is usually your browser or Files app). Then tap **Install**.
6. 🎉 Open **Spill the Bills** and add your first expense.

**⚠️ Android may show a warning.** That is normal. It happens because the app does not come from the Play Store. The app is safe to install if you got it from the Releases page above.

**📋 What you need:** a phone with **Android 7 or newer**.

## 🔄 Updating

Download the newer file from the [Releases page](https://github.com/shoeb-gg/Expense-Tracker/releases/latest) and install it over the old app. Your expenses stay. Tip: choose the same kind of file as the first time (the smaller one or the `all-phones` one).

## 💾 Keeping your data safe

Your expenses live only on your phone. That is great for privacy, but it also means you are the one who keeps them safe.

- 🕒 **Automatic backup is not here yet.** It is coming later.
- 📤 **For now, export now and then.** Go to **Settings → Export** and save the file somewhere safe, like your email or a cloud drive.
- 📥 **To get your data back,** go to **Settings → Import** and pick that file.
- ⚠️ **Uninstalling the app deletes its data.** Export first if you want to keep your expenses.

## ❓ Questions

**💰 Is it free?**
Yes. There are no ads and nothing to buy.

**📴 Does it need the internet?**
No. It works fully offline.

**🍎 Is there an iPhone version?**
Not yet. It is Android only for now.

**💱 Why are there no currency symbols?**
On purpose. The app shows plain numbers, so you can use it with any money.

## 🛠️ For developers

Spill the Bills is a [Flutter](https://flutter.dev) app (Flutter 3.38, Dart 3.10). The code is in the [`app`](app) folder. The data is kept in a local SQLite database. There is more about the design choices in [`ARCHITECTURE.md`](ARCHITECTURE.md).

```bash
cd app
flutter pub get
flutter run          # run on a phone or emulator
flutter test         # run all the tests
```

**Release builds** (both APKs, in `app/build/release/`):

```bash
cd app
pwsh tool/release.ps1
```

This needs the `android/key.properties` file, which is kept out of git. Without it, release builds are signed with the debug key, and such a build can't update an app that was signed with the real key.

**Check a download is genuine.** Releases are signed with one permanent key. The SHA-256 fingerprint of its certificate is:

```
34:F3:F8:0F:26:D8:43:AC:40:94:F4:C8:8C:E7:F3:F0:66:E3:D8:A4:94:70:5D:9B:33:72:DE:4C:78:71:4D:FA
```

To see the fingerprint of a downloaded file, run `apksigner verify --print-certs <file>.apk` (from the Android SDK build-tools) and compare the `certificate SHA-256 digest` line. It is shown without the colons.

**Update the README pictures.** The screenshots in `docs/screenshots/` come from a test. Run it from the `app` folder:

```bash
flutter test --dart-define=README_SHOTS=true test/shots/readme_shots_test.dart
```
