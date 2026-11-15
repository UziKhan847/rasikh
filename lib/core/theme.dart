import 'package:flutter/material.dart';
import 'package:qiraah_ui/theme.dart';

import 'settings.dart';

// The shared look (palettes, the app theme, type) is the family's
// (package:qiraah_ui); the muṣḥaf's papers and ornament colours are this
// app's own.
export 'package:qiraah_ui/theme.dart';

/// The 15-line muṣḥaf's page colours (Update 2 §1, 6.9 contrast overrides).
class MushafPaper {
  final String id;
  final Color bg, paper, ink, line, acc, frame, soft, hl, hl2, chrome, sub;

  /// Inside the Classic page border, and what the Classic ornaments are
  /// filled with (Update 9: the Madani and Mono papers — white within a
  /// cream or grey margin); null: the paper shows through.
  final Color? inner;

  /// Text set with the ornaments (the margin's labels and page number): a
  /// stronger shade of [frame]; null: worked out from it.
  final Color? frameInk;
  const MushafPaper(this.id, this.bg, this.paper, this.ink, this.line, this.acc,
      this.frame, this.soft, this.hl, this.hl2, this.chrome, this.sub,
      {this.inner, this.frameInk});
  bool get dark => paper.computeLuminance() < .2;

  /// The Mono pages: black and white only, artwork included.
  bool get mono => id == 'mono' || id.endsWith('_mono');
}

const kMushafPapers = <String, MushafPaper>{
  'cream': MushafPaper('cream', Color(0xFFE9E2D0), Color(0xFFFBF7EC),
      Color(0xFF1D2420), Color(0xFFE3D9C2), Color(0xFF0F6E58),
      Color(0xFFB4862C), Color(0xFFF4ECD8), Color(0xFFEFE3C5),
      Color(0xFFCBE3D6), Color(0xF7FBF7EC), Color(0xFF6F6656)),
  'white': MushafPaper('white', Color(0xFFEDEFEC), Color(0xFFFFFFFF),
      Color(0xFF16201C), Color(0xFFE2E5E1), Color(0xFF0F7A62),
      Color(0xFF5C8C7C), Color(0xFFEEF6F2), Color(0xFFEEF3EF),
      Color(0xFFCDE8DC), Color(0xF7FFFFFF), Color(0xFF6F7671)),
  'madani': MushafPaper('madani', Color(0xFFE9EAE6), Color(0xFFF3EEDD),
      Color(0xFF1D2420), Color(0xFFE2DAC4), Color(0xFF0F6E58),
      Color(0xFFA58A5A), Color(0xFFF6F1E3), Color(0xFFEFE3C5),
      Color(0xFFCBE3D6), Color(0xF7F3EEDD), Color(0xFF6F6656),
      inner: Color(0xFFFFFFFF)),
  'mono': MushafPaper('mono', Color(0xFFE8E8E8), Color(0xFFF1F1F0),
      Color(0xFF111111), Color(0xFFE2E2E2), Color(0xFF111111),
      Color(0xFF111111), Color(0xFFF4F4F4), Color(0xFFEDEDED),
      Color(0xFFDADADA), Color(0xF7F1F1F0), Color(0xFF6E6E6E),
      inner: Color(0xFFFFFFFF)),
  'night': MushafPaper('night', Color(0xFF090D0C), Color(0xFF121816),
      Color(0xFFE8E3D6), Color(0xFF25302C), Color(0xFF4DBB98),
      Color(0xFFCFAE62), Color(0xFF18211E), Color(0xFF1F2B27),
      Color(0xFF21473B), Color(0xF7121816), Color(0xFF929B96)),
  'oled': MushafPaper('oled', Color(0xFF000000), Color(0xFF000000),
      Color(0xFFE2DED3), Color(0xFF1A211E), Color(0xFF46B592),
      Color(0xFFBE9A4E), Color(0xFF0A0F0D), Color(0xFF14201B),
      Color(0xFF173A2F), Color(0xF7000000), Color(0xFF878F8B)),
  // The tiled frames' palettes (Update 10): white pages, the frame's colour
  // on the āyah circles and lantern, its accent on numbers and the juzʼ.
  'tile1': MushafPaper('tile1', Color(0xFFE4ECEC), Color(0xFFFFFFFF),
      Color(0xFF1D2420), Color(0xFFDDE5E5), Color(0xFFC0281E),
      Color(0xFF1BA6C4), Color(0xFFF2F6F6), Color(0xFFE3F3F7),
      Color(0xFFC8E8F0), Color(0xF7FFFFFF), Color(0xFF6F7671),
      inner: Color(0xFFFFFFFF)),
  'tile2': MushafPaper('tile2', Color(0xFFE6ECE7), Color(0xFFFFFFFF),
      Color(0xFF1D2420), Color(0xFFDDE5DF), Color(0xFF2F7A49),
      Color(0xFF4FA56C), Color(0xFFF2F6F3), Color(0xFFE6F2EA),
      Color(0xFFCFE6D6), Color(0xF7FFFFFF), Color(0xFF6F7671),
      inner: Color(0xFFFFFFFF)),
  'tile3': MushafPaper('tile3', Color(0xFFE5EBEC), Color(0xFFFFFFFF),
      Color(0xFF1D2420), Color(0xFFDDE4E6), Color(0xFFA04A44),
      Color(0xFF5AAFC2), Color(0xFFF2F6F6), Color(0xFFE5F3F6),
      Color(0xFFCDE7EE), Color(0xF7FFFFFF), Color(0xFF6F7671),
      inner: Color(0xFFFFFFFF)),
  // The dark themes' mono pages: everything on the page white.
  'night_mono': MushafPaper('night_mono', Color(0xFF0A0A0A), Color(0xFF121212),
      Color(0xFFF2F2F2), Color(0xFF2A2A2A), Color(0xFFFFFFFF),
      Color(0xFFF2F2F2), Color(0xFF1A1A1A), Color(0xFF262626),
      Color(0xFF3A3A3A), Color(0xF7121212), Color(0xFF9A9A9A)),
  'oled_mono': MushafPaper('oled_mono', Color(0xFF000000), Color(0xFF000000),
      Color(0xFFF2F2F2), Color(0xFF1E1E1E), Color(0xFFFFFFFF),
      Color(0xFFF2F2F2), Color(0xFF0D0D0D), Color(0xFF1C1C1C),
      Color(0xFF333333), Color(0xF7000000), Color(0xFF8C8C8C)),
};

/// The muṣḥaf paper for the current settings: the light theme offers cream,
/// white, Madani or mono; night and OLED their own page or a mono one, all
/// white on the dark; the mono theme its own.
///
/// The light theme's paper is [script]'s own (each script keeps its look);
/// by default the muṣḥaf's script.
///
/// The ornaments take the script's own colour ([kOrnamentSeeds]) whatever
/// the paper, quiet beside the text: lighter on a light page, darker on a
/// dark one. Mono pages keep theirs.
MushafPaper mushafPaperOf(AppSettings s, [String? script]) {
  final style = s.styleFor(script ?? s.mushafScript);
  final paper = switch (s.theme) {
    AppTheme.light => kMushafPapers[style.paper] ?? kMushafPapers['white']!,
    AppTheme.mono => kMushafPapers['mono']!,
    AppTheme.night =>
      kMushafPapers[s.mushafPaperDark == 'mono' ? 'night_mono' : 'night']!,
    AppTheme.oled =>
      kMushafPapers[s.mushafPaperDark == 'mono' ? 'oled_mono' : 'oled']!,
  };
  return paper.mono ? paper : _ornamented(paper, style.ornament);
}

/// The muṣḥaf on paper (the page export): white whatever the theme, its
/// ornaments in the colour chosen; a mono page stays mono.
MushafPaper mushafPrintPaperOf(AppSettings s, String script) {
  final style = s.styleFor(script);
  if (kMushafPapers[style.paper]?.mono ?? false) return kMushafPapers['mono']!;
  return _ornamented(kMushafPapers['white']!, style.ornament);
}

/// The ornament colours to pick from, apart from the paper: Material
/// seeds, one for light pages and one for dark (as the mistake marker's
/// themes), their tones taken from the scheme each makes.
const kOrnamentSeeds = <String, (Color, Color)>{
  'gold': (Color(0xFF7B580C), Color(0xFFEEBF6D)),
  'blue': (Color(0xFF35618E), Color(0xFFA0CAFD)),
  'red': (Color(0xFF904A45), Color(0xFFFFB3B0)),
  'green': (Color(0xFF34693F), Color(0xFF9AD4A1)),
  'purple': (Color(0xFF735187), Color(0xFFE2B7F4)),
};

/// [ornament]'s colours on a light or [dark] page: the art's, and the text
/// set with it. Light: a light tone (about 70) at the seed's full chroma,
/// the text its primary (40). Dark: a dark one (about 25), the text its
/// primary (80) eased toward the page.
({Color art, Color text}) ornamentColours(String ornament, {required bool dark}) =>
    _ornamentColours.putIfAbsent('$ornament/$dark', () {
      final seeds = kOrnamentSeeds[ornament] ?? kOrnamentSeeds['gold']!;
      final cs = ColorScheme.fromSeed(
          seedColor: dark ? seeds.$2 : seeds.$1,
          brightness: dark ? Brightness.dark : Brightness.light);
      return dark
          ? (
              art: Color.lerp(cs.onPrimaryFixedVariant, cs.surface, .25)!,
              text: Color.lerp(cs.primary, cs.surface, .25)!,
            )
          : (
              art: Color.lerp(cs.primary, cs.primaryFixedDim, .75)!,
              text: cs.primary,
            );
    });
final _ornamentColours = <String, ({Color art, Color text})>{};

/// [paper] with its ornaments in [ornament]. Kept, so a page's paper stays
/// the same object (the muṣḥaf's page memo compares it).
MushafPaper _ornamented(MushafPaper paper, String ornament) =>
    _ornamentedCache.putIfAbsent('${paper.id}/$ornament', () {
      final c = ornamentColours(ornament, dark: paper.dark);
      return MushafPaper(paper.id, paper.bg, paper.paper, paper.ink, paper.line,
          paper.acc, c.art, paper.soft, paper.hl, paper.hl2, paper.chrome,
          paper.sub,
          inner: paper.inner, frameInk: c.text);
    });
final _ornamentedCache = <String, MushafPaper>{};

