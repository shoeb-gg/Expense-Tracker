/// Category budgets: how much of a category's monthly budget is used.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a category stands against its budget for a month.
enum BudgetLevel {
  /// Under 90% used: green.
  ok,

  /// 90% up to and including 100%: yellow.
  near,

  /// Over 100%: red.
  over,
}

/// A category's spending in a month against its monthly budget, both in
/// minor units (amount x 100).
@immutable
class BudgetUse {
  const BudgetUse({required this.spent, required this.budget})
    : assert(budget > 0, 'a budget is always more than zero');

  /// Spent in the month.
  final int spent;

  /// The monthly budget.
  final int budget;

  /// Spent / budget: 0.3 is 30% used; over 1 is over budget.
  double get progress => spent / budget;

  /// Green under 90%, yellow from 90% to 100%, red over 100%.
  BudgetLevel get level {
    if (spent > budget) return BudgetLevel.over;
    if (spent * 10 >= budget * 9) return BudgetLevel.near;
    return BudgetLevel.ok;
  }

  /// How much over the budget (0 when not over).
  int get overBy => spent > budget ? spent - budget : 0;

  @override
  bool operator ==(Object other) =>
      other is BudgetUse && other.spent == spent && other.budget == budget;

  @override
  int get hashCode => Object.hash(spent, budget);
}

/// The budget use of every category that has a budget, in the pocket in use,
/// for the month starting on [monthStart] (a day number, see `core/days.dart`).
/// Categories without a budget are not in the map.
final budgetUsesProvider = Provider.family<Map<int, BudgetUse>, int>(
  (ref, monthStart) => const <int, BudgetUse>{},
);
