import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Add category (`/settings/categories/new`) and Edit category
/// (`/settings/categories/:id`, with [categoryId]).
/// PLACEHOLDER: the Categories feature replaces this file.
class CategoryFormScreen extends ConsumerWidget {
  const CategoryFormScreen({super.key, this.categoryId});

  final int? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = categoryId == null ? 'Add category' : 'Edit category';
    return PlaceholderScreen(
      title: title,
      header: SubHeader.form(
        title: title,
        onCancel: () => Navigator.of(context).maybePop(),
        onSave: null,
      ),
    );
  }
}
