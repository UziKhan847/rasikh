import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mushaf.dart' show MushafLook;
import '../ui/ornaments/tuning.dart';
import 'mushaf_style.dart';
import 'marks/marks_store.dart';
import 'theme.dart' show AppTheme, appThemeFrom;


/// The card reader's Indo-Pak script renders with DigitalKhattIndoPak.otf —
/// the same face the 15-line muṣḥaf uses (see CREDITS.md) — via a 1:1
/// codepoint transcode in `QuranRepo._transcodeIndopak` that aligns the
/// reader's text convention with the font's. PDMS Saleem is not involved and
/// was never shipped for the reader.
const bool kIndopakReaderAvailable = true;

/// The 15-line muṣḥaf's Indo-Pak script uses the same DigitalKhattIndoPak.otf
/// face (see CREDITS.md).
const bool kIndopakMushafAvailable = true;

/// The Nabr (Qurʾānic stress) module, after *Ṣawn al-Lisān ʿan al-Laḥn fī
/// al-Qurʾān*: hidden until the Shaykh has reviewed it and permission is
/// confirmed (tool/nabr/README.md). Reviewers turn on [AppSettings.nabrPreview]
/// (a long press on the āyah at the end of About).
const bool kNabrEnabled = false;

/// The muṣḥaf's look can be customised (Muṣḥaf style: frames, headers,
/// papers, ornaments, tuning). Off for now: every page is the one minimal
/// look (see [AppSettings.mushafLook]) — the styles and their code are kept.
const bool kMushafCustomization = false;

/// How the app is used on this device — chosen at first launch, changed in
/// Settings — and so what it opens to (see screens/shell/app_shell.dart):
/// - [hifz]: the muṣḥaf, minimal, for memorising and revising;
/// - [reader]: the reader, to read fluently (the 15-line muṣḥaf a tap away);
/// - [learn]: the learning modules (Qāʿidah, Tajwīd…);
/// - [write]: the tracing studio.
enum AppMode { hifz, reader, learn, write }

/// The marks server a build ships with (see AppSettings.syncServer).
const String kDefaultSyncServer = String.fromEnvironment('QIRAAH_SYNC_URL');

/// Reader & accessibility settings. The dyslexia-friendly options are real
/// interventions, not decoration:
///  * arabicScale       — larger glyphs reduce crowding
///  * letterTracking    — opt-in spacing between joined glyphs ("uncrowding")
///  * wordSpacing       — extra gaps between words
///  * paperMode         — warm low-contrast background (visual stress relief)
///  * dotEmphasis       — drills tint/badge the i'jam dots so ب/ت/ث differ
///  * focusWindow       — fluency drills show one word at a time
class AppSettings extends ChangeNotifier {
  bool dyslexiaMode = false;
  double arabicScale = 1.0; // 0.8 – 1.8
  double letterTracking = 0.0; // 0 – 10 logical px between glyphs
  double wordSpacing = 0.0; // 0 – 24
  bool paperMode = false;
  bool dotEmphasis = true;
  bool focusWindow = true;
  bool haptics = true;
  /// The app-wide theme: 'light' | 'mono' | 'night' | 'oled'.
  String appTheme = 'light';
  AppTheme get theme => appThemeFrom(appTheme);

  /// Each script's muṣḥaf look (ornaments, border, margin, running head,
  /// paper and tuning), as its printed muṣḥaf has its own.
  final Map<String, MushafStyle> mushafStyles = {
    'uthmani': MushafStyle.defaultsFor('uthmani'),
    'indopak': MushafStyle.defaultsFor('indopak'),
  };
  MushafStyle styleFor(String script) =>
      mushafStyles[script == 'indopak' ? 'indopak' : 'uthmani']!;

  /// The muṣḥaf script's own look ([styleFor] [mushafScript]): its page
  /// colours in the light theme ('cream' | 'white' | 'madani' | 'mono' |
  /// 'tile1'…'tile3'; the other themes have their own paper) and its
  /// ornaments, below.
  MushafStyle get _style => styleFor(mushafScript);
  String get mushafPaper => _style.paper;
  set mushafPaper(String v) => _style.paper = v;

  /// The muṣḥaf script's ornament colour, apart from its paper (see
  /// MushafStyle.ornament); in every theme but mono.
  String get mushafOrnament => _style.ornament;
  set mushafOrnament(String v) => _style.ornament = v;

  /// The night and OLED themes' muṣḥaf page: 'default' (theirs) or 'mono'
  /// (everything on it white).
  String mushafPaperDark = 'default';

  /// The muṣḥaf script's ornaments, each chosen on its own (see
  /// MushafStyle): sūrah header, āyah marker, page border, margin, and the
  /// tuning panel's overrides.
  String get orHeader => _style.header;
  set orHeader(String v) => _style.header = v;
  String get orMarker => _style.marker;
  set orMarker(String v) => _style.marker = v;
  String get orBorder => _style.border;
  set orBorder(String v) => _style.border = v;
  String get orMargin => _style.margin;
  set orMargin(String v) => _style.margin = v;
  Map<String, double> get orTune => _style.tune;
  set orTune(Map<String, double> v) => _style.tune = v;
  OrnamentTuning get ornamentTuning => _style.tuning;

  /// The slight gradients on hero cards, primary buttons and backgrounds.
  bool gradients = true;

  /// Lite mode, for slow devices: no animations (page fades, entrances,
  /// the tracing pulse), no blurred shadows, no gradients or ornaments, and
  /// the muṣḥaf drawn from its smaller glyph sheets. What the reader needs —
  /// recitation highlights, tajwīd colours, marks — is unchanged.
  bool lite = false;

  /// Memorize as verse cards: the āyah's font size (they're for large text).
  double memorizeCardFont = 36;

  /// Review as verse cards: the āyah's font size.
  double reviewCardFont = 30;

  /// Review as verse cards: under the card, the marked word large, with
  /// its comment and replies.
  bool reviewCardWord = true;

  /// Memorize: what a tap does — 'play' (a revealed word plays; revealing is
  /// done from the bar), 'word' or 'verse' (the screen's left half reveals
  /// the next word or āyah, its right half goes back), 'split' (the same,
  /// words in the top half and āyāt in the bottom), or 'pad' (one hand: a
  /// small thumb pad in a bottom corner does all four; taps on the page
  /// play, as with 'play').
  String memorizeTap = 'play';
  bool get memorizeTapReveals =>
      memorizeTap != 'play' && memorizeTap != 'pad';
  bool get memorizePad => memorizeTap == 'pad';

  /// The thumb pad's corner ('right' or 'left') and whether its guide (the
  /// zones' outlines and arrows) shows; hidden, the zones still work.
  String memorizePadSide = 'right';
  bool memorizePadGuide = true;

  /// Focus mode: the muṣḥaf and memorize, bare — just the page (no bars,
  /// running head or frame; the system bars hidden too), and memorize with
  /// only its essential controls. A tap still brings the muṣḥaf's bars back.
  bool focusMode = false;

  /// Light → dark (night) → OLED → light: the app's brightness, the muṣḥaf
  /// on its plain page for each (call inside [update]).
  void cycleBrightness() {
    appTheme = switch (appTheme) {
      'light' || 'mono' => 'night',
      'night' => 'oled',
      _ => 'light',
    };
    mushafPaperDark = 'default';
  }

  /// Shows the Nabr module before [kNabrEnabled], for its reviewers.
  bool nabrPreview = false;
  bool get nabrShown => kNabrEnabled || nabrPreview;

  /// The muṣḥaf's running head, focus mode applied.
  bool get mushafHeaderShown =>
      mushafHeader && !focusMode && !styleFor(mushafScript).edge;

  /// The muṣḥaf's look for [script]: the ornaments as chosen, Lite mode
  /// applied (plain headers and markers, artwork borders as a line, the
  /// juzʼ as text) and — with [focus] — focus mode's bare page.
  MushafLook mushafLook(String script, {bool focus = true}) {
    if (focus && focusMode) return MushafLook(script: script);
    if (!kMushafCustomization) {
      // The one look: edge to edge, no frame or margins, the script's own
      // sūrah headers and āyah markers (plain ones in Lite mode).
      return MushafLook.resolve(script,
          header: lite ? 'plain' : 'auto',
          marker: lite ? 'font' : 'auto',
          border: 'none',
          margin: 'none',
          head: 'inside',
          edge: true);
    }
    final st = styleFor(script);
    return MushafLook.resolve(
      script,
      header: lite ? 'plain' : st.header,
      marker: lite ? 'font' : st.marker,
      border: lite && !const ['none', 'line', 'double'].contains(st.border)
          ? 'line'
          : st.border,
      margin: lite && st.margin != 'none' ? 'text' : st.margin,
      head: st.head,
      edgeTop: st.edgeTop,
      edgeRuku: st.edgeRuku,
      edgeBottom: st.edgeBottom,
      edge: st.edge,
      tune: st.tuning,
    );
  }

  /// The one-time "this device seems slow — turn on Lite mode?" offer has
  /// been made (see core/jank_watch.dart).
  bool liteSuggested = false;

  /// What to draw, Lite mode applied: read these, not [gradients],
  /// [orHeader], [orMarker].
  bool get useGradients => gradients && !lite;
  String get headerStyle => lite ? 'plain' : orHeader;
  String get markerStyle => lite ? 'font' : orMarker;

  /// Any ornament at all (the reader's gold markers follow it).
  bool get useOrnate => headerStyle != 'plain' || markerStyle != 'font';

  /// The first-launch welcome has been finished or skipped.
  bool onboarded = false;

  /// [AppMode]'s name; '' until one is chosen (an install from before the
  /// modes chooses once, at its next launch).
  String appMode = '';
  AppMode? get mode {
    for (final m in AppMode.values) {
      if (m.name == appMode) return m;
    }
    return null;
  }
  String language = 'en'; // en | ar | ur | fr | es
  /// 'arabic' (Fatḥah/Ḍammah/Kasrah/Sukūn…) | 'indopak' (Zabar/Paish/Zair/Jazm…)
  /// — the tashkīl mark names shown app-wide (tashkilName() in
  /// glyph_names.dart). Defaults per-language in load(); user-overridable.
  String tashkilTerms = 'arabic';
  String quranScript = 'uthmani'; // 'uthmani' (Madani) | 'indopak' — card reader only
  String mushafScript = 'uthmani'; // 'uthmani' | 'indopak' — 15-line muṣḥaf's own, independent of quranScript
  bool mushafHeader = true; // traditional page header: sūrah · page · juzʼ
  /// Word marks (mistake / tajwīd / …) are drawn on the muṣḥaf and reader,
  /// and whether marks that have since been fixed still show (in green).
  bool showMarks = true;
  bool showFixedMarks = true;
  /// Listener name last used for a marking session (pre-fills the next one).
  String lastListener = '';
  /// Address of the self-hosted marks server (PocketBase). Empty = sync not
  /// set up; a build can preset it with --dart-define=QIRAAH_SYNC_URL=….
  String syncServer = kDefaultSyncServer;
  /// Desktop muṣḥaf view: 'spread' (two pages), 'single' (one page at 1.6×,
  /// scrolls) or 'fill' (one page as wide as the window, scrolls).
  String mushafView = 'spread';
  /// Phone muṣḥaf on its side: two facing pages instead of one page across
  /// the full width.
  bool mushafPhoneSpread = false;
  bool mushafTajwid = false; // tajwīd colours on the muṣḥaf page
  bool immersive = false; // hide system bars app-wide (edge-to-edge reading)
  double quranFontScale = 30 / 26; // reader Arabic size ÷ 26 (default 30px)
  double traceTolerance = 1.0; // 0.6 strict – 1.8 lenient (Tracing Studio guidance radius)
  double wbwGap = 10; // gap between words / segments (4–30)
  int wbwGroup = 1; // words per segment: 1–6
  bool wbwNewline = false; // each segment on its own line
  String wbwAlign = 'right'; // 'right' | 'center' — verse alignment
  bool stripTashkil = false; // hide ḥarakāt for clearer letter shapes
  bool tajwidColors = false; // tajwīd color-coding in the reader
  String desktopMode = 'auto'; // 'auto'|'on'|'off'
  /// Reader layout: the word grid (true) or flowing āyah cards (false).
  bool wordByWord = false;
  bool readerHeaderCollapsed = false; // retract the reader control panel
  String fontIndopak = 'DigitalKhattIndoPak';
  String reciter = 'tunaiji'; // 'tunaiji' | 'alafasy' | 'husary'
  String readerLayout = 'cards'; // 'cards' | 'mushaf' (continuous flow)
  String reciteFlow = 'single'; // 'single' | 'auto' (continue) | 'repeat'
  /// The recitation player: 'pinned' (docked) | 'floating' (draggable card)
  /// | 'hidden' (a round restore button only).
  String playerDock = 'pinned';
  bool get playerBarPinned => playerDock != 'floating';
  set playerBarPinned(bool v) => playerDock = v ? 'pinned' : 'floating';
  bool playerMinimised = false;
  double playbackSpeed = 1.0; // 0.75 | 1 | 1.25
  bool followAlong = true; // auto-scroll to the āyah being recited

  /// Learning: the daily goal in minutes (5/10/15/20), and the local daily
  /// reminder (time of day as minutes after midnight).
  int dailyGoalMinutes = 10;
  bool reminderOn = false;
  int reminderMinutes = 20 * 60;

  /// Desktop: the sidebar is collapsed to nothing.
  bool sidebarCollapsed = false;

  static const _key = 'noor.settings.v1';

  void setTheme(String id) {
    appTheme = id;
    notifyListeners();
    save();
  }

  void enableDyslexiaPreset() {
    dyslexiaMode = true;
    arabicScale = 1.35;
    letterTracking = 0.0; // keep words joined by default; user may add
    wordSpacing = 10;
    paperMode = true;
    dotEmphasis = true;
    focusWindow = true;
    notifyListeners();
    save();
  }

  Timer? _saveDebounce;

  // UI feedback (notifyListeners) is immediate; the disk write is debounced
  // so continuous slider drags (word gap, font scale, comfort sliders) don't
  // fire a SharedPreferences write — jsonEncode + a platform-channel call —
  // on every drag delta.
  void update(VoidCallback fn) {
    fn();
    notifyListeners();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), save);
  }

  /// Cancels any pending debounced write and saves immediately — call before
  /// the app is backgrounded/closed so a very recent change isn't lost.
  Future<void> flush() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    return save();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  /// Each script's look. From before they were per script (one shared set
  /// of ornament slots, or earlier still one "ornaments" style): the new
  /// printed looks, once.
  void _loadOrnaments(Map<String, dynamic> m) {
    final saved = m['mushafStyles'];
    for (final script in const ['uthmani', 'indopak']) {
      final one = saved is Map ? saved[script] : null;
      mushafStyles[script] = one is Map
          ? MushafStyle.fromJson(script, one.cast<String, dynamic>())
          : MushafStyle.defaultsFor(script);
    }
    // The Madani default was its printed look (all "auto" on the Madani
    // paper); it's now cream, and "auto" the new default.
    final u = mushafStyles['uthmani']!;
    if (u.paper == 'madani' &&
        [u.header, u.marker, u.border, u.margin, u.head]
            .every((v) => v == 'auto')) {
      u.paper = 'cream';
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    dyslexiaMode = m['dys'] ?? false;
    arabicScale = (m['scale'] ?? 1.0).toDouble();
    letterTracking = (m['track'] ?? 0.0).toDouble();
    wordSpacing = (m['word'] ?? 0.0).toDouble();
    paperMode = m['paper'] ?? false;
    dotEmphasis = m['dots'] ?? true;
    focusWindow = m['focus'] ?? true;
    haptics = m['haptics'] ?? true;
    // The redesign's four themes; before it, a light/dark/oled mode across
    // two colour families.
    appTheme = m['theme'] as String? ??
        switch (m['mode']) { 'dark' => 'night', 'oled' => 'oled', _ => 'light' };
    mushafPaperDark = m['mushafPaperDark'] as String? ?? 'default';
    _loadOrnaments(m);
    gradients = m['gradients'] ?? true;
    lite = m['lite'] ?? false;
    memorizeCardFont = (m['memorizeCardFont'] as num?)?.toDouble() ?? 36;
    reviewCardFont = (m['reviewCardFont'] as num?)?.toDouble() ?? 30;
    reviewCardWord = m['reviewCardWord'] ?? true;
    // Before the verse option: tap-to-reveal on or off.
    memorizeTap = m['memorizeTap'] as String? ??
        (m['memorizeTapReveals'] == true ? 'word' : 'play');
    memorizePadSide = m['memorizePadSide'] as String? ?? 'right';
    memorizePadGuide = m['memorizePadGuide'] as bool? ?? true;
    focusMode = m['focusMode'] ?? false;
    nabrPreview = m['nabrPreview'] ?? false;
    liteSuggested = m['liteSuggested'] ?? false;
    // An install from before the welcome existed has already found its way.
    onboarded = m['onboarded'] ?? true;
    appMode = m['appMode'] as String? ?? '';
    language = m['lang'] ?? 'en';
    // Urdu Qaidah teaching conventionally uses Zabar/Zair/Paish/Jazm, not
    // the Arabic mark names — default accordingly, but stay overridable.
    tashkilTerms = m['tashkilTerms'] ?? (language == 'ur' ? 'indopak' : 'arabic');
    wbwGap = (m['wbwGap'] ?? 10.0).toDouble();
    wbwGroup = (m['wbwGroup'] ?? 1) as int;
    wbwNewline = m['wbwNl'] ?? false;
    wbwAlign = m['wbwAlign'] ?? 'right';
    stripTashkil = m['strip'] ?? false;
    tajwidColors = m['tajwid'] ?? false;
    desktopMode = m['desktop'] ?? 'auto';
    // 'wbw' once meant "tappable words", which every layout now has; the
    // word grid is a layout of its own, off unless chosen.
    wordByWord = m['wbwGrid'] ?? false;
    readerHeaderCollapsed = m['hdrCol'] ?? false;
    fontIndopak = m['fontI'] ?? 'DigitalKhattIndoPak';
    // Anyone persisted on a removed/placeholder Indo-Pak face (the bundled
    // IndoPak.ttf or PDMS Saleem, both gone; or UthmanicHafs, the fallback
    // used while the reader's Indo-Pak was gated) gets migrated onto the
    // real face now that it's bundled and the gate is lifted.
    if (fontIndopak == 'IndoPak' ||
        fontIndopak == 'PDMSSaleem' ||
        fontIndopak == 'UthmanicHafs') {
      fontIndopak = 'DigitalKhattIndoPak';
    }
    quranScript = m['script'] ?? 'uthmani';
    if (!kIndopakReaderAvailable && quranScript == 'indopak') quranScript = 'uthmani';
    mushafScript = m['mushafScript'] ?? 'uthmani';
    if (!kIndopakMushafAvailable && mushafScript == 'indopak') mushafScript = 'uthmani';
    mushafHeader = m['mushafHeader'] ?? true;
    showMarks = m['showMarks'] ?? true;
    showFixedMarks = m['showFixedMarks'] ?? true;
    lastListener = m['lastListener'] ?? '';
    syncServer = m['syncServer'] ?? kDefaultSyncServer;
    mushafView = m['mushafView'] ??
        ((m['mushafFillW'] ?? false) == true ? 'fill' : 'spread');
    immersive = m['immersive'] ?? false;
    mushafPhoneSpread = m['mushafPhoneSpread'] ?? false;
    mushafTajwid = m['mushafTajwid'] ?? false;
    reciter = m['reciter'] ?? 'tunaiji';
    readerLayout = m['readerLayout'] ?? 'cards';
    reciteFlow = m['reciteFlow'] ?? 'single';
    quranFontScale = (m['qfont'] ?? 30 / 26).toDouble();
    traceTolerance = (m['traceTol'] ?? 1.0).toDouble();
    playerDock = m['playerDock'] as String? ??
        ((m['playerPinned'] ?? true) ? 'pinned' : 'floating');
    playerMinimised = m['playerMin'] ?? false;
    playbackSpeed = ((m['speed'] ?? 1.0) as num).toDouble();
    followAlong = m['follow'] ?? true;
    dailyGoalMinutes = (m['goalMin'] ?? 10) as int;
    reminderOn = m['remind'] ?? false;
    reminderMinutes = (m['remindAt'] ?? 20 * 60) as int;
    sidebarCollapsed = m['sideMin'] ?? false;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode({
        'dys': dyslexiaMode,
        'scale': arabicScale,
        'track': letterTracking,
        'word': wordSpacing,
        'paper': paperMode,
        'dots': dotEmphasis,
        'focus': focusWindow,
        'haptics': haptics,
        'theme': appTheme,
        'mushafPaperDark': mushafPaperDark,
        'mushafStyles': {
          for (final e in mushafStyles.entries) e.key: e.value.toJson(),
        },
        'gradients': gradients,
        'lite': lite,
        'memorizeCardFont': memorizeCardFont,
        'reviewCardFont': reviewCardFont,
        'reviewCardWord': reviewCardWord,
        'memorizeTap': memorizeTap,
        'memorizePadSide': memorizePadSide,
        'memorizePadGuide': memorizePadGuide,
        'focusMode': focusMode,
        'nabrPreview': nabrPreview,
        'liteSuggested': liteSuggested,
        'onboarded': onboarded,
        'appMode': appMode,
        'lang': language,
        'tashkilTerms': tashkilTerms,
        'wbwGap': wbwGap,
        'wbwGroup': wbwGroup,
        'wbwNl': wbwNewline,
        'wbwAlign': wbwAlign,
        'hdrCol': readerHeaderCollapsed,
        'strip': stripTashkil,
        'tajwid': tajwidColors,
        'desktop': desktopMode,
        'wbwGrid': wordByWord,
        'fontI': fontIndopak,
        'script': quranScript,
        'mushafScript': mushafScript,
        'mushafHeader': mushafHeader,
        'showMarks': showMarks,
        'showFixedMarks': showFixedMarks,
        'lastListener': lastListener,
        'syncServer': syncServer,
        'mushafView': mushafView,
        'immersive': immersive,
        'mushafPhoneSpread': mushafPhoneSpread,
        'mushafTajwid': mushafTajwid,
        'qfont': quranFontScale,
        'traceTol': traceTolerance,
        'reciter': reciter,
        'readerLayout': readerLayout,
        'reciteFlow': reciteFlow,
        'playerDock': playerDock,
        'playerMin': playerMinimised,
        'speed': playbackSpeed,
        'follow': followAlong,
        'goalMin': dailyGoalMinutes,
        'remind': reminderOn,
        'remindAt': reminderMinutes,
        'sideMin': sidebarCollapsed,
      }),
    );
  }
}

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);
  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
  static AppSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}

/// Stars-per-activity progress, persisted as JSON.
/// One card in the spaced-repetition review queue (Leitner boxes). A wrong
/// answer resets it to box 0 (due now); each correct review promotes it to a
/// longer interval; a correct answer past the last box graduates it out.
/// [distractors] preserves the other options the learner saw, so the review
/// re-asks an equally plausible question rather than an easier one.
///
/// Keyed by [id] — a stable identifier from the underlying data (e.g.
/// `'tashkil.shadda'`, `'letter.ب'`), NOT by [arabic]. Text-data fixes (e.g.
/// correcting Imlāʾī spelling to Uthmani) change what a card *displays*
/// without orphaning its Leitner progress, since the key never changes.
/// Cards saved before this split have no stable id — they load with
/// `id == arabic` (their old map key) and simply age out of the queue
/// naturally rather than being force-migrated onto a new id.
class ReviewItem {
  final String id; // stable queue key
  final String arabic; // display text (glyph/word) — may change across edits
  String prompt;
  String answer;
  List<String> distractors;
  bool optionsArabic;
  int box;
  int due; // epoch-day this becomes due
  int lapses;
  int reps;
  int lastSeen;

  ReviewItem({
    required this.id,
    required this.arabic,
    required this.prompt,
    required this.answer,
    required this.distractors,
    required this.optionsArabic,
    required this.box,
    required this.due,
    required this.lapses,
    required this.reps,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'g': arabic,
        'q': prompt,
        'a': answer,
        'd': distractors,
        'ar': optionsArabic,
        'b': box,
        'due': due,
        'l': lapses,
        'r': reps,
        's': lastSeen,
      };

  static ReviewItem fromJson(String id, Map<String, dynamic> m) => ReviewItem(
        id: id,
        arabic: (m['g'] ?? id) as String,
        prompt: (m['q'] ?? 'You missed this before — what is it?') as String,
        answer: (m['a'] ?? '') as String,
        distractors:
            ((m['d'] as List?)?.map((e) => e.toString()).toList()) ?? const [],
        optionsArabic: (m['ar'] ?? false) as bool,
        box: (m['b'] ?? 0) as int,
        due: (m['due'] ?? 0) as int,
        lapses: (m['l'] ?? 1) as int,
        reps: (m['r'] ?? 0) as int,
        lastSeen: (m['s'] ?? 0) as int,
      );
}

/// A lesson left halfway: built from [seed] (the same questions again), at
/// [step] of [total], with the options picked so far, by step.
class LessonPlace {
  final int seed, step, total;
  final Map<int, int> picks;
  const LessonPlace({required this.seed, required this.step, required this.total, this.picks = const {}});

  factory LessonPlace.fromJson(Map<String, dynamic> j) => LessonPlace(
        seed: j['seed'] as int,
        step: j['step'] as int,
        total: j['total'] as int,
        picks: {
          for (final e in ((j['picks'] ?? const {}) as Map).entries)
            int.parse(e.key as String): e.value as int,
        },
      );

  Map<String, dynamic> toJson() => {
        'seed': seed,
        'step': step,
        'total': total,
        'picks': {for (final e in picks.entries) '${e.key}': e.value},
      };
}

class ProgressStore extends ChangeNotifier {
  final Map<String, int> _stars = {};
  static const _keyBase = 'noor.progress.v1';
  static const _streakKeyBase = 'noor.streak.v1';
  static const _reviewKeyBase = 'noor.review.v1';

  static const _readingKeyBase = 'noor.reading.v1';
  static const _lessonsKeyBase = 'noor.lessons.v1';

  /// The active profile's keys (see core/profiles.dart): the default
  /// profile's are the plain keys, so data from before profiles is its.
  static String profileSuffix = '';
  static String get _key => '$_keyBase$profileSuffix';
  static String get _streakKey => '$_streakKeyBase$profileSuffix';
  static String get _reviewKey => '$_reviewKeyBase$profileSuffix';
  static String get _readingKey => '$_readingKeyBase$profileSuffix';
  static String get _lessonsKey => '$_lessonsKeyBase$profileSuffix';

  // ── lessons left halfway ──

  final Map<String, LessonPlace> _lessons = {};

  /// Where lesson [id] was left (null: not started, or finished).
  LessonPlace? lessonPlace(String id) => _lessons[id];

  /// Notes where lesson [id] is: built from [seed] (so it's the same lesson
  /// again), at [step] of [total], with these answers.
  void saveLessonPlace(String id, LessonPlace place) {
    _lessons[id] = place;
    notifyListeners(); // the lesson's card shows where it was left
    _saveLessons();
  }

  /// Lesson [id] finished (or started over): no place to come back to.
  void clearLessonPlace(String id) {
    if (_lessons.remove(id) != null) {
      notifyListeners();
      _saveLessons();
    }
  }

  Future<void> _saveLessons() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_lessonsKey,
        jsonEncode({for (final e in _lessons.entries) e.key: e.value.toJson()}));
  }

  void _loadLessons(SharedPreferences p) {
    _lessons.clear();
    final raw = p.getString(_lessonsKey);
    if (raw == null) return;
    try {
      (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
        _lessons[k] = LessonPlace.fromJson((v as Map).cast<String, dynamic>());
      });
    } catch (_) {}
  }

  /// Every key a profile with [suffix] keeps its progress under.
  static List<String> keysOf(String suffix) => [
        for (final k in [_keyBase, _streakKeyBase, _reviewKeyBase, _readingKeyBase, _lessonsKeyBase])
          '$k$suffix',
      ];

  /// The last muṣḥaf page of the profile with [suffix], without loading it.
  static int? peekPage(SharedPreferences p, String suffix) {
    final raw = p.getString('$_readingKeyBase$suffix');
    if (raw == null) return null;
    try {
      return ((jsonDecode(raw) as Map)['page'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Another profile's progress: everything here forgotten, then its keys
  /// loaded (load() alone adds to what's here).
  Future<void> reload() async {
    _stars.clear();
    review.clear();
    streakDays = 0;
    _lastDay = -1;
    _weekStartDay = -1;
    weekMask = 0;
    lastRead = null;
    lastMushafPage = null;
    lastMushafScript = null;
    bookmarks.clear();
    secondsToday = 0;
    _secondsDay = -1;
    _lessons.clear();
    await load();
    readingSignal.value++;
    notifyListeners();
  }

  // ── reading: last read, bookmarks, and today's minutes ──

  /// The last āyah opened in the reader (sūrah, āyah), or null.
  (int, int)? lastRead;

  /// The last muṣḥaf page opened (1-based), or null, and the script whose
  /// page numbers it's in (the two scripts paginate differently).
  int? lastMushafPage;
  String? lastMushafScript;

  /// Bookmarked āyāt, newest first.
  final List<(int, int)> bookmarks = [];

  /// Fires when the last āyah read or the bookmarks change — and only
  /// then: what shows them listens to this, not to every star and second.
  final readingSignal = ValueNotifier<int>(0);

  /// Seconds spent reading or learning today, for the daily goal.
  int secondsToday = 0;
  int _secondsDay = -1;

  int get minutesToday => _secondsDay == _today() ? secondsToday ~/ 60 : 0;

  void setLastRead(int surah, int ayah) {
    if (lastRead == (surah, ayah)) return;
    lastRead = (surah, ayah);
    readingSignal.value++;
    notifyListeners();
    _saveReading();
  }

  void setLastMushafPage(int page, String script) {
    if (lastMushafPage == page && lastMushafScript == script) return;
    lastMushafPage = page;
    lastMushafScript = script;
    // No notifyListeners(): nothing shows this, it's only read when the
    // muṣḥaf reopens — and notifying mid-swipe rebuilt every screen that
    // listens to progress (Today, Learn… hidden under the muṣḥaf).
    _saveReading();
  }

  bool isBookmarked(int surah, int ayah) => bookmarks.contains((surah, ayah));

  void toggleBookmark(int surah, int ayah) {
    if (!bookmarks.remove((surah, ayah))) bookmarks.insert(0, (surah, ayah));
    readingSignal.value++;
    notifyListeners();
    _saveReading();
  }

  /// Adds [seconds] of reading or learning time to today's total.
  void addTime(int seconds) {
    if (seconds <= 0) return;
    final t = _today();
    if (_secondsDay != t) {
      _secondsDay = t;
      secondsToday = 0;
    }
    final before = minutesToday;
    secondsToday += seconds;
    if (minutesToday != before) notifyListeners();
    _saveReading();
  }

  Future<void> _saveReading() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _readingKey,
        jsonEncode({
          'last': lastRead == null ? null : [lastRead!.$1, lastRead!.$2],
          'page': lastMushafPage,
          'pageScript': lastMushafScript,
          'marks': [
            for (final b in bookmarks) [b.$1, b.$2]
          ],
          'sec': secondsToday,
          'secDay': _secondsDay,
        }));
  }

  void _loadReading(SharedPreferences p) {
    final raw = p.getString(_readingKey);
    if (raw == null) return;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final last = m['last'] as List?;
    lastRead = last == null ? null : ((last[0] as num).toInt(), (last[1] as num).toInt());
    lastMushafPage = (m['page'] as num?)?.toInt();
    lastMushafScript = m['pageScript'] as String?;
    bookmarks
      ..clear()
      ..addAll([
        for (final b in (m['marks'] as List? ?? const []))
          ((b[0] as num).toInt(), (b[1] as num).toInt())
      ]);
    secondsToday = (m['sec'] as num?)?.toInt() ?? 0;
    _secondsDay = (m['secDay'] as num?)?.toInt() ?? -1;
  }

  // Days until an item in box i comes due again. A correct answer in the last
  // box graduates the item out of the queue entirely.
  static const _boxDays = [0, 1, 3, 7, 21];

  /// arabic glyph/word → its scheduled review card. Feeds the Reading Coach's
  /// Mistake Review as a real spaced-repetition loop, not a flat queue.
  final Map<String, ReviewItem> review = {};

  int get reviewCount => review.length;
  int get dueCount => review.values.where((r) => r.due <= _today()).length;
  bool get hasReviews => review.isNotEmpty;

  /// Whole-days until the next card comes due (0 if something is already due,
  /// null if the queue is empty).
  int? get nextReviewInDays {
    if (review.isEmpty) return null;
    final t = _today();
    var min = 1 << 30;
    for (final r in review.values) {
      final d = r.due - t;
      if (d < min) min = d;
    }
    return min < 0 ? 0 : min;
  }

  /// A review session: everything due first (hardest/oldest box first). If
  /// nothing is strictly due, the soonest cards, so a tap is never a dead end.
  List<ReviewItem> reviewSession({int max = 12}) {
    final t = _today();
    final due = review.values.where((r) => r.due <= t).toList()
      ..sort((a, b) => a.box != b.box ? a.box - b.box : a.due - b.due);
    final list = due.isNotEmpty
        ? due
        : (review.values.toList()..sort((a, b) => a.due - b.due));
    return list.take(max).toList();
  }

  /// Record a wrong answer: schedule the item for review now, resetting its
  /// Leitner box. [distractors] are the other options that were on screen.
  /// [id] is the stable queue key (from the underlying data, not the Arabic
  /// text itself); [arabic] is what to display when this card resurfaces.
  void recordMiss(String id, String arabic,
      {required String answer,
      String prompt = 'You missed this before — what is it?',
      List<String> distractors = const [],
      bool optionsArabic = false}) {
    final k = id.trim();
    final a = arabic.trim();
    if (k.isEmpty || a.isEmpty || answer.trim().isEmpty) return;
    final t = _today();
    final existing = review[k];
    review[k] = ReviewItem(
      id: k,
      arabic: a,
      prompt: prompt,
      answer: answer,
      distractors: distractors.where((d) => d != answer).toSet().toList(),
      optionsArabic: optionsArabic,
      box: 0,
      due: t,
      lapses: (existing?.lapses ?? 0) + 1,
      reps: existing?.reps ?? 0,
      lastSeen: t,
    );
    while (review.length > 60) {
      // Drop whichever card is furthest from due (the best-learned one).
      final furthest = review.entries
          .reduce((x, y) => x.value.due >= y.value.due ? x : y)
          .key;
      if (furthest == k) break;
      review.remove(furthest);
    }
    _saveReview();
    notifyListeners();
  }

  /// Record a correct answer anywhere: promote the card one Leitner box and
  /// push its next review out; a correct answer past the last box graduates it.
  void reviewCorrect(String id) {
    final k = id.trim();
    final item = review[k];
    if (item == null) return;
    final t = _today();
    final next = item.box + 1;
    if (next >= _boxDays.length) {
      review.remove(k); // graduated — learned
    } else {
      item.box = next;
      item.due = t + _boxDays[next];
      item.reps += 1;
      item.lastSeen = t;
    }
    _saveReview();
    notifyListeners();
  }

  void clearReview(String id) {
    if (review.remove(id.trim()) != null) {
      _saveReview();
      notifyListeners();
    }
  }

  /// Re-notify listeners after an external restore rewrote the stores.
  void announce() => notifyListeners();

  Future<void> _saveReview() async {
    final p = await SharedPreferences.getInstance();
    final m = {for (final e in review.entries) e.key: e.value.toJson()};
    await p.setString(_reviewKey, jsonEncode(m));
  }

  // Daily streak + this-week activity (7-bit mask, Mon..Sun).
  int streakDays = 0;
  int _lastDay = -1; // epoch-day index of last active day
  int _weekStartDay = -1; // epoch-day index of the Monday of the tracked week
  int weekMask = 0; // bit i set => active on weekday i (0=Mon)

  /// Test seam for setting the last-active day without waiting on the real
  /// clock — [_lastDay] is otherwise only ever reached through real activity
  /// or a `load()` round-trip. Mirrors [dayIndexFor]'s own
  /// `@visibleForTesting` exception, for the same reason.
  @visibleForTesting
  set lastActiveDayForTest(int day) => _lastDay = day;

  static int _today() => dayIndexFor(DateTime.now());

  /// The calendar-day index (days since 1970-01-01) that [local] falls on
  /// in ITS OWN calendar date — i.e. anchored to local midnight, not UTC
  /// midnight. Built from [local]'s year/month/day fields via
  /// `DateTime.utc(...)` rather than converting the instant itself to UTC,
  /// so this can't be thrown off by DST (a local midnight-to-midnight span
  /// is occasionally 23h or 25h, not 24h — converting instants and
  /// dividing by a fixed 86400000ms would round some of those wrong).
  ///
  /// Previously this used `DateTime.now().toUtc()`, which anchors "today"
  /// to UTC midnight instead: the day flipped at 10am local in UTC+10 and
  /// at 4pm local in UTC−8, silently breaking the streak for any user far
  /// from Greenwich. Existing installs get one harmless one-time ±1 day
  /// nudge to review-queue due dates from the changeover — a self-healing,
  /// non-destructive side effect of switching anchors, not a real loss.
  @visibleForTesting
  static int dayIndexFor(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/
          86400000;

  // weekday of an epoch-day: 1970-01-01 (day 0) was a Thursday (=3, 0=Mon).
  static int _weekdayOf(int day) => (day + 3) % 7;

  /// True once today's first activity has been recorded.
  bool get activeToday => _lastDay == _today();

  /// Record that the user did something today (call from lessons/quizzes).
  void recordActivity() {
    final t = _today();
    if (_lastDay == t) return; // already counted today
    if (_lastDay == t - 1) {
      streakDays++;
    } else {
      streakDays = 1;
    }
    _lastDay = t;
    final monday = t - _weekdayOf(t);
    if (_weekStartDay != monday) {
      _weekStartDay = monday;
      weekMask = 0;
    }
    weekMask |= 1 << _weekdayOf(t);
    notifyListeners();
    _saveStreak();
  }

  /// Keep streak/week display honest if the app is opened days later.
  void refreshStreak() {
    final t = _today();
    if (_lastDay >= 0 && t - _lastDay > 1) {
      streakDays = 0;
    }
    final monday = t - _weekdayOf(t);
    if (_weekStartDay != monday) {
      _weekStartDay = monday;
      weekMask = 0;
    }
    notifyListeners();
  }

  int get todayWeekday => _weekdayOf(_today()); // 0=Mon
  bool weekdayActive(int mon0) => (weekMask & (1 << mon0)) != 0;

  int get weekGoal => 5;
  int get weekDoneCount => weekMask.toRadixString(2).replaceAll('0', '').length;

  int starsFor(String id) => _stars[id] ?? 0;
  int get totalStars => _stars.values.fold(0, (a, b) => a + b);
  int get activitiesDone => _stars.values.where((s) => s > 0).length;
  int get lettersLearned =>
      _stars.keys.where((k) => k.startsWith('letter.')).length;

  /// Fraction of ids in [ids] with at least one star.
  double fraction(Iterable<String> ids) {
    if (ids.isEmpty) return 0;
    final done = ids.where((i) => starsFor(i) > 0).length;
    return done / ids.length;
  }

  void report(String id, int stars) {
    if (stars > 0) {
      recordActivity(); // any earned progress counts toward today
    }
    if (stars > starsFor(id)) {
      _stars[id] = stars;
      notifyListeners();
      _save();
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw != null) {
      (jsonDecode(raw) as Map<String, dynamic>)
          .forEach((k, v) => _stars[k] = (v as num).toInt());
    }
    review.clear();
    final rraw = p.getString(_reviewKey);
    if (rraw != null) {
      (jsonDecode(rraw) as Map<String, dynamic>).forEach((k, v) {
        review[k] = ReviewItem.fromJson(k, Map<String, dynamic>.from(v as Map));
      });
    }
    final sraw = p.getString(_streakKey);
    if (sraw != null) {
      final m = jsonDecode(sraw) as Map<String, dynamic>;
      streakDays = (m['streak'] ?? 0) as int;
      _lastDay = (m['last'] ?? -1) as int;
      _weekStartDay = (m['wkStart'] ?? -1) as int;
      weekMask = (m['wkMask'] ?? 0) as int;
    }
    refreshStreak();
    _loadReading(p);
    _loadLessons(p);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_stars));
  }

  Future<void> _saveStreak() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _streakKey,
        jsonEncode({
          'streak': streakDays,
          'last': _lastDay,
          'wkStart': _weekStartDay,
          'wkMask': weekMask,
        }));
  }
}

class ProgressScope extends InheritedNotifier<ProgressStore> {
  const ProgressScope({super.key, required ProgressStore progress, required super.child})
      : super(notifier: progress);
  static ProgressStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProgressScope>()!.notifier!;

  static ProgressStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProgressScope>()?.notifier;

  /// The store WITHOUT subscribing: for writes (last page read, bookmarks)
  /// from widgets that shouldn't rebuild on every progress change.
  static ProgressStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ProgressScope>()!.notifier!;
}

/// One-file backup of everything the learner has earned (settings, stars,
/// streak, mistake queue) — the active profile's.
/// Written to the app documents folder so it survives reinstalls when the
/// user copies it off-device.
class BackupService {
  static const _file = 'noor_qaidah_backup.json';

  /// [marks] (the word-marks store) is included when given: its books,
  /// sessions, marks and fixes go into the same file.
  static Future<String?> export(AppSettings s, {MarksStore? marks}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final data = {
        if (marks != null && marks.ready) 'marks': marks.exportJson(),
        'settings': p.getString(AppSettings._key),
        'progress': p.getString(ProgressStore._key),
        'streak': p.getString(ProgressStore._streakKey),
        'review': p.getString(ProgressStore._reviewKey),
        'reading': p.getString(ProgressStore._readingKey),
      };
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/$_file');
      await f.writeAsString(jsonEncode(data));
      return f.path;
    } catch (_) {
      return null;
    }
  }

  /// Marks in the backup are MERGED into [marks] (never replacing what's
  /// already here: a restore can't lose marks made since the backup).
  static Future<bool> restore(AppSettings s, ProgressStore prog,
      {MarksStore? marks}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/$_file');
      if (!await f.exists()) return false;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final p = await SharedPreferences.getInstance();
      final keys = {
        AppSettings._key: 'settings',
        ProgressStore._key: 'progress',
        ProgressStore._streakKey: 'streak',
        ProgressStore._reviewKey: 'review',
        ProgressStore._readingKey: 'reading',
      };
      for (final e in keys.entries) {
        final v = m[e.value];
        if (v is String) await p.setString(e.key, v);
      }
      final mk = m['marks'];
      if (marks != null && marks.ready && mk is Map) {
        marks.importJson(mk.cast<String, dynamic>());
      }
      await s.load();
      await prog.load();
      s.update(() {});
      prog.announce();
      return true;
    } catch (_) {
      return false;
    }
  }
}
