import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';

/// One slice of a ring chart.
@immutable
class RingSlice {
  const RingSlice({
    required this.key,
    required this.value,
    required this.color,
    required this.tag,
    required this.isEmoji,
  });

  /// Selection key ('c12', 'other', 'd20744', 'dother').
  final String key;

  /// Amount in minor units.
  final int value;
  final Color color;

  /// Text of the label tile: an emoji, a rank ("1") or "+6".
  final String tag;
  final bool isEmoji;
}

/// The ring of the Charts screen: slices clockwise from 12 o'clock, a label
/// tile beside each slice that has room for one, and [center] in the hole.
/// The selected slice is lifted (scaled 1.06) and the others fade to 40%.
class RingChart extends StatelessWidget {
  const RingChart({
    super.key,
    required this.slices,
    required this.selected,
    required this.onTap,
    required this.center,
  });

  static const double size = 272;
  static const double outer = 96;
  static const double inner = 70;
  static const double tileRadius = 121;
  static const double _mid = (outer + inner) / 2;
  static const Duration _anim = Duration(milliseconds: 200);

  final List<RingSlice> slices;

  /// Key of the lifted slice, or null.
  final String? selected;
  final ValueChanged<String> onTap;
  final Widget center;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = slices.fold<int>(0, (s, e) => s + e.value);
    final layers = <Widget>[];
    final mids = <double>[];
    final shown = <bool>[];

    if (total <= 0) {
      layers.add(_slice(ringSlicePath(0, math.pi * 2, 1), c.track));
    } else {
      // Which slices have room for a label tile (mockup rule: 36 px apart
      // on the tile circle, also across 12 o'clock).
      const need = 36 / tileRadius;
      double? lastMid;
      double? firstMid;
      var acc = 0.0;
      for (final s in slices) {
        final span = s.value / total * math.pi * 2;
        final mid = acc + span / 2;
        acc += span;
        mids.add(mid);
        final ok = (lastMid == null || mid - lastMid >= need) &&
            (firstMid == null || firstMid + math.pi * 2 - mid >= need);
        shown.add(ok);
        if (ok) {
          lastMid = mid;
          firstMid ??= mid;
        }
      }

      var start = 0.0;
      for (var i = 0; i < slices.length; i++) {
        final s = slices[i];
        final span = s.value / total * math.pi * 2;
        final path = ringSlicePath(start, start + span, slices.length);
        start += span;
        final on = selected == s.key;
        layers.add(
          AnimatedScale(
            scale: on ? 1.06 : 1,
            duration: _anim,
            curve: Curves.ease,
            child: AnimatedOpacity(
              opacity: selected != null && !on ? 0.4 : 1,
              duration: _anim,
              curve: Curves.ease,
              child: Stack(
                children: [
                  _slice(path, s.color),
                  if (shown[i])
                    Positioned(
                      left: size / 2 + tileRadius * math.sin(mids[i]) - 15,
                      top: size / 2 - tileRadius * math.cos(mids[i]) - 15,
                      child: _Tile(slice: s),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ...layers,
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final key = _hit(d.localPosition, total, mids, shown);
                if (key != null) onTap(key);
              },
            ),
          ),
          Positioned(
            left: 74,
            top: 74,
            width: 124,
            height: 124,
            child: center,
          ),
        ],
      ),
    );
  }

  Widget _slice(Path path, Color color) => CustomPaint(
        size: const Size(size, size),
        painter: _SlicePainter(path, color),
      );

  /// The slice under [p] (on the ring or on its label tile).
  String? _hit(Offset p, int total, List<double> mids, List<bool> shown) {
    if (total <= 0) return null;
    final dx = p.dx - size / 2;
    final dy = p.dy - size / 2;
    for (var i = 0; i < slices.length; i++) {
      if (!shown[i]) continue;
      final scale = selected == slices[i].key ? 1.06 : 1.0;
      final tx = tileRadius * scale * math.sin(mids[i]);
      final ty = -tileRadius * scale * math.cos(mids[i]);
      if ((dx - tx).abs() <= 15 * scale && (dy - ty).abs() <= 15 * scale) {
        return slices[i].key;
      }
    }
    final r = math.sqrt(dx * dx + dy * dy);
    if (r < inner - 2 || r > outer * 1.06 + 2) return null;
    var angle = math.atan2(dx, -dy);
    if (angle < 0) angle += math.pi * 2;
    var acc = 0.0;
    for (final s in slices) {
      acc += s.value / total * math.pi * 2;
      if (angle <= acc) return s.key;
    }
    return slices.last.key;
  }
}

/// The outline of one ring slice from angle [a0] to [a1] (radians, clockwise
/// from 12 o'clock) in the 272 px ring box, the mockup's `ring()` path: a
/// gap of 3 px at the middle radius between slices (less on thin slices),
/// radial edges and corners rounded by up to 5 px. A slice that fills the
/// whole ring is a plain donut.
Path ringSlicePath(double a0, double a1, int count) {
  const cx = RingChart.size / 2;
  const cy = RingChart.size / 2;
  const big = RingChart.outer;
  const small = RingChart.inner;
  Offset p(double rad, double ang) =>
      Offset(cx + rad * math.sin(ang), cy - rad * math.cos(ang));
  final span = a1 - a0;
  final gap = count > 1 ? math.min(3 / RingChart._mid, span * 0.3) : 0.0;
  final s0 = a0 + gap / 2;
  final s1 = a1 - gap / 2;
  final arc = s1 - s0;
  if (arc > math.pi * 2 - 0.001) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: big))
      ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: small));
  }
  final c = math.max(0.01, math.min(5.0, arc * small * 0.3));
  final dO = math.asin(c / (big - c));
  final dI = math.asin(c / (small + c));
  final ro = (big - c) * math.cos(dO);
  final ri = (small + c) * math.cos(dI);
  final corner = Radius.circular(c);
  return Path()
    ..moveTo(p(big, s0 + dO).dx, p(big, s0 + dO).dy)
    ..arcToPoint(
      p(big, s1 - dO),
      radius: const Radius.circular(big),
      largeArc: arc - 2 * dO > math.pi,
    )
    ..arcToPoint(p(ro, s1), radius: corner)
    ..lineTo(p(ri, s1).dx, p(ri, s1).dy)
    ..arcToPoint(p(small, s1 - dI), radius: corner)
    ..arcToPoint(
      p(small, s0 + dI),
      radius: const Radius.circular(small),
      largeArc: arc - 2 * dI > math.pi,
      clockwise: false,
    )
    ..arcToPoint(p(ri, s0), radius: corner)
    ..lineTo(p(ro, s0).dx, p(ro, s0).dy)
    ..arcToPoint(p(big, s0 + dO), radius: corner)
    ..close();
}

class _SlicePainter extends CustomPainter {
  _SlicePainter(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_SlicePainter old) =>
      old.color != color || old.path != path;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.slice});

  final RingSlice slice;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.tile,
        borderRadius: BorderRadius.circular(10),
      ),
      child: slice.isEmoji
          ? Text(slice.tag, style: AppText.emoji.copyWith(fontSize: 17))
          : Text(slice.tag, style: rankTagStyle(slice.tag, c.text)),
    );
  }
}

/// Text of a rank or "+6" tile: 11.5 px, 10.5 px for three characters, 9.5
/// px for more.
TextStyle rankTagStyle(String tag, Color color) {
  final size = tag.length >= 4
      ? 9.5
      : tag.length == 3
          ? 10.5
          : 11.5;
  return AppText.caption.copyWith(
    fontSize: size,
    height: 14 / size,
    fontWeight: FontWeight.w800,
    color: color,
  );
}
