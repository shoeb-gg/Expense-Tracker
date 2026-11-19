import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/backup/backup_service.dart';
import 'package:spill_the_bills/backup/drive_auth.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/data/photo_store.dart';
import 'package:spill_the_bills/data/pockets_repo.dart';
import 'package:spill_the_bills/data/settings_store.dart';
import 'package:spill_the_bills/state/backup.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/fake_drive.dart';
import '../support/test_db.dart';

/// Google sign-in without Google.
class FakeAuth implements DriveAuth {
  FakeAuth(this.drive);

  final FakeDrive drive;
  Object? signInError;
  bool silentWorks = true;
  int signIns = 0;
  bool signedOut = false;

  @override
  Future<String> signIn() async {
    signIns++;
    final e = signInError;
    if (e != null) throw e;
    return 'me@example.com';
  }

  @override
  Future<String?> token(String email, {required bool interactive}) async =>
      interactive || silentWorks ? drive.token() : null;

  @override
  Future<void> forgetToken(String token) async {}

  @override
  Future<void> signOut() async => signedOut = true;
}

void main() {
  late Directory temp;
  late AppDatabase db;
  late FakeDrive drive;
  late FakeAuth auth;
  late DateTime now;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('stb_ctl_');
    db = openTestDatabase();
    await db.customSelect('SELECT 1').get();
    drive = FakeDrive();
    auth = FakeAuth(drive);
    now = DateTime(2026, 11, 19, 21, 14);
  });
  tearDown(() async {
    await db.close();
    temp.deleteSync(recursive: true);
  });

  ProviderContainer container({BackupState initial = const BackupState(), http.Client? client}) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWith((ref) => Clock.fixed(now)),
        cacheDirProvider.overrideWithValue(() async => Directory(p.join(temp.path, 'cache'))..createSync(recursive: true)),
        photoStoreProvider.overrideWithValue(PhotoStore(baseDir: () async => Directory(p.join(temp.path, 'docs')))),
        driveAuthProvider.overrideWithValue(auth),
        driveHttpProvider.overrideWithValue(client ?? drive.client),
        initialBackupStateProvider.overrideWithValue(initial),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> addExpense({int amount = 12000}) async {
    final pocket = (await PocketsRepo(db).defaultPocket()).id;
    await ExpensesRepo(db).add(pocketId: pocket, categoryId: 1, amount: amount, day: dayOf(2026, 11, 19));
  }

  const signedIn = BackupState(email: 'me@example.com');

  group('signing in', () {
    test('with expenses: signs in and backs up at once', () async {
      await addExpense();
      final c = container();
      final outcome = await c.read(backupProvider.notifier).signIn();
      expect(outcome, isA<SignedInAndBackedUp>());
      final s = c.read(backupProvider);
      expect(s.email, 'me@example.com');
      expect(s.lastBackupAt, now);
      expect(s.busy, isFalse);
      expect(drive.files.values.single.name, 'Spill the Bills backup 2026-11-19 21-14.zip');
      expect(drive.files.values.single.props['expenses'], '1');
      final stored = await SettingsStore(db).load();
      expect(stored[BackupState.kEmail], 'me@example.com');
      expect(BackupState.fromEntries(stored).lastBackupAt, now);
    });

    test('on an empty phone: offers the backups in Drive', () async {
      // An earlier phone's backup.
      await addExpense();
      await container(initial: signedIn).read(backupProvider.notifier).backUpNow();
      await db.delete(db.expenses).go();

      final outcome = await container().read(backupProvider.notifier).signIn();
      expect(outcome, isA<SignedInWithBackups>());
      expect((outcome as SignedInWithBackups).backups.single.expenses, 1);
      expect(drive.files, hasLength(1), reason: 'no empty backup was made');
    });

    test('on an empty phone with nothing in Drive', () async {
      expect(await container().read(backupProvider.notifier).signIn(), isA<SignedInEmpty>());
    });

    test('closing Google\'s screen changes nothing', () async {
      auth.signInError = const BackupCancelled();
      final c = container();
      expect(await c.read(backupProvider.notifier).signIn(), isA<SignInCancelled>());
      expect(c.read(backupProvider).signedIn, isFalse);
      expect(c.read(backupProvider).busy, isFalse);
    });

    test('a sign-in error is reported in words', () async {
      auth.signInError = const BackupSignInFailed('DEVELOPER_ERROR');
      final outcome = await container().read(backupProvider.notifier).signIn();
      expect((outcome as SignInFailed).message, 'Google sign-in did not work. Try again.');
    });
  });

  group('the daily backup', () {
    test('runs when signed in and no backup was made today', () async {
      await addExpense();
      final c = container(initial: BackupState(email: 'me@example.com', lastBackupAt: now.subtract(const Duration(days: 1))));
      await c.read(backupProvider.notifier).maybeAutoBackup();
      expect(drive.files, hasLength(1));
      expect(c.read(backupProvider).lastBackupAt, now);
    });

    test('does nothing when not signed in, already done today, or nothing to back up', () async {
      await container().read(backupProvider.notifier).maybeAutoBackup();
      await addExpense();
      await container().read(backupProvider.notifier).maybeAutoBackup();
      await container(
        initial: BackupState(email: 'me@example.com', lastBackupAt: now.subtract(const Duration(hours: 2))),
      ).read(backupProvider.notifier).maybeAutoBackup();
      await db.delete(db.expenses).go();
      await container(initial: signedIn).read(backupProvider.notifier).maybeAutoBackup();
      expect(drive.files, isEmpty);
      expect(auth.signIns, 0);
    });

    test('never shows Google\'s screens: asks to sign in again instead', () async {
      await addExpense();
      auth.silentWorks = false;
      final c = container(initial: signedIn);
      await c.read(backupProvider.notifier).maybeAutoBackup();
      final s = c.read(backupProvider);
      expect(drive.files, isEmpty);
      expect(s.needsSignIn, isTrue);
      expect(s.lastError, 'Google asked to sign in again.');
      expect((await SettingsStore(db).load())[BackupState.kNeedsSignIn], 'true');
      // And it stops trying until the user signs in.
      auth.silentWorks = true;
      await c.read(backupProvider.notifier).maybeAutoBackup();
      expect(drive.files, isEmpty);
    });

    test('without internet it says so and waits half an hour', () async {
      await addExpense();
      var calls = 0;
      final offline = MockClient((_) async {
        calls++;
        throw const SocketException('no route');
      });
      final c = container(initial: signedIn, client: offline);
      await c.read(backupProvider.notifier).maybeAutoBackup();
      expect(c.read(backupProvider).lastError, 'No internet connection.');
      final before = calls;
      await c.read(backupProvider.notifier).maybeAutoBackup();
      expect(calls, before, reason: 'no second try within 30 minutes');
    });
  });

  test('keeps only the newest 10 backups', () async {
    await addExpense();
    final c = container(initial: signedIn);
    for (var i = 0; i < 12; i++) {
      drive.clock = drive.clock.add(const Duration(days: 1));
      expect(await c.read(backupProvider.notifier).backUpNow(), isNull);
    }
    expect(drive.files, hasLength(BackupService.keep));
    final kept = drive.files.values.map((f) => f.created).toList()..sort();
    expect(kept.first, DateTime.utc(2026, 11, 19, 15).add(const Duration(days: 3)));
  });

  test('restore replaces the data and the settings, keeps this phone\'s account', () async {
    await addExpense(amount: 63000);
    await SettingsStore(db).write('mood', 'iris');
    await SettingsStore(db).write(BackupState.kEmail, 'me@example.com');
    final c = container(initial: signedIn);
    await c.read(backupProvider.notifier).backUpNow();

    await db.delete(db.expenses).go();
    await addExpense(amount: 5);
    await c.read(settingsProvider.notifier).setMood(Mood.coral);

    final backups = await c.read(backupProvider.notifier).listBackups();
    final manifest = await c.read(backupProvider.notifier).restore(backups.single);
    expect(manifest.expenses, 1);
    expect((await db.select(db.expenses).get()).single.amount, 63000);
    expect(c.read(settingsProvider).mood, Mood.iris);
    expect(c.read(backupProvider).email, 'me@example.com');
    expect((await SettingsStore(db).load())[BackupState.kEmail], 'me@example.com');
  });

  test('sign out forgets the account; the backups stay in Drive', () async {
    await addExpense();
    final c = container(initial: signedIn);
    await c.read(backupProvider.notifier).backUpNow();
    await c.read(backupProvider.notifier).signOut();
    expect(c.read(backupProvider), const BackupState());
    expect(auth.signedOut, isTrue);
    expect(drive.files, hasLength(1));
    expect((await SettingsStore(db).load()).keys.where((k) => k.startsWith('backup.')), isEmpty);
  });
}
