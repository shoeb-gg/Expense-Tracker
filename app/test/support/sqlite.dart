import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:sqlite3/open.dart';

/// Absolute path of the test SQLite library (see tool/get_sqlite_dll.ps1).
String get testSqliteDllPath =>
    File('test/native/sqlite3.dll').absolute.path;

DynamicLibrary _openTestSqlite() => DynamicLibrary.open(testSqliteDllPath);

/// Points package:sqlite3 at test/native/sqlite3.dll on Windows when it is
/// there (run tool/get_sqlite_dll.ps1 once). Without it, package:sqlite3
/// falls back to Windows' own winsqlite3.dll. Called for every test file by
/// test/flutter_test_config.dart.
void useTestSqlite() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  if (Platform.isWindows && File(testSqliteDllPath).existsSync()) {
    open.overrideFor(OperatingSystem.windows, _openTestSqlite);
  }
}
