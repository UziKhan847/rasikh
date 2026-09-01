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
const _kidsOceanAccents = (
  Color(0xFF2196C9), Color(0xFF5BC4E8), Color(0xFF15738F), Color(0xFFF2A65A));
const _kidsDesertAccents = (
  Color(0xFFD97B4A), Color(0xFFE9A06D), Color(0xFFB5602E), Color(0xFF3FA79A));
const _kidsNightAccents = (
  Color(0xFF4A3F8C), Color(0xFF6C5CE7), Color(0xFF352A6B), Color(0xFFE8C468));

Palette _p(
        Brightness b,
        int bg, int surface, int high, int text, int dim,
        int paper, int paperInk, int shadow,
        (Color, Color, Color, Color) a) =>
    Palette(
      brightness: b,
      bg: Color(bg), surface: Color(surface), surfaceHigh: Color(high),
      text: Color(text), textDim: Color(dim),
      paper: Color(paper), paperInk: Color(paperInk), shadow: Color(shadow),
      accent: a.$1, accentBright: a.$2, accentDeep: a.$3, accent2: a.$4,
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
      _kidsOceanAccents),
  'kids_ocean.dark': _p(Brightness.dark, 0xFF11202A, 0xFF172934, 0xFF203847,
      0xFFE7F2F6, 0xFF8FADB6, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsOceanAccents),
  'kids_ocean.oled': _p(Brightness.dark, 0xFF000000, 0xFF0D1A22, 0xFF172934,
      0xFFE7F2F6, 0xFF7E9BA4, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsOceanAccents),
  'kids_desert.light': _p(Brightness.light, 0xFFF9F0E0, 0xFFFFFFFF,
      0xFFF2E2C6, 0xFF4A3524, 0xFF9C8368, 0xFFFBF1DD, 0xFF2B2417, 0x1A4A3524,
      _kidsDesertAccents),
  'kids_desert.dark': _p(Brightness.dark, 0xFF2A1F14, 0xFF35271A, 0xFF443322,
      0xFFF5EAD9, 0xFFBBA285, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsDesertAccents),
  'kids_desert.oled': _p(Brightness.dark, 0xFF000000, 0xFF1E150D, 0xFF35271A,
      0xFFF5EAD9, 0xFFAB9276, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsDesertAccents),
  'kids_night.light': _p(Brightness.light, 0xFFF3F0FA, 0xFFFFFFFF, 0xFFE9E3F5,
      0xFF2E2A4A, 0xFF817BA0, 0xFFFBF1DD, 0xFF2B2417, 0x1A2E2A4A,
      _kidsNightAccents),
  'kids_night.dark': _p(Brightness.dark, 0xFF1B1830, 0xFF242040, 0xFF302A54,
      0xFFEEEBFA, 0xFFA79FCB, 0xFF2E2A1F, 0xFFF0E7D2, 0x00000000,
      _kidsNightAccents),
  'kids_night.oled': _p(Brightness.dark, 0xFF000000, 0xFF161228, 0xFF242040,
      0xFFEEEBFA, 0xFF938AB8, 0xFF1B170E, 0xFFEFE6D0, 0x00000000,
      _kidsNightAccents),
};

/// Palette family ids the Kids Mode shop can unlock, in the order they
/// appear on its Colours shelf — see `kidsShopItems` in `kids_content.dart`.
/// `'kids'` itself is always available and is not a purchase.
const kKidsShopThemeFamilies = ['kids_ocean', 'kids_desert', 'kids_night'];

Palette paletteFor(String family, String mode) =>
    _palettes['$family.$mode'] ?? _palettes['mint.light']!;

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
    fontSize: size * s.arabicScale,
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
    fontSize: size * s.arabicScale,
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
  final (family, fallback) = _uiFont(SettingsScope.of(context).language);
  return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
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
      fontSize: size,
      fontWeight: weight,
      color: color ?? kidsPal(context).text);
}
