import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/sqlite.dart';

void main() {
  test('SQLite loads (test/native/sqlite3.dll when present)', () {
    final version = sqlite3.version.libVersion;
    // ignore: avoid_print
    print('SQLite used by the tests: $version');
    expect(version, isNotEmpty);
    if (Platform.isWindows && File(testSqliteDllPath).existsSync()) {
      expect(open.os, OperatingSystem.windows);
    }
  });
}
