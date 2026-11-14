import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/kit.dart';

/// Calendar (`/calendar?day=`): opens on the month of [day] (today when
/// null). PLACEHOLDER: the Calendar feature replaces this file.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key, this.day});

  final int? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const PlaceholderScreen(title: 'Calendar');
}
