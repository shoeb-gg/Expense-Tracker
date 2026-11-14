import 'package:flutter/widgets.dart';

/// A rounded box with a dashed outline drawn inside its edge, like a CSS
/// `border: 1.5px dashed` (the Manage tile and the "?" tile).
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.size,
    required this.radius,
    required this.color,
    required this.child,
    this.strokeWidth = 1.5,
  });

  final double size;
  final double radius;
  final Color color;
  final double strokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: color, radius: radius, strokeWidth: strokeWidth),
      child: SizedBox.square(
        dimension: size,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius, required this.strokeWidth});

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(half),
      Radius.circular(radius - half),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    // Like Chrome: dashes two strokes long with one-stroke gaps, spread so
    // the pattern closes evenly around the box.
    final dash = strokeWidth * 2;
    final gap = strokeWidth;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      final count = (metric.length / (dash + gap)).round().clamp(1, 1000);
      final step = metric.length / count;
      final on = step * dash / (dash + gap);
      for (var i = 0; i < count; i++) {
        final start = i * step;
        canvas.drawPath(metric.extractPath(start, start + on), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}
