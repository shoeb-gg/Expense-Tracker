import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Expense details (`/expense/:id`). PLACEHOLDER: the Expense feature
/// replaces this file.
class ExpenseDetailsScreen extends ConsumerWidget {
  const ExpenseDetailsScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const PlaceholderScreen(title: 'Details');
}
