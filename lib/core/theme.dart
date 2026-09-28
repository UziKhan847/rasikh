import 'package:flutter/material.dart';

import 'settings.dart';

/// Brand colors — taken from the reference direction:
/// mint #00C9A7, coral #FF6B67, lilac #8B85F0 on clean light / deep navy /
/// pure-black OLED surfaces.
class AppColors {
  static const mint = Color(0xFF00C9A7);
  static const mintBright = Color(0xFF2EE5A9);
  static const mintDeep = Color(0xFF00A98C);
  static const coral = Color(0xFFFF6B67);
  static const lilac = Color(0xFF8B85F0);
  static const navy = Color(0xFF1B2140);
  static const star = Color(0xFFFFC24B);

  // semantic (fixed across theme families)
  static const ok = Color(0xFF27B36B);
  static const bad = Color(0xFFE2554F);

  // Tajwid coding (tuned to read on both light and dark surfaces)
  static const tjGhunnah = Color(0xFF2DB84D);
  static const tjIkhfa = Color(0xFF4CBF8B);
  static const tjIdghamG = Color(0xFF18A29A);
  static const tjIdghamNoG = Color(0xFF8A93A8);
  static const tjIqlab = Color(0xFF4D9DE0);
  static const tjIzhar = Color(0xFF9A8FBF);
  static const tjQalqalah = Color(0xFF22B8D4);
  static const tjMadd2 = Color(0xFFE6A817);
  static const tjMadd4 = Color(0xFFF07F3C);
  static const tjMadd6 = Color(0xFFE2554F);
  static const tjShamsiyya = Color(0xFFE0709A);
  static const tjQamariyya = Color(0xFF6E8FE8);
  static const tjRaa = Color(0xFFB86B4B);
}

/// Mode-dependent surface & text tokens.
class Palette {
  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color text;
  final Color textDim;
  final Color paper; // warm reading background (dyslexia option)
  final Color paperInk; // text on paper
  final Color shadow; // card shadow (transparent on dark/oled)
  final Color accent; // theme-family primary (mint / coral)
  final Color accentBright;
  final Color accentDeep;
  final Color accent2; // theme-family secondary (coral / teal)
  final Color amber; // Kids Mode: goal ring, stars, badges, gems

  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.text,
    required this.textDim,
    required this.paper,
    required this.paperInk,
    required this.shadow,
    required this.accent,
    required this.accentBright,
    required this.accentDeep,
    required this.accent2,
    this.amber = const Color(0xFFF4B23E),
  });
}

const _mintAccents = (
  Color(0xFF00C9A7), Color(0xFF2EE5A9), Color(0xFF00A98C), Color(0xFFFF6B67));
const _noorAccents = (
  Color(0xFFE96A4B), Color(0xFFF18A63), Color(0xFFCB4F2E), Color(0xFF21A99C));
// Kids Mode's own family — coral/teal, close enough to Noor's own accents
// (design #EC6A4B/#1FA89B vs Noor's #E96A4B/#21A99C) that Kids Mode is a
// palette variant of the existing brand, not a new one.
const _kidsAccents = (
  Color(0xFFEC6A4B), Color(0xFFF2917A), Color(0xFFD1502F), Color(0xFF1FA89B));
// Shop-bought Kids Mode palettes — see `kids_content.dart`'s Colours shelf.
// Same accent-tuple-plus-neutrals shape as every family above; the point of
// buying one is that it repaints the WHOLE of Kids Mode, since every kids
// screen already resolves colour through `kidsPal`/`PaletteScope`.
//
// Every colour a screen paints must come out of one of these — `accent2` and
// `amber` most of all. `amber` is the "reward" colour (stars, the goal ring,
// badges, gems, the mascot, the streak pill), and it used to be one shared
// gold for every family, which is why Ocean's blue screens still had an
// orange mascot; and Ocean's own `accent2` used to BE an orange, painting the
// gems and the rank banner.
const _kidsOceanAccents = (
  Color(0xFF2196C9), Color(0xFF5BC4E8), Color(0xFF15738F), Color(0xFF6C63D6));
// Desert is sand, ochre and dusk — deliberately far from the default family's
// cream, coral and teal, which already reads as warm and sandy. (It used to
// share that family's teal, its gold and its pure-white surface, so buying it
// changed very little.)
const _kidsDesertAccents = (
  Color(0xFFC9772B), Color(0xFFE3A45B), Color(0xFF94531A), Color(0xFF7B5EA7));
const _kidsNightAccents = (
  Color(0xFF4A3F8C), Color(0xFF6C5CE7), Color(0xFF352A6B), Color(0xFFE8C468));
// Four more, chosen so every family's own ACCENT sits at least 25° apart on
// the hue wheel from every other one (verified in `kids_palette_test.dart`)
// — the point of a shop full of themes is that each one is recognisably its
// own colour, not a slightly-different version of one already sold.
const _kidsForestAccents = (
  Color(0xFF389444), Color(0xFF70CD7C), Color(0xFF195726), Color(0xFF885E3A));
const _kidsLagoonAccents = (
  Color(0xFF2C967C), Color(0xFF59CFBB), Color(0xFF165A51), Color(0xFFCEB07E));
const _kidsBlossomAccents = (
  Color(0xFFC760C7), Color(0xFFE29CE2), Color(0xFF883A88), Color(0xFF7153AC));
// Sunset's own accent leans magenta-red rather than orange (orange sits too
// close to Desert's hue to tell the two apart) — the "orange" half of
// "orange-magenta" is `accentBright` instead, so the gradient between them
// still reads as a sunset.
const _kidsSunsetAccents = (
  Color(0xFFD4545E), Color(0xFFF0A06A), Color(0xFF792A37), Color(0xFF8D57A8));
// Five more, for the painted-scene themes (Rain, Cave, Sunrise, Frozen,
// Snowy). Unlike the seven above these are NOT kept 25° apart in hue — Frozen
// and Ocean are both blue by nature, Sunrise and Desert both warm — because
// each is now a whole painted scene, not just a colour. What keeps them from
// reading as twins is the scene-identity guard in `kids_palette_test.dart`.
const _kidsRainAccents = (
  Color(0xFF4F6D8A), Color(0xFF8FB3D1), Color(0xFF2E4459), Color(0xFF7A6FA8));
const _kidsCaveAccents = (
  Color(0xFF6B4F8C), Color(0xFF9B7FD0), Color(0xFF3A2A4E), Color(0xFF3F8C8A));
const _kidsSunriseAccents = (
  Color(0xFFF08A4B), Color(0xFFFFC27A), Color(0xFFA2472A), Color(0xFFE0679A));
const _kidsFrozenAccents = (
  Color(0xFF3AA5C8), Color(0xFF8FDDF0), Color(0xFF1D6A86), Color(0xFF7C8BE0));
const _kidsSnowyAccents = (
  Color(0xFF5C7FB0), Color(0xFFA9C4E8), Color(0xFF34507A), Color(0xFF8A7FC0));
// Each family's reward colour — see [Palette.amber].
const _kidsOceanAmber = Color(0xFF28C4B4); // aqua, not gold
const _kidsDesertAmber = Color(0xFFE6B34A); // sun on sand
const _kidsNightAmber = Color(0xFFF0D278); // moon gold
const _kidsForestAmber = Color(0xFFC3B555); // moss gold
const _kidsLagoonAmber = Color(0xFFED876E); // coral
const _kidsBlossomAmber = Color(0xFFE2AD78); // rose gold
const _kidsSunsetAmber = Color(0xFFEEAF77); // peach
const _kidsRainAmber = Color(0xFFF2C94C);
const _kidsCaveAmber = Color(0xFF5FE0D0);
const _kidsSunriseAmber = Color(0xFFFFD66B);
const _kidsFrozenAmber = Color(0xFFC6F4FF);
const _kidsSnowyAmber = Color(0xFFFF8A65);

Palette _p(
        Brightness b,
        int bg, int surface, int high, int text, int dim,
        int paper, int paperInk, int shadow,
        (Color, Color, Color, Color) a, {Color? amber}) =>
    Palette(
      brightness: b,
      bg: Color(bg), surface: Color(surface), surfaceHigh: Color(high),
      text: Color(text), textDim: Color(dim),
      paper: Color(paper), paperInk: Color(paperInk), shadow: Color(shadow),
      accent: a.$1, accentBright: a.$2, accentDeep: a.$3, accent2: a.$4,
      amber: amber ?? const Color(0xFFF4B23E),
    );

final _palettes = <String, Palette>{
  // ── Mint family (reference: Flurent / Arabiya) ──
  'mint.light': _p(Brightness.light, 0xFFEDF0F6, 0xFFFFFFFF, 0xFFEDF0F9,
      0xFF20264A, 0xFF9AA3BC, 0xFFFBF1DD, 0xFF2B2417, 0x14202648, _mintAccents),
  'mint.dark': _p(Brightness.dark, 0xFF14192B, 0xFF1D2440, 0xFF2A3254,
      0xFFF2F4FF, 0xFF9AA3C7, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000, _mintAccents),
  'mint.oled': _p(Brightness.dark, 0xFF000000, 0xFF121418, 0xFF24282F,
      0xFFECEFF6, 0xFF7E869C, 0xFF1B170E, 0xFFEFE6D0, 0x00000000, _mintAccents),
  // ── Noor family (warm cream / coral / teal, from the design PDF) ──
  'noor.light': _p(Brightness.light, 0xFFF7F0E4, 0xFFFFFFFF, 0xFFF0E6D3,
      0xFF3B2E22, 0xFF8C7B67, 0xFFFBF1DD, 0xFF2B2417, 0x1A3B2E22, _noorAccents),
  'noor.dark': _p(Brightness.dark, 0xFF211913, 0xFF2C2218, 0xFF3A2D1F,
      0xFFF6EDE0, 0xFFB5A48E, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000, _noorAccents),
  'noor.oled': _p(Brightness.dark, 0xFF000000, 0xFF191410, 0xFF251D14,
      0xFFF6EDE0, 0xFFA8997F, 0xFF1B170E, 0xFFEFE6D0, 0x00000000, _noorAccents),
  // ── Kids family (playful coral / teal / amber, from the Kids Mode design)
  // — light-only in the design; dark/OLED derived to match the other
  // families, since Kids Mode's own Me screen offers all three. ──
  'kids.light': _p(Brightness.light, 0xFFFFF8F0, 0xFFFFFFFF, 0xFFFCEEDF,
      0xFF3B2E22, 0xFF8C7B67, 0xFFFBF1DD, 0xFF2B2417, 0x1A3B2E22, _kidsAccents),
  'kids.dark': _p(Brightness.dark, 0xFF231911, 0xFF2E2117, 0xFF3D2B1C,
      0xFFF6EDE0, 0xFFB5A48E, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000, _kidsAccents),
  'kids.oled': _p(Brightness.dark, 0xFF000000, 0xFF191009, 0xFF261B10,
      0xFFF6EDE0, 0xFFA8997F, 0xFF1B170E, 0xFFEFE6D0, 0x00000000, _kidsAccents),
  // ── Kids Mode shop palettes — same neutrals shape as the family above,
  // rebuilt around each theme's own accent tuple. ──
  'kids_ocean.light': _p(Brightness.light, 0xFFEFF7FA, 0xFFFFFFFF, 0xFFE1F0F5,
      0xFF1E3A44, 0xFF6D8B94, 0xFFFBF1DD, 0xFF2B2417, 0x1A1E3A44,
      _kidsOceanAccents, amber: _kidsOceanAmber),
  'kids_ocean.dark': _p(Brightness.dark, 0xFF11202A, 0xFF172934, 0xFF203847,
      0xFFE7F2F6, 0xFF8FADB6, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsOceanAccents, amber: _kidsOceanAmber),
  'kids_ocean.oled': _p(Brightness.dark, 0xFF000000, 0xFF0D1A22, 0xFF172934,
      0xFFE7F2F6, 0xFF7E9BA4, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsOceanAccents, amber: _kidsOceanAmber),
  'kids_desert.light': _p(Brightness.light, 0xFFF3E4C6, 0xFFFFF8EA,
      0xFFE9D3A8, 0xFF3F2A14, 0xFF8C7451, 0xFFFBF1DD, 0xFF2B2417, 0x1A3F2A14,
      _kidsDesertAccents, amber: _kidsDesertAmber),
  'kids_desert.dark': _p(Brightness.dark, 0xFF2B1F10, 0xFF37281A, 0xFF473521,
      0xFFF6EAD3, 0xFFBFA57F, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsDesertAccents, amber: _kidsDesertAmber),
  'kids_desert.oled': _p(Brightness.dark, 0xFF000000, 0xFF20160B, 0xFF37281A,
      0xFFF6EAD3, 0xFFAE946E, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsDesertAccents, amber: _kidsDesertAmber),
  'kids_night.light': _p(Brightness.light, 0xFFF3F0FA, 0xFFFFFFFF, 0xFFE9E3F5,
      0xFF2E2A4A, 0xFF817BA0, 0xFFFBF1DD, 0xFF2B2417, 0x1A2E2A4A,
      _kidsNightAccents, amber: _kidsNightAmber),
  'kids_night.dark': _p(Brightness.dark, 0xFF1B1830, 0xFF242040, 0xFF302A54,
      0xFFEEEBFA, 0xFFA79FCB, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsNightAccents, amber: _kidsNightAmber),
  'kids_night.oled': _p(Brightness.dark, 0xFF000000, 0xFF161228, 0xFF242040,
      0xFFEEEBFA, 0xFF938AB8, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsNightAccents, amber: _kidsNightAmber),
  'kids_forest.light': _p(Brightness.light, 0xFFE8F2E9, 0xFFFFFFFF, 0xFFD5E7D7,
      0xFF163B1B, 0xFF6F9B74, 0xFFFBF1DD, 0xFF2B2417, 0x1A163B1B,
      _kidsForestAccents, amber: _kidsForestAmber),
  'kids_forest.dark': _p(Brightness.dark, 0xFF152818, 0xFF1F3722, 0xFF2B4A2F,
      0xFFE7F3E9, 0xFF9DBEA1, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsForestAccents, amber: _kidsForestAmber),
  'kids_forest.oled': _p(Brightness.dark, 0xFF000000, 0xFF101E12, 0xFF1F3722,
      0xFFE7F3E9, 0xFF87AB8C, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsForestAccents, amber: _kidsForestAmber),
  'kids_lagoon.light': _p(Brightness.light, 0xFFE8F2F0, 0xFFFFFFFF, 0xFFD5E7E2,
      0xFF163B32, 0xFF6F9B90, 0xFFFBF1DD, 0xFF2B2417, 0x1A163B32,
      _kidsLagoonAccents, amber: _kidsLagoonAmber),
  'kids_lagoon.dark': _p(Brightness.dark, 0xFF152823, 0xFF1F3731, 0xFF2B4A42,
      0xFFE7F3F0, 0xFF9DBEB6, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsLagoonAccents, amber: _kidsLagoonAmber),
  'kids_lagoon.oled': _p(Brightness.dark, 0xFF000000, 0xFF101E1B, 0xFF1F3731,
      0xFFE7F3F0, 0xFF87ABA2, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsLagoonAccents, amber: _kidsLagoonAmber),
  'kids_blossom.light': _p(Brightness.light, 0xFFF2E8F2, 0xFFFFFFFF, 0xFFE7D5E7,
      0xFF3B163B, 0xFF9B6F9B, 0xFFFBF1DD, 0xFF2B2417, 0x1A3B163B,
      _kidsBlossomAccents, amber: _kidsBlossomAmber),
  'kids_blossom.dark': _p(Brightness.dark, 0xFF281528, 0xFF371F37, 0xFF4A2B4A,
      0xFFF3E7F3, 0xFFBE9DBE, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsBlossomAccents, amber: _kidsBlossomAmber),
  'kids_blossom.oled': _p(Brightness.dark, 0xFF000000, 0xFF1E101E, 0xFF371F37,
      0xFFF3E7F3, 0xFFAB87AB, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsBlossomAccents, amber: _kidsBlossomAmber),
  'kids_sunset.light': _p(Brightness.light, 0xFFF2E8E9, 0xFFFFFFFF, 0xFFE7D5D6,
      0xFF3B1619, 0xFF9B6F72, 0xFFFBF1DD, 0xFF2B2417, 0x1A3B1619,
      _kidsSunsetAccents, amber: _kidsSunsetAmber),
  'kids_sunset.dark': _p(Brightness.dark, 0xFF281517, 0xFF371F21, 0xFF4A2B2E,
      0xFFF3E7E8, 0xFFBE9DA0, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsSunsetAccents, amber: _kidsSunsetAmber),
  'kids_sunset.oled': _p(Brightness.dark, 0xFF000000, 0xFF1E1011, 0xFF371F21,
      0xFFF3E7E8, 0xFFAB878A, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsSunsetAccents, amber: _kidsSunsetAmber),
  'kids_rain.light': _p(Brightness.light, 0xFFE9EEF2, 0xFFFFFFFF, 0xFFDAE0E4,
      0xFF1F2D3A, 0xFF7A848D, 0xFFFBF1DD, 0xFF2B2417, 0x1A1F2D3A,
      _kidsRainAccents, amber: _kidsRainAmber),
  'kids_rain.dark': _p(Brightness.dark, 0xFF141C24, 0xFF202B35, 0xFF2D3A47,
      0xFFF2F6F9, 0xFFAFB5B9, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsRainAccents, amber: _kidsRainAmber),
  'kids_rain.oled': _p(Brightness.dark, 0xFF000000, 0xFF0F151B, 0xFF202B35,
      0xFFF2F6F9, 0xFF9A9FA3, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsRainAccents, amber: _kidsRainAmber),
  'kids_cave.light': _p(Brightness.light, 0xFFECE8F0, 0xFFFFFFFF, 0xFFDDD9E2,
      0xFF2A2233, 0xFF817B88, 0xFFFBF1DD, 0xFF2B2417, 0x1A2A2233,
      _kidsCaveAccents, amber: _kidsCaveAmber),
  'kids_cave.dark': _p(Brightness.dark, 0xFF16121C, 0xFF231D2E, 0xFF312840,
      0xFFF3F0F9, 0xFFB1ADB7, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsCaveAccents, amber: _kidsCaveAmber),
  'kids_cave.oled': _p(Brightness.dark, 0xFF000000, 0xFF110E15, 0xFF231D2E,
      0xFFF3F0F9, 0xFF9C98A1, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsCaveAccents, amber: _kidsCaveAmber),
  'kids_sunrise.light': _p(Brightness.light, 0xFFFBEFE6, 0xFFFFFFFF, 0xFFEDE0D7,
      0xFF3D2418, 0xFF927F75, 0xFFFBF1DD, 0xFF2B2417, 0x1A3D2418,
      _kidsSunriseAccents, amber: _kidsSunriseAmber),
  'kids_sunrise.dark': _p(Brightness.dark, 0xFF2A1A14, 0xFF3F2B1E, 0xFF553C28,
      0xFFFFF8EF, 0xFFBFB5AD, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsSunriseAccents, amber: _kidsSunriseAmber),
  'kids_sunrise.oled': _p(Brightness.dark, 0xFF000000, 0xFF20140F, 0xFF3F2B1E,
      0xFFFFF8EF, 0xFFA89F98, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsSunriseAccents, amber: _kidsSunriseAmber),
  'kids_frozen.light': _p(Brightness.light, 0xFFEAF4F8, 0xFFFFFFFF, 0xFFDAE5EA,
      0xFF15323D, 0xFF758991, 0xFFFBF1DD, 0xFF2B2417, 0x1A15323D,
      _kidsFrozenAccents, amber: _kidsFrozenAmber),
  'kids_frozen.dark': _p(Brightness.dark, 0xFF0E1C24, 0xFF1B2F38, 0xFF28434D,
      0xFFF2FBFD, 0xFFAEB8BC, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsFrozenAccents, amber: _kidsFrozenAmber),
  'kids_frozen.oled': _p(Brightness.dark, 0xFF000000, 0xFF0B151B, 0xFF1B2F38,
      0xFFF2FBFD, 0xFF99A2A5, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsFrozenAccents, amber: _kidsFrozenAmber),
  'kids_snowy.light': _p(Brightness.light, 0xFFF1F3F7, 0xFFFFFFFF, 0xFFE2E4E9,
      0xFF23303F, 0xFF808892, 0xFFFBF1DD, 0xFF2B2417, 0x1A23303F,
      _kidsSnowyAccents, amber: _kidsSnowyAmber),
  'kids_snowy.dark': _p(Brightness.dark, 0xFF131A26, 0xFF222B39, 0xFF313C4D,
      0xFFF5F8FC, 0xFFB1B5BC, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsSnowyAccents, amber: _kidsSnowyAmber),
  'kids_snowy.oled': _p(Brightness.dark, 0xFF000000, 0xFF0E141D, 0xFF222B39,
      0xFFF5F8FC, 0xFF9C9FA5, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsSnowyAccents, amber: _kidsSnowyAmber),
};

/// Palette family ids the Kids Mode shop can unlock, in the order they
/// appear on its Colours shelf — see `kidsShopItems` in `kids_content.dart`.
/// `'kids'` itself is always available and is not a purchase.
const kKidsShopThemeFamilies = [
  'kids_ocean',
  'kids_desert',
  'kids_night',
  'kids_forest',
  'kids_lagoon',
  'kids_blossom',
  'kids_sunset',
  'kids_rain',
  'kids_cave',
  'kids_sunrise',
  'kids_frozen',
  'kids_snowy',
];

/// The palette for [family] in [mode]. An unrecognised mode falls back to the
/// family's light palette, and an unrecognised family to its own kind's
/// default — a corrupt or retired `kids_*` id must give a child the DEFAULT
/// Kids Mode palette, not the grown-up app's mint green.
Palette paletteFor(String family, String mode) {
  final base = family.startsWith('kids') ? 'kids' : 'mint';
  return _palettes['$family.$mode'] ??
      _palettes['$family.light'] ??
      _palettes['$base.$mode'] ??
      _palettes['$base.light']!;
}

/// The families the grown-up theme picker cycles through/offers. 'kids' is
/// deliberately excluded — it's Kids Mode's own palette (see [kidsPal]),
/// never a user-selectable choice in the adult app.
const kAdultThemeFamilies = ['mint', 'noor'];

/// The current palette, reactive to theme family + mode settings.
/// Overrides what [pal] resolves to for everything beneath it.
///
/// Kids Mode publishes one holding [kidsPal], because the grown-up screens it
/// reuses — the Qāʿidah lesson trees, the shared [QuizScreen], every widget
/// that calls [pal] rather than taking an explicit colour — otherwise paint in
/// the parent app's `themeFamily`, which has nothing to do with the child's
/// own Light/Dark/OLED choice. Without this, reusing one lesson inside Kids
/// Mode means either recolouring it by hand or shipping two copies.
class PaletteScope extends InheritedWidget {
  final Palette palette;
  const PaletteScope(
      {super.key, required this.palette, required super.child});

  @override
  bool updateShouldNotify(PaletteScope old) => old.palette != palette;
}

Palette pal(BuildContext context) {
  // No dependency is registered when there is no PaletteScope above, so the
  // grown-up app pays only a map lookup for this.
  final scoped = context.dependOnInheritedWidgetOfExactType<PaletteScope>();
  if (scoped != null) return scoped.palette;
  final s = SettingsScope.of(context);
  return paletteFor(s.themeFamily, s.themeMode);
}

/// Kids Mode's own palette — independent of the grown-up `themeFamily`
/// setting on purpose: Kids Mode has its own Light/Dark/OLED appearance
/// picker (see the Me screen), so switching it never touches the parent
/// app's theme, and switching the parent app's theme never affects Kids Mode.
///
/// The FAMILY (which accent colours — the default coral/teal, or a
/// shop-bought one) comes from the active child's own profile, not a global
/// setting — a sibling's purchase should never repaint another child's app.
/// Read from `SettingsScope` alone, not `ProgressScope`: this is called from
/// screens that render before a child's `ProgressStore` exists yet (the
/// profile picker, the profile-loading spinner), and those still need a
/// palette.
Palette kidsPal(BuildContext context) {
  final s = SettingsScope.of(context);
  final family = s.activeKidsProfile?.theme ?? 'kids';
  return paletteFor(family, s.kidsThemeMode);
}

ThemeData buildTheme(AppSettings s) =>
    _themeFrom(paletteFor(s.themeFamily, s.themeMode), s.language);

/// Kids Mode's own `ThemeData` — [kidsPal] instead of the grown-up
/// [pal]/`themeFamily`, so tooltips, scrollbars, hover ink and text selection
/// under the kids desktop shell follow the kids palette instead of whatever
/// the parent app's adult theme happens to be. Mobile Kids Mode never needed
/// this (every kids widget already passes explicit colours), but the desktop
/// shell reaches Material widgets — `Tooltip`, `Scrollbar` — that read
/// `Theme.of(context)` directly.
ThemeData kidsTheme(BuildContext context) =>
    _themeFrom(kidsPal(context), SettingsScope.of(context).language);

ThemeData _themeFrom(Palette p, String language) {
  final (uiFamily, uiFallback) = _uiFont(language);
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: Colors.white,
      secondary: p.accent2,
      onSecondary: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      error: AppColors.bad,
      onError: Colors.white,
    ),
  );
  final text = _withFallback(uiFallback, base.textTheme
      .apply(fontFamily: uiFamily, bodyColor: p.text, displayColor: p.text));
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontFamily: uiFamily,
          fontFamilyFallback: uiFallback,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: p.text),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      thumbColor: p.accent,
      inactiveTrackColor: p.surfaceHigh,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? Colors.white
              : p.textDim),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? p.accent
              : p.surfaceHigh),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: DividerThemeData(color: p.surfaceHigh),
    listTileTheme: ListTileThemeData(iconColor: p.textDim),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: p.textDim,
      collapsedIconColor: p.textDim,
      textColor: p.text,
      collapsedTextColor: p.text,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.brightness == Brightness.light
          ? AppColors.navy
          : p.surfaceHigh,
      contentTextStyle: TextStyle(
          fontFamily: uiFamily,
          fontFamilyFallback: uiFallback,
          color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// UI-chrome font per active language: Outfit for the Latin languages
/// (en/fr/es — they share one face), ScheherazadeNew for Arabic, and Noto
/// Nastaliq Urdu for Urdu (Urdu reads as Nastaliq, not the Naskh style
/// Arabic uses; ScheherazadeNew is its fallback for any glyph it lacks).
(String, List<String>) _uiFont(String lang) => switch (lang) {
      'ar' => ('ScheherazadeNew', const <String>[]),
      'ur' => ('NotoNastaliqUrdu', const ['ScheherazadeNew']),
      _ => ('Outfit', const <String>[]),
    };

TextTheme _withFallback(List<String> fallback, TextTheme t) {
  TextStyle? add(TextStyle? s) => s?.copyWith(fontFamilyFallback: fallback);
  return TextTheme(
    displayLarge: add(t.displayLarge),
    displayMedium: add(t.displayMedium),
    displaySmall: add(t.displaySmall),
    headlineLarge: add(t.headlineLarge),
    headlineMedium: add(t.headlineMedium),
    headlineSmall: add(t.headlineSmall),
    titleLarge: add(t.titleLarge),
    titleMedium: add(t.titleMedium),
    titleSmall: add(t.titleSmall),
    bodyLarge: add(t.bodyLarge),
    bodyMedium: add(t.bodyMedium),
    bodySmall: add(t.bodySmall),
    labelLarge: add(t.labelLarge),
    labelMedium: add(t.labelMedium),
    labelSmall: add(t.labelSmall),
  );
}

/// The multiplier on Arabic glyph sizes: the grown-up Reading Coach's
/// [AppSettings.arabicScale], or — while Kids Mode is on — Kids Mode's own
/// [AppSettings.kidsTextScale]. A parent's reader slider used to resize the
/// Arabic in a child's screens while the child's Latin text stayed put, and the
/// child's app had no say in it.
double arabicScaleOf(AppSettings s) =>
    s.kidsMode ? s.kidsTextScale : s.arabicScale;

/// [arabicScaleOf], minus Kids Mode's dial when a [KidsTextScale] above
/// [context] already applies it as a text scaler — so it is applied once.
double _arabicScaleAt(BuildContext context, AppSettings s) =>
    s.kidsMode && kidsTextScaledAbove(context) ? 1.0 : arabicScaleOf(s);

/// Kids Mode's own Text size dial (Me ▸ Appearance ▸ Text size), applied ONCE
/// to everything below it — as a text scaler, which also reaches text drawn
/// with plain `TextStyle`s, like the design kit's (`lib/kids_backdrops/`).
///
/// The style helpers ([kidsStyle], [arabicStyle], [quranicStyle], [uiStyle])
/// used to multiply by the dial themselves; under a [KidsTextScale] they skip
/// it, and outside one (a dialog, a widget test pumping a bare screen) they
/// still apply it, so no text is ever scaled twice and none is left unscaled.
/// Nesting is harmless: an inner one is a no-op.
class KidsTextScale extends StatelessWidget {
  final Widget child;
  const KidsTextScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kidsTextScaledAbove(context)) return child;
    final k = SettingsScope.of(context).kidsTextScale;
    final mq = MediaQuery.of(context);
    return _KidsTextScaled(
      child: MediaQuery(
        data: mq.copyWith(textScaler: _TimesScaler(mq.textScaler, k)),
        child: child,
      ),
    );
  }
}

class _KidsTextScaled extends InheritedWidget {
  const _KidsTextScaled({required super.child});
  @override
  bool updateShouldNotify(_KidsTextScaled old) => false;
}

/// Whether a [KidsTextScale] above [context] already applies the dial.
bool kidsTextScaledAbove(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_KidsTextScaled>() != null;

/// The platform's own scaler (which may be non-linear) applied to the font size
/// the Kids dial asks for — the same result the style helpers used to produce by
/// multiplying the size before handing it to the platform.
class _TimesScaler extends TextScaler {
  final TextScaler base;
  final double k;
  const _TimesScaler(this.base, this.k);
  @override
  double scale(double fontSize) => base.scale(fontSize * k);
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * k;
  @override
  bool operator ==(Object other) =>
      other is _TimesScaler && other.base == base && other.k == k;
  @override
  int get hashCode => Object.hash(base, k);
}

/// Arabic text style that respects reader settings (scale, tracking,
/// word spacing). Defaults to the palette text color.
TextStyle arabicStyle(
  BuildContext context, {
  double size = 34,
  Color? color,
  FontWeight weight = FontWeight.w500,
  double height = 1.95,
}) {
  final s = SettingsScope.of(context);
  return TextStyle(
    fontFamily: 'ScheherazadeNew',
    fontSize: size * _arabicScaleAt(context, s),
    height: height,
    fontWeight: weight,
    letterSpacing: s.letterTracking,
    wordSpacing: s.wordSpacing,
    color: color ?? pal(context).text,
  );
}

/// Qur'anic text style — UthmanicHafs (KFGQPC Ḥafṣ), the same face the
/// reader uses. Any Arabic that's an actual Qur'anic quote (verses, example
/// words, quiz prompts drawn from the muṣḥaf) should use this, never
/// [arabicStyle] — that one is ScheherazadeNew, correct for prose/UI Arabic
/// but wrong for Qur'anic orthography (no shadda+kasra ligature stacking the
/// kasra above the letter, dotted-yā' substitution, etc.).
///
/// `height: 1.8` is deliberate, not a round number: UthmanicHafs declares
/// ascent 1.1719em + descent 0.5859em = 1.7578em of vertical extent per its
/// own hhea/OS2 tables, so anything below that clips. 1.8 is the minimum
/// with a small safety margin; pass a taller value for full-verse text.
TextStyle quranicStyle(
  BuildContext context, {
  double size = 34,
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.8,
}) {
  final s = SettingsScope.of(context);
  return TextStyle(
    fontFamily: 'UthmanicHafs',
    fontSize: size * _arabicScaleAt(context, s),
    height: height,
    fontWeight: weight,
    letterSpacing: s.letterTracking,
    wordSpacing: s.wordSpacing,
    color: color ?? pal(context).text,
  );
}

/// Text color for containers that switch to the warm "paper" background.
Color readingInk(BuildContext context) {
  final s = SettingsScope.of(context);
  return s.paperMode ? pal(context).paperInk : pal(context).text;
}

TextStyle uiStyle(
  BuildContext context, {
  double size = 15,
  Color? color,
  FontWeight weight = FontWeight.w500,
}) {
  final s = SettingsScope.of(context);
  final (family, fallback) = _uiFont(s.language);
  return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      // Kids Mode's own size dial reaches the shared quiz screen too — it is
      // drawn with this helper, not [kidsStyle], and would otherwise stay
      // small when everything around it grew.
      fontSize: s.kidsMode && !kidsTextScaledAbove(context)
          ? size * s.kidsTextScale
          : size,
      fontWeight: weight,
      color: color ?? pal(context).text);
}

/// Kids Mode's UI chrome font — Baloo 2, a rounded display face bundled at
/// `assets/fonts/Baloo2-*.ttf` (SIL OFL, see CREDITS.md) — never
/// fetched over the network, same as every other face in this app. Latin
/// only (it has full French/Spanish diacritic coverage); Arabic UI text in
/// Kids Mode still goes through [arabicStyle]/[quranicStyle] as usual, with
/// Outfit as the fallback for any stray Latin punctuation.
TextStyle kidsStyle(
  BuildContext context, {
  double size = 15,
  Color? color,
  FontWeight weight = FontWeight.w600,
}) {
  return TextStyle(
      fontFamily: 'Baloo2',
      // ScheherazadeNew last: neither Baloo2 nor Outfit has Arabic glyphs, and
      // Kids Mode's later stages show copy from the grown-up path that mixes
      // scripts ("The echoing bounce of قطب جد"). Real devices would fall back
      // to a system face, but a bundled one makes it certain.
      fontFamilyFallback: const ['Outfit', 'ScheherazadeNew'],
      // Kids Mode's own size dial (Me ▸ Appearance ▸ Text size). The number at
      // a call site is the MEDIUM size; Small and Large scale it.
      fontSize: kidsTextScaledAbove(context)
          ? size
          : size * SettingsScope.of(context).kidsTextScale,
      fontWeight: weight,
      color: color ?? kidsPal(context).text);
}
