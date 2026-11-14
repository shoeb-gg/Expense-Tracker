/// Colour tokens, computed exactly like the mockup's `theme(mood)` in
/// design/mockup/project/NewCharts.dc.html (plus the hero-card tokens of
/// MoodAqua and the pop-up tokens of `popKit()`).
///
/// Read them with `context.colors` (an [AppColors] theme extension).
library;

import 'package:flutter/material.dart';

/// The three colour themes. Aqua is the default.
enum Mood {
  aqua('Aqua'),
  coral('Coral'),
  iris('Iris');

  const Mood(this.label);

  /// Name shown in Settings.
  final String label;
}

/// `mix(a, b, w)`: w parts of colour [a], the rest colour [b], per channel,
/// rounded (the mockup's helper). Alpha is taken from [a].
Color mix(Color a, Color b, double w) {
  int ch(Color c, int shift) => (c.toARGB32() >> shift) & 0xFF;
  int part(int shift) => (ch(a, shift) * w + ch(b, shift) * (1 - w)).round();
  return Color.fromARGB(ch(a, 24), part(16), part(8), part(0));
}

/// Every colour token of one mood.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.mood,
    required this.bg,
    required this.nav,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.onAccent,
    required this.ink,
    required this.tile,
    required this.accentSoft,
    required this.accentGlow,
    required this.wash,
    required this.other,
    required this.barSoft,
    required this.barDim,
    required this.ramp,
    required this.tip,
    required this.stub,
    required this.track,
    required this.onAccentDim,
    required this.heat,
    required this.dim,
    required this.good,
    required this.bad,
    required this.onBad,
    required this.pillDim,
    required this.sheen,
    required this.ring,
    required this.ringSoft,
    required this.switchOff,
    required this.popDim,
    required this.popGrab,
    required this.popStub,
    required this.scrim,
  });

  /// Tokens of [mood], computed like the mockup.
  factory AppColors.of(Mood mood) {
    final base = _bases[mood]!;
    final surface = base.surface;
    final surface2 = base.surface2;
    final accent = base.accent;
    final tile = Color.fromARGB(
      0xFF,
      ((surface.toARGB32() >> 16 & 0xFF) * 0.87 + 33).round(),
      ((surface.toARGB32() >> 8 & 0xFF) * 0.87 + 33).round(),
      ((surface.toARGB32() & 0xFF) * 0.87 + 33).round(),
    );
    return AppColors(
      mood: mood,
      bg: base.bg,
      nav: base.nav,
      surface: surface,
      surface2: surface2,
      line: base.line,
      text: base.text,
      text2: base.text2,
      text3: base.text3,
      accent: accent,
      onAccent: base.onAccent,
      ink: base.ink,
      tile: tile,
      accentSoft: accent.withAlpha(0x2E),
      accentGlow: accent.withAlpha(0x59),
      wash: accent.withAlpha(0x29),
      other: mix(base.text3, surface, 0.5),
      barSoft: mix(accent, surface, 0.6),
      barDim: mix(accent, surface, 0.36),
      ramp: List.unmodifiable(
        [1.0, 0.86, 0.72, 0.58, 0.44].map((w) => mix(accent, surface, w)),
      ),
      tip: mix(const Color(0xFFFFFFFF), surface2, 0.1),
      stub: mix(base.text3, surface, 0.28),
      track: mix(base.bg, surface, 0.5),
      onAccentDim: base.onAccent.withAlpha(0xD9),
      heat: List.unmodifiable(
        [0.4, 0.56, 0.74, 0.94].map((w) => mix(accent, base.bg, w)),
      ),
      dim: mix(base.text3, base.bg, 0.55),
      good: const Color(0xFF5BD49B),
      bad: const Color(0xFFFF8C9A),
      onBad: const Color(0xFF2A0B12),
      pillDim: const Color(0xB8FFFFFF),
      sheen: const Color(0x4DFFFFFF),
      ring: const Color(0x47FFFFFF),
      ringSoft: const Color(0x26FFFFFF),
      switchOff: mix(base.text3, surface, 0.4),
      popDim: mix(base.text3, surface2, 0.5),
      popGrab: mix(base.text3, surface2, 0.4),
      popStub: mix(base.text3, surface2, 0.45),
      scrim: const Color(0xE0040A0B),
    );
  }

  final Mood mood;

  /// Page background.
  final Color bg;

  /// Bottom bar and docked bars.
  final Color nav;

  /// Cards and round buttons.
  final Color surface;

  /// Card title bands, pop-ups and sheets.
  final Color surface2;

  /// Dividers and hairlines.
  final Color line;

  /// Main text.
  final Color text;

  /// Secondary text (unselected nav labels, quiet lines).
  final Color text2;

  /// Tertiary text (sub-lines, hints, chevrons).
  final Color text3;

  /// The mood's accent (turquoise in Aqua).
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// Darkest ink tone of the mood.
  final Color ink;

  /// Neutral tile behind emojis and in pop-ups: surface x 0.87 + 33.
  final Color tile;

  /// Accent at alpha 0x2E (selected tints, date badges).
  final Color accentSoft;

  /// Accent at alpha 0x59 (glows under accent buttons).
  final Color accentGlow;

  /// Accent at alpha 0x29.
  final Color wash;

  /// Chart slate for "all the rest".
  final Color other;

  /// Soft accent bars (charts).
  final Color barSoft;

  /// Dim accent bars (charts).
  final Color barDim;

  /// Five accent steps from strong to weak (charts).
  final List<Color> ramp;

  /// Chart tooltip background.
  final Color tip;

  /// Faint chart marks ("still to come").
  final Color stub;

  /// Slider and progress-bar tracks.
  final Color track;

  /// onAccent at alpha 0xD9 (quiet text on accent).
  final Color onAccentDim;

  /// Calendar heat ramp, four steps from low to high spending.
  final List<Color> heat;

  /// A dim text tone (future days, slider stops).
  final Color dim;

  /// Green: spending went down.
  final Color good;

  /// Rose: destructive actions, spending went up.
  final Color bad;

  /// Text on [bad].
  final Color onBad;

  /// White at alpha 0xB8 (year label on the Home month pill).
  final Color pillDim;

  /// White at alpha 0x4D (inner top highlight of the hero card).
  final Color sheen;

  /// White at alpha 0x47 (hero card ring).
  final Color ring;

  /// White at alpha 0x26 (hero card outer ring).
  final Color ringSoft;

  /// Switch track when off: mix(text3, surface, 0.4).
  final Color switchOff;

  /// Pop-ups: faint neighbouring days, mix(text3, surface2, 0.5).
  final Color popDim;

  /// Pop-ups: sheet grabber, mix(text3, surface2, 0.4).
  final Color popGrab;

  /// Pop-ups: unticked rings and tick boxes, mix(text3, surface2, 0.45).
  final Color popStub;

  /// Pop-up scrim, rgba(4, 10, 11, 0.88).
  final Color scrim;

  /// The mockup's `mix` helper.
  Color mixColors(Color a, Color b, double w) => mix(a, b, w);

  @override
  AppColors copyWith({Mood? mood}) => mood == null ? this : AppColors.of(mood);

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> ll(List<Color> a, List<Color> b) =>
        List<Color>.generate(a.length, (i) => l(a[i], b[i]));
    return AppColors(
      mood: t < 0.5 ? mood : other.mood,
      bg: l(bg, other.bg),
      nav: l(nav, other.nav),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      line: l(line, other.line),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      ink: l(ink, other.ink),
      tile: l(tile, other.tile),
      accentSoft: l(accentSoft, other.accentSoft),
      accentGlow: l(accentGlow, other.accentGlow),
      wash: l(wash, other.wash),
      other: l(this.other, other.other),
      barSoft: l(barSoft, other.barSoft),
      barDim: l(barDim, other.barDim),
      ramp: ll(ramp, other.ramp),
      tip: l(tip, other.tip),
      stub: l(stub, other.stub),
      track: l(track, other.track),
      onAccentDim: l(onAccentDim, other.onAccentDim),
      heat: ll(heat, other.heat),
      dim: l(dim, other.dim),
      good: l(good, other.good),
      bad: l(bad, other.bad),
      onBad: l(onBad, other.onBad),
      pillDim: l(pillDim, other.pillDim),
      sheen: l(sheen, other.sheen),
      ring: l(ring, other.ring),
      ringSoft: l(ringSoft, other.ringSoft),
      switchOff: l(switchOff, other.switchOff),
      popDim: l(popDim, other.popDim),
      popGrab: l(popGrab, other.popGrab),
      popStub: l(popStub, other.popStub),
      scrim: l(scrim, other.scrim),
    );
  }
}

/// Reads [AppColors] from the theme: `context.colors.accent`.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.of(Mood.aqua);
}

class _Base {
  const _Base({
    required this.bg,
    required this.nav,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.onAccent,
    required this.ink,
  });

  final Color bg;
  final Color nav;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color onAccent;
  final Color ink;
}

const Map<Mood, _Base> _bases = {
  Mood.aqua: _Base(
    bg: Color(0xFF0B1517),
    nav: Color(0xFF101D20),
    surface: Color(0xFF152528),
    surface2: Color(0xFF1C3034),
    line: Color(0xFF24383C),
    text: Color(0xFFFFFFFF),
    text2: Color(0xFFCBDADC),
    text3: Color(0xFF9BB0B3),
    accent: Color(0xFF4FD1C5),
    onAccent: Color(0xFF04231F),
    ink: Color(0xFF0F1E21),
  ),
  Mood.coral: _Base(
    bg: Color(0xFF0F1320),
    nav: Color(0xFF151A2A),
    surface: Color(0xFF1A2033),
    surface2: Color(0xFF232A42),
    line: Color(0xFF2B3350),
    text: Color(0xFFFFFFFF),
    text2: Color(0xFFD3D8E8),
    text3: Color(0xFFA2ABC4),
    accent: Color(0xFFFF7A5F),
    onAccent: Color(0xFF2A0F0A),
    ink: Color(0xFF171B2B),
  ),
  Mood.iris: _Base(
    bg: Color(0xFF100F1C),
    nav: Color(0xFF171527),
    surface: Color(0xFF1D1B30),
    surface2: Color(0xFF27243E),
    line: Color(0xFF33304D),
    text: Color(0xFFFFFFFF),
    text2: Color(0xFFD4D1EC),
    text3: Color(0xFFA9A6CA),
    accent: Color(0xFFA898FF),
    onAccent: Color(0xFF150F33),
    ink: Color(0xFF17132B),
  ),
};

/// The eight chart colours a category can have. Category colours never
/// change with the mood.
enum CategoryColor {
  blue('Blue', Color(0xFF3987E5)),
  green('Green', Color(0xFF41AE61)),
  violet('Violet', Color(0xFF9085E9)),
  amber('Amber', Color(0xFFC98500)),
  cyan('Cyan', Color(0xFF0096AF)),
  pink('Pink', Color(0xFFD55181)),
  orange('Orange', Color(0xFFD95926)),
  coral('Coral', Color(0xFFE66767));

  const CategoryColor(this.label, this.color);

  final String label;
  final Color color;

  /// ARGB int as stored in the database (`Categories.color`).
  int get argb => color.toARGB32();

  /// The colour whose ARGB value is [argb], or null.
  static CategoryColor? fromArgb(int argb) {
    for (final c in values) {
      if (c.argb == argb) return c;
    }
    return null;
  }
}
