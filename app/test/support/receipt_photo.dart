import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/data/photo_store.dart';
import 'package:spill_the_bills/features/add/photo_picker.dart';
import 'package:spill_the_bills/theme/text.dart';

/// A [PhotoStore] in [dir] that copies instead of compressing.
PhotoStore copyingPhotoStore(Directory dir) => PhotoStore(
  baseDir: () async => dir,
  compressor: (source, target) async {
    await File(source).copy(target);
    return true;
  },
);

/// A picker that hands back [path] (or null, like backing out), and
/// remembers what was asked.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker(this.path);

  String? path;
  final List<PhotoSource> asked = [];

  @override
  Future<String?> pick(PhotoSource source) async {
    asked.add(source);
    return path;
  }
}

/// Draws a receipt photo like the mockup's (a clinic receipt on a brown
/// table, 360 x 540 at 2x) and writes it as a PNG. Run inside
/// `tester.runAsync`.
Future<File> writeReceiptPhoto(Directory dir, {String name = 'camera_shot.png'}) async {
  const w = 360.0;
  const h = 540.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(2);

  // The table: radial-gradient(120% 90% at 30% 15%, #6A5846, #46392D 50%, #2A221B).
  final bg = Paint()
    ..shader = ui.Gradient.radial(
      const Offset(w * 0.3, h * 0.15),
      h * 0.95,
      const [Color(0xFF6A5846), Color(0xFF46392D), Color(0xFF2A221B)],
      const [0, 0.5, 1],
    );
  canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), bg);

  // The paper, 240 x 456 at (60, 42), turned -2.5 degrees.
  const paper = Rect.fromLTWH(60, 42, 240, 456);
  canvas
    ..save()
    ..translate(paper.center.dx, paper.center.dy)
    ..rotate(-2.5 * math.pi / 180)
    ..translate(-paper.center.dx, -paper.center.dy);
  canvas.drawRect(
    paper.shift(const Offset(0, 18)),
    Paint()
      ..color = const Color(0x73000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
  );
  canvas.drawRect(
    paper,
    Paint()
      ..shader = ui.Gradient.linear(paper.topCenter, paper.bottomCenter, const [
        Color(0xFFF8F5EE),
        Color(0xFFEDE8DC),
      ]),
  );

  const ink = Color(0xFF2B2925);
  const faint = Color(0xFF6B675E);
  const left = 80.0;
  const right = 280.0;
  var y = 64.0;
  void line(
    String text, {
    Color color = ink,
    double size = 12,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.left,
    double spacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: kFontFamily,
          fontSize: size,
          height: 20 / size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: color,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: right - left, maxWidth: right - left);
    tp.paint(canvas, Offset(left, y));
  }

  void pair(String a, String b, {double size = 12, FontWeight weight = FontWeight.w500}) {
    line(a, size: size, weight: weight);
    line(b, size: size, weight: weight, align: TextAlign.right);
  }

  void dashes() {
    y += 12;
    final paint = Paint()
      ..color = const Color(0xFFA8A397)
      ..strokeWidth = 1.5;
    for (var x = left; x < right; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, right), y), paint);
    }
    y += 13.5;
  }

  line(
    'CITY HEALTH CLINIC',
    size: 14,
    weight: FontWeight.w700,
    align: TextAlign.center,
    spacing: 1,
  );
  y += 20;
  line('Receipt no. 004512', color: faint, align: TextAlign.center);
  y += 20;
  line('18 Oct 2026  10:12', color: faint, align: TextAlign.center);
  y += 20;
  dashes();
  pair('Consultation', '800');
  y += 20;
  pair('Blood test', '300');
  y += 20;
  pair('Medicine', '80');
  y += 20;
  dashes();
  pair('TOTAL', '1,180', size: 15, weight: FontWeight.w700);
  y += 28;
  line('Paid in cash', color: faint);
  y += 44;
  // Barcode.
  final bar = Paint()..color = ink;
  for (var x = left; x < right; x += 15) {
    canvas
      ..drawRect(Rect.fromLTWH(x, y, 2, 44), bar)
      ..drawRect(Rect.fromLTWH(x + 5, y, 1, 44), bar)
      ..drawRect(
        Rect.fromLTWH(x + 10, y, math.max(0, math.min(3, right - x - 10)).toDouble(), 44),
        bar,
      );
  }
  y += 54;
  line('Thank you', color: faint, align: TextAlign.center);
  canvas.restore();

  final image = await recorder.endRecording().toImage(720, 1080);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}
