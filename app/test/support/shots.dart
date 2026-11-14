/// Screenshot harness: renders the real app at 360 x 780 logical px, device
/// pixel ratio 2, with the real fonts, the mockup sample data and today
/// pinned to 18 Oct 2026 10:18, and writes PNGs to `build/shots/<name>.png`.
///
/// ```dart
/// @Tags(['shots'])
/// library;
///
/// void main() {
///   setUpAll(loadShotFonts);
///   testWidgets('home', (tester) async {
///     final db = await sampleDatabase(tester);
///     await pumpApp(tester, db: db, location: '/');
///     await takeShot(tester, 'home_default');
///     await closeApp(tester, db);
///   });
/// }
/// ```
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/app.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/photo_store.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';

import 'sample_data.dart';
import 'test_db.dart';

/// Font family name the emoji font is loaded under (see [loadShotFonts]).
const String shotEmojiFamily = 'ShotEmoji';

/// Candidate colour emoji fonts, best first. Windows' Segoe UI Emoji is a
/// COLR colour font that Flutter's test renderer draws in colour.
const List<String> _emojiFonts = [
  r'C:\Windows\Fonts\seguiemj.ttf',
  '/System/Library/Fonts/Apple Color Emoji.ttc',
  '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
];

const Key _boundaryKey = ValueKey<String>('shot-boundary');
bool _fontsLoaded = false;

/// Loads Plus Jakarta Sans (500-800) from the app's assets, Material
/// Symbols Rounded from the material_symbols_icons package, and a colour
/// emoji font from the system as [shotEmojiFamily]. Call in `setUpAll`.
Future<void> loadShotFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_fontsLoaded) return;
  final jakarta = FontLoader('PlusJakartaSans');
  for (final w in ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jakarta.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await jakarta.load();

  final symbols = FontLoader('packages/material_symbols_icons/MaterialSymbolsRounded')
    ..addFont(
      rootBundle.load(
        'packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
      ),
    );
  await symbols.load();

  for (final path in _emojiFonts) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      final emoji = FontLoader(shotEmojiFamily)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await emoji.load();
      break;
    }
  }
  _fontsLoaded = true;
}

/// A fresh test database filled with the mockup sample data (in the
/// default "Personal" pocket).
Future<AppDatabase> sampleDatabase(WidgetTester tester) async {
  final db = openTestDatabase();
  await tester.runAsync(() => fillSampleData(db));
  return db;
}

/// Pumps the whole app (router, theme, providers) on [location] at
/// 360 x 780 px, DPR 2, with today pinned to 18 Oct 2026 10:18.
/// [settings] are the stored settings; [overrides] are added last.
Future<void> pumpApp(
  WidgetTester tester, {
  required AppDatabase db,
  String location = Routes.home,
  AppSettings settings = const AppSettings(),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(720, 1560);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  // flutter_test draws shadows without blur by default; shots need real
  // shadows. closeApp() switches this back (flutter_test checks it).
  debugDisableShadows = false;
  addTearDown(() => debugDisableShadows = true);
  final temp = Directory.systemTemp.createTempSync('stb_shot_');
  addTearDown(() => temp.deleteSync(recursive: true));
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(Clock.fixed(mockupNow)),
          initialSettingsProvider.overrideWithValue(settings),
          fontFallbackProvider.overrideWithValue(const [shotEmojiFamily]),
          routerProvider.overrideWithValue(
            buildRouter(initialLocation: location),
          ),
          documentsDirProvider.overrideWithValue(() async => temp),
          cacheDirProvider.overrideWithValue(
            () async => Directory(p.join(temp.path, 'cache'))..createSync(),
          ),
          photoStoreProvider.overrideWithValue(
            PhotoStore(baseDir: () async => temp),
          ),
          ...overrides,
        ],
        child: const SpillTheBillsApp(),
      ),
    ),
  );
  await settle(tester);
}

/// Lets database queries finish and animations end.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Writes the current frame to `build/shots/<name>.png` (720 x 1560).
Future<File> takeShot(WidgetTester tester, String name) async {
  await settle(tester);
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  final file = File(p.join('build', 'shots', '$name.png'));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
  return file;
}

/// Unmounts the app and closes the database (call at the end of a test).
Future<void> closeApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.runAsync(db.close);
  debugDisableShadows = true;
}
