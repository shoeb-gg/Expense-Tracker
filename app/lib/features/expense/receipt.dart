import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../state/providers.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit.dart';

/// The bytes of a receipt photo by its stored file name, or null when the
/// file is not on the phone any more. The file is read once and closed
/// (no file handle stays open, so a replaced photo can be deleted at once).
final photoBytesProvider = FutureProvider.autoDispose.family<Uint8List?, String>((ref, name) async {
  final file = await ref.watch(photoStoreProvider).file(name);
  try {
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  } on FileSystemException {
    return null;
  }
});

/// Image of a receipt photo, decoded at about [width] logical px (so a
/// small thumbnail does not decode a whole photo).
ImageProvider receiptImage(Uint8List bytes, {double? width}) {
  final image = MemoryImage(bytes);
  if (width == null) return image;
  return ResizeImage(image, width: (width * 3).round(), allowUpscaling: false);
}

/// A small square picture of the receipt photo. Shows a plain tile with a
/// receipt icon while loading or when the file is missing.
class ReceiptThumb extends ConsumerWidget {
  const ReceiptThumb({super.key, required this.fileName, required this.size, required this.radius});

  final String fileName;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final bytes = ref.watch(photoBytesProvider(fileName)).value;
    final fallback = ColoredBox(
      color: c.tile,
      child: Center(
        child: Icon(Symbols.receipt_long_rounded, size: size * 0.55, color: c.text3),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: bytes == null
            ? fallback
            : Image(
                image: receiptImage(bytes, width: size),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// What the user chose on the receipt photo sheet.
enum ReceiptAction { view, camera, gallery, remove }

/// The "Receipt photo" sheet (Edit expense, or Add with a photo attached):
/// View photo, Take a new photo, Choose from gallery, Remove photo.
Future<ReceiptAction?> showReceiptSheet(BuildContext context, {required String fileName}) {
  return showAppSheet<ReceiptAction>(
    context,
    builder: (ctx) {
      void pick(ReceiptAction a) => Navigator.of(ctx).pop(a);
      return AppSheet(
        title: 'Receipt photo',
        message: 'Attached to this expense.',
        headerTrailing: Semantics(
          button: true,
          label: 'View photo',
          child: GestureDetector(
            onTap: () => pick(ReceiptAction.view),
            child: ExcludeSemantics(child: ReceiptThumb(fileName: fileName, size: 44, radius: 12)),
          ),
        ),
        children: [
          SheetActionRow(
            icon: Symbols.visibility_rounded,
            label: 'View photo',
            onTap: () => pick(ReceiptAction.view),
          ),
          SheetActionRow(
            icon: Symbols.photo_camera_rounded,
            label: 'Take a new photo',
            onTap: () => pick(ReceiptAction.camera),
          ),
          SheetActionRow(
            icon: Symbols.image_rounded,
            label: 'Choose from gallery',
            onTap: () => pick(ReceiptAction.gallery),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SheetActionRow(
              icon: Symbols.delete_rounded,
              label: 'Remove photo',
              destructive: true,
              onTap: () => pick(ReceiptAction.remove),
            ),
          ),
        ],
      );
    },
  );
}

/// Body for an expense that does not exist (bad link, or deleted).
class MissingExpense extends StatelessWidget {
  const MissingExpense({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(
              icon: Symbols.receipt_long_rounded,
              size: 64,
              radius: 20,
              iconSize: 30,
              iconColor: c.text3,
            ),
            const SizedBox(height: 16),
            Text('This expense is gone', style: AppText.cardTitle),
            const SizedBox(height: 4),
            Text(
              'It may have been deleted.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: c.text2),
            ),
          ],
        ),
      ),
    );
  }
}
