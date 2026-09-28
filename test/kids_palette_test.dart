import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_app.dart';

/// The Kids Mode shop sells whole-app colour themes. These tests pin the two
/// things that made Ocean look wrong once it was equipped: an orange that
/// belonged to no theme but the default, and a fallback that could hand a
/// child the grown-up app's mint green.
void main() {
  const modes = ['light', 'dark', 'oled'];
  const defaultAmber = Color(0xFFF4B23E);

  double hue(Color c) => HSVColor.fromColor(c).hue;

  /// Roughly red-orange through amber — the colours that clash with Ocean's blues.
  bool isOrange(Color c) {
    final h = hue(c);
    return h >= 12 && h <= 50;
  }

  group('every shop theme owns its reward colour', () {
    for (final family in kKidsShopThemeFamilies) {
      for (final mode in modes) {
        test('$family.$mode does not use the default amber', () {
          expect(
            paletteFor(family, mode).amber,
            isNot(defaultAmber),
            reason:
                '`amber` paints the goal ring, the mascot and every '
                'badge — a shared gold made Ocean look half-orange',
          );
        });
      }
    }
  });

  group('Ocean has nothing orange in it', () {
    for (final mode in modes) {
      final p = paletteFor('kids_ocean', mode);
      test('accents and reward colour ($mode)', () {
        for (final (name, c) in [
          ('accent', p.accent),
          ('accentBright', p.accentBright),
          ('accentDeep', p.accentDeep),
          ('accent2', p.accent2),
          ('amber', p.amber),
        ]) {
          expect(
            isOrange(c),
            isFalse,
            reason: 'Ocean $name is orange (hue ${hue(c).round()}°)',
          );
        }
      });
    }
  });

  group('Desert is not the default palette in a different hat', () {
    for (final mode in modes) {
      test('$mode differs in accents and neutrals', () {
        final d = paletteFor('kids_desert', mode);
        final base = paletteFor('kids', mode);
        expect(d.accent, isNot(base.accent));
        expect(d.accent2, isNot(base.accent2));
        // OLED is pure black in every family; only its surfaces can differ.
        if (mode != 'oled') expect(d.bg, isNot(base.bg));
        expect(
          d.surface,
          isNot(base.surface),
          reason:
              'the default surface is plain white in light mode; '
              'Desert must be visibly a different sand',
        );
      });
    }
  });

  group('every shop theme is its own theme, not a near-twin of another', () {
    // This used to be one rule — every pair of accents ≥ 25° apart in hue —
    // written when a theme was only a colour. Twelve families cannot all sit
    // 25° apart (the wheel has room for fourteen, and Frozen, Ocean, Rain and
    // Snowy are all blue by nature), and a theme is now a whole painted scene:
    // Ocean's waves and bubbles are unmistakable beside Frozen's ice shards and
    // aurora however close their blues are. So the rule became two:
    //
    //  1. colours may never be near-identical, and
    //  2. where two are close in hue, their SCENES must clearly differ.
    double circularDistance(double a, double b) {
      final d = (a - b).abs() % 360;
      return d > 180 ? 360 - d : d;
    }

    // The five things that make a scene read as itself.
    List<String> features(String family) {
      final s = kbThemeFor(family);
      final o = s.orn;
      return [
        // What hangs in the sky.
        o == null ? 'none' : '${o.kind}/${o.soft ? 'soft' : 'hard'}',
        // On the horizon, or high up (Sunrise vs Desert and Sunset).
        o != null && o.y > .4 ? 'horizon' : 'high',
        // The silhouettes, back to front.
        s.ridges.map((r) => r.kind).join(','),
        // What drifts.
        s.moteType,
        // The extras: stars, flowers, snow caps, snow ground, crystals.
        [
          s.stars,
          s.flowers,
          s.snowcap,
          s.ground == 'snow',
          s.crystals,
        ].map((f) => f ? '1' : '0').join(),
      ];
    }

    int differing(String a, String b) {
      final fa = features(a), fb = features(b);
      return [
        for (var i = 0; i < fa.length; i++)
          if (fa[i] != fb[i]) i,
      ].length;
    }

    final hues = {
      for (final f in kKidsShopThemeFamilies)
        f: hue(paletteFor(f, 'light').accent),
    };
    final pairs = [
      for (var i = 0; i < hues.length; i++)
        for (var j = i + 1; j < hues.length; j++)
          (hues.keys.elementAt(i), hues.keys.elementAt(j)),
    ];

    test('no two accents are near-identical (3° floor)', () {
      for (final (a, b) in pairs) {
        final d = circularDistance(hues[a]!, hues[b]!);
        expect(
          d,
          greaterThanOrEqualTo(3),
          reason:
              '$a (${hues[a]!.round()}°) and $b (${hues[b]!.round()}°) are '
              'only ${d.toStringAsFixed(1)}° apart — the same colour',
        );
      }
    });

    test(
      'accents closer than 25° in hue differ in at least 2 scene features',
      () {
        for (final (a, b) in pairs) {
          final d = circularDistance(hues[a]!, hues[b]!);
          if (d >= 25) continue;
          expect(
            differing(a, b),
            greaterThanOrEqualTo(2),
            reason:
                '$a and $b are only ${d.toStringAsFixed(1)}° apart in hue, so '
                'their scenes must set them apart: ${features(a)} vs '
                '${features(b)}',
          );
        }
      },
    );

    test('no two families share the same scene at all', () {
      for (final (a, b) in pairs) {
        expect(
          differing(a, b),
          greaterThanOrEqualTo(1),
          reason: '$a and $b paint the same scene',
        );
      }
    });

    test('the pairs that needed the relaxation are exactly the known ones', () {
      // A tripwire, not a rule: if a NEW theme lands within 25° of another,
      // this fails so the choice is looked at rather than inherited silently.
      final close = {
        for (final (a, b) in pairs)
          if (circularDistance(hues[a]!, hues[b]!) < 25) '$a~$b',
      };
      expect(close, {
        'kids_ocean~kids_frozen',
        'kids_ocean~kids_rain',
        'kids_ocean~kids_snowy',
        'kids_desert~kids_sunrise',
        'kids_night~kids_cave',
        'kids_rain~kids_frozen',
        'kids_rain~kids_snowy',
        'kids_frozen~kids_snowy',
      });
    });
  });

  group('every shop theme keeps its text readable (WCAG AA)', () {
    // Relative luminance and contrast ratio, per the WCAG 2 formula — the
    // same 4.5:1 minimum every other legibility check in the app assumes.
    double channel(double c) => c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    double relativeLuminance(Color c) =>
        0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
    double contrast(Color a, Color b) {
      final la = relativeLuminance(a), lb = relativeLuminance(b);
      final lighter = math.max(la, lb), darker = math.min(la, lb);
      return (lighter + 0.05) / (darker + 0.05);
    }

    for (final family in kKidsShopThemeFamilies) {
      for (final mode in modes) {
        test('$family.$mode: text on bg, and on surface', () {
          final p = paletteFor(family, mode);
          expect(
            contrast(p.text, p.bg),
            greaterThanOrEqualTo(4.5),
            reason: '$family.$mode text/bg',
          );
          expect(
            contrast(p.text, p.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$family.$mode text/surface',
          );
        });
      }
    }
  });

  group('paletteFor falls back to its own kind', () {
    test('an unknown kids_* family gives the default Kids palette', () {
      for (final mode in modes) {
        expect(paletteFor('kids_bogus', mode), paletteFor('kids', mode));
      }
    });

    test('an unknown mode gives the family light palette, not mint', () {
      expect(
        paletteFor('kids_ocean', 'sepia'),
        paletteFor('kids_ocean', 'light'),
      );
      expect(paletteFor('kids', 'sepia'), paletteFor('kids', 'light'));
    });

    test('an unknown grown-up family still gives mint', () {
      expect(paletteFor('bogus', 'light'), paletteFor('mint', 'light'));
    });
  });

  testWidgets('the shop\'s colours shelf and the theme family list agree', (
    tester,
  ) async {
    // `kKidsShopThemeFamilies` used to be dead code nothing cross-checked, so
    // a family could ship in one list and not the other.
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final ids = [
      for (final i in kidsShopItems(ctx))
        if (i.shelf == KidsShopShelf.colours) i.id,
    ];
    expect(ids, kKidsShopThemeFamilies);
    for (final id in ids) {
      for (final mode in modes) {
        // Every shop colour has a real palette for every mode — not a
        // fallback wearing its name.
        expect(
          paletteFor(id, mode),
          isNot(paletteFor('kids', mode)),
          reason: '$id.$mode',
        );
      }
    }
  });
}
