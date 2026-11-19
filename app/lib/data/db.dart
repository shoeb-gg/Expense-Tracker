/// The app's one SQLite database (Drift). Everything lives here, settings
/// included, so a backup is a single file.
///
/// Do not change this schema without reporting back: other screens query
/// these tables and columns by name.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../theme/tokens.dart' show CategoryColor;

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

/// A category's monthly budget in one pocket, in minor units (amount x 100).
/// Each pocket has its own budgets; a category with no row in a pocket has
/// no budget there. The same amount applies to every month.
@DataClassName('CategoryBudget')
class CategoryBudgets extends Table {
  IntColumn get pocketId => integer().references(Pockets, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {pocketId, categoryId};
}

/// App settings as key/value text (see state/settings.dart).
@DataClassName('SettingsEntry')
class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// A default category: name, emoji and chart colour.
typedef DefaultCategory = ({String name, String emoji, CategoryColor color});

/// The 15 categories created on first start and after "Delete all data",
/// in this order. The last one is Miscellaneous. Each has its own colour,
/// and colours that sit within a few places of each other in this list are
/// far apart, because charts draw categories side by side.
const List<DefaultCategory> defaultCategories = [
  (name: 'Groceries', emoji: '\u{1F966}', color: CategoryColor.green),
  (name: 'Snacks', emoji: '\u{1F357}', color: CategoryColor.violet),
  (name: 'Transportation', emoji: '\u{1F68D}', color: CategoryColor.pink),
  (name: 'Shopping', emoji: '\u{1F6CD}\u{FE0F}', color: CategoryColor.magenta),
  (name: 'House Rent', emoji: '\u{1F3E0}', color: CategoryColor.blue),
  (name: 'Electric Bill', emoji: '\u{26A1}', color: CategoryColor.amber),
  (name: 'Internet Bill', emoji: '\u{1F310}', color: CategoryColor.cyan),
  (name: 'Phone', emoji: '\u{260E}\u{FE0F}', color: CategoryColor.indigo),
  (name: 'Gas', emoji: '\u{1F525}', color: CategoryColor.orange),
  (name: 'Health', emoji: '\u{1F48A}', color: CategoryColor.teal),
  (name: 'Gym', emoji: '\u{1F4AA}', color: CategoryColor.lime),
  (name: 'Self Care', emoji: '\u{1F9F4}', color: CategoryColor.coral),
  (
    name: 'Online Subscriptions',
    emoji: '\u{25B6}\u{FE0F}',
    color: CategoryColor.sky,
  ),
  (name: 'Gifts', emoji: '\u{1F381}', color: CategoryColor.rose),
  (name: 'Miscellaneous', emoji: '\u{1F9E9}', color: CategoryColor.slate),
];

/// The colours the defaults had in schema 1, when only eight colours existed
/// and several categories shared one. Schema 2 moves the defaults that
/// still wear these to their own colour (see
/// [AppDatabase.recolourDefaultCategories]).
const Map<String, CategoryColor> seedColorsV1 = {
  'Groceries': CategoryColor.green,
  'Snacks': CategoryColor.violet,
  'Transportation': CategoryColor.pink,
  'Shopping': CategoryColor.pink,
  'House Rent': CategoryColor.blue,
  'Electric Bill': CategoryColor.amber,
  'Internet Bill': CategoryColor.cyan,
  'Phone': CategoryColor.cyan,
  'Gas': CategoryColor.orange,
  'Health': CategoryColor.cyan,
  'Gym': CategoryColor.orange,
  'Self Care': CategoryColor.coral,
  'Online Subscriptions': CategoryColor.blue,
  'Gifts': CategoryColor.coral,
  'Miscellaneous': CategoryColor.violet,
};

/// Name of the category that can never be deleted.
const String miscCategoryName = 'Miscellaneous';

/// The default pocket created on first start: "Personal" 👛.
const ({String name, String emoji}) defaultPocket =
    (name: 'Personal', emoji: '\u{1F45B}');

@DriftDatabase(
  tables: [
    Pockets,
    Categories,
    Expenses,
    LearnedWords,
    SettingsEntries,
    CategoryBudgets,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// The app's database file `spill_the_bills.sqlite` in the documents folder.
  AppDatabase() : super(driftDatabase(name: 'spill_the_bills'));

  /// For tests: `AppDatabase.forTesting(NativeDatabase.memory())`.
  AppDatabase.forTesting(super.executor);

  /// A database on [executor] other than the app's own file: a backup being
  /// brought up to date before a restore.
  AppDatabase.withExecutor(super.executor);

  /// 1: first release. 2: every default category has its own colour.
  /// 3: category budgets.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await recolourDefaultCategories();
          if (from < 3) await m.createTable(categoryBudgets);
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
              color: c.color.argb,
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

  /// Schema 2: gives each default category its own colour. A default (found
  /// by name, ignoring case) is moved from its schema 1 colour to its new one
  /// only while it still wears the old one; a colour the user picked, and
  /// every category the user made, stay as they are. Safe to run twice.
  /// Returns how many categories changed.
  Future<int> recolourDefaultCategories() async {
    var changed = 0;
    for (final d in defaultCategories) {
      final old = seedColorsV1[d.name];
      if (old == null || old == d.color) continue;
      changed += await (update(categories)
            ..where(
              (c) =>
                  c.name.lower().equals(d.name.toLowerCase()) &
                  c.color.equals(old.argb),
            ))
          .write(CategoriesCompanion(color: Value(d.color.argb)));
    }
    return changed;
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
