import 'dart:async';

import 'support/sqlite.dart';

/// Runs before every test file in test/: sets up the test SQLite library.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  useTestSqlite();
  await testMain();
}
