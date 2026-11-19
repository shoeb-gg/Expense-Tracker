import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/backup_service.dart';
import '../../core/days.dart';
import '../../core/format.dart';
import '../../state/backup.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';
import '../data/data_parts.dart';
import '../settings/settings_parts.dart';

/// "Today, 9:14 PM", "Yesterday, 8:02 AM", else "Nov 12, 2026, 9:14 PM".
String backupTimeLabel(DateTime time, int today) {
  final day = dayFromDate(time);
  final date = day == today
      ? 'Today'
      : day == today - 1
      ? 'Yesterday'
      : mediumDate(day);
  return '$date, ${timeOfDay(time)}';
}

/// The Settings row's line: "Off", "Last backup today, 9:14 PM", or what
/// went wrong.
String backupSubtitle(BackupState s, int today) {
  if (!s.signedIn) return 'Off. Keeps your expenses safe in your Drive.';
  if (s.needsSignIn) return 'Sign in again to keep backing up';
  if (s.lastError != null) return 'Last try did not work. Tap to see why.';
  final last = s.lastBackupAt;
  if (last == null) return 'On. No backup yet.';
  return 'Last backup: ${backupTimeLabel(last, today)}';
}

/// "4.2 MB", "850 KB".
String backupSizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).ceil()} KB';
}

/// The header: only a back button, so the long title has 48 px sides (not
/// the 88 px kept for Cancel and Save pills) and shows whole, at its full size,
/// at every text size.
const SubHeader _header = SubHeader(title: 'Google Drive backup', sideWidth: 48);

/// Google Drive backup: sign in, the last backup, back up now, restore, and
/// sign out.
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(backupProvider);
    return s.signedIn ? _SignedIn(state: s) : _SignedOut(state: s);
  }
}

/// Before sign-in: what the backup does, and the sign-in button.
class _SignedOut extends ConsumerWidget {
  const _SignedOut({required this.state});

  final BackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final busy = state.task == BackupTask.signingIn;
    return DataPage(
      header: _header,
      dock: DataDock(
        label: busy ? 'Signing in…' : 'Sign in with Google',
        hint: 'You choose the Google account next.',
        onPressed: state.busy ? null : () => unawaited(signInToBackup(context, ref)),
      ),
      children: [
        _Intro(
          icon: Symbols.cloud_upload_rounded,
          title: 'Back up to Google Drive',
          subtitle: 'Your expenses stay safe if you lose or change your phone.',
        ),
        BandCard(
          title: 'How it works',
          child: Column(
            children: [
              for (final (i, row) in _how.indexed)
                BottomHairline(
                  show: i < _how.length - 1,
                  child: ListRow(
                    title: row.$1,
                    subtitle: row.$2,
                    divider: false,
                    wrap: true,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: CenteredNote(
            'The app asks Google only for its own files. It cannot see anything else in your Drive.',
            style: AppText.body.copyWith(fontSize: 13, height: 20 / 13, color: c.text3),
          ),
        ),
      ],
    );
  }
}

const List<(String, String)> _how = [
  ('Everything is saved', 'Expenses, pockets, categories, budgets, settings and receipt photos'),
  ('Once a day, by itself', 'When you open the app. The newest 10 backups are kept.'),
  ('Restore on any phone', 'Sign in with the same Google account and pick a backup'),
];

/// After sign-in: the last backup, restore, sign out, and "Back up now".
class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.state});

  final BackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final last = state.lastBackupAt;
    final error = state.lastError;
    final String dockLabel = switch (state.task) {
      BackupTask.backingUp => 'Backing up…',
      BackupTask.restoring => 'Restoring…',
      BackupTask.signingIn => 'Signing in…',
      _ => state.needsSignIn ? 'Sign in again' : 'Back up now',
    };
    return DataPage(
      header: _header,
      dock: DataDock(
        label: dockLabel,
        hint: 'It also backs up by itself once a day.',
        onPressed: state.busy
            ? null
            : state.needsSignIn
            ? () => unawaited(signInToBackup(context, ref))
            : () => unawaited(_backUpNow(context, ref)),
      ),
      children: [
        _Intro(
          icon: error != null
              ? Symbols.cloud_off_rounded
              : last == null
              ? Symbols.cloud_upload_rounded
              : Symbols.cloud_done_rounded,
          title: state.needsSignIn
              ? 'Sign in again'
              : error != null
              ? 'Last try didn’t work'
              : last == null
              ? 'No backup yet'
              : 'Backed up',
          subtitle: state.email!,
          oneLine: true,
          warn: error != null,
        ),
        BandCard(
          title: 'Backups',
          child: Column(
            children: [
              BottomHairline(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListRow(
                      title: 'Last backup',
                      trailingText: last == null ? 'Not yet' : backupTimeLabel(last, today),
                      divider: false,
                      wrap: true,
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text(
                          state.needsSignIn
                              ? 'Google asked you to sign in again. Until then, nothing is backed up.'
                              : '$error It tries again by itself.',
                          style: AppText.body.copyWith(color: c.bad),
                        ),
                      ),
                  ],
                ),
              ),
              ListRow(
                title: 'Restore from a backup',
                subtitle: switch (state.task) {
                  BackupTask.loading => 'Loading your backups…',
                  BackupTask.restoring => 'Restoring. Keep the app open.',
                  _ => 'Replaces everything in the app',
                },
                trailing: state.task == BackupTask.loading || state.task == BackupTask.restoring
                    ? const _Spinner()
                    : const ValueChevron(),
                divider: false,
                wrap: true,
                onTap: state.busy ? null : () => unawaited(chooseBackupToRestore(context, ref)),
              ),
            ],
          ),
        ),
        BandCard(
          title: 'Account',
          child: Column(
            children: [
              BottomHairline(
                child: ListRow(
                  title: 'Change account',
                  subtitle: state.task == BackupTask.signingIn
                      ? 'Signing in…'
                      : 'Back up to another Google account',
                  trailing: state.task == BackupTask.signingIn ? const _Spinner() : const ValueChevron(),
                  divider: false,
                  wrap: true,
                  onTap: state.busy ? null : () => unawaited(signInToBackup(context, ref, change: true)),
                ),
              ),
              ListRow(
                title: 'Sign out',
                subtitle: 'Stops the daily backup. Your backups stay in Google Drive.',
                divider: false,
                wrap: true,
                onTap: state.busy ? null : () => unawaited(_signOut(context, ref)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The card at the top: an icon tile, a title and a line under it.
class _Intro extends StatelessWidget {
  const _Intro({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.oneLine = false,
    this.warn = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// The line under the title keeps to one line (an email address).
  final bool oneLine;

  /// The last backup failed: the icon turns red.
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PlainCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconTile(
            icon: icon,
            iconSize: 24,
            background: warn ? c.bad.withValues(alpha: 0.14) : null,
            iconColor: warn ? c.bad : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.screenTitle),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: oneLine ? 1 : null,
                  overflow: oneLine ? TextOverflow.ellipsis : null,
                  style: AppText.body.copyWith(color: c.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Signs in ([change]: to another account), then says what happened: backed
/// up, backups found (offering a restore), or why it did not work.
Future<void> signInToBackup(BuildContext context, WidgetRef ref, {bool change = false}) async {
  final controller = ref.read(backupProvider.notifier);
  final outcome = change ? await controller.changeAccount() : await controller.signIn();
  if (!context.mounted) return;
  switch (outcome) {
    case SignedInAndBackedUp():
      final email = ref.read(backupProvider).email;
      showToast(context, change && email != null ? 'Now backing up to $email' : 'Backed up to Google Drive');
    case SignedInWithBackups(:final backups):
      final pick = await showAppDialog(
        context,
        title: 'Backups found',
        boldLine: backups.length == 1
            ? 'Your Google Drive has a backup from ${_label(ref, backups.first)}.'
            : 'Your Google Drive has ${backups.length} backups. The newest is from ${_label(ref, backups.first)}.',
        quietLine: 'Restore one to bring your expenses to this phone.',
        actionLabel: 'Choose a backup',
        cancelLabel: 'Not now',
      );
      if (pick && context.mounted) await chooseBackupToRestore(context, ref, known: backups);
    case SignedInEmpty():
      showToast(context, 'Signed in. Backups start once you add expenses.');
    case SignInCancelled():
      break;
    case SignInFailed(:final message):
      showToast(context, message);
  }
}

String _label(WidgetRef ref, BackupInfo b) => backupTimeLabel(b.createdAt, ref.read(todayProvider));

Future<void> _backUpNow(BuildContext context, WidgetRef ref) async {
  final error = await ref.read(backupProvider.notifier).backUpNow();
  if (!context.mounted) return;
  showToast(context, error ?? 'Backed up to Google Drive');
}

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  final ok = await showAppDialog(
    context,
    title: 'Sign out of backup?',
    quietLine: 'The daily backup stops. Your backups stay in Google Drive, and you can sign in again any time.',
    actionLabel: 'Sign out',
  );
  if (!ok) return;
  await ref.read(backupProvider.notifier).signOut();
  if (context.mounted) showToast(context, 'Signed out of backup');
}

/// Lists the backups in Drive ([known] when already loaded), asks which one,
/// confirms, and restores it.
Future<void> chooseBackupToRestore(BuildContext context, WidgetRef ref, {List<BackupInfo>? known}) async {
  final controller = ref.read(backupProvider.notifier);
  List<BackupInfo> backups;
  try {
    backups = known ?? await controller.listBackups();
  } on Object catch (e) {
    if (context.mounted) showToast(context, backupErrorText(e));
    return;
  }
  if (!context.mounted) return;
  if (backups.isEmpty) {
    showToast(context, 'No backups in your Google Drive yet');
    return;
  }
  final fmt = ref.read(amountFormatProvider);
  final today = ref.read(todayProvider);
  final picked = await showAppSheet<BackupInfo>(
    context,
    builder: (ctx) => AppSheet(
      title: 'Restore a backup',
      message: 'Everything in the app is replaced by the backup you pick.',
      children: [
        for (final b in backups)
          _BackupRow(
            title: backupTimeLabel(b.createdAt, today),
            note: [
              if (b.expenses != null) expenseCount(b.expenses!, fmt),
              if (b.size != null) backupSizeLabel(b.size!),
            ].join(' · '),
            onTap: () => Navigator.of(ctx).pop(b),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  final when = backupTimeLabel(picked.createdAt, today);
  final count = picked.expenses == null ? '' : ' (${expenseCount(picked.expenses!, fmt)})';
  final ok = await showAppDialog(
    context,
    title: 'Restore this backup?',
    boldLine: 'The backup from $when$count replaces everything in the app now.',
    quietLine: 'Expenses, pockets, categories, budgets, settings and photos. This can’t be undone.',
    actionLabel: 'Restore',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  try {
    final manifest = await controller.restore(picked);
    if (context.mounted) showToast(context, 'Restored ${expenseCount(manifest.expenses, fmt)}');
  } on Object catch (e) {
    if (context.mounted) showToast(context, 'Not restored: ${backupErrorText(e)}');
  }
}

/// A small accent spinner in a row's trailing spot.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: context.colors.accent),
    );
  }
}

/// A backup in the restore sheet: the time, and its expenses and size.
class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.title, required this.note, required this.onTap});

  final String title;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Pressable(
        onTap: onTap,
        color: c.tile,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Icon(Symbols.history_rounded, size: 22, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppText.rowTitle.copyWith(color: c.text)),
                    if (note.isNotEmpty)
                      Text(note, style: AppText.sub.copyWith(color: c.text3)),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right_rounded, size: 22, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}
