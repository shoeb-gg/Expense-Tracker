/// The app's one SQLite database (Drift). Everything lives here, settings
/// included, so a backup is a single file.
///
/// Do not change this schema without reporting back: other screens query
/// these tables and columns by name.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'db.g.dart';

/// A separate book of expenses. There is always exactly one default pocket.
@DataClassName('Pocket')
class Pockets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
}

/// Expense categories, one list for the whole app (all pockets).
/// Named `ExpenseCategory` in Dart because Flutter already has a `Category`.
@DataClassName('ExpenseCategory')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();

  /// ARGB colour, one of [CategoryColor] in theme/tokens.dart.
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Miscellaneous: can never be deleted; deleted categories move here.
  BoolColumn get isMisc => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
}

/// One expense. [amount] is in minor units (amount x 100). [day] is the local
/// calendar date as days since 1970-01-01 (see core/days.dart).
@DataClassName('Expense')
@TableIndex(name: 'expenses_pocket_day', columns: {#pocketId, #day})
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pocketId => integer().references(Pockets, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amount => integer()();

  /// The expense "title". Optional: '' when none.
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get day => integer()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  /// File name of the receipt photo inside the app's `photos/` folder.
  TextColumn get photoPath => text().nullable()();
}

/// Type to add memory: which category a (lower-case) word belongs to.
/// Shared by all pockets.
@DataClassName('LearnedWord')
class LearnedWords extends Table {
  TextColumn get word => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column<Object>> get primaryKey => {word};
}

/// App settings as key/value text (see state/settings.dart).
@DataClassName('SettingsEntry')
class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// A default category: name, emoji and ARGB colour.
typedef DefaultCategory = ({String name, String emoji, int color});

const int _blue = 0xFF3987E5;
const int _green = 0xFF41AE61;
const int _violet = 0xFF9085E9;
const int _amber = 0xFFC98500;
const int _cyan = 0xFF0096AF;
const int _pink = 0xFFD55181;
const int _orange = 0xFFD95926;
const int _coral = 0xFFE66767;

/// The 15 categories created on first start and after "Delete all data",
/// in this order. The last one is Miscellaneous.
const List<DefaultCategory> defaultCategories = [
  (name: 'Groceries', emoji: '\u{1F966}', color: _green),
  (name: 'Snacks', emoji: '\u{1F357}', color: _violet),
  (name: 'Transportation', emoji: '\u{1F68D}', color: _pink),
  (name: 'Shopping', emoji: '\u{1F6CD}\u{FE0F}', color: _pink),
  (name: 'House Rent', emoji: '\u{1F3E0}', color: _blue),
  (name: 'Electric Bill', emoji: '\u{26A1}', color: _amber),
  (name: 'Internet Bill', emoji: '\u{1F310}', color: _cyan),
  (name: 'Phone', emoji: '\u{260E}\u{FE0F}', color: _cyan),
  (name: 'Gas', emoji: '\u{1F525}', color: _orange),
  (name: 'Health', emoji: '\u{1F48A}', color: _cyan),
  (name: 'Gym', emoji: '\u{1F4AA}', color: _orange),
  (name: 'Self Care', emoji: '\u{1F9F4}', color: _coral),
  (name: 'Online Subscriptions', emoji: '\u{25B6}\u{FE0F}', color: _blue),
  (name: 'Gifts', emoji: '\u{1F381}', color: _coral),
  (name: 'Miscellaneous', emoji: '\u{1F9E9}', color: _violet),
];

/// Name of the category that can never be deleted.
const String miscCategoryName = 'Miscellaneous';

/// The default pocket created on first start: "Personal" 👛.
const ({String name, String emoji}) defaultPocket =
    (name: 'Personal', emoji: '\u{1F45B}');

@DriftDatabase(
  tables: [Pockets, Categories, Expenses, LearnedWords, SettingsEntries],
)
class AppDatabase extends _$AppDatabase {
  /// The app's database file `spill_the_bills.sqlite` in the documents folder.
  AppDatabase() : super(driftDatabase(name: 'spill_the_bills'));

  /// For tests: `AppDatabase.forTesting(NativeDatabase.memory())`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Inserts the default pocket and the 15 default categories. Only call on
  /// an empty database (first start, or after everything was wiped).
  /// Returns the id of the new default pocket.
  Future<int> seedDefaults({DateTime? now}) async {
    final at = now ?? DateTime.now();
    return transaction(() async {
      final pocketId = await seedDefaultPocketOnly(at);
      await batch((b) {
        for (var i = 0; i < defaultCategories.length; i++) {
          final c = defaultCategories[i];
          b.insert(
            categories,
            CategoriesCompanion.insert(
              name: c.name,
              emoji: c.emoji,
              color: c.color,
              sortOrder: Value(i),
              isMisc: Value(c.name == miscCategoryName),
              createdAt: Value(at),
            ),
          );
        }
      });
      return pocketId;
    });
  }

  /// Inserts only the default pocket ("Personal" 👛) and returns its id.
  Future<int> seedDefaultPocketOnly(DateTime at) {
    return into(pockets).insert(
      PocketsCompanion.insert(
        name: defaultPocket.name,
        emoji: defaultPocket.emoji,
        sortOrder: const Value(0),
        isDefault: const Value(true),
        createdAt: Value(at),
      ),
    );
  }
}
