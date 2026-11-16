import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spill_the_bills/theme/tokens.dart';

/// WCAG 2 contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// [fg] (maybe translucent) drawn over the opaque [bg].
Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

/// OKLab distance x 100 (the data-viz palette validator's number).
double deltaE(Color a, Color b) {
  List<double> lab(Color c) {
    double lin(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final r = lin(c.r), g = lin(c.g), bl = lin(c.b);
    final l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl, 1 / 3);
    final m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl, 1 / 3);
    final s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl, 1 / 3);
    return [
      0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
    ];
  }

  final x = lab(a), y = lab(b);
  return 100 *
      math.sqrt(
        math.pow(x[0] - y[0], 2) +
            math.pow(x[1] - y[1], 2) +
            math.pow(x[2] - y[2], 2),
      );
}

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

/// Body text.
const double body = 4.5;

/// Muted text, icons, meaningful borders, graphical marks.
const double muted = 3.0;

void main() {
  for (final mood in Mood.values) {
    group('light ${mood.label}', () {
      final c = AppColors.of(mood, brightness: Brightness.light);
      // Every surface a text token can sit on.
      final surfaces = <String, Color>{
        'bg': c.bg,
        'nav': c.nav,
        'surface': c.surface,
        'surface2': c.surface2,
      };

      void expectOn(
        String name,
        Color fg,
        double min, {
        Map<String, Color>? on,
      }) {
        (on ?? surfaces).forEach((surfaceName, surface) {
          final ratio = contrast(over(fg, surface), surface);
          expect(
            ratio,
            greaterThanOrEqualTo(min),
            reason:
                '$name ${hex(fg)} on $surfaceName ${hex(surface)}: '
                '${ratio.toStringAsFixed(2)}:1, wanted $min:1',
          );
        });
      }

      test('is a light theme on light surfaces', () {
        expect(c.brightness, Brightness.light);
        for (final surface in surfaces.values) {
          expect(surface.computeLuminance(), greaterThan(0.8));
        }
        expect(c.text.computeLuminance(), lessThan(0.05));
      });

      test('primary and secondary text reach 4.5:1 on every surface', () {
        expectOn('text', c.text, body);
        expectOn('text2', c.text2, body);
      });

      test('muted text reaches 4.5:1 on the surfaces and 3:1 on tiles', () {
        // Asked for 3:1; the tokens are held to 4.5:1 since hints and
        // sub-lines are real text.
        expectOn('text3', c.text3, body);
        expectOn('text3', c.text3, muted, on: {'tile': c.tile});
        expectOn('text', c.text, body, on: {'tile': c.tile});
        expectOn('text2', c.text2, body, on: {'tile': c.tile});
      });

      test('the accent reads as text and glyph on every surface', () {
        expectOn('accent', c.accent, body);
      });

      test('white on the deep accent (tracks, ticks) reaches 4.5:1', () {
        expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(body));
        expect(
          contrast(over(c.onAccentDim, c.accent), c.accent),
          greaterThanOrEqualTo(body),
          reason: 'the slider stops on the filled track',
        );
      });

      test('the bright fill carries ink: 4.5:1 for text and icons on it', () {
        expect(c.accentFill, isNot(c.accent), reason: 'the accent is split');
        expect(contrast(c.onFill, c.accentFill), greaterThanOrEqualTo(body));
        expect(
          contrast(over(c.onFillDim, c.accentFill), c.accentFill),
          greaterThanOrEqualTo(body),
          reason: 'quiet text on the fill',
        );
        // The fill is the mood's bright tone, the deep accent is deeper.
        expect(
          c.accentFill.computeLuminance(),
          greaterThan(c.accent.computeLuminance()),
        );
        // The ink chips on the hero card and the calendar's month bar.
        expectOn('onInk', c.onInk, body, on: {'chip': c.onFill});
        expectOn('pillDim', c.pillDim, body, on: {'chip': c.onFill});
        expectOn('accentFill', c.accentFill, muted, on: {'chip': c.onFill});
      });

      test('the inverse toast reads: text 4.5:1, Undo 4.5:1', () {
        expectOn('toastText', c.toastText, body, on: {'toast': c.raised});
        expectOn('toastAction', c.toastAction, body, on: {'toast': c.raised});
        expect(c.toastAction, c.accentFill);
      });

      test('good, bad and "more" are readable text; onBad is on bad', () {
        expectOn('good', c.good, body);
        expectOn('bad', c.bad, body);
        expectOn('more', c.more, body);
        expect(c.more, c.bad, reason: 'one red for "spent more"');
        expect(contrast(c.onBad, c.bad), greaterThanOrEqualTo(body));
      });

      test('the calendar: ink on the three light steps, white on the deep', () {
        expect(c.heat, hasLength(4));
        expect(c.heatStrongFrom, 4);
        expectOn(
          'text',
          c.text,
          body,
          on: {'heat1': c.heat[0], 'heat2': c.heat[1], 'heat3': c.heat[2]},
        );
        expectOn('onAccent', c.onAccent, body, on: {'heat4': c.heat[3]});
        // Each step is visibly deeper than the one before it.
        final steps = [c.surface, ...c.heat];
        for (var i = 1; i < steps.length; i++) {
          expect(
            contrast(steps[i], steps[i - 1]),
            greaterThanOrEqualTo(1.25),
            reason: 'step $i against step ${i - 1}',
          );
        }
        // White amounts on the tinted strip: 4.5:1 on every step.
        expect(
          contrast(const Color(0xFFFFFFFF), c.strip),
          greaterThanOrEqualTo(body),
        );
        expect(
          contrast(const Color(0xFFFFFFFF), c.stripStrong),
          greaterThanOrEqualTo(body),
        );
        expect(c.strip.a, 1, reason: 'a tinted strip, not a grey veil');
        // The chosen day's badge.
        expect(contrast(c.onInverse, c.inverse), greaterThanOrEqualTo(body));
      });

      test('what carries meaning reaches 3:1: switch, tick boxes, "rest"', () {
        expectOn('switchOff', c.switchOff, muted, on: {'surface': c.surface});
        expectOn('popStub', c.popStub, muted, on: {'surface2': c.surface2});
        // The "rest" of the donut is meant to be quiet (a light slate), but
        // it must still show on the card; its list bars show on their track.
        expectOn('other', c.other, 1.4, on: {'surface': c.surface});
        expect(
          contrast(c.otherBar, c.track),
          greaterThanOrEqualTo(2.5),
          reason: 'the bars of the rows after the fifth, on their track',
        );
        // The switch knob on its off track.
        expect(contrast(c.thumb, c.switchOff), greaterThanOrEqualTo(muted));
      });

      test('the chart accent steps stay visible on the card', () {
        for (final step in c.ramp) {
          expect(contrast(step, c.surface), greaterThan(1.5));
        }
      });

      test('cards, pop-ups, keys and tiles are told apart', () {
        // Pop-ups and sheets are white; the page is the deeper tone.
        expect(c.pop, c.surface);
        // Keys and fields are visible on a white sheet, and on a white card.
        expect(contrast(c.control, c.surface), greaterThanOrEqualTo(1.1));
        // Tiles inside white cards keep white emoji parts visible.
        expect(contrast(c.tile, c.surface), greaterThanOrEqualTo(1.1));
        expect(contrast(c.tile, c.surface), greaterThan(contrast(c.control, c.surface)));
        // Tiles on the page are white with the card edge.
        expect(c.pageTile, c.surface);
        expect(c.edge.a, greaterThan(0));
        expect(c.lift1.a, greaterThan(0));
        expect(c.lift2.a, greaterThan(0));
        // The chosen tile is a tint of the deeper accent.
        expect(contrast(c.litTile, c.surface), greaterThanOrEqualTo(1.05));
        expectOn('accent ring', c.accent, muted, on: {'litTile': c.litTile});
        // No rim along the top of the hero card.
        expect(c.sheen.a, 0);
      });

      test('the deep accent reads on its soft tints at 4.5:1', () {
        // The soft tints (selected tabs, day chips, the nav pill, the Today
        // key) are solid and light: any text on them, bold or not, is 4.5:1.
        for (final tint in [c.accentSoft, c.wash]) {
          expect(tint.a, 1, reason: 'a solid tint');
          expect(
            contrast(c.accent, tint),
            greaterThanOrEqualTo(body),
            reason: 'accent ${hex(c.accent)} on ${hex(tint)}',
          );
          // Still a tint: it shows against the white card.
          expect(contrast(tint, c.surface), greaterThanOrEqualTo(1.05));
        }
        expect(
          contrast(c.accentSoft, c.surface),
          greaterThanOrEqualTo(contrast(c.wash, c.surface)),
          reason: 'the wash is the lighter of the two',
        );
      });

      test('the muted bars are one tone, clearer than before', () {
        expect(c.barSoft, c.barDim);
        expect(contrast(c.barSoft, c.surface), greaterThanOrEqualTo(1.6));
        // And the selected bar (the deep accent) stands out from it.
        expect(contrast(c.accent, c.barSoft), greaterThanOrEqualTo(2.0));
      });

      test('one scrim: the mood ink at 32%', () {
        expect(c.scrim, c.scrimPocket);
        expect(c.scrim, c.scrimMenu);
        expect(c.scrim.a, closeTo(0.32, 0.005));
      });

      test("shadows and scrims are lighter than the dark theme's", () {
        final dark = AppColors.of(mood);
        expect(c.shadowSm.a, lessThan(dark.shadowSm.a));
        expect(c.shadowMd.a, lessThan(dark.shadowMd.a));
        expect(c.shadowLg.a, lessThan(dark.shadowLg.a));
        expect(c.scrim.a, lessThan(dark.scrim.a));
        expect(c.scrimPocket.a, lessThan(dark.scrimPocket.a));
        expect(c.scrimMenu.a, lessThan(dark.scrimMenu.a));
      });
    });
  }

  group('light category colours', () {
    final cards = {
      for (final mood in Mood.values)
        mood.label: AppColors.of(mood, brightness: Brightness.light).surface,
    };

    test('every one reaches 3:1 on the light card', () {
      for (final color in CategoryColor.values) {
        cards.forEach((mood, card) {
          final ratio = contrast(color.forBrightness(Brightness.light), card);
          expect(
            ratio,
            greaterThanOrEqualTo(muted),
            reason:
                '${color.label} ${hex(color.lightColor)} on $mood card: '
                '${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });

    test('Green and Yellow (under 3:1) got a deeper step, Amber a nudge', () {
      final white = const Color(0xFFFFFFFF);
      final changed = <String>[];
      for (final color in CategoryColor.values) {
        final plain = contrast(color.color, white);
        if (color.lightColor == color.color) {
          expect(plain, greaterThanOrEqualTo(muted), reason: color.label);
          continue;
        }
        changed.add(color.label);
        expect(
          contrast(color.lightColor, white),
          greaterThanOrEqualTo(muted),
          reason: color.label,
        );
        // The same family of hue as the palette colour.
        final a = HSLColor.fromColor(color.color);
        final b = HSLColor.fromColor(color.lightColor);
        final hueGap = (a.hue - b.hue).abs();
        expect(math.min(hueGap, 360 - hueGap), lessThan(15), reason: color.label);
        if (plain < muted) {
          // Under 3:1: a deeper step.
          expect(
            color.lightColor.computeLuminance(),
            lessThan(color.color.computeLuminance()),
            reason: color.label,
          );
        }
      }
      expect(changed, ['Green', 'Amber', 'Yellow']);
      expect(CategoryColor.yellow.lightColor, const Color(0xFFB08A00));
      expect(contrast(CategoryColor.yellow.lightColor, white), closeTo(3.24, 0.01));
    });

    test("neighbours stay apart: no pair closer than the dark palette's", () {
      double closest(Brightness b) {
        var best = double.infinity;
        final all = CategoryColor.values;
        for (var i = 0; i < all.length; i++) {
          for (var j = i + 1; j < all.length; j++) {
            best = math.min(
              best,
              deltaE(all[i].forBrightness(b), all[j].forBrightness(b)),
            );
          }
        }
        return best;
      }

      final dark = closest(Brightness.dark);
      final light = closest(Brightness.light);
      expect(dark, closeTo(7.1, 0.1));
      expect(light, greaterThanOrEqualTo(7.0));
    });

    test('the stored colour never changes; dark and unknown colours pass', () {
      expect(CategoryColor.yellow.argb, 0xFFCCB501);
      expect(CategoryColor.green.argb, 0xFF41AE61);
      expect(CategoryColor.fromArgb(0xFFCCB501), CategoryColor.yellow);
      for (final color in CategoryColor.values) {
        expect(color.forBrightness(Brightness.dark), color.color);
        expect(
          CategoryColor.displayColor(color.argb, Brightness.dark),
          color.color,
        );
        expect(
          CategoryColor.displayColor(color.argb, Brightness.light),
          color.lightColor,
        );
      }
      // Not in the palette (an old or imported value): drawn as stored.
      const unknown = 0xFF123456;
      expect(CategoryColor.fromArgb(unknown), isNull);
      expect(
        CategoryColor.displayColor(unknown, Brightness.light),
        const Color(unknown),
      );
      expect(
        CategoryColor.displayColor(unknown, Brightness.dark),
        const Color(unknown),
      );
    });

    testWidgets('context.categoryColor follows the theme', (tester) async {
      Color? seen;
      Future<void> pumpIn(Brightness brightness) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) {
              seen = context.categoryColor(CategoryColor.yellow.argb);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await pumpIn(Brightness.dark);
      await tester.pumpAndSettle();
      expect(seen, CategoryColor.yellow.color);
      await pumpIn(Brightness.light);
      await tester.pumpAndSettle();
      expect(seen, CategoryColor.yellow.lightColor);
    });
  });

  group('light Coral', () {
    final c = AppColors.of(Mood.coral, brightness: Brightness.light);

    test('the deep accent is the last heat step, with berry strips', () {
      expect(c.accent, const Color(0xFFB9402A));
      expect(c.heat, const [
        Color(0xFFFFD9D0),
        Color(0xFFFFAF9D),
        Color(0xFFFA826A),
        Color(0xFFB9402A),
      ]);
      expect(c.heat.last, c.accent);
      expect(c.strip, const Color(0xFF8E3346));
      expect(c.stripStrong, const Color(0xFF6E1E30));
      expect(contrast(c.accent, c.surface), greaterThanOrEqualTo(5.4));
      expect(contrast(c.accent, c.surface2), greaterThanOrEqualTo(4.9));
    });

    test('the soft tints are solid peach, not a dusty mauve', () {
      expect(c.accentSoft, const Color(0xFFFCE4DD));
      expect(c.wash, const Color(0xFFFFE7E2));
    });
  });

  group('light tints of Aqua and Iris', () {
    test('are solid, in the accent fill hue', () {
      final aqua = AppColors.of(Mood.aqua, brightness: Brightness.light);
      expect(aqua.accentSoft, const Color(0xFFD8F5F2));
      expect(aqua.wash, const Color(0xFFDFF7F5));
      final iris = AppColors.of(Mood.iris, brightness: Brightness.light);
      expect(iris.accentSoft, const Color(0xFFEFECFF));
      expect(iris.wash, const Color(0xFFF1EFFF));
    });
  });

  group('dark stays as it was', () {
    test('the dark tokens of every mood are the ones of before', () {
      final aqua = AppColors.of(Mood.aqua);
      expect(aqua.brightness, Brightness.dark);
      expect(aqua.bg, const Color(0xFF0B1517));
      expect(aqua.accent, const Color(0xFF4FD1C5));
      expect(aqua.onAccent, const Color(0xFF04231F));
      expect(aqua.scrim, const Color(0xE0040A0B));
      expect(aqua.shadowSm, const Color(0x59000000));
      expect(aqua.shadowMd, const Color(0x73000000));
      expect(aqua.shadowLg, const Color(0x80000000));
      expect(aqua.good, const Color(0xFF5BD49B));
      expect(aqua.bad, const Color(0xFFFF8C9A));
      expect(aqua.more, const Color(0xFFFF9A8F));
      expect(aqua.pillDim, const Color(0xB8FFFFFF));
      expect(aqua.inverse, const Color(0xFFFFFFFF));
      expect(aqua.onInverse, aqua.onAccent);
      expect(aqua.thumb, aqua.text);
      expect(aqua.strip, aqua.onAccent.withAlpha(0x8C));
      // What `scrim.withValues(alpha: ...)` gave the two scrims before.
      expect(
        aqua.scrimPocket,
        aqua.scrim.withValues(alpha: 0.80),
      );
      expect(aqua.scrimMenu, aqua.scrim.withValues(alpha: 0.68));
      expect(aqua.raised, aqua.tile);
      expect(aqua.heat.first, mix(aqua.accent, aqua.bg, 0.4));
      // The tokens added with the light theme are the dark ones' own values.
      for (final mood in Mood.values) {
        final d = AppColors.of(mood);
        expect(d.accentFill, d.accent, reason: mood.name);
        expect(d.onFill, d.onAccent, reason: mood.name);
        expect(d.onFillDim, d.onAccentDim, reason: mood.name);
        expect(d.onInk, d.text, reason: mood.name);
        expect(d.control, d.surface2, reason: mood.name);
        expect(d.pop, d.surface2, reason: mood.name);
        expect(d.pageTile, d.tile, reason: mood.name);
        expect(d.litTile, mix(d.accent, d.tile, 0.15), reason: mood.name);
        expect(d.stripStrong, d.strip, reason: mood.name);
        expect(d.heatStrongFrom, 3, reason: mood.name);
        expect(d.otherBar, d.other, reason: mood.name);
        expect(d.toastText, d.text, reason: mood.name);
        expect(d.toastAction, d.accent, reason: mood.name);
        expect(d.sheen, const Color(0x4DFFFFFF), reason: mood.name);
        expect(d.edge.a, 0, reason: 'no card stroke on dark');
        expect(d.lift1.a, 0, reason: 'no card lift on dark');
        expect(d.lift2.a, 0, reason: 'no card lift on dark');
        expect(d.accentGlow, d.accent.withAlpha(0x59), reason: mood.name);
        expect(d.barSoft, mix(d.accent, d.surface, 0.6), reason: mood.name);
        expect(d.barDim, mix(d.accent, d.surface, 0.36), reason: mood.name);
        expect(d.other, mix(d.text3, d.surface, 0.5), reason: mood.name);
      }
      expect(AppColors.of(Mood.coral).accent, const Color(0xFFFF7A5F));
      expect(AppColors.of(Mood.iris).accent, const Color(0xFFA898FF));
    });
  });
}
