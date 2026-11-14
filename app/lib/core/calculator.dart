/// The Add expense keypad's calculator (port of the mockup's `calc()` and
/// `press()` in NewAddCalc.dc.html).
///
/// Expressions are strings of numbers (dot decimal, no grouping) joined by
/// the operators [opPlus], [opMinus] (U+2212), [opTimes] (U+00D7) and
/// [opDivide] (U+00F7). ASCII `-`, `*`, `/`, `x` are accepted as aliases.
library;

import 'format.dart';

const String opPlus = '+';
const String opMinus = '−';
const String opTimes = '×';
const String opDivide = '÷';

/// Operators on the "Plus and minus" keypad.
const List<String> plusMinusOperators = [opPlus, opMinus];

/// Operators on the "All four keys" keypad.
const List<String> allOperators = [opTimes, opPlus, opDivide, opMinus];

final RegExp _operator = RegExp('[+−×÷]');
final RegExp _trailingOperator = RegExp('[+−×÷]\$');
final RegExp _digit = RegExp(r'^[0-9]$');

String _normalise(String expr) => expr
    .replaceAll(' ', '')
    .replaceAll('-', opMinus)
    .replaceAll('*', opTimes)
    .replaceAll('x', opTimes)
    .replaceAll('/', opDivide);

/// Whether [expr] contains an operator (the keypad then shows "=").
bool hasOperator(String expr) => _operator.hasMatch(_normalise(expr));

/// Whether [key] is one of the four operator keys.
bool isOperatorKey(String key) => _operator.hasMatch(key) && key.length == 1;

/// The expression as shown in the small line above the amount: operators
/// get a space on each side ("120 × 3 + 50").
String displayExpression(String expr) =>
    _normalise(expr).replaceAllMapped(_operator, (m) => ' ${m[0]} ');

/// Works out [expr] with the usual order (× and ÷ before + and −) and
/// returns the result in minor units (rounded to cents).
///
/// Returns null when there is no result: dividing by zero, a negative
/// result, or a result of 1e15 or more. A trailing operator is ignored
/// ("120×" is 120). An empty expression is 0.
int? evaluateExpression(String expr) {
  final e = _normalise(expr).replaceFirst(_trailingOperator, '');
  if (e.isEmpty) return 0;
  final numbers = e.split(_operator);
  final ops = _operator.allMatches(e).map((m) => m[0]!).toList();
  double parse(String s) => double.tryParse(s) ?? 0;
  var total = 0.0;
  var sign = 1.0;
  var term = parse(numbers.first);
  for (var i = 0; i < ops.length; i++) {
    final n = parse(numbers[i + 1]);
    final op = ops[i];
    if (op == opTimes) {
      term *= n;
    } else if (op == opDivide) {
      if (n == 0) return null;
      term /= n;
    } else {
      total += sign * term;
      sign = op == opPlus ? 1 : -1;
      term = n;
    }
  }
  total += sign * term;
  if (!total.isFinite || total.abs() >= 1e15) return null;
  final minor = (total * 100).round();
  if (minor < 0) return null;
  return minor;
}

/// Applies one keypad key to [expr] and returns the new expression.
///
/// Keys: '0'-'9', '.', the operators, 'del' (backspace) and '=' (replace the
/// expression by its result). Rules from the mockup: at most 9 digits and 2
/// decimals per number; a lone leading 0 is replaced by the next digit; '.'
/// on an empty number types "0."; an operator right after another operator
/// replaces it; an operator on an empty expression does nothing.
String applyKeypadKey(String expr, String key) {
  var e = _normalise(expr);
  final k = key.length == 1 ? _normalise(key) : key;
  final last = e.split(_operator).last;
  if (_digit.hasMatch(k)) {
    final dot = last.indexOf('.');
    if (dot >= 0 && last.length - dot - 1 >= 2) return e;
    if (last == '0') return e.substring(0, e.length - 1) + k;
    if (last.replaceAll('.', '').length < 9) return e + k;
    return e;
  }
  if (k == '.') {
    if (last.contains('.')) return e;
    return e + (last.isEmpty ? '0.' : '.');
  }
  if (isOperatorKey(k)) {
    if (e.isEmpty) return e;
    return _trailingOperator.hasMatch(e) ? e.substring(0, e.length - 1) + k : e + k;
  }
  if (k == 'del') {
    return e.isEmpty ? e : e.substring(0, e.length - 1);
  }
  if (k == '=') {
    final result = evaluateExpression(e);
    e = result == null ? '' : minorToKeypad(result);
    return e;
  }
  return e;
}
