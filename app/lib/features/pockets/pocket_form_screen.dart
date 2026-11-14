import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Add pocket (`/pockets/new`) and Edit pocket (`/pockets/:id`, with
/// [pocketId]). PLACEHOLDER: the Pockets feature replaces this file.
class PocketFormScreen extends ConsumerWidget {
  const PocketFormScreen({super.key, this.pocketId});

  final int? pocketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = pocketId == null ? 'Add pocket' : 'Edit pocket';
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
