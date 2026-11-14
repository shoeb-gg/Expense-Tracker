import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/core/calculator.dart';

int? units(String e) {
  final minor = evaluateExpression(e);
  return minor == null ? null : minor ~/ 100;
}

void main() {
  group('evaluateExpression (mockup calc())', () {
    test('cases from NewAddCalc', () {
      expect(units('120×3+50'), 410);
      expect(units('100÷4−5'), 20);
      expect(units('2+3×4'), 14);
      expect(units('10−2×3'), 4);
    });

    test('no result: divide by zero, negative, huge', () {
      expect(evaluateExpression('5÷0'), isNull);
      expect(evaluateExpression('10+5÷0'), isNull);
      expect(evaluateExpression('5−10'), isNull);
      expect(evaluateExpression('999999999×999999999'), isNull);
    });

    test('trailing operator is ignored, empty is 0', () {
      expect(units('120×'), 120);
      expect(units('120+'), 120);
      expect(evaluateExpression(''), 0);
      expect(evaluateExpression('5−5'), 0);
    });

    test('decimals round to cents', () {
      expect(evaluateExpression('0.1+0.2'), 30);
      expect(evaluateExpression('10÷3'), 333);
      expect(evaluateExpression('12.5'), 1250);
      expect(evaluateExpression('1.25×2'), 250);
    });

    test('ASCII operators are accepted', () {
      expect(units('120*3+50'), 410);
      expect(units('100/4-5'), 20);
    });
  });

  group('applyKeypadKey (mockup press())', () {
    String type(String keys) {
      var e = '';
      for (final k in keys.split(' ')) {
        e = applyKeypadKey(e, k);
      }
      return e;
    }

    test('digits, dot and decimals', () {
      expect(type('1 2 0'), '120');
      expect(type('. 5'), '0.5');
      expect(type('1 . 2 5 9'), '1.25'); // at most two decimals
      expect(type('0 7'), '7'); // a lone 0 is replaced
      expect(type('1 2 3 4 5 6 7 8 9 1'), '123456789'); // at most 9 digits
      expect(type('1 . .'), '1.');
    });

    test('operators', () {
      expect(type('+'), ''); // nothing to add to yet
      expect(type('1 2 0 + −'), '120−'); // a second operator replaces the first
      expect(type('1 2 0 × 3 + 5 0'), '120×3+50');
      expect(hasOperator('120×3'), isTrue);
      expect(hasOperator('120'), isFalse);
      expect(displayExpression('120×3+50'), '120 × 3 + 50');
    });

    test('backspace and equals', () {
      expect(type('1 2 del'), '1');
      expect(type('del'), '');
      expect(type('1 2 0 × 3 + 5 0 ='), '410');
      expect(type('1 0 ÷ 4 ='), '2.5');
      expect(type('5 ÷ 0 ='), ''); // no result
    });
  });
}
