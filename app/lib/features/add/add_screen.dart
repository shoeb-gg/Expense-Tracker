import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Add expense (`/add?day=`) and Edit expense (`/expense/:id/edit`, with
/// [expenseId]). [day] preselects the date (Calendar's "Add expense on").
/// PLACEHOLDER: the Add feature replaces this file.
class AddScreen extends ConsumerWidget {
  const AddScreen({super.key, this.day, this.expenseId});

  final int? day;
  final int? expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = expenseId == null ? 'Add expense' : 'Edit expense';
    return PlaceholderScreen(
      title: title,
      header: SubHeader.cancel(
        title: title,
        onCancel: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
