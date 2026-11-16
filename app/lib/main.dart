import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/db.dart';
import 'data/maintenance.dart';
import 'data/photo_store.dart';
import 'data/settings_store.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final db = AppDatabase();
  final settings = await AppSettings.load(SettingsStore(db));
  SystemChrome.setSystemUIOverlayStyle(
    systemBarsStyle(
      settings.mood,
      brightness: startBrightness(
        settings.themeMode,
        PlatformDispatcher.instance.platformBrightness,
      ),
    ),
  );

  runApp(
    ProviderScope(
      // A failing provider shows its error instead of retrying silently.
      retry: (_, _) => null,
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const SpillTheBillsApp(),
    ),
  );

  // Receipt photos of expenses deleted in an earlier session can no longer
  // be restored with Undo; remove them quietly.
  unawaited(
    DataMaintenance(
      db,
      photos: PhotoStore(baseDir: getApplicationDocumentsDirectory),
      cacheDir: getTemporaryDirectory,
    ).purgeOrphanPhotos().then((_) {}, onError: (Object _) {}),
  );
}
