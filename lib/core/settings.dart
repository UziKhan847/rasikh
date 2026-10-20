import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Muṣḥaf page colour in the light theme: 'cream' | 'white'. The other
  /// themes have their own paper.
  String mushafPaper = 'cream';

  /// Settings → Style → Ornaments: 'plain' | 'modern' (the drawn rosette
  /// headers) | 'classic' (the traced artwork: sūrah border, āyah circle,
  /// juzʼ lantern). Then the slight gradients on hero cards, primary buttons
  /// and backgrounds.
  String ornaments = 'classic';
  bool gradients = true;

  /// The muṣḥaf's page border (its thin frame), whatever the ornaments.
  bool mushafBorder = false;

  /// Classic: the juzʼ lantern in each page's outer margin.
  bool mushafMarginInfo = true;

  /// Lite mode, for slow devices: no animations (page fades, entrances,
  /// the tracing pulse), no blurred shadows, no gradients or ornaments, and
  /// the muṣḥaf drawn from its smaller glyph sheets. What the reader needs —
  /// recitation highlights, tajwīd colours, marks — is unchanged.
  bool lite = false;

  /// Memorize as verse cards: the āyah's font size (they're for large text).
  double memorizeCardFont = 36;

  /// Review as verse cards: the āyah's font size.
  double reviewCardFont = 30;

  /// Memorize: a tap reveals the next word (anywhere on the page or card).
  /// Off (the default), tapping a revealed word plays it, and revealing is
  /// done from the bar.
  bool memorizeTapReveals = false;

  /// Focus mode: the muṣḥaf and memorize, bare — just the page (no bars,
  /// running head or frame; the system bars hidden too), and memorize with
  /// only its essential controls. A tap still brings the muṣḥaf's bars back.
  bool focusMode = false;

  /// The muṣḥaf's ornaments, border and running head, focus mode applied.
  String get mushafOrnaments => focusMode ? 'plain' : ornamentStyle;
  bool get mushafBorderShown => mushafBorder && !focusMode;
  bool get mushafMarginShown => mushafMarginInfo && !focusMode;
  bool get mushafHeaderShown => mushafHeader && !focusMode;

  /// The one-time "this device seems slow — turn on Lite mode?" offer has
  /// been made (see core/jank_watch.dart).
  bool liteSuggested = false;

  /// What to draw, Lite mode applied: read these, not
  /// [gradients]/[ornaments].
  bool get useGradients => gradients && !lite;
  String get ornamentStyle => lite ? 'plain' : ornaments;
  bool get useOrnate => ornamentStyle != 'plain';
  bool get useClassic => ornamentStyle == 'classic';

  /// The first-launch welcome has been finished or skipped.
  bool onboarded = false;
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
    mushafPaper = m['mushafPaper'] ?? 'cream';
    // Before the three styles: an on/off "ornate borders".
    ornaments = m['ornaments'] as String? ??
        (m['ornate'] == false ? 'plain' : 'classic');
    mushafBorder = m['mushafBorder'] ?? false;
    mushafMarginInfo = m['mushafMarginInfo'] ?? true;
    gradients = m['gradients'] ?? true;
    lite = m['lite'] ?? false;
    memorizeCardFont = (m['memorizeCardFont'] as num?)?.toDouble() ?? 36;
    reviewCardFont = (m['reviewCardFont'] as num?)?.toDouble() ?? 30;
    memorizeTapReveals = m['memorizeTapReveals'] ?? false;
    focusMode = m['focusMode'] ?? false;
    liteSuggested = m['liteSuggested'] ?? false;
    // An install from before the welcome existed has already found its way.
    onboarded = m['onboarded'] ?? true;
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
        'mushafPaper': mushafPaper,
        'ornaments': ornaments,
        'mushafBorder': mushafBorder,
        'mushafMarginInfo': mushafMarginInfo,
        'gradients': gradients,
        'lite': lite,
        'memorizeCardFont': memorizeCardFont,
        'reviewCardFont': reviewCardFont,
        'memorizeTapReveals': memorizeTapReveals,
        'focusMode': focusMode,
        'liteSuggested': liteSuggested,
        'onboarded': onboarded,
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

class ProgressStore extends ChangeNotifier {
  final Map<String, int> _stars = {};
  static const _keyBase = 'noor.progress.v1';
  static const _streakKeyBase = 'noor.streak.v1';
  static const _missKey = 'noor.misses.v1'; // legacy — read once to migrate; adult-only
  static const _reviewKeyBase = 'noor.review.v1';

  static const _readingKey = 'noor.reading.v1';

  String get _key => _keyBase;
  String get _streakKey => _streakKeyBase;
  String get _reviewKey => _reviewKeyBase;

  // ── reading: last read, bookmarks, and today's minutes ──

  /// The last āyah opened in the reader (sūrah, āyah), or null.
  (int, int)? lastRead;

  /// The last muṣḥaf page opened (1-based), or null, and the script whose
  /// page numbers it's in (the two scripts paginate differently).
  int? lastMushafPage;
  String? lastMushafScript;

  /// Bookmarked āyāt, newest first.
  final List<(int, int)> bookmarks = [];

  /// Seconds spent reading or learning today, for the daily goal.
  int secondsToday = 0;
  int _secondsDay = -1;

  int get minutesToday => _secondsDay == _today() ? secondsToday ~/ 60 : 0;

  void setLastRead(int surah, int ayah) {
    if (lastRead == (surah, ayah)) return;
    lastRead = (surah, ayah);
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
    // Review queue — with a one-time migration from the old flat miss map so
    // existing learners keep everything they'd missed.
    review.clear();
    final rraw = p.getString(_reviewKey);
    if (rraw != null) {
      (jsonDecode(rraw) as Map<String, dynamic>).forEach((k, v) {
        review[k] = ReviewItem.fromJson(k, Map<String, dynamic>.from(v as Map));
      });
    } else {
      // Legacy flat-miss-map migration.
      final mraw = p.getString(_missKey);
      if (mraw != null) {
        final t = _today();
        Map<String, String>.from(jsonDecode(mraw) as Map).forEach((k, answer) {
          review[k] = ReviewItem(
            id: k,
            arabic: k,
            prompt: 'You missed this before — what is it?',
            answer: answer,
            distractors: const [],
            optionsArabic: false,
            box: 0,
            due: t,
            lapses: 1,
            reps: 0,
            lastSeen: t,
          );
        });
        if (review.isNotEmpty) _saveReview();
      }
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
/// streak, mistake queue).
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
        'progress': p.getString(ProgressStore._keyBase),
        'streak': p.getString(ProgressStore._streakKeyBase),
        'misses': p.getString(ProgressStore._missKey),
        'review': p.getString(ProgressStore._reviewKeyBase),
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
        ProgressStore._keyBase: 'progress',
        ProgressStore._streakKeyBase: 'streak',
        ProgressStore._missKey: 'misses',
        ProgressStore._reviewKeyBase: 'review',
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
