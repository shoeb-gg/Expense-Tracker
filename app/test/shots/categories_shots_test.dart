@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/state/providers.dart';
import 'package:spill_the_bills/theme/tokens.dart';

import '../support/board.dart';
import '../support/shots.dart';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('categories: the list (board Categories)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.categories);
    await boardHeight(tester, 1114);
    expect(find.text('15 categories'), findsOneWidget);
    await takeShot(tester, 'categories_list');
    await closeApp(tester, db);
  });

  testWidgets('categories: delete confirmation', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.categories);
    await tester.tap(find.bySemanticsLabel('Delete Groceries'));
    await settle(tester);
    expect(find.text('164 expenses move to Miscellaneous.'), findsOneWidget);
    await takeShot(tester, 'categories_delete');
    await closeApp(tester, db);
  });

  testWidgets('categories: add form (board Add category)', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.newCategory);
    await boardHeight(tester, 1000);
    await takeShot(tester, 'categories_add');
    await closeApp(tester, db);
  });

  testWidgets('categories: edit form (board Edit category, Gym)', (
    tester,
  ) async {
    final db = await sampleDatabase(tester);
    final gym = await tester.runAsync(
      () => CategoriesRepo(db).findByName('Gym'),
    );
    await pumpApp(tester, db: db, location: Routes.editCategory(gym!.id));
    await boardHeight(tester, 1000);
    expect(find.text('Lime'), findsOneWidget);
    await takeShot(tester, 'categories_edit');
    await closeApp(tester, db);
  });

  // Not in the boards: the color card now wraps all 18 colors and says who
  // else has the chosen one. Default size and the largest.
  for (final (:name, :scale) in [
    (name: 'default', scale: 1.0),
    (name: 'largest', scale: textScaleSteps.last),
  ]) {
    testWidgets('categories: add form, taken colors ($name)', (tester) async {
      final db = await sampleDatabase(tester);
      await pumpApp(
        tester,
        db: db,
        location: Routes.newCategory,
        settings: AppSettings(textScale: scale),
      );
      await boardHeight(tester, 1100);
      await takeShot(tester, 'categories_add_colors_$name');
      // Pick one that House Rent has.
      await tester.tap(find.bySemanticsLabel('Blue'));
      await settle(tester);
      expect(find.text('Also used by House Rent'), findsOneWidget);
      await takeShot(tester, 'categories_add_colors_taken_$name');
      await closeApp(tester, db);
    });

    testWidgets('categories: edit form, two others share it ($name)', (
      tester,
    ) async {
      final db = await sampleDatabase(tester);
      final repo = CategoriesRepo(db);
      final pets = await tester.runAsync(() async {
        await repo.add(
          name: 'Toys',
          emoji: '\u{1F9F8}',
          color: CategoryColor.pink.argb,
        );
        return repo.get(
          await repo.add(
            name: 'Pets',
            emoji: '\u{1F436}',
            color: CategoryColor.pink.argb,
          ),
        );
      });
      await pumpApp(
        tester,
        db: db,
        location: Routes.editCategory(pets!.id),
        settings: AppSettings(textScale: scale),
      );
      await boardHeight(tester, 1100);
      expect(
        find.text('Also used by Transportation and Toys'),
        findsOneWidget,
      );
      await takeShot(tester, 'categories_edit_shared_$name');
      await closeApp(tester, db);
    });
  }

  // Not drawn: the app's shared "not found" card (as pockets_not_found,
  // expense_gone and charts_category_not_found).
  testWidgets('categories: edit a category that is gone', (tester) async {
    final db = await sampleDatabase(tester);
    await pumpApp(tester, db: db, location: Routes.editCategory(999));
    expect(find.text('Category not found'), findsOneWidget);
    await takeShot(tester, 'categories_not_found');
    await closeApp(tester, db);
  });
}
