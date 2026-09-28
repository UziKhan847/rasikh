import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/letters.dart';

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
/// Shop frames that were retired, and the frame each one became — so a child who
/// bought the golden or the emerald frame keeps a frame of the same price tier
/// instead of losing what they paid for. Applied wherever a saved frame id or an
/// owned-items list is read back.
const kLegacyFrameIds = {
  'golden_frame': 'starlight_frame',
  'emerald_frame': 'aurora_frame',
};

/// How much Kids Mode's backdrop and cards paint — a dial, not a switch.
///
///  * [plain] — flat `bg`, flat cards. Exactly the look every kids screen had
///    before the depth pass, and the low-end-device escape hatch.
///  * [medium] — the soft painted scene and raised cards, with **no moving
///    layer at all**. This is the setting a slower phone picks, so it must
///    cost nothing per frame.
///  * [high] — the vivid scene, with drifting motes.
enum KidsDetail { plain, medium, high }

class KidsProfile {
  final String id;
  String name;
  String avatar; // one emoji
  String gender; // 'm' | 'f' | ''

  // What this child currently has EQUIPPED from the shop — not what they
  // OWN, which lives in that child's own `ProgressStore.shopOwned` instead.
  // These live here, rather than on the store, so `kidsPal`/`KidsAvatar` can
  // resolve them from `SettingsScope` alone: `kidsPal` is called from screens
  // that render before a `ProgressScope` exists yet (the profile picker, the
  // profile-loading spinner), and reading the wrong data source there would
  // mean those screens can't follow a purchased theme at all.
  //
  // There is deliberately no `hat` slot. One shipped briefly and was removed
  // — an emoji avatar has no anchor a drawn accessory can attach to, so it
  // read as a rendering artefact rather than a hat; see `kidsShopItems` in
  // `data/kids_content.dart`. A saved profile carrying the old `hat` key
  // loads fine: [fromJson] simply ignores it.
  String theme; // a kids_* palette family id, 'kids' if nothing equipped
  String frame; // an owned KidsShopItem id, '' if no frame equipped

  /// The emoji the child chose when their profile was made, remembered while an
  /// avatar unlock from the shop is worn over it, so taking the unlock off puts
  /// their own avatar back rather than a stand-in. Empty until an unlock is
  /// first equipped.
  String baseAvatar;

  KidsProfile({
    required this.id,
    required this.name,
    this.avatar = '🦊',
    this.gender = '',
    this.theme = 'kids',
    this.frame = '',
    this.baseAvatar = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'gender': gender,
        'theme': theme,
        'frame': frame,
        'baseAvatar': baseAvatar,
      };

  factory KidsProfile.fromJson(Map<String, dynamic> m) => KidsProfile(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        avatar: (m['avatar'] ?? '🦊') as String,
        gender: (m['gender'] ?? '') as String,
        theme: (m['theme'] ?? 'kids') as String,
        // A frame that has since been retired keeps working as its successor.
        frame: kLegacyFrameIds[m['frame']] ?? (m['frame'] ?? '') as String,
        baseAvatar: (m['baseAvatar'] ?? '') as String,
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
  /// How big everything in Kids Mode is drawn — Latin text AND Arabic — as a
  /// multiplier on its sizes: 0.9 small, 1.0 medium (the default), 1.2 large.
  /// Kids Mode's own dial, independent of the grown-up Reading Coach's
  /// [arabicScale], which used to resize the Arabic in a child's screens
  /// while the rest of their text stayed put (see `kidsStyle` in core/theme).
  double kidsTextScale = 1.0;

  /// Painted backdrops, raised gradient cards, and the celebration's fuller
  /// pop — the depth pass over Kids Mode's flat backgrounds. [KidsDetail.high]
  /// by default; [KidsDetail.plain] gives back exactly the flat look every
  /// screen had before it, which is also the low-end-device escape hatch (see
  /// `KidsBackdrop`).
  ///
  /// Replaces a `bool kidsHighDetail`, which is why [load] still reads that
  /// key: an install that turned detail off must not get it switched back on.
  KidsDetail kidsDetail = KidsDetail.high;

  /// Whether cards get the raised gradient look — every level but plain.
  /// (Medium and high differ only in the backdrop and its motion.)
  bool get kidsRaised => kidsDetail != KidsDetail.plain;

  /// Minutes into a Kids Mode session before [KidsShell] suggests a break —
  /// once, gently, never a lockout. `0` is off (the default): a parent opts
  /// in, this app never nags on its own. Paired with the Home tab's own
  /// "good place to stop" banner once the daily goal is met, these are the
  /// direct answer to the "hard to put down without crying" complaint —
  /// see the v4 plan's Phase 7.
  int kidsSessionMinutes = 0;
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

  /// The detail level from persisted JSON [m].
  ///
  /// The new `kidsDetail` key wins when present. Otherwise the old
  /// `kidsHighDetail` bool is mapped — `true` to high, `false` to plain — so a
  /// parent who turned detail off keeps it off. Neither key means a fresh
  /// install, which gets the default.
  static KidsDetail _loadKidsDetail(Map<String, dynamic> m) {
    final named = m['kidsDetail'];
    if (named is String) {
      for (final d in KidsDetail.values) {
        if (d.name == named) return d;
      }
    }
    final legacy = m['kidsHighDetail'];
    if (legacy is bool) return legacy ? KidsDetail.high : KidsDetail.plain;
    return KidsDetail.high;
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
    kidsTextScale = ((m['kidsTextScale'] ?? 1.0) as num).toDouble().clamp(0.8, 1.2);
    kidsDetail = _loadKidsDetail(m);
    kidsSessionMinutes = (m['kidsSessionMinutes'] as num?)?.toInt() ?? 0;
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
        'kidsTextScale': kidsTextScale,
        'kidsDetail': kidsDetail.name,
        'kidsSessionMinutes': kidsSessionMinutes,
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

/// How many sessions each ḥarakah drill is split into — mirrors
/// `kidsDrillSessions` in `screens/kids/kids_syllable_drill.dart`.
const _drillSessions = 3;

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

  /// Testing switch: every Kids Mode stage and tile is reachable regardless of
  /// what has actually been finished. It lifts the **locks only** — nothing is
  /// marked done, no XP, gems or badges are granted, and turning it back off
  /// leaves real progress exactly as it was. Set from the mascot's ten-tap
  /// gesture (see `KidsSecretUnlock`), persisted per profile so a rebuild or a
  /// device restart doesn't drop a tester back at alif.
  bool unlockAll = false;

  void setUnlockAll(bool value) {
    if (unlockAll == value) return;
    unlockAll = value;
    // A stage pin left over from a previous testing session would otherwise
    // silently keep steering Home once unlocking is switched back on.
    if (!value) devStage = null;
    notifyListeners();
    _saveXp();
  }

  /// Testing switch: pins [kidsCurrentBlockIndex] to one [KidsBlock.id]
  /// rather than the first stage with unfinished items, so Home (and the
  /// Learn tab's "current" row) can be pointed at any stage to test it —
  /// without actually playing through everything before it. Only honoured
  /// while [unlockAll] is on (see `kidsCurrentBlockIndex`), and, like
  /// [unlockAll], touches nothing about real progress: no stars, XP, gems or
  /// badges change, so turning it off leaves the child's actual place in the
  /// path exactly as it was.
  String? devStage;

  void setDevStage(String? id) {
    if (devStage == id) return;
    devStage = id;
    notifyListeners();
    _saveXp();
  }

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
          'unlockAll': unlockAll,
          'devStage': devStage,
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

  /// Shop-bought consumable: covers exactly one missed day so the streak
  /// survives it — see [recordActivity] and [refreshStreak], the only two
  /// places that ever spend one. A count, not a `shopOwned` membership, since
  /// it is meant to be bought and used repeatedly rather than owned once.
  int streakFreezes = 0;

  /// Set for one notification after a freeze is spent (see [recordActivity],
  /// [refreshStreak]) so the Home screen can tell the child what happened.
  /// Without this a freeze is a fully silent mechanic: the only visible
  /// effect is the streak NOT resetting, which looks identical to nothing
  /// having gone wrong in the first place — there is no way to connect that
  /// to the gems just spent on it. NOT persisted: it only needs to survive
  /// to the next rebuild, not across app restarts.
  bool justUsedFreeze = false;

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
    } else if (_lastDay >= 0 && t - _lastDay == 2 && streakFreezes > 0) {
      // Exactly one day skipped, and a freeze is in hand: the streak
      // continues as if that day had happened.
      streakFreezes--;
      justUsedFreeze = true;
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
  ///
  /// Also where a streak freeze covers a missed day on its own, without
  /// waiting for the child's next activity: without this, opening the app
  /// two days after the last one would flash the streak to zero right up
  /// until the next lesson silently repaired it via [recordActivity]'s own
  /// freeze check — a worse experience than never showing zero at all.
  void refreshStreak() {
    final t = _today();
    if (_lastDay >= 0 && t - _lastDay == 2 && streakFreezes > 0) {
      streakFreezes--;
      justUsedFreeze = true;
      _lastDay = t - 1; // the frozen day now reads as if it had activity
      _saveStreak();
    } else if (_lastDay >= 0 && t - _lastDay > 1) {
      streakDays = 0;
    }
    final monday = t - _weekdayOf(t);
    if (_weekStartDay != monday) {
      _weekStartDay = monday;
      weekMask = 0;
    }
    notifyListeners();
  }

  /// Spends [cost] gems on one streak freeze. Unlike [buyShopItem] there is
  /// no ownership set to check — freezes are consumed, so buying another one
  /// is always allowed once the balance covers it.
  /// Clears [justUsedFreeze] once the Home screen has shown its one-time
  /// "streak saved" banner. Deliberately does not notify — nothing else
  /// needs to react to this being acknowledged.
  void acknowledgeFreezeUsed() => justUsedFreeze = false;

  bool buyStreakFreeze(int cost) {
    if (gems < cost) return false;
    gems -= cost;
    streakFreezes++;
    notifyListeners();
    _saveXp(); // persists gems
    _saveStreak(); // persists streakFreezes
    return true;
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

  /// Number of starred ids beginning with [prefix] — [kidsLettersLearned]'s
  /// shape, generalised for badges keyed to a whole stage's worth of ids
  /// rather than one fixed id.
  int countStarred(String prefix) => _stars.keys
      .where((k) => k.startsWith(prefix) && _stars[k]! > 0)
      .length;

  /// How many activities were cleared with a perfect three-star mark.
  int get perfectCount => _stars.values.where((s) => s >= 3).length;

  /// True once any Kids Mode quiz has been passed with at least one star.
  /// Kids Mode has two quiz-id conventions — `kids.quiz.*` for the letters/
  /// forms/special-shapes stages, `kids.<unit>.test` for stages that reuse a
  /// grown-up Qāʿidah/Tajwīd unit's own Test phase (see `kids_path.dart`) —
  /// so this checks both rather than one fixed id.
  bool get kidsAnyQuizPassed => _stars.entries.any((e) =>
      e.value > 0 && (e.key.startsWith('kids.quiz.') || e.key.endsWith('.test')));

  /// True once any Kids Mode quiz has been passed with a perfect (3-star)
  /// mark. See [kidsAnyQuizPassed] for the id conventions this matches.
  bool get kidsAnyQuizPerfect => _stars.entries.any((e) =>
      e.value >= 3 && (e.key.startsWith('kids.quiz.') || e.key.endsWith('.test')));

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
    // Legacy Joining Shapes migration — that stage used to be one lesson per
    // LETTER (`kids.forms.more.<char>`, all its shapes traced together); it
    // is one lesson per SHAPE now (`kids.forms.<ini|med|fin>.<char>`), so a
    // single old star cannot become three honestly earned ones. It is copied
    // onto every new shape id for that letter instead of dropped, since the
    // work it represents really was done — a child who finished a letter's
    // joining shapes before this changed should not be sent back to redo it.
    // Read once: harmless (and a no-op) on the adult store or a profile that
    // never had these ids, and never saved back under the old prefix, so this
    // block simply stops matching anything once every profile has migrated.
    var migratedForms = false;
    for (final l in letters) {
      final old = _stars['kids.forms.more.${l.char}'];
      if (old == null) continue;
      for (final f in l.joins ? const ['ini', 'med', 'fin'] : const ['fin']) {
        final id = 'kids.forms.$f.${l.char}';
        if (!_stars.containsKey(id)) {
          _stars[id] = old;
          migratedForms = true;
        }
      }
    }
    // Each ḥarakah drill used to be ONE tile per mark (`kids.harakat.fatha`)
    // and is now [_drillSessions] short sessions (`kids.harakat.fatha.1..3`).
    // A finished old drill covered all of them, so its stars carry onto each
    // new session — same shape as the forms migration above, and for the same
    // reason: nothing a child already earned may be orphaned by the path
    // being split into shorter pieces. The old id is left in place, unread.
    // (Literal ids on purpose: this is `core/`, and the path lives in
    // `screens/kids`; test/kids_drill_migration_test.dart pins the two
    // together.)
    var migratedDrills = false;
    for (final old in const [
      'kids.harakat.fatha',
      'kids.harakat.kasra',
      'kids.harakat.damma',
      'kids.sukun.sukun',
      'kids.shadda.shadda',
      'kids.tanwin.fathatan',
      'kids.tanwin.kasratan',
      'kids.tanwin.dammatan',
    ]) {
      final stars = _stars[old];
      if (stars == null) continue;
      for (var n = 1; n <= _drillSessions; n++) {
        final id = '$old.$n';
        if (!_stars.containsKey(id)) {
          _stars[id] = stars;
          migratedDrills = true;
        }
      }
    }
    if (migratedForms || migratedDrills) await _save();
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
      // Read before refreshStreak() below, which may spend one immediately.
      streakFreezes = (m['freezes'] ?? 0) as int;
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
        ..addAll([
          for (final id in ((m['shop'] as List?) ?? const []).cast<String>())
            kLegacyFrameIds[id] ?? id,
        ]);
      unlockAll = (m['unlockAll'] ?? false) as bool;
      devStage = m['devStage'] as String?;
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
          'freezes': streakFreezes,
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
