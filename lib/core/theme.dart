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
  });
}

const _mintAccents = (
  Color(0xFF00C9A7), Color(0xFF2EE5A9), Color(0xFF00A98C), Color(0xFFFF6B67));
const _noorAccents = (
  Color(0xFFE96A4B), Color(0xFFF18A63), Color(0xFFCB4F2E), Color(0xFF21A99C));

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
};

Palette paletteFor(String family, String mode) =>
    _palettes['$family.$mode'] ?? _palettes['mint.light']!;

/// The current palette, reactive to theme family + mode settings.
Palette pal(BuildContext context) {
  final s = SettingsScope.of(context);
  return paletteFor(s.themeFamily, s.themeMode);
}

ThemeData buildTheme(AppSettings s) {
  final p = paletteFor(s.themeFamily, s.themeMode);
  final (uiFamily, uiFallback) = _uiFont(s.language);
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

/// Arabic UI/body text is Amiri first — ScheherazadeNew only covers glyphs
/// Amiri itself doesn't (there shouldn't be any in practice, but this keeps
/// text visible rather than silently falling through to a system font if
/// one ever comes up).
const _arabicFallback = ['ScheherazadeNew'];

/// UI-chrome font per active language: Outfit for the Latin languages
/// (en/fr/es — they share one face), Amiri for Arabic, and Noto Nastaliq
/// Urdu for Urdu (Urdu reads as Nastaliq, not the Naskh style Arabic uses).
(String, List<String>) _uiFont(String lang) => switch (lang) {
      'ar' => ('Amiri', _arabicFallback),
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
    fontFamily: 'Amiri',
    fontFamilyFallback: _arabicFallback,
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
