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
