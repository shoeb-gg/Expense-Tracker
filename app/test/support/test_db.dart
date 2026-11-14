import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:spill_the_bills/data/db.dart';

/// A fresh in-memory database, seeded like a first start (one "Personal"
/// pocket and the 15 categories). Close it at the end of the test
/// (`addTearDown(db.close)`, or `await tester.runAsync(db.close)` in widget
/// tests).
AppDatabase openTestDatabase() => AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
