import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/calculator.dart';
import 'package:spill_the_bills/core/days.dart';
import 'package:spill_the_bills/core/format.dart';
import 'package:spill_the_bills/core/type_to_add.dart';
import 'package:spill_the_bills/features/add/add_logic.dart';

void main() {
  const fmt = AmountFormat();

  String typeKeys(String keys) {
    var expr = '';
    for (final k in keys.split(' ')) {
      expr = applyKeypadKey(expr, k);
    }
    return expr;
  }

  group('keypadView', () {
    test('empty shows a grey 0 and a greyed Save', () {
      final v = keypadView('', fmt);
      expect(v.amountText, '0');
      expect(v.isPlaceholder, isTrue);
      expect(v.checkKey, CheckKey.saveDisabled);
      expect(v.amount, isNull);
    });

    test('a plain number can be saved, in minor units', () {
      final v = keypadView(typeKeys('1 1 8 0'), fmt);
      expect(v.amountText, '1,180');
      expect(v.amount, 118000);
      expect(v.checkKey, CheckKey.save);
      expect(v.expressionText, isNull);
    });

    test('decimals show as typed', () {
      expect(keypadView(typeKeys('1 2 .'), fmt).amountText, '12.');
      expect(keypadView(typeKeys('1 2 . 5'), fmt).amount, 1250);
    });

    test('zero cannot be saved', () {
      final v = keypadView(typeKeys('0'), fmt);
      expect(v.amount, isNull);
      expect(v.checkKey, CheckKey.saveDisabled);
    });

    test('an operator shows the expression, the running result and =', () {
      final v = keypadView(typeKeys('1 2 0 + 3 0'), fmt);
      expect(v.expressionText, '120 + 30');
      expect(v.amountText, '150');
      expect(v.checkKey, CheckKey.equals);
      expect(v.amount, isNull);
    });

    test('× and ÷ go before + and −', () {
      final v = keypadView(typeKeys('2 + 3 × 4'), fmt);
      expect(v.amountText, '14');
      expect(keypadView(typeKeys('1 0 0 ÷ 4 − 5'), fmt).amountText, '20');
    });

    test('= turns the expression into its result', () {
      final expr = typeKeys('1 2 0 + 3 0 =');
      expect(expr, '150');
      expect(keypadView(expr, fmt).checkKey, CheckKey.save);
    });

    test('dividing by zero or going below zero gives no result', () {
      for (final keys in ['5 ÷ 0', '5 − 1 0']) {
        final v = keypadView(typeKeys(keys), fmt);
        expect(v.noResult, isTrue, reason: keys);
        expect(v.checkKey, CheckKey.equalsDisabled);
        expect(v.amountText, '0');
        expect(v.isPlaceholder, isTrue);
      }
      expect(typeKeys('5 ÷ 0 ='), '');
    });

    test('a trailing operator is ignored in the result', () {
      final v = keypadView(typeKeys('1 2 0 +'), fmt);
      expect(v.expressionText, '120 +');
      expect(v.amountText, '120');
    });
  });

  test('expressionLine groups each number in the number style', () {
    expect(expressionLine('1200+80', fmt), '1,200 + 80');
    expect(
      expressionLine('1234.5×2', const AmountFormat(style: NumberStyle.dotComma)),
      '1.234,5 × 2',
    );
  });

  test('shortDayLabel', () {
    final today = dayOf(2026, 10, 18);
    expect(shortDayLabel(today, today), 'Today');
    expect(shortDayLabel(today - 1, today), 'Yesterday');
    expect(shortDayLabel(today + 1, today), 'Tomorrow');
    expect(shortDayLabel(dayOf(2026, 10, 12), today), 'Oct 12');
    expect(shortDayLabel(dayOf(2025, 10, 12), today), 'Oct 12, 2025');
  });

  group('quickView', () {
    const cats = <CategoryRef>[(id: 2, name: 'Snacks'), (id: 14, name: 'Gifts')];
    const ids = {2, 14};

    QuickView view(String text, {Map<String, int> learned = const {}, int? pick}) => quickView(
      text: text,
      parsed: parseTypeToAdd(text, categories: cats, learned: learned),
      validIds: ids,
      manualPick: pick,
    );

    test('stages', () {
      expect(view('').stage, QuickStage.empty);
      expect(view('coffee').stage, QuickStage.wordOnly);
      expect(view('saree 12000').stage, QuickStage.unknown);
      expect(view('snacks 50').stage, QuickStage.matched);
    });

    test('a known word lights its tile before the amount', () {
      final v = view('coffee', learned: {'coffee': 2});
      expect(v.stage, QuickStage.wordOnly);
      expect(v.categoryId, 2);
    });

    test('a pick by hand wins, is remembered, and confirms it', () {
      final v = view('saree 12000', pick: 14);
      expect(v.stage, QuickStage.matched);
      expect(v.categoryId, 14);
      expect(v.byHand, isTrue);
      expect(v.wordsToLearn, ['saree']);
      expect(v.hint('Gifts'), 'Next time, “saree” goes to Gifts.');
    });

    test('a guessed category teaches nothing and shows no hint', () {
      final v = view('coffee 120', learned: {'coffee': 2});
      expect(v.byHand, isFalse);
      expect(v.wordsToLearn, isEmpty);
      expect(v.hint('Snacks'), isNull);
    });

    test('a pick of a deleted category is ignored', () {
      final v = view('saree 12000', pick: 99);
      expect(v.stage, QuickStage.unknown);
      expect(v.byHand, isFalse);
    });

    test('the hint names the learned words, not the whole title', () {
      final v = view('250 for taxi', pick: 14);
      expect(v.parsed.title, 'Taxi');
      expect(v.wordsToLearn, ['taxi']);
      expect(v.hint('Transportation'), 'Next time, “taxi” goes to Transportation.');
    });

    test('the hint lists several learned words naturally', () {
      final two = view('taxi uber 250', pick: 14);
      expect(two.wordsToLearn, ['taxi', 'uber']);
      expect(two.hint('Transportation'), 'Next time, “taxi” and “uber” go to Transportation.');

      final three = view('taxi to the airport uber 250', pick: 14);
      expect(three.wordsToLearn, ['taxi', 'airport', 'uber']);
      expect(
        three.hint('Transportation'),
        'Next time, “taxi”, “airport” and “uber” go to Transportation.',
      );
    });

    test('words that are not learned stay out of the hint', () {
      final v = view('lunch with Sam 240 x2', pick: 2);
      expect(v.wordsToLearn, ['lunch', 'sam']);
      expect(v.hint('Snacks'), 'Next time, “lunch” and “sam” go to Snacks.');
    });

    test('no title, no hint', () {
      expect(view('500', pick: 14).hint('Gifts'), isNull);
    });
  });

  test('learnableWords skips numbers, one letter and linking words', () {
    expect(learnableWords(['dinner', 'with', 'sam', '240', 'a', 'tv', 'x2', 'dinner']), [
      'dinner',
      'sam',
      'tv',
    ]);
  });
}
