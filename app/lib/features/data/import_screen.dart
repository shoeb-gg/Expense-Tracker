import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Import, step 1 of 3 (`/settings/import`). PLACEHOLDER: the Data feature
/// replaces this file.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const PlaceholderScreen(
        title: 'Import',
        header: SubHeader(title: 'Import', subtitle: 'Step 1 of 3'),
      );
}
