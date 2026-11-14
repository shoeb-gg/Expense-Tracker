@Tags(['shots'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/router.dart';

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
    await boardHeight(tester, 900);
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
    await boardHeight(tester, 900);
    expect(find.text('Orange'), findsOneWidget);
    await takeShot(tester, 'categories_edit');
    await closeApp(tester, db);
  });

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
