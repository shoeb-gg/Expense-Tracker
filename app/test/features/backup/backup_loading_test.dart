import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spill_the_bills/backup/drive_auth.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/backup.dart';

import '../../support/fake_drive.dart';
import '../../support/shots.dart';

class _Auth implements DriveAuth {
  _Auth(this.drive);
  final FakeDrive drive;
  @override
  Future<String> signIn() async => 'me@example.com';
  @override
  Future<String?> token(String email, {required bool interactive}) => drive.token();
  @override
  Future<void> forgetToken(String token) async {}
  @override
  Future<void> signOut() async {}
}

/// Opening the restore list takes a moment (Drive is online): the row says
/// so with a spinner instead of looking stuck (the user, 2026-11-19).
void main() {
  testWidgets('the restore row shows a spinner while the backups load', (tester) async {
    await loadShotFonts();
    final db = await sampleDatabase(tester);
    final drive = FakeDrive();
    final gate = Completer<void>();
    final slow = MockClient((r) async {
      await gate.future;
      final copy = http.Request(r.method, r.url)
        ..headers.addAll(r.headers)
        ..bodyBytes = r.bodyBytes;
      return http.Response.fromStream(await drive.client.send(copy));
    });
    await pumpApp(
      tester,
      db: db,
      location: Routes.backup,
      overrides: [
        initialBackupStateProvider.overrideWithValue(BackupState(email: 'me@example.com', lastBackupAt: DateTime(2026, 10, 18, 9))),
        driveAuthProvider.overrideWithValue(_Auth(drive)),
        driveHttpProvider.overrideWithValue(slow),
      ],
    );
    await tester.tap(find.text('Restore from a backup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Loading your'), findsOneWidget);

    gate.complete();
    // Two Drive calls (find the folder, list it) on real time.
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('No backups in your Google'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester, db);
  });

  testWidgets('the Account card offers to change the account', (tester) async {
    await loadShotFonts();
    final db = await sampleDatabase(tester);
    await pumpApp(
      tester,
      db: db,
      location: Routes.backup,
      overrides: [
        initialBackupStateProvider.overrideWithValue(BackupState(email: 'me@example.com', lastBackupAt: DateTime(2026, 10, 18, 9))),
      ],
    );
    expect(find.text('Change account'), findsOneWidget);
    await closeApp(tester, db);
  });
}
