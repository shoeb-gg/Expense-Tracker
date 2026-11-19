/// The screenshots in the README (`docs/screenshots/*.png` at the repo root).
///
/// Every screen is the real app on a 360 x 800 dp phone at pixel ratio 3
/// (1080 x 2400 px), drawn with the real fonts and a colour emoji font, then
/// scaled down to 540 px wide so the files stay small.
///
/// These files are tracked in git, so a normal `flutter test` does NOT touch
/// them: it renders the same screens into `build/shots/readme/` (git-ignored).
/// To refresh the README pictures, run from the `app` folder:
///
/// ```
/// flutter test --dart-define=README_SHOTS=true test/shots/readme_shots_test.dart
/// ```
///
/// To add a screen, add one more entry to [_scenes] below.
@Tags(['shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/budgets_repo.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/features/home/pocket_button.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/backup.dart';
import 'package:spill_the_bills/state/providers.dart';

import '../support/add_support.dart';
import '../support/board.dart' show settleFor;
import '../support/pocket_samples.dart';
import '../support/shots.dart';

/// True when the run should write into `docs/screenshots/` (the repo root).
const bool _writeToDocs = bool.fromEnvironment('README_SHOTS');

/// Phone size in logical px, and the pixel ratio it is drawn at.
const Size _phone = Size(360, 800);
const double _ratio = 3;

/// Width of the saved pictures, in px (the height follows the phone shape).
const int _savedWidth = 540;

/// The phone's status bar height, so headers sit below it as on a real phone.
const double _statusBar = 28;

/// Where this run writes its pictures, relative to the `app` folder.
final String _outDir = _writeToDocs
    ? p.join('..', 'docs', 'screenshots')
    : p.join('build', 'shots', 'readme');

/// Gets the app on the screen: a [Scene] sets up its data, calls this and
/// then drives the app to the state that is drawn.
typedef Scene = Future<void> Function(WidgetTester tester, AppDatabase db);

/// One README picture: the file name (without `.png`) and its [Scene].
typedef Shot = ({String name, Scene scene});

/// Opens the app on [location] at README phone size.
Future<void> _open(
  WidgetTester tester,
  AppDatabase db, {
  String location = Routes.home,
  AppSettings settings = const AppSettings(),
  List<Override> overrides = const [],
}) async {
  await pumpApp(tester, db: db, location: location, settings: settings, overrides: overrides);
  tester.view
    ..physicalSize = _phone * _ratio
    ..devicePixelRatio = _ratio
    ..padding = const FakeViewPadding(top: _statusBar * _ratio)
    ..viewPadding = const FakeViewPadding(top: _statusBar * _ratio);
  await tester.pump();
  await settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settle(tester);
}

/// Scrolls the screen's main list down by [dp] logical px.
Future<void> _scroll(WidgetTester tester, double dp) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, -dp));
  await settle(tester);
}

/// Taps the keypad keys in [typed] (separated by spaces).
Future<void> _keys(WidgetTester tester, String typed) async {
  for (final k in typed.split(' ')) {
    await tester.tap(find.text(k).last);
    await tester.pump();
  }
  await settle(tester);
}

/// Every picture of the README, in the order they appear there.
///
/// Add new ones at the end (or where they belong). The light-theme picture
/// is Home in Aqua light: the `light` setting is passed to [_open].
final List<Shot> _scenes = <Shot>[
  (
    name: 'home',
    scene: (tester, db) async {
      await _open(tester, db);
      expect(find.text('Doctor visit'), findsOneWidget);
    },
  ),
  (
    name: 'add',
    scene: (tester, db) async {
      await _open(tester, db, location: Routes.add());
      await _tap(tester, find.text('Snacks').first);
      await _keys(tester, '1 2 0 + 3 0');
      await tester.enterText(find.byType(EditableText).first, 'Coffee');
      await hideKeyboard(tester);
      expect(find.text('150'), findsOneWidget);
    },
  ),
  (
    name: 'calendar',
    scene: (tester, db) async {
      await _open(tester, db, location: Routes.calendar());
      expect(find.text('34,555 spent'), findsOneWidget);
    },
  ),
  (
    name: 'charts',
    scene: (tester, db) async {
      await _open(tester, db, location: Routes.charts);
      expect(find.text('34,555'), findsWidgets);
      await _scroll(tester, 168);
    },
  ),
  (
    name: 'reports',
    scene: (tester, db) async {
      await _open(tester, db, location: Routes.reports);
      expect(find.text('1,090,360'), findsOneWidget);
      await _scroll(tester, 585);
    },
  ),
  (
    name: 'pockets',
    scene: (tester, db) async {
      await tester.runAsync(() => addMockupPockets(db));
      await _open(tester, db);
      await _tap(tester, find.byType(PocketButton));
    },
  ),
  (
    name: 'themes',
    scene: (tester, db) async {
      await _open(tester, db, location: Routes.settings);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Color theme'), findsOneWidget);
    },
  ),
  (
    name: 'light',
    scene: (tester, db) async {
      await _open(
        tester,
        db,
        settings: const AppSettings(themeMode: AppThemeMode.light),
      );
      expect(find.text('Doctor visit'), findsOneWidget);
    },
  ),
  (
    name: 'budgets',
    scene: (tester, db) async {
      await tester.runAsync(() => _addSampleBudgets(db));
      await _open(tester, db, location: Routes.add());
    },
  ),
  (
    name: 'backup',
    scene: (tester, db) async {
      await _open(
        tester,
        db,
        location: Routes.backup,
        overrides: [
          initialBackupStateProvider.overrideWithValue(
            BackupState(email: 'you@gmail.com', lastBackupAt: DateTime(2026, 10, 18, 9, 2)),
          ),
        ],
      );
      expect(find.text('Backed up'), findsOneWidget);
    },
  ),
];

/// October budgets for a few categories of the sample data, so the rings
/// show every colour: Snacks 30% and Groceries 60% (green), Transportation
/// 94% (yellow), House Rent over (red).
Future<void> _addSampleBudgets(AppDatabase db) async {
  final pocket = (await PocketsRepo(db).defaultPocket()).id;
  final cats = await CategoriesRepo(db).all();
  for (final (name, share) in [('Snacks', 0.30), ('Groceries', 0.60), ('Transportation', 0.94), ('House Rent', 1.15)]) {
    final id = cats.firstWhere((c) => c.name == name).id;
    final spent = await ExpensesRepo(db).categoryTotal(pocket, id, dayOf(2026, 10, 1), dayOf(2026, 10, 31));
    if (spent == 0) continue;
    // A round budget near spent / share.
    final budget = ((spent / share) / 10000).round() * 10000;
    await BudgetsRepo(db).set(pocket, id, budget);
  }
}

/// Draws the phone and writes `<name>.png`, [_savedWidth] px wide.
Future<File> _save(WidgetTester tester, String name) async {
  await settle(tester);
  await settleFor(tester, rounds: 3);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey<String>('shot-boundary')),
  );
  final file = File(p.join(_outDir, '$name.png'));
  await tester.runAsync(() async {
    final full = await boundary.toImage(pixelRatio: _ratio);
    // Halving exactly: each saved pixel is the average of 2 x 2 drawn ones.
    final height = (full.height * _savedWidth / full.width).round();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      full,
      Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
      Rect.fromLTWH(0, 0, _savedWidth.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final small = await recorder.endRecording().toImage(_savedWidth, height);
    final data = await small.toByteData(format: ui.ImageByteFormat.png);
    full.dispose();
    small.dispose();
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
  return file;
}

void main() {
  setUpAll(loadShotFonts);

  for (final shot in _scenes) {
    testWidgets('README picture: ${shot.name}', (tester) async {
      final db = await sampleDatabase(tester);
      await shot.scene(tester, db);
      final file = await _save(tester, shot.name);
      expect(file.existsSync(), isTrue);
      await closeApp(tester, db);
    });
  }
}
