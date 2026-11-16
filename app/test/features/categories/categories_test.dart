import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/data/categories_repo.dart';
import 'package:spill_the_bills/data/db.dart';
import 'package:spill_the_bills/data/expenses_repo.dart';
import 'package:spill_the_bills/features/categories/categories_screen.dart';
import 'package:spill_the_bills/features/categories/category_parts.dart';
import 'package:spill_the_bills/router.dart';
import 'package:spill_the_bills/theme/symbols.dart';
import 'package:spill_the_bills/theme/tokens.dart';
import 'package:spill_the_bills/widgets/kit.dart';

import '../../support/board.dart';
import '../../support/shots.dart';
import '../../support/test_db.dart';
import '../../support/text_cut.dart';

Future<List<ExpenseCategory>> cats(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => CategoriesRepo(db).all()))!;

void main() {
  test('emoji from the keyboard: only emoji count', () {
    expect(isEmojiGrapheme('\u{1F984}'), isTrue);
    expect(isEmojiGrapheme('☕'), isTrue);
    expect(isEmojiGrapheme('a'), isFalse);
    expect(isEmojiGrapheme('7'), isFalse);
    expect(lastEmoji('ab\u{1F436}c'), '\u{1F436}');
    expect(lastEmoji('\u{1F44D}\u{1F3FD}'), '\u{1F44D}\u{1F3FD}');
    expect(lastEmoji('hello'), isNull);
    expect(colorName(CategoryColor.cyan.argb), 'Cyan');
    expect(colorName(CategoryColor.slate.argb), 'Slate');
    expect(colorName(0xFF123456), 'Custom');
    expect(categoryEmojiGroups.expand((g) => g.emojis).length, 36);
  });

  testWidgets('add a category: Save waits for a name; it goes before '
      'Miscellaneous', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.newCategory);
    expect(find.text('Red'), findsOneWidget, reason: 'first colour nobody has');
    final save = find.widgetWithText(Pill, 'Save');
    expect(tester.widget<Pill>(save).onTap, isNull);
    await tester.enterText(find.byType(TextField).first, '  Pets ');
    await tester.pump();
    expect(tester.widget<Pill>(save).onTap, isNotNull);
    await tester.tap(find.bySemanticsLabel('Blue'));
    await tester.pump();
    expect(find.text('Blue'), findsOneWidget);
    await tester.ensureVisible(find.text('\u{1F436}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u{1F436}'));
    await tester.pump();
    await tester.tap(save);
    await settleFor(tester);
    final all = await cats(tester, db);
    final pets = all.firstWhere((c) => c.name == 'Pets');
    expect(pets.emoji, '\u{1F436}');
    expect(pets.color, CategoryColor.blue.argb);
    expect(all.last.isMisc, isTrue);
    await closeApp(tester, db);
  });

  testWidgets('the name placeholder is text3, like Add pocket', (
    tester,
  ) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.newCategory);
    final field = find.byType(TextField).first;
    final decoration = tester.widget<TextField>(field).decoration!;
    expect(decoration.hintText, 'Category name');
    expect(decoration.hintStyle!.color, tester.element(field).colors.text3);
    await closeApp(tester, db);
  });

  test('"Also used by" names who has a colour', () {
    expect(colorOwnersLine(const <String>[]), isNull);
    expect(colorOwnersLine(['Shopping']), 'Also used by Shopping');
    expect(
      colorOwnersLine(['Shopping', 'Gifts']),
      'Also used by Shopping and Gifts',
    );
    expect(
      colorOwnersLine(['Shopping', 'Gifts', 'Gym']),
      'Also used by Shopping, Gifts and Gym',
    );
    expect(
      colorOwnersLine(['Shopping', 'Gifts', 'Gym', 'Pets', 'Toys']),
      'Also used by Shopping, Gifts, Gym and 2 more',
    );
  });

  group('colours already taken', () {
    /// A database with [extra] categories (name, colour) added to the 15.
    Future<AppDatabase> withExtra(
      WidgetTester tester,
      List<(String, int)> extra,
    ) async {
      final db = openTestDatabase();
      await tester.runAsync(() async {
        final repo = CategoriesRepo(db);
        for (final (name, color) in extra) {
          await repo.add(name: name, emoji: '\u{1F436}', color: color);
        }
      });
      return db;
    }

    Finder taken(CategoryColor color) =>
        find.byKey(ValueKey<String>('taken-${color.name}'));

    testWidgets('all 18 colours are there, and each one can be picked', (
      tester,
    ) async {
      final db = openTestDatabase();
      await pumpApp(tester, db: db, location: Routes.newCategory);
      for (final color in CategoryColor.values) {
        final swatch = find.bySemanticsLabel(color.label);
        expect(swatch, findsOneWidget, reason: color.label);
        expect(
          tester.getSize(swatch).shortestSide,
          greaterThanOrEqualTo(40),
          reason: '${color.label} stays easy to tap',
        );
        await tester.tap(swatch);
        await tester.pump();
        expect(find.text(color.label), findsOneWidget, reason: 'header');
      }
      await closeApp(tester, db);
    });

    testWidgets('they wrap in rows inside the card', (tester) async {
      final db = openTestDatabase();
      await pumpApp(tester, db: db, location: Routes.newCategory);
      final card = tester.getRect(find.byType(ColorSwatches));
      final tops = <double>{};
      for (final color in CategoryColor.values) {
        final box = tester.getRect(find.bySemanticsLabel(color.label));
        expect(box.left, greaterThanOrEqualTo(card.left - 0.5));
        expect(box.right, lessThanOrEqualTo(card.right + 0.5));
        tops.add(box.top.roundToDouble());
      }
      expect(tops.length, 3, reason: 'three rows of six');
      await closeApp(tester, db);
    });

    testWidgets('a new category starts on the first colour nobody uses', (
      tester,
    ) async {
      final db = openTestDatabase();
      await pumpApp(tester, db: db, location: Routes.newCategory);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('No other category uses this color'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Pets');
      await tester.pump();
      await tester.tap(find.widgetWithText(Pill, 'Save'));
      await settleFor(tester);
      final pets = (await cats(tester, db)).firstWhere((c) => c.name == 'Pets');
      expect(pets.color, CategoryColor.red.argb);
      await closeApp(tester, db);
    });

    testWidgets('with every colour taken it starts on the first one', (
      tester,
    ) async {
      final db = await withExtra(tester, [
        ('A', CategoryColor.red.argb),
        ('B', CategoryColor.yellow.argb),
        ('C', CategoryColor.sand.argb),
      ]);
      await pumpApp(tester, db: db, location: Routes.newCategory);
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Also used by House Rent'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('taken colours are marked with their owner; free ones not', (
      tester,
    ) async {
      final db = openTestDatabase();
      await pumpApp(tester, db: db, location: Routes.newCategory);
      const free = [CategoryColor.red, CategoryColor.yellow, CategoryColor.sand];
      for (final color in CategoryColor.values) {
        expect(
          taken(color),
          free.contains(color) ? findsNothing : findsOneWidget,
          reason: color.label,
        );
      }
      // The owner's emoji sits on the swatch: House Rent's house on Blue.
      expect(
        find.descendant(
          of: taken(CategoryColor.blue),
          matching: find.text('\u{1F3E0}'),
        ),
        findsOneWidget,
      );
      await closeApp(tester, db);
    });

    testWidgets('picking a taken colour says who uses it, and still picks it', (
      tester,
    ) async {
      final db = await withExtra(tester, [
        ('Pets', CategoryColor.pink.argb),
        ('Toys', CategoryColor.pink.argb),
      ]);
      await pumpApp(tester, db: db, location: Routes.newCategory);
      await tester.tap(find.bySemanticsLabel('Blue'));
      await tester.pump();
      expect(find.text('Also used by House Rent'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Pink'));
      await tester.pump();
      expect(
        find.text('Also used by Transportation, Pets and Toys'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Yellow'));
      await tester.pump();
      expect(find.text('No other category uses this color'), findsOneWidget);
      expect(find.textContaining('Also used by'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Pink'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Fish');
      await tester.pump();
      await tester.tap(find.widgetWithText(Pill, 'Save'));
      await settleFor(tester);
      final fish = (await cats(tester, db)).firstWhere((c) => c.name == 'Fish');
      expect(fish.color, CategoryColor.pink.argb, reason: 'taken, still chosen');
      await closeApp(tester, db);
    });

    testWidgets('the category being edited does not take its own colour', (
      tester,
    ) async {
      final db = await withExtra(tester, [('Pets', CategoryColor.pink.argb)]);
      final pets = (await cats(tester, db)).firstWhere((c) => c.name == 'Pets');
      await pumpApp(tester, db: db, location: Routes.editCategory(pets.id));
      // Pets is pink like Transportation: only Transportation is named.
      expect(find.text('Also used by Transportation'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'Also used by .*Pets')),
        findsNothing,
        reason: 'not itself',
      );
      expect(taken(CategoryColor.lime), findsOneWidget, reason: 'Gym has it');
      await tester.tap(find.bySemanticsLabel('Red'));
      await tester.pump();
      expect(find.text('No other category uses this color'), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('a colour only the edited category has is free for it', (
      tester,
    ) async {
      final db = openTestDatabase();
      final gym = (await cats(tester, db)).firstWhere((c) => c.name == 'Gym');
      await pumpApp(tester, db: db, location: Routes.editCategory(gym.id));
      expect(find.text('Lime'), findsOneWidget);
      expect(find.text('No other category uses this color'), findsOneWidget);
      expect(taken(CategoryColor.lime), findsNothing, reason: 'only Gym has it');
      expect(taken(CategoryColor.blue), findsOneWidget);
      await closeApp(tester, db);
    });

    testWidgets('a colour outside the palette is "Custom" and can be shared', (
      tester,
    ) async {
      final db = await withExtra(tester, [('Pets', 0xFF123456), ('Cats', 0xFF123456)]);
      final pets = (await cats(tester, db)).firstWhere((c) => c.name == 'Pets');
      await pumpApp(tester, db: db, location: Routes.editCategory(pets.id));
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Also used by Cats'), findsOneWidget);
      await closeApp(tester, db);
    });
  });

  testWidgets('a name already in use is refused', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.newCategory);
    await tester.enterText(find.byType(TextField).first, 'groceries');
    await tester.pump();
    await tester.tap(find.widgetWithText(Pill, 'Save'));
    await settleUntil(tester, find.textContaining('already a category'));
    expect(
      find.text('There is already a category called groceries'),
      findsOneWidget,
    );
    expect((await cats(tester, db)).length, 15);
    await tester.pump(const Duration(seconds: 5));
    await closeApp(tester, db);
  });

  testWidgets('emoji from the phone keyboard', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.newCategory);
    await tester.ensureVisible(find.text('Pick any emoji from your keyboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick any emoji from your keyboard'));
    await tester.pump();
    final catcher = find.descendant(
      of: find.byType(KeyboardEmojiCatcher),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(catcher).focusNode!.hasFocus, isTrue);
    await tester.enterText(catcher, '\u{1F984}');
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('\u{1F984}'), findsOneWidget, reason: 'preview tile');
    await closeApp(tester, db);
  });

  testWidgets('edit a category', (tester) async {
    final db = openTestDatabase();
    final gym = (await tester.runAsync(
      () => CategoriesRepo(db).findByName('Gym'),
    ))!;
    await pumpApp(tester, db: db, location: Routes.editCategory(gym.id));
    expect(find.text('Edit category'), findsOneWidget);
    expect(find.text('Lime'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Fitness');
    await tester.pump();
    await tester.tap(find.widgetWithText(Pill, 'Save'));
    await settle(tester);
    final after = (await tester.runAsync(
      () => CategoriesRepo(db).get(gym.id),
    ))!;
    expect(after.name, 'Fitness');
    expect(after.emoji, gym.emoji);
    await closeApp(tester, db);
  });

  testWidgets('an unknown category shows a message', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: '/settings/categories/999');
    expect(find.byType(NotFoundCard), findsOneWidget);
    expect(find.text('Category not found'), findsOneWidget);
    expect(noteText('It may have been deleted.'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('delete asks first; expenses move to Miscellaneous', (
    tester,
  ) async {
    final db = openTestDatabase();
    late int groceries;
    late int misc;
    await tester.runAsync(() async {
      final repo = CategoriesRepo(db);
      groceries = (await repo.findByName('Groceries'))!.id;
      misc = (await repo.misc()).id;
      final expenses = ExpensesRepo(db);
      for (var i = 0; i < 3; i++) {
        await expenses.add(
          pocketId: 1,
          categoryId: groceries,
          amount: 100,
          day: dayOf(2026, 10, i + 1),
        );
      }
    });
    await pumpApp(tester, db: db, location: Routes.categories);
    await tester.tap(find.bySemanticsLabel('Delete Groceries'));
    await settle(tester);
    expect(find.text('Delete Groceries?'), findsOneWidget);
    expect(find.text('3 expenses move to Miscellaneous.'), findsOneWidget);
    expect(find.text('Nothing is lost.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('15 categories'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Delete Groceries'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settleUntil(tester, find.text('14 categories'));
    expect(find.text('14 categories'), findsOneWidget);
    final moved = await tester.runAsync(
      () => CategoriesRepo(db).countExpenses(misc),
    );
    expect(moved, 3);

    // Miscellaneous cannot be deleted.
    await revealRow(tester, find.text('Miscellaneous'));
    await tester.tap(find.bySemanticsLabel('Miscellaneous cannot be deleted'));
    await settle(tester);
    expect(find.byType(AppDialog), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('a category with no expenses says so', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.categories);
    await tester.tap(find.bySemanticsLabel('Delete Snacks'));
    await settle(tester);
    expect(find.text('Snacks has no expenses.'), findsOneWidget);
    expect(find.text('It will simply be removed.'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('drag a handle to reorder', (tester) async {
    final db = openTestDatabase();
    await pumpApp(tester, db: db, location: Routes.categories);
    // The band's hint shows the same icon first; row handles follow.
    final handle = find.byIcon(Symbols.drag_indicator_rounded).at(1);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 7; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
    await settleUntil(tester, find.byType(CategoriesScreen));
    final order = await cats(tester, db);
    expect(order.first.name, 'Snacks');
    expect(order[1].name, 'Groceries');
    await closeApp(tester, db);
  });
}
