/// Signing in to Google for the Drive backup, and the access tokens for it.
library;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

/// The one permission the backup asks for: the files this app makes in the
/// user's Drive, and nothing else.
const String driveFileScope = 'https://www.googleapis.com/auth/drive.file';

/// The "Spill the Bills Web" OAuth client of the spill-the-bills Google
/// Cloud project. Android sign-in needs it as the server client; it is not a
/// secret. (The Android client is matched by package name and the release
/// key's SHA-1, so sign-in only works in release builds.)
const String _webClientId =
    '596177739191-3drk6n4vchf3aj4cjr4v3faj9s44gi32.apps.googleusercontent.com';

/// The user closed the Google sign-in or permission screen.
class BackupCancelled implements Exception {
  const BackupCancelled();
}

/// Google sign-in failed for another reason.
class BackupSignInFailed implements Exception {
  const BackupSignInFailed(this.message);

  final String message;

  @override
  String toString() => 'BackupSignInFailed: $message';
}

/// Sign-in and tokens, behind an interface so tests need no Google.
abstract interface class DriveAuth {
  /// Shows Google's sign-in and asks for the Drive permission. Returns the
  /// account's email. Throws [BackupCancelled] or [BackupSignInFailed].
  Future<String> signIn();

  /// An access token for [email]. Without [interactive] it never shows
  /// anything and returns null when the user has to sign in again.
  Future<String?> token(String email, {required bool interactive});

  /// Forgets a token Drive turned down, so the next [token] is a fresh one.
  Future<void> forgetToken(String token);

  /// Signs out of Google in this app. The backups stay in Drive.
  Future<void> signOut();
}

/// [DriveAuth] with the google_sign_in plugin.
class GoogleDriveAuth implements DriveAuth {
  Future<void>? _ready;

  Future<void> _init() => _ready ??= GoogleSignIn.instance.initialize(serverClientId: _webClientId);

  static bool _cancelled(GoogleSignInException e) =>
      e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted;

  @override
  Future<String> signIn() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate(scopeHint: const [driveFileScope]);
      await account.authorizationClient.authorizeScopes(const [driveFileScope]);
      return account.email;
    } on GoogleSignInException catch (e) {
      if (_cancelled(e)) throw const BackupCancelled();
      throw BackupSignInFailed(e.description ?? e.code.name);
    }
  }

  @override
  Future<String?> token(String email, {required bool interactive}) async {
    await _init();
    try {
      final data = await GoogleSignInPlatform.instance.clientAuthorizationTokensForScopes(
        ClientAuthorizationTokensForScopesParameters(
          request: AuthorizationRequestDetails(
            scopes: const [driveFileScope],
            userId: null,
            email: email,
            promptIfUnauthorized: interactive,
          ),
        ),
      );
      return data?.accessToken;
    } on GoogleSignInException catch (e) {
      if (_cancelled(e) && interactive) throw const BackupCancelled();
      if (!interactive) return null;
      throw BackupSignInFailed(e.description ?? e.code.name);
    }
  }

  @override
  Future<void> forgetToken(String token) async {
    await _init();
    await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: token);
  }

  @override
  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
  }
}
