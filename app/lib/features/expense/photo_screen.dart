import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Full-screen receipt photo of an expense (`/expense/:id/photo`).
/// PLACEHOLDER: the Expense feature replaces this file.
class PhotoScreen extends ConsumerWidget {
  const PhotoScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const PlaceholderScreen(title: 'Receipt photo');
}
