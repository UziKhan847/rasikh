import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../ui/qiraah_icons.dart';
import 'settings.dart';

/// The four app-wide themes of the redesign (design_handoff_qiraah_flutter,
/// Update 2 §1). One theme colours every screen — shell, lessons, reader and
/// muṣḥaf alike.
enum AppTheme { light, mono, night, oled }

AppTheme appThemeFrom(String id) => switch (id) {
      'mono' => AppTheme.mono,
      'night' => AppTheme.night,
      'oled' => AppTheme.oled,
      _ => AppTheme.light,
    };

/// Fixed colours that do not follow the theme: semantic right/wrong, the
/// star gold, and the tajwīd rule colours used by the lesson screens.
class AppColors {
  // Brand (the redesign's emerald, gold and the deep "hero" green).
  static const mint = Color(0xFF0F7A62);
  static const mintBright = Color(0xFF3FB08F);
  static const mintDeep = Color(0xFF0B5E4B);
  static const coral = Color(0xFFB4483B);
  static const lilac = Color(0xFF6E62B0);
  static const navy = Color(0xFF0F3B32);
  static const star = Color(0xFFB4862C);

  // semantic (fixed across themes)
  static const ok = Color(0xFF2E8A5F);
  static const bad = Color(0xFFB4483B);

  // Tajwid coding (tuned to read on both light and dark surfaces)
  static const tjGhunnah = Color(0xFF2E9A5A);
  static const tjIkhfa = Color(0xFF3FA585);
  static const tjIdghamG = Color(0xFF1E8A86);
  static const tjIdghamNoG = Color(0xFF8A93A8);
  static const tjIqlab = Color(0xFF3F7FC2);
  static const tjIzhar = Color(0xFF7B6FB3);
  static const tjQalqalah = Color(0xFF2F6CA6);
  static const tjMadd2 = Color(0xFFB4862C);
  static const tjMadd4 = Color(0xFFC9682F);
  static const tjMadd6 = Color(0xFFB4483B);
  static const tjShamsiyya = Color(0xFFC0587F);
  static const tjQamariyya = Color(0xFF5C7BD0);
  static const tjRaa = Color(0xFFA0603F);
}

/// Every colour token of the redesign, for one theme. Read through
/// [pal]; widgets never hard-code a hex value of their own.
class Palette {
  final AppTheme theme;
  final Brightness brightness;
  final Color bg, card, ink, ink2, ink3, mut;
  final Color line, line2, line3, track, segOn, side, hover;
  final Color acc, accBg, accSoft, accInk, hero, dim, sel, outer, ghost, hl;
  final Color red, gold;

  /// The warm reading background of the Reading Coach's paper mode, and the
  /// ink that goes on it.
  final Color paper, paperInk;
  final Color shadowColor;

  const Palette({
    required this.theme,
    required this.brightness,
    required this.bg,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.mut,
    required this.line,
    required this.line2,
    required this.line3,
    required this.track,
    required this.segOn,
    required this.side,
    required this.hover,
    required this.acc,
    required this.accBg,
    required this.accSoft,
    required this.accInk,
    required this.hero,
    required this.dim,
    required this.sel,
    required this.outer,
    required this.ghost,
    required this.hl,
    required this.red,
    required this.gold,
    required this.paper,
    required this.paperInk,
    required this.shadowColor,
  });

  bool get isDark => brightness == Brightness.dark;

  Color get shadow => shadowColor;
}

const _light = Palette(
  theme: AppTheme.light,
  brightness: Brightness.light,
  bg: Color(0xFFF5F3EE),
  card: Color(0xFFFFFFFF),
  ink: Color(0xFF16201C),
  ink2: Color(0xFF56605B),
  ink3: Color(0xFF676E69), // 6.9 gave 6F7671: 4.2:1 on bg
  mut: Color(0xFF656C67), // 6.9 gave 6B726D: 4.45:1 on bg
  line: Color(0xFFE6E2D8),
  line2: Color(0xFFECE8DF),
  line3: Color(0xFFD9D5CB),
  track: Color(0xFFF0EDE6),
  segOn: Color(0xFFFFFFFF),
  side: Color(0xFFFBFAF7),
  hover: Color(0xFFEFECE5),
  acc: Color(0xFF0F7A62),
  accBg: Color(0xFF0F7A62),
  accSoft: Color(0xFFE1EEE8),
  accInk: Color(0xFF0B5E4B),
  hero: Color(0xFF0F3B32),
  dim: Color(0xFFB5BAB4),
  sel: Color(0xFFF3EAD5),
  outer: Color(0xFFE8E4DA),
  ghost: Color(0xFFECE7DC),
  hl: Color(0xFFD9ECE3),
  red: Color(0xFFB4483B),
  gold: Color(0xFFB4862C),
  paper: Color(0xFFFBF7EC),
  paperInk: Color(0xFF1D2420),
  shadowColor: Color(0x1A14201C),
);

const _mono = Palette(
  theme: AppTheme.mono,
  brightness: Brightness.light,
  bg: Color(0xFFF4F4F4),
  card: Color(0xFFFFFFFF),
  ink: Color(0xFF111111),
  ink2: Color(0xFF555555),
  ink3: Color(0xFF6E6E6E),
  mut: Color(0xFF6A6A6A),
  line: Color(0xFFE2E2E2),
  line2: Color(0xFFEBEBEB),
  line3: Color(0xFFD2D2D2),
  track: Color(0xFFECECEC),
  segOn: Color(0xFFFFFFFF),
  side: Color(0xFFFAFAFA),
  hover: Color(0xFFEDEDED),
  acc: Color(0xFF111111),
  accBg: Color(0xFF111111),
  accSoft: Color(0xFFE8E8E8),
  accInk: Color(0xFF111111),
  hero: Color(0xFF1A1A1A),
  dim: Color(0xFFB3B3B3),
  sel: Color(0xFFEDEDED),
  outer: Color(0xFFE4E4E4),
  ghost: Color(0xFFEAEAEA),
  hl: Color(0xFFE4E4E4),
  red: Color(0xFFB4483B),
  gold: Color(0xFF8A8A8A),
  paper: Color(0xFFFFFFFF),
  paperInk: Color(0xFF111111),
  shadowColor: Color(0x1A000000),
);

const _night = Palette(
  theme: AppTheme.night,
  brightness: Brightness.dark,
  bg: Color(0xFF0E1412),
  card: Color(0xFF161E1B),
  ink: Color(0xFFECE8DF),
  ink2: Color(0xFFA3ABA6),
  ink3: Color(0xFF8F9893),
  mut: Color(0xFF8F9893),
  line: Color(0xFF26302B),
  line2: Color(0xFF222B27),
  line3: Color(0xFF34403A),
  track: Color(0xFF1C2522),
  segOn: Color(0xFF2C3833),
  side: Color(0xFF121916),
  hover: Color(0xFF1C2522),
  acc: Color(0xFF3FB08F),
  accBg: Color(0xFF16856A),
  accSoft: Color(0xFF173A2F),
  accInk: Color(0xFF9FE0C6),
  hero: Color(0xFF0F3B32),
  dim: Color(0xFF56605B),
  sel: Color(0xFF3A3220),
  outer: Color(0xFF050807),
  ghost: Color(0xFF26302B),
  hl: Color(0xFF1F4337),
  red: Color(0xFFE07A6C),
  gold: Color(0xFFC9A253),
  paper: Color(0xFF161E1B),
  paperInk: Color(0xFFECE8DF),
  shadowColor: Color(0x00000000),
);

const _oled = Palette(
  theme: AppTheme.oled,
  brightness: Brightness.dark,
  bg: Color(0xFF000000),
  card: Color(0xFF0B0F0D),
  ink: Color(0xFFE6E2D8),
  ink2: Color(0xFF9AA19D),
  ink3: Color(0xFF878F8B),
  mut: Color(0xFF878F8B),
  line: Color(0xFF1C2421),
  line2: Color(0xFF161D1A),
  line3: Color(0xFF2A3430),
  track: Color(0xFF121815),
  segOn: Color(0xFF222B27),
  side: Color(0xFF000000),
  hover: Color(0xFF121815),
  acc: Color(0xFF3FB08F),
  accBg: Color(0xFF16856A),
  accSoft: Color(0xFF0F2A21),
  accInk: Color(0xFF9FE0C6),
  hero: Color(0xFF0F3B32),
  dim: Color(0xFF4A524E),
  sel: Color(0xFF2E2817),
  outer: Color(0xFF000000),
  ghost: Color(0xFF1A211E),
  hl: Color(0xFF123326),
  red: Color(0xFFE07A6C),
  gold: Color(0xFFBE9A4E),
  paper: Color(0xFF0B0F0D),
  paperInk: Color(0xFFE6E2D8),
  shadowColor: Color(0x00000000),
);

Palette paletteOf(AppTheme t) => switch (t) {
      AppTheme.light => _light,
      AppTheme.mono => _mono,
      AppTheme.night => _night,
      AppTheme.oled => _oled,
    };

/// The palette and UI language, carried by the app's ThemeData. Reading them
/// from the theme (rather than from [SettingsScope]) means a widget only
/// rebuilds when the theme or language changes — not on every setting.
class PaletteTheme extends ThemeExtension<PaletteTheme> {
  final Palette palette;
  final String language;
  const PaletteTheme(this.palette, this.language);

  @override
  PaletteTheme copyWith({Palette? palette, String? language}) =>
      PaletteTheme(palette ?? this.palette, language ?? this.language);

  @override
  PaletteTheme lerp(covariant PaletteTheme? other, double t) =>
      other == null || t < .5 ? this : other;
}

/// The current palette, following Settings → Theme.
Palette pal(BuildContext context) =>
    Theme.of(context).extension<PaletteTheme>()?.palette ??
    paletteOf(SettingsScope.of(context).theme);

/// The UI language (en, ar, ur, fr, es) — from the theme when it carries it.
String uiLanguage(BuildContext context) =>
    Theme.of(context).extension<PaletteTheme>()?.language ??
    SettingsScope.of(context).language;

/// The 15-line muṣḥaf's page colours (Update 2 §1, 6.9 contrast overrides).
class MushafPaper {
  final String id;
  final Color bg, paper, ink, line, acc, frame, soft, hl, hl2, chrome, sub;

  /// Inside the Classic page border, and what the Classic ornaments are
  /// filled with (Update 9: the Madani and Mono papers — white within a
  /// cream or grey margin); null: the paper shows through.
  final Color? inner;
  const MushafPaper(this.id, this.bg, this.paper, this.ink, this.line, this.acc,
      this.frame, this.soft, this.hl, this.hl2, this.chrome, this.sub,
      {this.inner});
  bool get dark => paper.computeLuminance() < .2;
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
      Color(0xFF111111), Color(0xFFE2E2E2), Color(0xFF222222),
      Color(0xFF4A4A4A), Color(0xFFF4F4F4), Color(0xFFEDEDED),
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
      Color(0xFFE6E6E6), Color(0xFF1A1A1A), Color(0xFF262626),
      Color(0xFF3A3A3A), Color(0xF7121212), Color(0xFF9A9A9A)),
  'oled_mono': MushafPaper('oled_mono', Color(0xFF000000), Color(0xFF000000),
      Color(0xFFF2F2F2), Color(0xFF1E1E1E), Color(0xFFFFFFFF),
      Color(0xFFE0E0E0), Color(0xFF0D0D0D), Color(0xFF1C1C1C),
      Color(0xFF333333), Color(0xF7000000), Color(0xFF8C8C8C)),
};

/// The muṣḥaf paper for the current settings: the light theme offers cream,
/// white, Madani or mono; night and OLED their own page or a mono one, all
/// white on the dark; the mono theme its own.
MushafPaper mushafPaperOf(AppSettings s) => switch (s.theme) {
      AppTheme.light => kMushafPapers[s.mushafPaper] ?? kMushafPapers['cream']!,
      AppTheme.mono => kMushafPapers['mono']!,
      AppTheme.night =>
        kMushafPapers[s.mushafPaperDark == 'mono' ? 'night_mono' : 'night']!,
      AppTheme.oled =>
        kMushafPapers[s.mushafPaperDark == 'mono' ? 'oled_mono' : 'oled']!,
    };

final Map<String, ThemeData> _themeCache = {};

/// The app theme for [s]. Cached per (theme, language): MaterialApp animates
/// between themes that aren't equal, and a freshly built ThemeData never is,
/// so every settings change used to run a 200 ms whole-app theme animation.
ThemeData buildTheme(AppSettings s) => _themeCache.putIfAbsent(
    '${s.theme.name}/${s.language}',
    () => _themeFrom(paletteOf(s.theme), s.language));

/// Route transition of the redesign: every route fades in (220ms ease).
class _FadeTransitions extends PageTransitionsBuilder {
  const _FadeTransitions();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
          Animation<double> animation, Animation<double> secondaryAnimation,
          Widget child) =>
      // Lite mode (or the system's "remove animations"): the new screen
      // simply appears.
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
          ? child
          : FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.ease),
              child: child);
}

SystemUiOverlayStyle overlayStyleFor(Palette p) => p.isDark
    ? SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.bg,
        systemNavigationBarIconBrightness: Brightness.light)
    : SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.bg,
        systemNavigationBarIconBrightness: Brightness.dark);

ThemeData _themeFrom(Palette p, String language) {
  final (uiFamily, uiFallback) = _uiFont(language);
  const fade = _FadeTransitions();
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: p.hover,
    hoverColor: p.hover,
    focusColor: p.hover,
    dividerColor: p.line2,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: fade,
      TargetPlatform.iOS: fade,
      TargetPlatform.linux: fade,
      TargetPlatform.macOS: fade,
      TargetPlatform.windows: fade,
      TargetPlatform.fuchsia: fade,
    }),
    colorScheme: ColorScheme(
      brightness: p.brightness,
      primary: p.accBg,
      onPrimary: Colors.white,
      secondary: p.gold,
      onSecondary: Colors.white,
      surface: p.card,
      onSurface: p.ink,
      surfaceContainerHighest: p.track,
      surfaceContainerHigh: p.track,
      surfaceContainer: p.card,
      surfaceContainerLow: p.card,
      surfaceContainerLowest: p.card,
      onSurfaceVariant: p.ink2,
      outline: p.line3,
      outlineVariant: p.line2,
      primaryContainer: p.accSoft,
      onPrimaryContainer: p.accInk,
      secondaryContainer: p.accSoft,
      onSecondaryContainer: p.accInk,
      error: p.red,
      onError: Colors.white,
    ),
  );
  final text = _withFallback(uiFallback, base.textTheme
      .apply(fontFamily: uiFamily, bodyColor: p.ink, displayColor: p.ink));
  TextStyle ui(double size, FontWeight w, Color c) => TextStyle(
      fontFamily: uiFamily,
      fontFamilyFallback: uiFallback,
      fontSize: size,
      fontWeight: w,
      color: c);
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
  return base.copyWith(
    extensions: [PaletteTheme(p, language)],
    textTheme: text,
    iconTheme: IconThemeData(color: p.ink2),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: overlayStyleFor(p),
      toolbarHeight: 64,
      leadingWidth: 64,
      titleSpacing: 4,
      titleTextStyle: ui(17, FontWeight.w700, p.ink),
    ),
    // Every pushed screen's back button is the redesign's 40px round button.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: p.card,
          shape: BoxShape.circle,
          border: Border.all(color: p.line),
        ),
        child: Icon(QiraahIcons.back, size: 20, color: p.ink2),
      ),
      closeButtonIconBuilder: (context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: p.card,
          shape: BoxShape.circle,
          border: Border.all(color: p.line),
        ),
        child: Icon(QiraahIcons.close, size: 20, color: p.ink2),
      ),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.line2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accBg,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        shape: pill,
        textStyle: ui(15, FontWeight.w700, Colors.white),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accBg,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(44, 44),
        shape: pill,
        textStyle: ui(15, FontWeight.w700, Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        side: BorderSide(color: p.line3),
        minimumSize: const Size(44, 44),
        shape: pill,
        textStyle: ui(15, FontWeight.w700, p.ink),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.acc,
        minimumSize: const Size(44, 44),
        textStyle: ui(14, FontWeight.w700, p.acc),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.ink2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((st) =>
            st.contains(WidgetState.selected) ? p.segOn : p.track),
        foregroundColor: WidgetStateProperty.resolveWith((st) =>
            st.contains(WidgetState.selected) ? p.ink : p.ink2),
        side: WidgetStatePropertyAll(BorderSide(color: p.track)),
        textStyle: WidgetStatePropertyAll(ui(14, FontWeight.w700, p.ink)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12))),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.card,
      selectedColor: p.accSoft,
      side: BorderSide(color: p.line3),
      labelStyle: ui(13, FontWeight.w600, p.ink),
      secondaryLabelStyle: ui(13, FontWeight.w700, p.accInk),
      checkmarkColor: p.accInk,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      hintStyle: ui(14, FontWeight.w500, p.ink3),
      prefixIconColor: p.ink3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.acc, width: 1.5)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.acc,
      thumbColor: p.acc,
      inactiveTrackColor: p.line3,
      overlayColor: p.acc.withValues(alpha: .12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? p.accBg : p.line3),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((st) =>
          st.contains(WidgetState.selected) ? p.accBg : Colors.transparent),
      side: BorderSide(color: p.line3, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((st) =>
          st.contains(WidgetState.selected) ? p.acc : p.line3),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.acc,
      linearTrackColor: p.line2,
      circularTrackColor: p.line2,
    ),
    dividerTheme: DividerThemeData(color: p.line2, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: p.ink2,
      textColor: p.ink,
      titleTextStyle: ui(15, FontWeight.w700, p.ink),
      subtitleTextStyle: ui(12.5, FontWeight.w500, p.ink3),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: p.ink3,
      collapsedIconColor: p.ink3,
      textColor: p.ink,
      collapsedTextColor: p.ink,
      shape: const Border(),
      collapsedShape: const Border(),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.card,
      dragHandleColor: p.line3,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: ui(18, FontWeight.w700, p.ink),
      contentTextStyle: ui(14, FontWeight.w500, p.ink2),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.line2)),
      textStyle: ui(14, FontWeight.w600, p.ink),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
          color: p.isDark ? p.segOn : p.ink,
          borderRadius: BorderRadius.circular(8)),
      textStyle: ui(12, FontWeight.w600, p.isDark ? p.ink : p.card),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(p.line3),
      radius: const Radius.circular(8),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.isDark ? p.segOn : p.ink,
      contentTextStyle: ui(14, FontWeight.w600, p.isDark ? p.ink : p.card),
      actionTextColor: p.isDark ? p.accInk : p.accSoft,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.ink,
      unselectedLabelColor: p.ink3,
      indicatorColor: p.acc,
      dividerColor: p.line2,
      labelStyle: ui(14, FontWeight.w700, p.ink),
      unselectedLabelStyle: ui(14, FontWeight.w600, p.ink3),
    ),
  );
}

/// UI-chrome font per active language: Inter for the Latin
/// languages (en/fr/es), Noto Naskh Arabic for Arabic, and Noto Nastaliq Urdu
/// for Urdu (Urdu reads as Nastaliq, not the Naskh style Arabic uses).
(String, List<String>) _uiFont(String lang) => switch (lang) {
      'ar' => ('NotoNaskhArabic', const ['Inter']),
      'ur' => ('NotoNastaliqUrdu',
          const ['NotoNaskhArabic', 'Inter']),
      _ => ('Inter', const ['NotoNaskhArabic']),
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
/// word spacing): Noto Naskh Arabic, the redesign's letter face. Defaults to
/// the palette ink.
TextStyle arabicStyle(
  BuildContext context, {
  double size = 34,
  Color? color,
  FontWeight weight = FontWeight.w500,
  double height = 1.95,
}) {
  final s = SettingsScope.of(context);
  return TextStyle(
    fontFamily: 'NotoNaskhArabic',
    fontFamilyFallback: const ['ScheherazadeNew'],
    fontSize: size * s.arabicScale,
    height: height,
    fontWeight: weight,
    letterSpacing: s.letterTracking,
    wordSpacing: s.wordSpacing,
    color: color ?? pal(context).ink,
  );
}

/// Qur'anic text style — UthmanicHafs (KFGQPC Ḥafṣ), the same face the
/// reader uses. Any Arabic that's an actual Qur'anic quote (verses, example
/// words, quiz prompts drawn from the muṣḥaf) should use this, never
/// [arabicStyle], which is for letters and prose.
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
    color: color ?? pal(context).ink,
  );
}

/// Text color for containers that switch to the warm "paper" background.
Color readingInk(BuildContext context) {
  final s = SettingsScope.of(context);
  return s.paperMode ? pal(context).paperInk : pal(context).ink;
}

/// UI text: Inter (or the language's own face).
TextStyle uiStyle(
  BuildContext context, {
  double size = 15,
  Color? color,
  FontWeight weight = FontWeight.w500,
  double? height,
  double? letterSpacing,
}) {
  final (family, fallback) = _uiFont(uiLanguage(context));
  return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? pal(context).ink);
}

/// Display headings: Source Serif 4 for the Latin languages. Arabic and Urdu have
/// no Source Serif 4, so they take their own UI face at a heavier weight and a
/// slightly smaller size, which keeps the hierarchy of a serif heading.
TextStyle displayStyle(
  BuildContext context, {
  double size = 30,
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.12,
  FontStyle? fontStyle,
}) {
  final lang = uiLanguage(context);
  final c = color ?? pal(context).ink;
  return switch (lang) {
    'ar' => TextStyle(
        fontFamily: 'NotoNaskhArabic',
        fontSize: size * .88,
        fontWeight: FontWeight.w700,
        height: 1.5,
        color: c),
    'ur' => TextStyle(
        fontFamily: 'NotoNastaliqUrdu',
        fontFamilyFallback: const ['NotoNaskhArabic'],
        fontSize: size * .8,
        fontWeight: FontWeight.w600,
        height: 1.9,
        color: c),
    _ => TextStyle(
        fontFamily: 'SourceSerif4',
        fontFamilyFallback: const ['NotoNaskhArabic'],
        fontSize: size,
        fontWeight: weight,
        fontStyle: fontStyle,
        height: height,
        letterSpacing: -.2,
        color: c),
  };
}

/// Section label: 12/700, wide letter-spacing, uppercase, `mut`.
TextStyle labelStyle(BuildContext context, {Color? color, double size = 12}) =>
    uiStyle(context,
        size: size,
        weight: FontWeight.w700,
        letterSpacing: switch (uiLanguage(context)) {
          'en' || 'fr' || 'es' => 1.0,
          _ => 0,
        },
        color: color ?? pal(context).mut);
