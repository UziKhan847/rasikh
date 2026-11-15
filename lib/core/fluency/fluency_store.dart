import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marks/word_ref.dart';
import '../settings.dart' show ProgressStore;

/// The Reader's fluency work, after the plan for adult readers (automatic
/// word recognition): words marked not fluent, pairs of words that join,
/// words split into stem and attachments — each a card to flash until it's
/// read instantly — and the plan's sessions and cold reads.
///
/// Per profile, like progress ([ProgressStore.profileSuffix]); not synced.

/// What a fluency mark is.
enum FluencyKind { word, pair, chunk }

/// How a card was read: at once, slowly, or wrongly.
enum Recall { instant, slow, wrong }

/// One mark on the text.
class FluencyMark {
  final FluencyKind kind;

  /// The word (a pair: its first word).
  final WordRef ref;

  /// As the muṣḥaf prints it (a pair: both words, a space between).
  final String form;

  /// A pair: how its words join ('wasl', 'idgham', 'iqlab', 'ikhfa',
  /// 'shamsi', 'join').
  final String join;

  /// A chunk: how many letters of [form] are its prefix and suffix.
  final int prefix, suffix;
  final int addedAt;
  const FluencyMark({
    required this.kind,
    required this.ref,
    required this.form,
    this.join = '',
    this.prefix = 0,
    this.suffix = 0,
    required this.addedAt,
  });

  String get id => idOf(kind, ref);
  static String idOf(FluencyKind k, WordRef r) => '${k.name}:${r.key}';

  /// Its card: a word's is its form's (the same word wherever it's
  /// marked, and a tier word too); a pair's and a chunk's their own.
  String get cardId => kind == FluencyKind.word ? 'f:$form' : id;

  Map<String, Object> toJson() => {
        'k': kind.name,
        'r': ref.key,
        'f': form,
        if (join.isNotEmpty) 'j': join,
        if (prefix > 0) 'p': prefix,
        if (suffix > 0) 's': suffix,
        't': addedAt,
      };

  factory FluencyMark.fromJson(Map<String, dynamic> j) => FluencyMark(
        kind: FluencyKind.values.byName(j['k'] as String),
        ref: WordRef.fromKey(j['r'] as int),
        form: j['f'] as String,
        join: j['j'] as String? ?? '',
        prefix: j['p'] as int? ?? 0,
        suffix: j['s'] as int? ?? 0,
        addedAt: j['t'] as int,
      );
}

/// A card's progress: the days it was read instantly (three separate ones
/// retire it), and how it was read last.
class CardProgress {
  final List<int> instantDays;
  Recall? last;
  int lastSeen;
  CardProgress({List<int>? instantDays, this.last, this.lastSeen = 0})
      : instantDays = instantDays ?? [];

  /// Instant in three separate sessions (on separate days): retired from
  /// the warm-up.
  bool get retired => instantDays.length >= 3;

  Map<String, Object> toJson() => {
        'd': instantDays,
        if (last != null) 'l': last!.name,
        'v': lastSeen,
      };

  factory CardProgress.fromJson(Map<String, dynamic> j) => CardProgress(
        instantDays: [for (final d in (j['d'] as List? ?? const [])) d as int],
        last: j['l'] == null ? null : Recall.values.byName(j['l'] as String),
        lastSeen: j['v'] as int? ?? 0,
      );
}

/// A 1-minute cold read: what was read, how much of it correctly, the
/// stalls and madd errors counted, and the recording.
class ColdRead {
  final int at;

  /// The passage: its first and last token (the muṣḥaf's stream).
  final int firstTok, lastTok;
  final String script;
  final int seconds;
  final int wordsCorrect;
  final int stalls, maddErrors;

  /// The timing perception check's score out of 10 (every 3 weeks), if
  /// taken this time.
  final int? perception;
  final String? recording;
  final String notes;
  const ColdRead({
    required this.at,
    required this.firstTok,
    required this.lastTok,
    required this.script,
    this.seconds = 60,
    required this.wordsCorrect,
    this.stalls = 0,
    this.maddErrors = 0,
    this.perception,
    this.recording,
    this.notes = '',
  });

  double get perMinute => wordsCorrect * 60 / seconds;

  ColdRead copyWith({int? stalls, int? maddErrors, int? perception, String? notes, int? wordsCorrect}) =>
      ColdRead(
        at: at,
        firstTok: firstTok,
        lastTok: lastTok,
        script: script,
        seconds: seconds,
        wordsCorrect: wordsCorrect ?? this.wordsCorrect,
        stalls: stalls ?? this.stalls,
        maddErrors: maddErrors ?? this.maddErrors,
        perception: perception ?? this.perception,
        recording: recording,
        notes: notes ?? this.notes,
      );

  Map<String, Object> toJson() => {
        't': at,
        'a': firstTok,
        'b': lastTok,
        'sc': script,
        'sec': seconds,
        'w': wordsCorrect,
        'st': stalls,
        'm': maddErrors,
        'pc': ?perception,
        'rec': ?recording,
        if (notes.isNotEmpty) 'n': notes,
      };

  factory ColdRead.fromJson(Map<String, dynamic> j) => ColdRead(
        at: j['t'] as int,
        firstTok: j['a'] as int,
        lastTok: j['b'] as int,
        script: j['sc'] as String? ?? 'uthmani',
        seconds: j['sec'] as int? ?? 60,
        wordsCorrect: j['w'] as int,
        stalls: j['st'] as int? ?? 0,
        maddErrors: j['m'] as int? ?? 0,
        perception: j['pc'] as int?,
        recording: j['rec'] as String?,
        notes: j['n'] as String? ?? '',
      );
}

/// How a mark shows on its word (see the lines' and cards' fluency
/// painting).
@immutable
class FluencyVisual {
  final bool slow;

  /// Joined to the next word (the first of a pair) / to the one before.
  final bool pairStart, pairEnd;
  final bool chunk;
  const FluencyVisual(
      {this.slow = false, this.pairStart = false, this.pairEnd = false, this.chunk = false});

  FluencyVisual merge(FluencyVisual o) => FluencyVisual(
      slow: slow || o.slow,
      pairStart: pairStart || o.pairStart,
      pairEnd: pairEnd || o.pairEnd,
      chunk: chunk || o.chunk);

  @override
  bool operator ==(Object other) =>
      other is FluencyVisual &&
      other.slow == slow &&
      other.pairStart == pairStart &&
      other.pairEnd == pairEnd &&
      other.chunk == chunk;

  @override
  int get hashCode => Object.hash(slow, pairStart, pairEnd, chunk);
}

/// The day number (local) of [ms], for "separate sessions".
int dayOf(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
}

class FluencyStore extends ChangeNotifier {
  /// The prefs key, before the profile's suffix.
  static const keyBase = 'fluency.v1';
  static String get _key => '$keyBase${ProgressStore.profileSuffix}';

  final Map<String, FluencyMark> _marks = {};
  final Map<String, CardProgress> _cards = {};
  final List<ColdRead> _coldReads = [];

  /// Plan sessions done: day → the blocks done that day.
  final Map<int, Set<String>> _sessions = {};

  /// Global āyāt heard in the Reader (recitation played), as bits; passages
  /// known by heart (first tokens); passages used for cold reads.
  Uint8List _heard = Uint8List(6236 ~/ 8 + 1);
  final Set<int> _known = {};

  /// When the 12-week plan was started (null: not yet).
  int? planStart;

  bool _loaded = false;
  Timer? _saveTimer;

  /// For tests: the clock.
  int Function() now = () => DateTime.now().millisecondsSinceEpoch;

  bool get loaded => _loaded;

  /// The key what's here was loaded from (and is saved to): a switch of
  /// profile changes [_key] before the old one's last save.
  String? _loadedKey;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _clear();
    _loadedKey = _key;
    final raw = p.getString(_key);
    if (raw != null) {
      try {
        _fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
      } catch (e) {
        debugPrint('[fluency] unreadable: $e');
      }
    }
    _loaded = true;
    _visuals = null;
    notifyListeners();
  }

  /// Another profile's: what's pending saved, then theirs loaded.
  Future<void> reload() async {
    await flush();
    await load();
  }

  void _clear() {
    _marks.clear();
    _cards.clear();
    _coldReads.clear();
    _sessions.clear();
    _heard = Uint8List(6236 ~/ 8 + 1);
    _known.clear();
    planStart = null;
  }

  Map<String, Object?> toJson() => {
        'marks': [for (final m in _marks.values) m.toJson()],
        'cards': {for (final e in _cards.entries) e.key: e.value.toJson()},
        'cold': [for (final c in _coldReads) c.toJson()],
        'sessions': {for (final e in _sessions.entries) '${e.key}': e.value.toList()},
        'heard': base64Encode(_heard),
        'known': _known.toList(),
        if (planStart != null) 'plan': planStart,
      };

  void _fromJson(Map<String, dynamic> j) {
    for (final m in (j['marks'] as List? ?? const [])) {
      final mark = FluencyMark.fromJson((m as Map).cast());
      _marks[mark.id] = mark;
    }
    ((j['cards'] as Map?) ?? const {}).forEach((k, v) {
      _cards[k as String] = CardProgress.fromJson((v as Map).cast());
    });
    for (final c in (j['cold'] as List? ?? const [])) {
      _coldReads.add(ColdRead.fromJson((c as Map).cast()));
    }
    ((j['sessions'] as Map?) ?? const {}).forEach((k, v) {
      _sessions[int.parse(k as String)] = {for (final b in v as List) b as String};
    });
    final h = j['heard'] as String?;
    if (h != null) {
      final bytes = base64Decode(h);
      if (bytes.length == _heard.length) _heard = bytes;
    }
    _known.addAll([for (final k in (j['known'] as List? ?? const [])) k as int]);
    planStart = j['plan'] as int?;
  }

  /// Replaces everything with a backup's (null: emptied).
  Future<void> restore(Map<String, dynamic>? j) async {
    _clear();
    if (j != null) _fromJson(j);
    _visuals = null;
    notifyListeners();
    await flush();
  }

  void _changed({bool marks = false}) {
    if (marks) _visuals = null;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final key = _loadedKey;
    if (!_loaded || key == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(toJson()));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ── marks ──

  Iterable<FluencyMark> get marks => _marks.values;
  Iterable<FluencyMark> marksOf(FluencyKind k) => _marks.values.where((m) => m.kind == k);

  FluencyMark? markAt(FluencyKind k, WordRef ref) => _marks[FluencyMark.idOf(k, ref)];

  /// [ref]'s marks as they are (for undo): each kind's, or null.
  Map<String, FluencyMark?> snapshotAt(WordRef ref) => {
        for (final k in FluencyKind.values) FluencyMark.idOf(k, ref): _marks[FluencyMark.idOf(k, ref)],
      };

  /// Puts back [snap]; returns how they were (for redo).
  Map<String, FluencyMark?> restoreSnapshot(Map<String, FluencyMark?> snap) {
    final back = {for (final id in snap.keys) id: _marks[id]};
    snap.forEach((id, m) => m == null ? _marks.remove(id) : _marks[id] = m);
    _changed(marks: true);
    return back;
  }
  bool isSlow(WordRef ref) => markAt(FluencyKind.word, ref) != null;

  /// Marks [ref] not fluent, or unmarks it.
  void toggleSlow(WordRef ref, String form) {
    final id = FluencyMark.idOf(FluencyKind.word, ref);
    if (_marks.remove(id) == null) {
      _marks[id] = FluencyMark(kind: FluencyKind.word, ref: ref, form: form, addedAt: now());
    }
    _changed(marks: true);
  }

  /// Pairs [ref] with the word after it, or unpairs it ([form]: both).
  void togglePair(WordRef ref, String form, String join) {
    final id = FluencyMark.idOf(FluencyKind.pair, ref);
    if (_marks.remove(id) == null) {
      _marks[id] = FluencyMark(
          kind: FluencyKind.pair, ref: ref, form: form, join: join, addedAt: now());
    }
    _changed(marks: true);
  }

  /// Sets [ref]'s split ([prefix] and [suffix] letters of [form]); both
  /// 0 unsets it.
  void setChunk(WordRef ref, String form, int prefix, int suffix) {
    final id = FluencyMark.idOf(FluencyKind.chunk, ref);
    if (prefix <= 0 && suffix <= 0) {
      _marks.remove(id);
    } else {
      _marks[id] = FluencyMark(
          kind: FluencyKind.chunk,
          ref: ref,
          form: form,
          prefix: prefix,
          suffix: suffix,
          addedAt: _marks[id]?.addedAt ?? now());
    }
    _changed(marks: true);
  }

  Map<int, FluencyVisual>? _visuals;

  /// How each marked word shows, by [WordRef.key]. [nextOf] gives the word
  /// after a pair's first (its second word).
  Map<int, FluencyVisual> visuals(WordRef? Function(WordRef first) nextOf) {
    final cached = _visuals;
    if (cached != null) return cached;
    final out = <int, FluencyVisual>{};
    void add(WordRef r, FluencyVisual v) =>
        out[r.key] = (out[r.key] ?? const FluencyVisual()).merge(v);
    for (final m in _marks.values) {
      switch (m.kind) {
        case FluencyKind.word:
          add(m.ref, const FluencyVisual(slow: true));
        case FluencyKind.pair:
          add(m.ref, const FluencyVisual(pairStart: true));
          final next = nextOf(m.ref);
          if (next != null) add(next, const FluencyVisual(pairEnd: true));
        case FluencyKind.chunk:
          add(m.ref, const FluencyVisual(chunk: true));
      }
    }
    return _visuals = out;
  }

  // ── cards ──

  CardProgress? progressOf(String cardId) => _cards[cardId];

  /// [cardId] read as [r]: instant on a new day counts towards retiring
  /// it; slow or wrong starts it over.
  void rate(String cardId, Recall r) {
    final t = now();
    final c = _cards.putIfAbsent(cardId, CardProgress.new);
    c
      ..last = r
      ..lastSeen = t;
    if (r == Recall.instant) {
      final d = dayOf(t);
      if (!c.instantDays.contains(d)) c.instantDays.add(d);
    } else {
      c.instantDays.clear();
    }
    _changed();
  }

  // ── the plan ──

  void startPlan() {
    planStart = now();
    _changed();
  }

  void resetPlan() {
    planStart = null;
    _changed();
  }

  /// The plan's week (1-based; 0 before it starts; past 12 stays 12+).
  int get week => planStart == null ? 0 : (now() - planStart!) ~/ (7 * 86400000) + 1;

  Set<String> blocksDoneOn(int day) => _sessions[day] ?? const {};
  Set<String> get blocksDoneToday => blocksDoneOn(dayOf(now()));

  void blockDone(String block) {
    if (!(_sessions[dayOf(now())] ??= {}).add(block)) return;
    _changed();
  }

  // ── cold reads ──

  List<ColdRead> get coldReads => List.unmodifiable(_coldReads);

  void addColdRead(ColdRead c) {
    _coldReads.add(c);
    _changed();
  }

  void updateColdRead(ColdRead old, ColdRead updated) {
    final i = _coldReads.indexWhere((c) => c.at == old.at);
    if (i < 0) return;
    _coldReads[i] = updated;
    _changed();
  }

  // ── passages ──

  bool heard(int globalAyah) =>
      globalAyah >= 0 && (_heard[globalAyah >> 3] & (1 << (globalAyah & 7))) != 0;

  /// The Reader played [globalAyah]: not unseen any more.
  void markHeard(int globalAyah) {
    if (globalAyah < 0 || heard(globalAyah)) return;
    _heard[globalAyah >> 3] |= 1 << (globalAyah & 7);
    _changed();
  }

  Set<int> get known => _known;

  void setKnown(int firstTok, bool on) {
    on ? _known.add(firstTok) : _known.remove(firstTok);
    _changed();
  }
}

class FluencyScope extends InheritedNotifier<FluencyStore> {
  const FluencyScope({super.key, required FluencyStore store, required super.child})
      : super(notifier: store);

  static FluencyStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FluencyScope>()?.notifier;

  /// Without depending on it (for callbacks).
  static FluencyStore? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FluencyScope>()?.notifier;
}
