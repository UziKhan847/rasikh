import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String themeMode = 'light'; // 'light' | 'dark' | 'oled'
  String themeFamily = 'mint'; // 'mint' | 'noor'
  String language = 'en'; // en | ar | ur | fr | es
  String quranScript = 'uthmani'; // 'uthmani' (Madani) | 'indopak'
  bool mushafHeader = true; // traditional page header: sūrah · page · juzʼ
  bool immersive = false; // hide system bars app-wide (edge-to-edge reading)
  double quranFontScale = 1.0; // 0.7 – 2.2 (reader-only slider)
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
  String fontIndopak = 'PDMSSaleem'; // PDMS Saleem renders the IndoPak text cleanly
  String reciter = 'tunaiji'; // 'tunaiji' | 'alafasy' (word-sync highlight)
  String readerLayout = 'cards'; // 'cards' | 'mushaf' (continuous flow)
  String reciteFlow = 'single'; // 'single' | 'auto' (continue) | 'repeat'
  bool playerBarPinned = true; // recitation player bar: fixed vs. floating/draggable

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
    fontIndopak = m['fontI'] ?? 'IndoPak';
    // legacy options removed from the UI — normalize to the supported pair.
    // The bundled IndoPak face mis-shapes the IndoPak text, so the Indo-Pak
    // script now renders with PDMS Saleem (a proper Indo-Pak Qur'an font).
    if (fontUthmani == 'ScheherazadeNew') fontUthmani = 'UthmanicHafs';
    if (fontIndopak == 'IndoPak') fontIndopak = 'PDMSSaleem';
    quranScript = m['script'] ?? 'uthmani';
    mushafHeader = m['mushafHeader'] ?? true;
    immersive = m['immersive'] ?? false;
    reciter = m['reciter'] ?? 'tunaiji';
    readerLayout = m['readerLayout'] ?? 'cards';
    reciteFlow = m['reciteFlow'] ?? 'single';
    quranFontScale = (m['qfont'] ?? 1.0).toDouble();
    playerBarPinned = m['playerPinned'] ?? true;
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
        'mushafHeader': mushafHeader,
        'immersive': immersive,
        'qfont': quranFontScale,
        'reciter': reciter,
        'readerLayout': readerLayout,
        'reciteFlow': reciteFlow,
        'playerPinned': playerBarPinned,
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
class ReviewItem {
  final String arabic; // the glyph/word — the queue key
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

  static ReviewItem fromJson(String arabic, Map<String, dynamic> m) => ReviewItem(
        arabic: arabic,
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
  static const _key = 'noor.progress.v1';
  static const _streakKey = 'noor.streak.v1';
  static const _missKey = 'noor.misses.v1'; // legacy — read once to migrate
  static const _reviewKey = 'noor.review.v1';

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
  void recordMiss(String arabic,
      {required String answer,
      String prompt = 'You missed this before — what is it?',
      List<String> distractors = const [],
      bool optionsArabic = false}) {
    final a = arabic.trim();
    if (a.isEmpty || answer.trim().isEmpty) return;
    final t = _today();
    final existing = review[a];
    review[a] = ReviewItem(
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
      final k = review.entries
          .reduce((x, y) => x.value.due >= y.value.due ? x : y)
          .key;
      if (k == a) break;
      review.remove(k);
    }
    _saveReview();
    notifyListeners();
  }

  /// Record a correct answer anywhere: promote the card one Leitner box and
  /// push its next review out; a correct answer past the last box graduates it.
  void reviewCorrect(String arabic) {
    final a = arabic.trim();
    final item = review[a];
    if (item == null) return;
    final t = _today();
    final next = item.box + 1;
    if (next >= _boxDays.length) {
      review.remove(a); // graduated — learned
    } else {
      item.box = next;
      item.due = t + _boxDays[next];
      item.reps += 1;
      item.lastSeen = t;
    }
    _saveReview();
    notifyListeners();
  }

  void clearReview(String arabic) {
    if (review.remove(arabic.trim()) != null) {
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

  static int _today() =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
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
    if (stars > 0) recordActivity(); // any earned progress counts toward today
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
      final mraw = p.getString(_missKey);
      if (mraw != null) {
        final t = _today();
        Map<String, String>.from(jsonDecode(mraw) as Map).forEach((k, answer) {
          review[k] = ReviewItem(
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
}

/// One-file backup of everything the learner has earned (settings, stars,
/// streak, mistake queue). Written to the app documents folder so it survives
/// reinstalls when the user copies it off-device.
class BackupService {
  static const _file = 'noor_qaidah_backup.json';

  static Future<String?> export() async {
    try {
      final p = await SharedPreferences.getInstance();
      final data = {
        'settings': p.getString(AppSettings._key),
        'progress': p.getString(ProgressStore._key),
        'streak': p.getString(ProgressStore._streakKey),
        'misses': p.getString(ProgressStore._missKey),
        'review': p.getString(ProgressStore._reviewKey),
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
        ProgressStore._key: 'progress',
        ProgressStore._streakKey: 'streak',
        ProgressStore._missKey: 'misses',
        ProgressStore._reviewKey: 'review',
      };
      for (final e in keys.entries) {
        final v = m[e.value];
        if (v is String) await p.setString(e.key, v);
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
