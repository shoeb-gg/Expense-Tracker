import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Category drill-down (`/category/:id?from=&to=`, opened from Charts).
/// [from] and [to] are inclusive day numbers (null: the screen decides).
/// PLACEHOLDER: the Charts feature replaces this file.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({
    super.key,
    required this.categoryId,
    this.from,
    this.to,
  });

  final int categoryId;
  final int? from;
  final int? to;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const PlaceholderScreen(title: 'Category');
}
