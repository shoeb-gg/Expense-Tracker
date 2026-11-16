import 'package:flutter/widgets.dart';

import '../../core/days.dart';
import '../../core/format.dart';
import '../../state/budgets.dart';
import '../../theme/symbols.dart';
import '../../theme/tokens.dart';
import '../../widgets/budget_ring.dart';

/// The toast after saving an expense into a category that has a budget.
@immutable
class BudgetAlert {
  const BudgetAlert({required this.level, required this.title, required this.detail});

  /// [BudgetLevel.near] (just passed 90%) or [BudgetLevel.over].
  final BudgetLevel level;

  /// "Snacks is 600 over budget" / "Snacks has used 92% of its budget".
  final String title;

  /// "5,600 of 5,000 spent this month" (plus "· 400 left" when near).
  final String detail;

  @override
  bool operator ==(Object other) =>
      other is BudgetAlert && other.level == level && other.title == title && other.detail == detail;

  @override
  int get hashCode => Object.hash(level, title, detail);

  @override
  String toString() => 'BudgetAlert($level, $title, $detail)';
}

/// What to say after a save moved [category]'s spending in the month of
/// [day] from [before] to [after] (minor units), against its monthly
/// [budget]; null when there is nothing to say.
///
/// - Over budget after the save: always say so, and by how much.
/// - Just passed 90% (under 90% before, 90% to 100% after): say it once.
/// - Anything else (still under 90%, or already past 90% before): nothing.
BudgetAlert? budgetAlert({
  required String category,
  required int before,
  required int after,
  required int budget,
  required int day,
  required int today,
  required AmountFormat fmt,
}) {
  if (budget <= 0) return null;
  final when = _whichMonth(day, today);
  final spent = '${fmt.format(after)} of ${fmt.format(budget)} spent $when';
  final level = BudgetUse.levelOf(after, budget);
  if (level == BudgetLevel.over) {
    final over = after - budget;
    // With decimals hidden, under 0.50 over would round to "0 over".
    final overText = fmt.format(over) == fmt.format(0) ? fmt.formatExact(over) : fmt.format(over);
    return BudgetAlert(
      level: BudgetLevel.over,
      title: '$category is $overText over budget',
      detail: spent,
    );
  }
  if (level == BudgetLevel.near && BudgetUse.levelOf(before, budget) == BudgetLevel.ok) {
    final percent = after * 100 ~/ budget;
    final left = budget - after;
    return BudgetAlert(
      level: BudgetLevel.near,
      title: '$category has used $percent% of its budget',
      detail: left > 0 ? '$spent · ${fmt.format(left)} left' : spent,
    );
  }
  return null;
}

/// "this month", "in September", or "in December 2025" for another year.
String _whichMonth(int day, int today) {
  final d = dateOfDay(day);
  final t = dateOfDay(today);
  if (d.year == t.year && d.month == t.month) return 'this month';
  final name = monthName(d.month);
  return d.year == t.year ? 'in $name' : 'in $name ${d.year}';
}

/// The toast's status mark: a rising line in yellow when near, a filled
/// "!" circle in red when over (two shapes, so it never rests on colour).
class BudgetAlertMark extends StatelessWidget {
  const BudgetAlertMark({super.key, required this.level});

  final BudgetLevel level;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Icon(
      level == BudgetLevel.over ? Symbols.error_rounded : Symbols.trending_up_rounded,
      size: 24,
      color: budgetColor(c.brightness == Brightness.light ? c.copyWith(brightness: Brightness.dark) : c, level),
    );
  }
}
