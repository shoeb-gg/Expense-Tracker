import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../state/providers.dart';
import '../../widgets/kit.dart';

/// The one way to delete an expense (Details and Home's hold menu).
///
/// Asks "Delete this expense?" with "title (or category) · amount" and a
/// quiet second line (the NewExpense board's layout). The board's "This
/// can't be undone." is not true here, because the toast offers Undo, so
/// the line says that instead. When confirmed it runs [onConfirmed]
/// (Details keeps showing the expense while it closes), deletes the
/// expense and shows "Expense
/// deleted" with Undo. The photo file stays on the phone until Clear cache
/// or the next start, so Undo brings the photo back too.
///
/// Returns true when the expense was deleted.
Future<bool> deleteExpenseWithUndo(
  BuildContext context,
  WidgetRef ref,
  Expense expense, {
  VoidCallback? onConfirmed,
}) async {
  final category = ref.read(categoriesByIdProvider)[expense.categoryId];
  final fmt = ref.read(amountFormatProvider);
  final note = expense.note.trim();
  final name = note.isNotEmpty ? note : (category?.name ?? '');
  final ok = await showAppDialog(
    context,
    title: 'Delete this expense?',
    boldLine: '$name · ${fmt.format(expense.amount)}',
    quietLine: 'You can undo this right after.',
    actionLabel: 'Delete',
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  final repo = ref.read(expensesRepoProvider);
  onConfirmed?.call();
  final deleted = await repo.delete(expense.id);
  if (deleted == null) return false;
  if (context.mounted) {
    showToast(
      context,
      'Expense deleted',
      onUndo: () => unawaited(repo.restore(deleted)),
    );
  }
  return true;
}
