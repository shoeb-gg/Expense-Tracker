/// Category budgets: how much of a category's monthly budget is used.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/days.dart';
import '../data/budgets_repo.dart';
import 'providers.dart';

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
  BudgetLevel get level => levelOf(spent, budget);

  /// How much over the budget (0 when not over).
  int get overBy => spent > budget ? spent - budget : 0;

  /// The level of [spent] against [budget] (both minor units, budget > 0).
  static BudgetLevel levelOf(int spent, int budget) {
    if (spent > budget) return BudgetLevel.over;
    if (spent * 10 >= budget * 9) return BudgetLevel.near;
    return BudgetLevel.ok;
  }

  @override
  bool operator ==(Object other) =>
      other is BudgetUse && other.spent == spent && other.budget == budget;

  @override
  int get hashCode => Object.hash(spent, budget);

  @override
  String toString() => 'BudgetUse($spent of $budget)';
}

/// A pocket and the first day of a month (a day number, see core/days.dart).
typedef PocketMonth = ({int pocketId, int monthStart});

final budgetsRepoProvider = Provider<BudgetsRepo>(
  (ref) => BudgetsRepo(ref.watch(databaseProvider)),
);

/// A pocket's budgets: category id -> monthly amount (minor units).
final pocketBudgetsProvider = StreamProvider.autoDispose.family<Map<int, int>, int>(
  (ref, pocketId) => ref.watch(budgetsRepoProvider).watch(pocketId),
);

/// The budget use of every category that has a budget in the pocket, for
/// the month. Categories without a budget are not in the map.
final budgetUsesProvider = Provider.autoDispose.family<Map<int, BudgetUse>, PocketMonth>(
  (ref, k) {
    final budgets = ref.watch(pocketBudgetsProvider(k.pocketId)).value;
    if (budgets == null || budgets.isEmpty) return const <int, BudgetUse>{};
    final first = dateOfDay(k.monthStart);
    final range = (
      pocketId: k.pocketId,
      from: k.monthStart,
      to: monthEnd(first.year, first.month),
    );
    final totals = ref.watch(categoryTotalsProvider(range)).value ?? const <CategoryTotal>[];
    final spent = {for (final t in totals) t.categoryId: t.total};
    return {
      for (final MapEntry(key: id, value: budget) in budgets.entries)
        id: BudgetUse(spent: spent[id] ?? 0, budget: budget),
    };
  },
);
