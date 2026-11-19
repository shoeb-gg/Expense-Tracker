/// The Google Drive backup: who is signed in, when it last ran, and the
/// actions (sign in, back up now, the daily backup, restore, sign out).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../backup/backup_archive.dart';
import '../backup/backup_service.dart';
import '../backup/drive_auth.dart';
import '../backup/drive_client.dart';
import '../core/days.dart';
import '../data/maintenance.dart';
import 'providers.dart';

/// What the backup is busy with.
enum BackupTask { signingIn, backingUp, loading, restoring }

/// The backup's state. The account, the last backup time and the last error
/// are stored with the settings (keys starting with "backup.", which a
/// restore leaves alone: they belong to this phone).
@immutable
class BackupState {
  const BackupState({this.email, this.lastBackupAt, this.lastError, this.task, this.needsSignIn = false});

  factory BackupState.fromEntries(Map<String, String> e) => BackupState(
    email: e[kEmail],
    lastBackupAt: DateTime.tryParse(e[kLastAt] ?? '')?.toLocal(),
    lastError: e[kError],
    needsSignIn: e[kNeedsSignIn] == 'true',
  );

  static const String kEmail = '${deviceSettingPrefix}email';
  static const String kLastAt = '${deviceSettingPrefix}lastAt';
  static const String kError = '${deviceSettingPrefix}error';
  static const String kNeedsSignIn = '${deviceSettingPrefix}needsSignIn';

  /// The Google account the backups go to; null when not set up.
  final String? email;
  final DateTime? lastBackupAt;

  /// Why the last backup failed (cleared by the next good one).
  final String? lastError;

  /// The running action, if any.
  final BackupTask? task;

  /// Google needs the user to sign in again before backups can go on.
  final bool needsSignIn;

  bool get signedIn => email != null;
  bool get busy => task != null;

  BackupState copyWith({
    String? Function()? email,
    DateTime? Function()? lastBackupAt,
    String? Function()? lastError,
    BackupTask? Function()? task,
    bool? needsSignIn,
  }) => BackupState(
    email: email == null ? this.email : email(),
    lastBackupAt: lastBackupAt == null ? this.lastBackupAt : lastBackupAt(),
    lastError: lastError == null ? this.lastError : lastError(),
    task: task == null ? this.task : task(),
    needsSignIn: needsSignIn ?? this.needsSignIn,
  );

  @override
  bool operator ==(Object other) =>
      other is BackupState &&
      other.email == email &&
      other.lastBackupAt == lastBackupAt &&
      other.lastError == lastError &&
      other.task == task &&
      other.needsSignIn == needsSignIn;

  @override
  int get hashCode => Object.hash(email, lastBackupAt, lastError, task, needsSignIn);
}

/// What happened when the user signed in.
sealed class SignInOutcome {
  const SignInOutcome();
}

/// The first backup went up right away.
class SignedInAndBackedUp extends SignInOutcome {
  const SignedInAndBackedUp();
}

/// This phone has no expenses yet, and Drive holds these backups: offer a
/// restore.
class SignedInWithBackups extends SignInOutcome {
  const SignedInWithBackups(this.backups);

  final List<BackupInfo> backups;
}

/// Signed in; nothing to back up and nothing to restore yet.
class SignedInEmpty extends SignInOutcome {
  const SignedInEmpty();
}

/// The user closed Google's screen.
class SignInCancelled extends SignInOutcome {
  const SignInCancelled();
}

/// Signing in or the first backup failed; [message] says why.
class SignInFailed extends SignInOutcome {
  const SignInFailed(this.message);

  final String message;
}

/// The stored backup state, loaded before runApp (overridden in main()).
final initialBackupStateProvider = Provider<BackupState>((ref) => const BackupState());

/// Google sign-in. Tests override it.
final driveAuthProvider = Provider<DriveAuth>((ref) => GoogleDriveAuth());

/// The HTTP client for Drive. Tests override it.
final driveHttpProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final backupProvider = NotifierProvider<BackupController, BackupState>(BackupController.new);

/// Words for a failed backup or restore.
String backupErrorText(Object error) => switch (error) {
  DriveException(offline: true) => 'No internet connection.',
  DriveException(unauthorized: true) => 'Google asked to sign in again.',
  DriveException(:final statusCode) => 'Google Drive did not accept it (error $statusCode).',
  BackupFormatException(:final message) => message,
  BackupSignInFailed() => 'Google sign-in did not work. Try again.',
  _ => 'Something went wrong. Try again.',
};

class BackupController extends Notifier<BackupState> {
  /// When the daily backup last tried and failed (not stored): it waits
  /// half an hour before the next try, so a phone without internet is not
  /// asked again on every return to the app.
  DateTime? _lastAutoFailure;

  @override
  BackupState build() => ref.read(initialBackupStateProvider);

  DriveAuth get _auth => ref.read(driveAuthProvider);

  Future<void> _store(String key, String? value) async {
    final store = ref.read(settingsStoreProvider);
    if (value == null) {
      await store.remove(key);
    } else {
      await store.write(key, value);
    }
  }

  BackupService _service(String email, {required bool interactive}) {
    String? last;
    final drive = DriveClient(ref.read(driveHttpProvider), ({bool refresh = false}) async {
      final stale = last;
      if (refresh && stale != null) await _auth.forgetToken(stale);
      final token = await _auth.token(email, interactive: interactive);
      if (token == null) throw const DriveException(401, 'Sign in again');
      return last = token;
    });
    final db = ref.read(databaseProvider);
    final photos = ref.read(photoStoreProvider);
    return BackupService(
      db: db,
      photos: photos,
      workDir: ref.read(cacheDirProvider),
      drive: drive,
      now: ref.read(clockProvider).now,
      cleanUpPhotos: () async {
        await DataMaintenance(db, photos: photos, cacheDir: ref.read(cacheDirProvider)).purgeOrphanPhotos();
      },
    );
  }

  Future<int> _expenseCount() => ref
      .read(databaseProvider)
      .customSelect('SELECT COUNT(*) AS n FROM expenses')
      .map((r) => r.read<int>('n'))
      .getSingle();

  /// Signs in to Google. A phone with expenses backs up at once; an empty
  /// one looks for backups to restore.
  Future<SignInOutcome> signIn() async {
    if (state.busy) return const SignInCancelled();
    state = state.copyWith(task: () => BackupTask.signingIn);
    final String email;
    try {
      email = await _auth.signIn();
    } on BackupCancelled {
      state = state.copyWith(task: () => null);
      return const SignInCancelled();
    } on Object catch (e) {
      state = state.copyWith(task: () => null);
      return SignInFailed(backupErrorText(e));
    }
    await _store(BackupState.kEmail, email);
    await _store(BackupState.kNeedsSignIn, null);
    if (email != state.email) {
      // Another account: its Drive has none of this phone's backups yet.
      await _store(BackupState.kLastAt, null);
      await _store(BackupState.kError, null);
      state = state.copyWith(lastBackupAt: () => null, lastError: () => null);
    }
    state = state.copyWith(email: () => email, needsSignIn: false, task: () => null);
    if (await _expenseCount() > 0) {
      final error = await _backUp(interactive: true);
      return error == null ? const SignedInAndBackedUp() : SignInFailed(error);
    }
    try {
      final backups = await listBackups(interactive: true);
      return backups.isEmpty ? const SignedInEmpty() : SignedInWithBackups(backups);
    } on Object catch (e) {
      return SignInFailed(backupErrorText(e));
    }
  }

  /// Back up to another Google account. Google shows its account list again;
  /// closing it keeps the current account. The old account's backups stay
  /// in its Drive.
  Future<SignInOutcome> changeAccount() async {
    if (state.busy) return const SignInCancelled();
    try {
      await _auth.signOut();
    } on Object {
      // The account list still opens.
    }
    return signIn();
  }

  /// "Back up now". Returns null when it worked, else why not.
  Future<String?> backUpNow() => _backUp(interactive: true);

  Future<String?> _backUp({required bool interactive}) async {
    final email = state.email;
    if (email == null || state.busy) return null;
    state = state.copyWith(task: () => BackupTask.backingUp);
    try {
      await _service(email, interactive: interactive).backUp();
      final at = ref.read(clockProvider).now();
      await _store(BackupState.kLastAt, at.toUtc().toIso8601String());
      await _store(BackupState.kError, null);
      await _store(BackupState.kNeedsSignIn, null);
      state = state.copyWith(lastBackupAt: () => at, lastError: () => null, needsSignIn: false, task: () => null);
      return null;
    } on BackupCancelled {
      state = state.copyWith(task: () => null);
      return 'Google sign-in was closed.';
    } on Object catch (e) {
      final text = backupErrorText(e);
      final again = e is DriveException && e.unauthorized;
      await _store(BackupState.kError, text);
      if (again) await _store(BackupState.kNeedsSignIn, 'true');
      state = state.copyWith(lastError: () => text, needsSignIn: again || state.needsSignIn, task: () => null);
      return text;
    }
  }

  /// The once-a-day backup, called when the app opens or comes back. It
  /// runs only when signed in, when no backup was made today, when there is
  /// something to back up, and never shows Google's screens.
  Future<void> maybeAutoBackup() async {
    final s = state;
    if (!s.signedIn || s.busy || s.needsSignIn) return;
    final now = ref.read(clockProvider).now();
    final last = s.lastBackupAt;
    if (last != null && dayFromDate(last) == dayFromDate(now)) return;
    final failed = _lastAutoFailure;
    if (failed != null && now.difference(failed) < const Duration(minutes: 30)) return;
    if (await _expenseCount() == 0) return;
    final error = await _backUp(interactive: false);
    _lastAutoFailure = error == null ? null : now;
  }

  /// The backups in Drive, newest first.
  Future<List<BackupInfo>> listBackups({bool interactive = true}) async {
    final email = state.email;
    if (email == null) return const [];
    final wasBusy = state.busy;
    if (!wasBusy) state = state.copyWith(task: () => BackupTask.loading);
    try {
      return await _service(email, interactive: interactive).list();
    } finally {
      if (!wasBusy) state = state.copyWith(task: () => null);
    }
  }

  /// Replaces everything in the app with [backup]. Returns the backup's
  /// manifest, or throws with words for the user ([backupErrorText]).
  Future<BackupManifest> restore(BackupInfo backup) async {
    final email = state.email;
    if (email == null) throw StateError('Not signed in');
    state = state.copyWith(task: () => BackupTask.restoring);
    try {
      final manifest = await _service(email, interactive: true).restore(backup);
      await ref.read(settingsProvider.notifier).reload();
      return manifest;
    } finally {
      state = state.copyWith(task: () => null);
    }
  }

  /// Stops the backups on this phone. The backups stay in Drive.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on Object {
      // Forgetting the account below is what matters.
    }
    for (final key in [BackupState.kEmail, BackupState.kLastAt, BackupState.kError, BackupState.kNeedsSignIn]) {
      await _store(key, null);
    }
    state = const BackupState();
  }
}
