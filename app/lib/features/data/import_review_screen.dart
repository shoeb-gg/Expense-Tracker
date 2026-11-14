import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Import, step 3 of 3: "Review and import" (`/settings/import/review`).
/// PLACEHOLDER: the Data feature replaces this file.
class ImportReviewScreen extends ConsumerWidget {
  const ImportReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const PlaceholderScreen(
        title: 'Review and import',
        header: SubHeader(title: 'Review and import', subtitle: 'Step 3 of 3'),
      );
}
