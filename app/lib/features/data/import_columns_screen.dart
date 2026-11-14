import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Import, step 2 of 3: "Check the columns" (`/settings/import/columns`).
/// PLACEHOLDER: the Data feature replaces this file.
class ImportColumnsScreen extends ConsumerWidget {
  const ImportColumnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const PlaceholderScreen(
        title: 'Check the columns',
        header: SubHeader(title: 'Check the columns', subtitle: 'Step 2 of 3'),
      );
}
