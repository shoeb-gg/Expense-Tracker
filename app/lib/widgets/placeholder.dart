import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'headers.dart';

/// Temporary body of a screen that is not built yet. Feature agents replace
/// the screen file; delete this widget once no screen uses it.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.header,
    this.lines = const [],
    this.tab = false,
  });

  final String title;

  /// Replaces the default header (SubHeader with a back button, or the
  /// tab PageHeader when [tab]).
  final Widget? header;

  /// Extra lines shown in the body (for debugging the data flow).
  final List<String> lines;

  /// Tab screen: 64 px PageHeader and no back button.
  final bool tab;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header ?? (tab ? PageHeader(title: title) : SubHeader(title: title)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title is not built yet.',
                      style: AppText.rowTitle.copyWith(color: c.text3),
                    ),
                    for (final line in lines) ...[
                      const SizedBox(height: 8),
                      Text(line, style: AppText.rowTitle),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
