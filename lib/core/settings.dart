import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The card reader's Indo-Pak script renders with DigitalKhattIndoPak.otf —
/// the same face the 15-line muṣḥaf uses (see CREDITS.md) — via a 1:1
/// codepoint transcode in `QuranRepo._transcodeIndopak` that aligns the
/// reader's text convention with the font's. PDMS Saleem is not involved and
/// was never shipped for the reader.
const bool kIndopakReaderAvailable = true;

/// The 15-line muṣḥaf's Indo-Pak script uses the same DigitalKhattIndoPak.otf
/// face (see CREDITS.md).
const bool kIndopakMushafAvailable = true;

/// Reader & accessibility settings. The dyslexia-friendly options are real
/// interventions, not decoration:
///  * arabicScale       — larger glyphs reduce crowding
///  * letterTracking    — opt-in spacing between joined glyphs ("uncrowding")
///  * wordSpacing       — extra gaps between words
///  * paperMode         — warm low-contrast background (visual stress relief)
///  * dotEmphasis       — drills tint/badge the i'jam dots so ب/ت/ث differ
///  * focusWindow       — fluency drills show one word at a time
/// One child's Kids Mode profile — local & on-device only (see "Family
/// profiles, same UI" in the Kids Mode plan). [gender] is used solely to pick
/// a grammatically-correct Arabic praise form (أَحْسَنْتَ vs أَحْسَنْتِ); '' renders
/// the gender-neutral copy.
class KidsProfile {
  final String id;
  String name;
  String avatar; // one emoji
  String gender; // 'm' | 'f' | ''
  KidsProfile({
    required this.id,
    required this.name,
    this.avatar = '🦊',
    this.gender = '',
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'avatar': avatar, 'gender': gender};

  factory KidsProfile.fromJson(Map<String, dynamic> m) => KidsProfile(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        avatar: (m['avatar'] ?? '🦊') as String,
        gender: (m['gender'] ?? '') as String,
      );
}

class AppSettings extends ChangeNotifier {
  bool dyslexiaMode = false;
  double arabicScale = 1.0; // 0.8 – 1.8
  double letterTracking = 0.0; // 0 – 10 logical px between glyphs
  double wordSpacing = 0.0; // 0 – 24
  bool paperMode = false;
  bool dotEmphasis = true;
  bool focusWindow = true;
  bool haptics = true;
  String themeMode = 'light'; // 'light' | 'dark' | 'oled'
  String themeFamily = 'mint'; // 'mint' | 'noor'
  String language = 'en'; // en | ar | ur | fr | es
  /// 'arabic' (Fatḥah/Ḍammah/Kasrah/Sukūn…) | 'indopak' (Zabar/Paish/Zair/Jazm…)
  /// — the tashkīl mark names shown app-wide (tashkilName() in
  /// glyph_names.dart). Defaults per-language in load(); user-overridable.
  String tashkilTerms = 'arabic';
  String quranScript = 'uthmani'; // 'uthmani' (Madani) | 'indopak' — card reader only
  String mushafScript = 'uthmani'; // 'uthmani' | 'indopak' — 15-line muṣḥaf's own, independent of quranScript
  bool mushafHeader = true; // traditional page header: sūrah · page · juzʼ
  bool mushafBarCollapsed = false; // retract the mushaf bottom control bar
  bool mushafFillWidth = false; // desktop: fill page width and scroll vertically, like phone landscape
  bool immersive = false; // hide system bars app-wide (edge-to-edge reading)
  double quranFontScale = 1.0; // 0.7 – 2.2 (reader-only slider)
  double traceTolerance = 1.0; // 0.6 strict – 1.8 lenient (Tracing Studio guidance radius)
  double wbwGap = 10; // gap between words / segments (4–30)
  int wbwGroup = 1; // words per segment: 1–6
  bool wbwNewline = false; // each segment on its own line
  String wbwAlign = 'right'; // 'right' | 'center' — verse alignment
  bool stripTashkil = false; // hide ḥarakāt for clearer letter shapes
  bool tajwidColors = false; // tajwīd color-coding in the reader
  String desktopMode = 'auto'; // 'auto'|'on'|'off'
  bool wordByWord = true; // reader: split verses into tappable words
  bool readerHeaderCollapsed = false; // retract the reader control panel
  String fontUthmani = 'UthmanicHafs'; // or 'ScheherazadeNew'
  String fontIndopak = 'DigitalKhattIndoPak';
  String reciter = 'tunaiji'; // 'tunaiji' | 'alafasy' | 'husary'
  String readerLayout = 'cards'; // 'cards' | 'mushaf' (continuous flow)
  String reciteFlow = 'single'; // 'single' | 'auto' (continue) | 'repeat'
  bool playerBarPinned = true; // recitation player bar: fixed vs. floating/draggable

  // ── Kids Mode ──
  bool kidsMode = false; // presentation preference, like dyslexiaMode — no
      // separate app, no backend, no accounts (see docs/privacy-policy.html)
  String kidsThemeMode = 'light'; // 'light' | 'dark' | 'oled' — independent
      // of the grown-up `themeMode` (see kidsPal() in core/theme.dart)
  List<KidsProfile> kidsProfiles = [];
  String? activeKidsProfileId;

  KidsProfile? get activeKidsProfile => activeKidsProfileId == null
      ? null
      : kidsProfiles.cast<KidsProfile?>().firstWhere(
          (p) => p!.id == activeKidsProfileId,
          orElse: () => null);

  static const _key = 'noor.settings.v1';

  void cycleTheme() {
    themeMode = themeMode == 'light' ? 'dark' : themeMode == 'dark' ? 'oled' : 'light';
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

  /// Switches into Kids Mode. A brand-new install has no child profile yet —
  /// the Kids shell's own onboarding creates the first one — so this only
  /// flips the flag; it never fabricates a profile on the parent's behalf.
  void enableKidsPreset() {
    kidsMode = true;
    notifyListeners();
    save();
  }

  /// Leaves Kids Mode, back to the grown-up app. Profiles and their progress
  /// are left untouched — this is a presentation switch, not a reset.
  void disableKidsMode() {
    kidsMode = false;
    notifyListeners();
    save();
  }

  void addKidsProfile(KidsProfile p) {
    kidsProfiles = [...kidsProfiles, p];
    activeKidsProfileId = p.id;
    notifyListeners();
    save();
  }

  void setActiveKidsProfile(String id) {
    activeKidsProfileId = id;
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
    themeMode = m['mode'] ?? 'light';
    themeFamily = m['family'] ?? 'mint';
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
    wordByWord = m['wbw'] ?? true;
    readerHeaderCollapsed = m['hdrCol'] ?? false;
    fontUthmani = m['fontU'] ?? 'UthmanicHafs';
    fontIndopak = m['fontI'] ?? 'DigitalKhattIndoPak';
    // legacy options removed from the UI — normalize to the supported pair.
    if (fontUthmani == 'ScheherazadeNew') fontUthmani = 'UthmanicHafs';
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
    mushafBarCollapsed = m['mushafBarCol'] ?? false;
    mushafFillWidth = m['mushafFillW'] ?? false;
    immersive = m['immersive'] ?? false;
    reciter = m['reciter'] ?? 'tunaiji';
    readerLayout = m['readerLayout'] ?? 'cards';
    reciteFlow = m['reciteFlow'] ?? 'single';
    quranFontScale = (m['qfont'] ?? 1.0).toDouble();
    traceTolerance = (m['traceTol'] ?? 1.0).toDouble();
    playerBarPinned = m['playerPinned'] ?? true;
    kidsMode = m['kidsMode'] ?? false;
    kidsThemeMode = m['kidsThemeMode'] ?? 'light';
    kidsProfiles = ((m['kidsProfiles'] as List?) ?? const [])
        .map((e) => KidsProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    activeKidsProfileId = m['activeKidsProfileId'] as String?;
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
        'mode': themeMode,
        'family': themeFamily,
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
        'wbw': wordByWord,
        'fontU': fontUthmani,
        'fontI': fontIndopak,
        'script': quranScript,
        'mushafScript': mushafScript,
        'mushafHeader': mushafHeader,
        'mushafBarCol': mushafBarCollapsed,
        'mushafFillW': mushafFillWidth,
        'immersive': immersive,
        'qfont': quranFontScale,
        'traceTol': traceTolerance,
        'reciter': reciter,
        'readerLayout': readerLayout,
        'reciteFlow': reciteFlow,
        'playerPinned': playerBarPinned,
        'kidsMode': kidsMode,
        'kidsThemeMode': kidsThemeMode,
        'kidsProfiles': [for (final p in kidsProfiles) p.toJson()],
        'activeKidsProfileId': activeKidsProfileId,
      }),
    );
  }
}

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);
  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
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
  /// null → the grown-up app's single global store, at the same storage keys
  /// this class has always used. A Kids Mode profile id → that child's own
  /// store, at keys suffixed with the profile id (never prefixed — several
  /// adult ids, e.g. `letter.ب`, are matched with `startsWith`, so suffixing
  /// is the only scoping that can't collide with existing id conventions).
  /// Every profile's data lives only on-device, same as the adult store —
  /// no accounts, no backend, no sync.
  final String? profileId;
  ProgressStore({this.profileId});

  final Map<String, int> _stars = {};
  static const _keyBase = 'noor.progress.v1';
  static const _streakKeyBase = 'noor.streak.v1';
  static const _missKey = 'noor.misses.v1'; // legacy — read once to migrate; adult-only
  static const _reviewKeyBase = 'noor.review.v1';
  static const _xpKeyBase = 'noor.kidsxp.v1';

  String get _key => _scoped(_keyBase);
  String get _streakKey => _scoped(_streakKeyBase);
  String get _reviewKey => _scoped(_reviewKeyBase);
  String get _xpKey => _scoped(_xpKeyBase);
  String _scoped(String base) => profileId == null ? base : '$base.$profileId';

  // ── Kids Mode progression: XP, levels, gems, badges. Unused (stays at
  // defaults) for the adult store — nothing here reads or writes it outside
  // Kids Mode screens. Gems are earned only: every call site that adds gems
  // is a lesson/quiz/streak reward, never a purchase — see
  // test/kids_mode_test.dart's earned-only-gems check. ──
  int xp = 0;
  int gems = 0;
  final Set<String> badges = {};
  final Set<String> shopOwned = {};

  int get level => 1 + (xp ~/ 100); // 100 XP per level — simple, predictable
  int get xpIntoLevel => xp % 100;

  void awardXp(int amount) {
    if (amount <= 0) return;
    xp += amount;
    notifyListeners();
    _saveXp();
  }

  void awardGems(int amount) {
    if (amount <= 0) return;
    gems += amount;
    notifyListeners();
    _saveXp();
  }

  void unlockBadge(String id) {
    if (badges.add(id)) {
      notifyListeners();
      _saveXp();
    }
  }

  /// Spends earned gems on a cosmetic shop item; returns false (no-op) if the
  /// balance is short. There is no path that adds gems except being earned,
  /// so this can never be a real-money purchase.
  bool buyShopItem(String id, int cost) {
    if (shopOwned.contains(id) || gems < cost) return false;
    gems -= cost;
    shopOwned.add(id);
    notifyListeners();
    _saveXp();
    return true;
  }

  Future<void> _saveXp() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _xpKey,
        jsonEncode({
          'xp': xp,
          'gems': gems,
          'badges': badges.toList(),
          'shop': shopOwned.toList(),
        }));
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
    streakDays = (_lastDay == t - 1) ? streakDays + 1 : 1;
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
    if (_lastDay >= 0 && t - _lastDay > 1) streakDays = 0;
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

  // Kids Mode's daily-goal ring needs a same-day activity count, which
  // nothing above tracks (recordActivity() only flags the FIRST activity of
  // the day, for the streak). Kept separate from the streak/week fields on
  // purpose — this is just "how many today", not a new streak mechanism.
  int todayActivityCount = 0;
  int _todayCountDay = -1;

  void _bumpTodayCount() {
    final t = _today();
    if (_todayCountDay != t) {
      todayActivityCount = 0;
      _todayCountDay = t;
    }
    todayActivityCount++;
    _saveStreak();
  }

  int starsFor(String id) => _stars[id] ?? 0;
  int get totalStars => _stars.values.fold(0, (a, b) => a + b);
  int get activitiesDone => _stars.values.where((s) => s > 0).length;
  int get lettersLearned =>
      _stars.keys.where((k) => k.startsWith('letter.')).length;

  /// Letters completed through the Kids Mode letter path (`kids.letter.<char>`
  /// ids) — separate from the adult reader's [lettersLearned] above, since a
  /// child profile and the grown-up progress are never the same store.
  int get kidsLettersLearned =>
      _stars.keys.where((k) => k.startsWith('kids.letter.')).length;

  /// Fraction of ids in [ids] with at least one star.
  double fraction(Iterable<String> ids) {
    if (ids.isEmpty) return 0;
    final done = ids.where((i) => starsFor(i) > 0).length;
    return done / ids.length;
  }

  void report(String id, int stars) {
    if (stars > 0) {
      recordActivity(); // any earned progress counts toward today
      _bumpTodayCount();
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
    } else if (profileId == null) {
      // Legacy flat-miss-map migration — adult store only; a Kids Mode
      // profile never had one to migrate from.
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
      todayActivityCount = (m['todayCount'] ?? 0) as int;
      _todayCountDay = (m['todayCountDay'] ?? -1) as int;
    }
    refreshStreak();
    final xraw = p.getString(_xpKey);
    if (xraw != null) {
      final m = jsonDecode(xraw) as Map<String, dynamic>;
      xp = (m['xp'] ?? 0) as int;
      gems = (m['gems'] ?? 0) as int;
      badges
        ..clear()
        ..addAll(((m['badges'] as List?) ?? const []).cast<String>());
      shopOwned
        ..clear()
        ..addAll(((m['shop'] as List?) ?? const []).cast<String>());
    }
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
          'todayCount': todayActivityCount,
          'todayCountDay': _todayCountDay,
        }));
  }
}

class ProgressScope extends InheritedNotifier<ProgressStore> {
  const ProgressScope({super.key, required ProgressStore progress, required super.child})
      : super(notifier: progress);
  static ProgressStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProgressScope>()!.notifier!;
}

/// One-file backup of everything the learner has earned (settings, stars,
/// streak, mistake queue) — for the adult app AND every Kids Mode profile.
/// Written to the app documents folder so it survives reinstalls when the
/// user copies it off-device.
class BackupService {
  static const _file = 'noor_qaidah_backup.json';

  static Future<String?> export(AppSettings s) async {
    try {
      final p = await SharedPreferences.getInstance();
      final data = {
        'settings': p.getString(AppSettings._key),
        'progress': p.getString(ProgressStore._keyBase),
        'streak': p.getString(ProgressStore._streakKeyBase),
        'misses': p.getString(ProgressStore._missKey),
        'review': p.getString(ProgressStore._reviewKeyBase),
        'kids': {
          for (final kp in s.kidsProfiles)
            kp.id: {
              'progress': p.getString('${ProgressStore._keyBase}.${kp.id}'),
              'streak':
                  p.getString('${ProgressStore._streakKeyBase}.${kp.id}'),
              'review':
                  p.getString('${ProgressStore._reviewKeyBase}.${kp.id}'),
              'xp': p.getString('${ProgressStore._xpKeyBase}.${kp.id}'),
            },
        },
      };
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/$_file');
      await f.writeAsString(jsonEncode(data));
      return f.path;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> restore(AppSettings s, ProgressStore prog) async {
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
      };
      for (final e in keys.entries) {
        final v = m[e.value];
        if (v is String) await p.setString(e.key, v);
      }
      final kids = m['kids'] as Map<String, dynamic>? ?? const {};
      for (final entry in kids.entries) {
        final id = entry.key;
        final blob = entry.value as Map<String, dynamic>;
        final kidKeys = {
          '${ProgressStore._keyBase}.$id': 'progress',
          '${ProgressStore._streakKeyBase}.$id': 'streak',
          '${ProgressStore._reviewKeyBase}.$id': 'review',
          '${ProgressStore._xpKeyBase}.$id': 'xp',
        };
        for (final e in kidKeys.entries) {
          final v = blob[e.value];
          if (v is String) await p.setString(e.key, v);
        }
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
