/// Pictures of the Google Drive backup screens, for review. Only drawn when
/// the run says so:
///
/// ```
/// flutter test --dart-define=BACKUP_SHOTS_DIR=<folder> test/shots/backup_shots_test.dart
/// ```
@Tags(['shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/backup/drive_auth.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/backup.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/board.dart';
import '../support/fake_drive.dart';
import '../support/shots.dart';

const String _dir = String.fromEnvironment('BACKUP_SHOTS_DIR');
const bool _enabled = _dir != '';

Future<void> _save(WidgetTester tester, String name) async {
  await settle(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey<String>('shot-boundary')));
  final file = File(p.join(_dir, '$name.png'));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

class _Auth implements DriveAuth {
  _Auth(this.drive);
  final FakeDrive drive;
  @override
  Future<String> signIn() async => 'shoeb.ua@gmail.com';
  @override
  Future<String?> token(String email, {required bool interactive}) => drive.token();
  @override
  Future<void> forgetToken(String token) async {}
  @override
  Future<void> signOut() async {}
}

FakeDrive _driveWithBackups() {
  final drive = FakeDrive();
  drive.folders['folder-1'] = 'Spill the Bills backups';
  for (final (i, ago) in [Duration.zero, const Duration(days: 1), const Duration(days: 2, hours: 3)].indexed) {
    drive.files['file-$i'] = FakeDriveFile(
      'Spill the Bills backup $i.zip',
      'folder-1',
      List<int>.filled(4400000 - i * 30000, 0),
      DateTime(2026, 10, 18, 9, 2).subtract(ago).toUtc(),
      {'expenses': '${1266 - i * 7}'},
    );
  }
  return drive;
}

void main() {
  setUpAll(loadShotFonts);

  Future<AppDatabase> open(
    WidgetTester tester,
    BackupState state, {
    AppSettings settings = const AppSettings(),
    String location = Routes.backup,
  }) async {
    final db = await sampleDatabase(tester);
    final drive = _driveWithBackups();
    await pumpApp(
      tester,
      db: db,
      location: location,
      settings: settings,
      overrides: [
        initialBackupStateProvider.overrideWithValue(state),
        driveAuthProvider.overrideWithValue(_Auth(drive)),
        driveHttpProvider.overrideWithValue(drive.client),
      ],
    );
    await boardHeight(tester, 791);
    return db;
  }

  const signedOut = BackupState();
  final signedIn = BackupState(email: 'shoeb.ua@gmail.com', lastBackupAt: DateTime(2026, 10, 18, 9, 2));
  final failed = BackupState(
    email: 'shoeb.ua@gmail.com',
    lastBackupAt: DateTime(2026, 10, 18, 7, 40),
    lastError: 'No internet connection.',
  );
  final again = BackupState(
    email: 'shoeb.ua@gmail.com',
    lastBackupAt: DateTime(2026, 10, 15, 8, 30),
    lastError: 'Google asked to sign in again.',
    needsSignIn: true,
  );

  final themes = <String, AppSettings>{
    'dark_aqua': const AppSettings(),
    'light_iris': const AppSettings(mood: Mood.iris, themeMode: AppThemeMode.light),
  };

  for (final MapEntry(key: theme, value: settings) in themes.entries) {
    testWidgets('backup: signed out, $theme', (tester) async {
      final db = await open(tester, signedOut, settings: settings);
      await _save(tester, 'signed_out_$theme');
      await closeApp(tester, db);
    }, skip: !_enabled);

    testWidgets('backup: signed in, $theme', (tester) async {
      final db = await open(tester, signedIn, settings: settings);
      await _save(tester, 'signed_in_$theme');
      await closeApp(tester, db);
    }, skip: !_enabled);
  }

  testWidgets('backup: last try failed', (tester) async {
    final db = await open(tester, failed);
    await _save(tester, 'failed_dark_aqua');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('backup: sign in again', (tester) async {
    final db = await open(tester, again);
    await _save(tester, 'sign_in_again_dark_aqua');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('backup: the restore sheet and the question', (tester) async {
    final db = await open(tester, signedIn);
    await tester.tap(find.text('Restore from a backup'));
    await settle(tester);
    await _save(tester, 'restore_sheet_dark_aqua');
    await tester.tap(find.text('Yesterday, 9:02 AM'));
    await settle(tester);
    await _save(tester, 'restore_confirm_dark_aqua');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('backup: largest text, signed in and out', (tester) async {
    final big = AppSettings(textScale: textScaleSteps.last);
    var db = await open(tester, signedIn, settings: big);
    await _save(tester, 'signed_in_largest');
    await closeApp(tester, db);
    db = await open(tester, signedOut, settings: big);
    await _save(tester, 'signed_out_largest');
    await closeApp(tester, db);
  }, skip: !_enabled);

  testWidgets('backup: the Settings row', (tester) async {
    final db = await open(tester, signedIn, location: Routes.settings);
    await revealRow(tester, find.text('Google Drive backup'));
    await _save(tester, 'settings_row_dark_aqua');
    await closeApp(tester, db);
  }, skip: !_enabled);
}
