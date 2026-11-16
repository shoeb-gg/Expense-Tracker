import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/core/type_to_add.dart';
import 'package:spill_the_bills/data/db.dart';

final List<CategoryRef> cats = [
  for (var i = 0; i < defaultCategories.length; i++)
    (id: i + 1, name: defaultCategories[i].name),
];

int idOf(String name) => cats.firstWhere((c) => c.name == name).id;

TypedExpense parse(
  String text, {
  Map<String, int> learned = const {},
  AmountFormat format = const AmountFormat(),
}) =>
    parseTypeToAdd(text, categories: cats, learned: learned, format: format);

void main() {
  test('category by name, amount, no title', () {
    final r = parse('snacks 555');
    expect(r.amount, 55500);
    expect(r.categoryId, idOf('Snacks'));
    expect(r.title, '');
    expect(r.categoryWords, ['snacks']);
    expect(r.hasAmount, isTrue);
  });

  test('category by a name prefix of 3+ letters', () {
    expect(parse('snack 120').categoryId, idOf('Snacks'));
    expect(parse('elec 2000').categoryId, idOf('Electric Bill'));
    expect(parse('rent 15000').categoryId, idOf('House Rent'));
    expect(parse('gy 500').categoryId, isNull); // too short
  });

  test('learned word picks the category and stays in the title', () {
    final r = parse('coffee 120', learned: {'coffee': idOf('Snacks')});
    expect(r.categoryId, idOf('Snacks'));
    expect(r.title, 'Coffee');
    expect(r.titleWords, ['coffee']);
    expect(r.byLearnedWord, isTrue);
  });

  test('unknown word gives no category, the word becomes the title', () {
    final r = parse('saree 1200');
    expect(r.categoryId, isNull);
    expect(r.title, 'Saree');
    expect(r.titleWords, ['saree']);
    expect(r.amount, 120000);
  });

  test('NO built-in word list: coffee alone is unknown', () {
    expect(parse('coffee 120').categoryId, isNull);
    expect(parse('doctor 500').categoryId, isNull);
  });

  test('majority of words wins', () {
    final learned = {
      'cake': idOf('Gifts'),
      'candles': idOf('Gifts'),
      'tea': idOf('Snacks'),
    };
    final r = parse('tea cake candles 900', learned: learned);
    expect(r.categoryId, idOf('Gifts'));
    expect(r.title, 'Tea cake candles');
  });

  test('a tie goes to the category named first', () {
    final learned = {'tea': idOf('Snacks'), 'cake': idOf('Gifts')};
    expect(parse('tea cake 300', learned: learned).categoryId, idOf('Snacks'));
    expect(parse('cake tea 300', learned: learned).categoryId, idOf('Gifts'));
  });

  test('a word that starts two category names does not decide alone', () {
    expect(parse('bill 500').categoryId, isNull);
    final r = parse('internet bill 1500');
    expect(r.categoryId, idOf('Internet Bill'));
    expect(r.title, ''); // both words name the category
  });

  test('learned word beats a name match for that word', () {
    final r = parse('gas 300', learned: {'gas': idOf('Transportation')});
    expect(r.categoryId, idOf('Transportation'));
  });

  test('amount with commas, decimals and currency', () {
    expect(parse('rent 15,000').amount, 1500000);
    expect(parse('lunch 120.50').amount, 12050);
    expect(parse('lunch 120 tk').title, 'Lunch');
    expect(parse('lunch tk120').amount, 12000);
    expect(parse('lunch \$45').amount, 4500);
    const eu = AmountFormat(style: NumberStyle.dotComma);
    expect(parse('rent 15.000', format: eu).amount, 1500000);
    expect(parse('tea 2,5', format: eu).amount, 250);
  });

  test('first number is the amount, later numbers stay in the title', () {
    final r = parse('2 coffees 240');
    expect(r.amount, 200);
    expect(r.title, 'Coffees 240');
  });

  test('title keeps the user case and capitalises the first letter', () {
    final r = parse('dinner with Sam 900');
    expect(r.title, 'Dinner with Sam');
    expect(r.titleWords, ['dinner', 'with', 'sam']);
  });

  test('filler words at the start and end of the title are dropped', () {
    final r = parse('250 for taxi');
    expect(r.amount, 25000);
    expect(r.title, 'Taxi');
    expect(r.titleWords, ['taxi']);

    expect(parse('taxi to 250').title, 'Taxi');
    expect(parse('for the taxi at 250').title, 'Taxi');
    expect(parse('250 on a lunch with').title, 'Lunch');
    // Filler words only: nothing left for a title.
    expect(parse('250 for the').title, '');
    expect(parse('250 for the').titleWords, isEmpty);
    // Capitals and punctuation do not hide a filler word.
    expect(parse('For, taxi 250').title, 'Taxi');
  });

  test('filler words in the middle of the title stay', () {
    expect(parse('Present for mom 500').title, 'Present for mom');
    expect(parse('Present for mom 500').titleWords, ['present', 'for', 'mom']);
    expect(parse('250 for taxi to the airport').title, 'Taxi to the airport');
    // A category word standing alone leaves the title first, then the ends
    // are trimmed.
    expect(parse('snacks aldi for kids 120').title, 'Aldi for kids');
  });

  group('a category word joined to the rest by a linking word', () {
    test('keeps the whole phrase as the title', () {
      final r = parse('250 gift for mom');
      expect(r.amount, 25000);
      expect(r.categoryId, idOf('Gifts'));
      expect(r.title, 'Gift for mom');
      expect(r.categoryWords, ['gift']);
      // The user's own case stays, the first letter is capitalised.
      expect(parse('gift for Mom 250').title, 'Gift for Mom');
      expect(parse('snacks for kids 120').title, 'Snacks for kids');
      expect(parse('snacks for kids 120').categoryId, idOf('Snacks'));
    });

    test('works with every linking word and with words before the phrase', () {
      expect(parse('birthday gift to mom 500').title, 'Birthday gift to mom');
      expect(parse('rent from Sam 15000').title, 'Rent from Sam');
      expect(parse('gift with love 300').title, 'Gift with love');
      expect(parse('gift for the kids 300').title, 'Gift for the kids');
      expect(parse('gift for the kids 300').categoryId, idOf('Gifts'));
    });

    test('a category name of two words stays whole in the phrase', () {
      final r = parse('internet bill for dad 900');
      expect(r.categoryId, idOf('Internet Bill'));
      expect(r.title, 'Internet bill for dad');
      expect(r.categoryWords, ['internet', 'bill']);
    });

    test('a category word standing alone is still left out', () {
      expect(parse('groceries 250').title, '');
      expect(parse('groceries aldi 250').title, 'Aldi');
      expect(parse('250 aldi groceries').title, 'Aldi');
      // The next word is not a linking word, so the category word goes.
      expect(parse('gift aldi for mom 250').title, 'Aldi for mom');
    });

    test('a linking word with nothing after it does not keep the category word', () {
      expect(parse('gift for 250').title, '');
      expect(parse('groceries for the 250').title, '');
      expect(parse('gift for 250').categoryId, idOf('Gifts'));
    });

    test('learned words behave as before', () {
      final r = parse('250 for taxi', learned: {'taxi': idOf('Transportation')});
      expect(r.categoryId, idOf('Transportation'));
      expect(r.title, 'Taxi');
      expect(r.titleWords, ['taxi']);
    });

    test('the category word is not offered for learning', () {
      expect(parse('gift for mom 250').titleWords, ['for', 'mom']);
    });
  });

  test('no amount yet, but a known word already picks the category', () {
    final r = parse('snacks');
    expect(r.amount, isNull);
    expect(r.hasAmount, isFalse);
    expect(r.categoryId, idOf('Snacks'));
  });

  test('empty text', () {
    final r = parse('   ');
    expect(r.amount, isNull);
    expect(r.categoryId, isNull);
    expect(r.title, '');
  });
}
