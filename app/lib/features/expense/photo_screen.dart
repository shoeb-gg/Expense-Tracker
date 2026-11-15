import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../state/providers.dart';
import '../../theme/symbols.dart';
import '../../theme/text.dart';
import '../../widgets/kit.dart';
import '../add/add_styles.dart';
import 'receipt.dart';

/// Full-screen receipt photo of an expense (`/expense/:id/photo`).
class PhotoScreen extends ConsumerWidget {
  const PhotoScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseProvider(expenseId));
    final expense = async.value;
    if (expense == null) {
      return PhotoViewer(
        fileName: null,
        title: async.isLoading ? '' : 'Expense not found',
        caption: '',
      );
    }
    final category = ref.watch(categoriesByIdProvider)[expense.categoryId];
    final fmt = ref.watch(amountFormatProvider);
    return PhotoViewer(
      fileName: expense.photoPath,
      title: expense.note.isNotEmpty ? expense.note : (category?.name ?? ''),
      caption: photoCaption(expense.day, expense.amount, fmt),
    );
  }
}

/// "Oct 18, 2026 · 1,180", under the photo.
String photoCaption(int day, int amount, AmountFormat format) =>
    '${mediumDate(day)} · ${format.format(amount)}';

/// Opens the viewer for a photo that is not saved with an expense yet
/// (Add expense, or a new photo on Edit expense).
Future<void> openPhotoViewer(
  BuildContext context, {
  required String fileName,
  required String title,
  required String caption,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PhotoViewer(fileName: fileName, title: title, caption: caption),
    ),
  );
}

/// The viewer itself: always dark, a close button, the photo (pinch to
/// zoom) and a caption with the title, date and amount.
class PhotoViewer extends ConsumerWidget {
  const PhotoViewer({
    super.key,
    required this.fileName,
    required this.title,
    required this.caption,
  });

  /// Stored file name, or null when there is no photo.
  final String? fileName;
  final String title;
  final String caption;

  /// Background of the viewer, the same in every colour theme.
  static const Color background = Color(0xFF05090A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = fileName;
    final bytesAsync = name == null ? null : ref.watch(photoBytesProvider(name));
    final bytes = bytesAsync?.value;
    final loading = bytesAsync != null && bytesAsync.isLoading;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final Widget photo;
    if (bytes != null) {
      photo = InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(
          child: Image(
            image: receiptImage(bytes),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const _MissingPhoto(),
          ),
        ),
      );
    } else if (loading) {
      photo = const SizedBox.expand();
    } else {
      photo = const _MissingPhoto();
    }
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubHeader(
              title: 'Receipt',
              leading: RoundIconButton(
                icon: Symbols.close_rounded,
                semanticLabel: 'Close',
                background: const Color(0x1FFFFFFF),
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(child: ClipRect(child: photo)),
            Container(
              height: 58 + inset,
              padding: EdgeInsets.fromLTRB(16, 0, 16, inset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: boardText(15, 20, FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.tabular(
                            AppText.sub,
                          ).copyWith(color: const Color(0xADFFFFFF)),
                        ),
                      ],
                    ),
                  ),
                  if (bytes != null) ...[
                    const SizedBox(width: 12),
                    const ExcludeSemantics(child: _PinchHint()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinchHint extends StatelessWidget {
  const _PinchHint();

  @override
  Widget build(BuildContext context) {
    const color = Color(0x8CFFFFFF);
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.zoom_in_rounded, size: 16, color: color),
          const SizedBox(width: 4),
          Text('Pinch to zoom', style: boardText(12.5, 20, FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}

/// Shown when the photo file is not on the phone any more.
class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Symbols.hide_image_rounded, size: 30, color: Color(0x8CFFFFFF)),
          ),
          const SizedBox(height: 16),
          Text('Photo not found', style: AppText.cardTitle),
          const SizedBox(height: 4),
          Text(
            'The file is no longer on this phone.',
            style: AppText.body.copyWith(color: const Color(0xADFFFFFF)),
          ),
        ],
      ),
    );
  }
}
