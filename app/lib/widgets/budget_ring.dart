import 'package:flutter/widgets.dart';

import '../state/budgets.dart';
import '../theme/tokens.dart';

/// The colour of a budget ring at [level].
Color budgetColor(AppColors c, BudgetLevel level) => switch (level) {
  BudgetLevel.ok => c.budgetOk,
  BudgetLevel.near => c.budgetNear,
  BudgetLevel.over => c.budgetOver,
};

/// A budget's progress drawn along the inside of a rounded square's edge: a
/// faint [track] all the way round, then the used part in [color], starting
/// at the top centre and running clockwise. Over 100% the ring is full.
class BudgetRingPainter extends CustomPainter {
  const BudgetRingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.radius,
    this.stroke = 3,
  });

  /// Spent / budget (any value from 0; 1 and more draw a full ring).
  final double progress;

  /// The used part.
  final Color color;

  /// The whole way round, under the used part.
  final Color track;

  /// Corner radius of the square the ring lines.
  final double radius;

  /// Ring thickness, drawn inside the edge.
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = stroke / 2;
    final rect = (Offset.zero & size).deflate(inset);
    final r = radius - inset;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
    canvas.drawRRect(rrect, paint..color = track);

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    if (p >= 1) {
      canvas.drawRRect(rrect, paint..color = color);
      return;
    }
    final corner = Radius.circular(r);
    final path = Path()
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: corner)
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(Offset(rect.right - r, rect.bottom), radius: corner)
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - r), radius: corner)
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: corner)
      ..lineTo(rect.center.dx, rect.top);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * p),
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(BudgetRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.radius != radius ||
      old.stroke != stroke;
}
