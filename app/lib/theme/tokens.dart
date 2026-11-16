/// Colour tokens, computed exactly like the mockup's `theme(mood)` in
/// design/mockup/project/NewCharts.dc.html (plus the hero-card tokens of
/// MoodAqua and the pop-up tokens of `popKit()`), in a dark and a light
/// brightness. The light tokens keep each mood's identity on light neutral
/// surfaces: the same roles and layout, a deeper accent step, ink text.
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

/// Every colour token of one mood in one brightness.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.mood,
    required this.brightness,
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
    required this.scrimPocket,
    required this.scrimMenu,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.inverse,
    required this.onInverse,
    required this.strip,
    required this.thumb,
    required this.more,
    required this.raised,
  });

  /// Tokens of [mood] in [brightness], computed like the mockup (dark) or
  /// from the light bases below.
  factory AppColors.of(
    Mood mood, {
    Brightness brightness = Brightness.dark,
  }) {
    final light = brightness == Brightness.light;
    final base = (light ? _lightBases : _darkBases)[mood]!;
    final surface = base.surface;
    final surface2 = base.surface2;
    final accent = base.accent;
    // Dark: a tile lighter than the surface (surface x 0.87 + 33). Light:
    // a tile a little deeper than the page, between the page and the lines.
    final tile = light
        ? mix(base.bg, base.line, 0.55)
        : Color.fromARGB(
            0xFF,
            ((surface.toARGB32() >> 16 & 0xFF) * 0.87 + 33).round(),
            ((surface.toARGB32() >> 8 & 0xFF) * 0.87 + 33).round(),
            ((surface.toARGB32() & 0xFF) * 0.87 + 33).round(),
          );
    // The shadows and scrims: black on dark; the mood's ink, lighter, on
    // light (a black shadow is too heavy on a light page).
    final shade = light ? base.ink : const Color(0xFF000000);
    final scrimBase = light ? base.ink : const Color(0xFF040A0B);
    return AppColors(
      mood: mood,
      brightness: brightness,
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
      other: mix(base.text3, surface, light ? 0.8 : 0.5),
      barSoft: mix(accent, surface, 0.6),
      barDim: mix(accent, surface, 0.36),
      ramp: List.unmodifiable(
        [1.0, 0.86, 0.72, 0.58, 0.44].map((w) => mix(accent, surface, w)),
      ),
      tip: light ? surface : mix(const Color(0xFFFFFFFF), surface2, 0.1),
      stub: mix(base.text3, surface, 0.28),
      track: light
          ? mix(base.text3, surface, 0.22)
          : mix(base.bg, surface, 0.5),
      onAccentDim: base.onAccent.withAlpha(light ? 0xEB : 0xD9),
      // Light: two soft tints with ink on them, then the accent and a deeper
      // step with white on them (the calendar switches text colour at the
      // third step).
      heat: List.unmodifiable(
        light
            ? [
                mix(accent, base.bg, 0.22),
                mix(accent, base.bg, 0.46),
                accent,
                mix(accent, base.text, 0.78),
              ]
            : [0.4, 0.56, 0.74, 0.94].map((w) => mix(accent, base.bg, w)),
      ),
      dim: mix(base.text3, base.bg, 0.55),
      good: light ? const Color(0xFF127A4B) : const Color(0xFF5BD49B),
      bad: light ? const Color(0xFFC22D4A) : const Color(0xFFFF8C9A),
      onBad: light ? const Color(0xFFFFFFFF) : const Color(0xFF2A0B12),
      pillDim: light ? base.text3 : const Color(0xB8FFFFFF),
      sheen: const Color(0x4DFFFFFF),
      ring: const Color(0x47FFFFFF),
      ringSoft: const Color(0x26FFFFFF),
      switchOff: mix(base.text3, surface, light ? 0.8 : 0.4),
      popDim: mix(base.text3, surface2, 0.5),
      popGrab: mix(base.text3, surface2, light ? 0.5 : 0.4),
      popStub: mix(base.text3, surface2, light ? 0.8 : 0.45),
      scrim: light ? scrimBase.withValues(alpha: 0.5) : const Color(0xE0040A0B),
      scrimPocket: scrimBase.withValues(alpha: light ? 0.42 : 0.80),
      scrimMenu: scrimBase.withValues(alpha: light ? 0.32 : 0.68),
      shadowSm: shade.withAlpha(light ? 0x24 : 0x59),
      shadowMd: shade.withAlpha(light ? 0x33 : 0x73),
      shadowLg: shade.withAlpha(light ? 0x3D : 0x80),
      inverse: light ? base.text : const Color(0xFFFFFFFF),
      onInverse: light ? const Color(0xFFFFFFFF) : base.onAccent,
      strip: light ? base.ink.withAlpha(0xA6) : base.onAccent.withAlpha(0x8C),
      thumb: light ? surface : base.text,
      more: light ? const Color(0xFFB93A28) : const Color(0xFFFF9A8F),
      raised: light ? surface : tile,
    );
  }

  final Mood mood;

  /// Dark or light.
  final Brightness brightness;

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

  /// Pop-up scrim: rgba(4, 10, 11, 0.88) on dark; the mood's ink at 50% on
  /// light.
  final Color scrim;

  /// Scrim under the pocket switcher (a little lighter than [scrim]).
  final Color scrimPocket;

  /// Scrim under the quick menu (the lightest).
  final Color scrimMenu;

  /// Small shadows (keypad panel, chart tip, slider thumb, add button).
  final Color shadowSm;

  /// Medium shadows (the quick menu).
  final Color shadowMd;

  /// Large shadows (pop-ups, toasts, sheets).
  final Color shadowLg;

  /// Fill of a "chosen" mark on a calendar cell: white on dark, ink on
  /// light.
  final Color inverse;

  /// Text on [inverse].
  final Color onInverse;

  /// Dim strip under a calendar day's amount (white text reads on it).
  final Color strip;

  /// The text size slider's thumb.
  final Color thumb;

  /// Warm colour of "N% more than ..." in Charts.
  final Color more;

  /// Fill of things that float over the page (the toast): [tile] on dark,
  /// white on light.
  final Color raised;

  /// The mockup's `mix` helper.
  Color mixColors(Color a, Color b, double w) => mix(a, b, w);

  @override
  AppColors copyWith({Mood? mood, Brightness? brightness}) =>
      mood == null && brightness == null
          ? this
          : AppColors.of(
              mood ?? this.mood,
              brightness: brightness ?? this.brightness,
            );

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> ll(List<Color> a, List<Color> b) =>
        List<Color>.generate(a.length, (i) => l(a[i], b[i]));
    return AppColors(
      mood: t < 0.5 ? mood : other.mood,
      brightness: t < 0.5 ? brightness : other.brightness,
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
      scrimPocket: l(scrimPocket, other.scrimPocket),
      scrimMenu: l(scrimMenu, other.scrimMenu),
      shadowSm: l(shadowSm, other.shadowSm),
      shadowMd: l(shadowMd, other.shadowMd),
      shadowLg: l(shadowLg, other.shadowLg),
      inverse: l(inverse, other.inverse),
      onInverse: l(onInverse, other.onInverse),
      strip: l(strip, other.strip),
      thumb: l(thumb, other.thumb),
      more: l(more, other.more),
      raised: l(raised, other.raised),
    );
  }
}

/// Reads [AppColors] from the theme: `context.colors.accent`.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.of(Mood.aqua);

  /// The colour to draw the category colour [argb] in on the current theme:
  /// a palette colour gets its light variant on a light theme; any other
  /// value (an unknown colour) is drawn as stored.
  Color categoryColor(int argb) =>
      CategoryColor.displayColor(argb, Theme.of(this).brightness);
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

/// The dark bases (the mockup's).
const Map<Mood, _Base> _darkBases = {
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

/// The light bases: pale neutral surfaces with a faint tint of the mood, white
/// cards, ink text, and an accent one deeper step than the dark one so it
/// reads on light (white on the accent is at least 5:1 in every mood).
const Map<Mood, _Base> _lightBases = {
  Mood.aqua: _Base(
    bg: Color(0xFFEDF4F4),
    nav: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F7F7),
    line: Color(0xFFD8E4E5),
    text: Color(0xFF0D2125),
    text2: Color(0xFF37535A),
    text3: Color(0xFF587276),
    accent: Color(0xFF0A7A71),
    onAccent: Color(0xFFFFFFFF),
    ink: Color(0xFF0F1E21),
  ),
  Mood.coral: _Base(
    bg: Color(0xFFF0F2F8),
    nav: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F5FA),
    line: Color(0xFFDBE0EC),
    text: Color(0xFF161B2E),
    text2: Color(0xFF434A66),
    text3: Color(0xFF606886),
    accent: Color(0xFFC23B21),
    onAccent: Color(0xFFFFFFFF),
    ink: Color(0xFF171B2B),
  ),
  Mood.iris: _Base(
    bg: Color(0xFFF1F0FA),
    nav: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF5F3FC),
    line: Color(0xFFDDDAF0),
    text: Color(0xFF19152B),
    text2: Color(0xFF48436A),
    text3: Color(0xFF645F88),
    accent: Color(0xFF6A55E0),
    onAccent: Color(0xFFFFFFFF),
    ink: Color(0xFF17132B),
  ),
};

/// The 18 chart colours a category can have, the one source of truth for
/// every category colour (the defaults, the form's swatches, imports).
/// Category colours never change with the mood. On a light theme two of them
/// (Green and Yellow, the ones under 3:1 against a white card) are drawn one
/// deeper step; see [CategoryColor.lightColor].
///
/// The first eight are the original palette: their values, names and order
/// never change, so stored colours and earlier picks still match. The other
/// ten (Red ... Slate) were added so every default category can have its own.
/// They were chosen with the data-viz palette validator against the dark
/// surfaces: every pair is at least 7.1 apart to normal vision (OKLab x100;
/// Orange and Coral, from the original eight, are the closest pair) and every
/// new colour is at least 8.2 from all the others. Sky, Sand and Slate are
/// softer than the rest on purpose, and Yellow is lighter so it stays apart
/// from Amber for colour-blind readers.
enum CategoryColor {
  blue('Blue', Color(0xFF3987E5)),
  green('Green', Color(0xFF41AE61), light: Color(0xFF38A55A)),
  violet('Violet', Color(0xFF9085E9)),
  amber('Amber', Color(0xFFC98500)),
  cyan('Cyan', Color(0xFF0096AF)),
  pink('Pink', Color(0xFFD55181)),
  orange('Orange', Color(0xFFD95926)),
  coral('Coral', Color(0xFFE66767)),
  red('Red', Color(0xFFB94542)),
  yellow('Yellow', Color(0xFFCCB501), light: Color(0xFF9D9500)),
  lime('Lime', Color(0xFF4A8F08)),
  teal('Teal', Color(0xFF017C5F)),
  sky('Sky', Color(0xFF6C96CA)),
  indigo('Indigo', Color(0xFF645BD4)),
  magenta('Magenta', Color(0xFFCB67D0)),
  rose('Rose', Color(0xFF995583)),
  sand('Sand', Color(0xFF89704A)),
  slate('Slate', Color(0xFF576D8E));

  const CategoryColor(this.label, this.color, {Color? light})
      : _light = light;

  final String label;

  /// The palette colour, as stored in the database and drawn on dark.
  final Color color;

  final Color? _light;

  /// The colour drawn on light surfaces: [color] where it already reaches
  /// 3:1 against the light card, otherwise a deeper step of the same hue.
  /// Only what is drawn changes; the stored [argb] never does.
  Color get lightColor => _light ?? color;

  /// [color] on dark, [lightColor] on light.
  Color forBrightness(Brightness brightness) =>
      brightness == Brightness.light ? lightColor : color;

  /// What to draw for the stored colour [argb] on [brightness]: the palette
  /// entry's colour for that brightness, or [argb] itself when it is not a
  /// palette colour.
  static Color displayColor(int argb, Brightness brightness) =>
      fromArgb(argb)?.forBrightness(brightness) ?? Color(argb);

  /// ARGB int as stored in the database (`Categories.color`).
  int get argb => color.toARGB32();

  /// The colour whose ARGB value is [argb], or null.
  static CategoryColor? fromArgb(int argb) {
    for (final c in values) {
      if (c.argb == argb) return c;
    }
    return null;
  }

  /// The first colour (in palette order) that none of [takenArgb] has; the
  /// first colour of the palette when every one is taken. A new category
  /// starts on it.
  static CategoryColor firstFree(Iterable<int> takenArgb) {
    final taken = takenArgb.toSet();
    for (final c in values) {
      if (!taken.contains(c.argb)) return c;
    }
    return values.first;
  }

  /// Colours for [count] new categories (an import): the free ones first, in
  /// palette order, then the whole palette in turn from its start.
  static List<CategoryColor> forNew(int count, Iterable<int> takenArgb) {
    final taken = takenArgb.toSet();
    final free = [
      for (final c in values)
        if (!taken.contains(c.argb)) c,
    ];
    return [
      for (var i = 0; i < count; i++)
        i < free.length ? free[i] : values[(i - free.length) % values.length],
    ];
  }
}
