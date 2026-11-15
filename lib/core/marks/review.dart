import 'package:flutter/foundation.dart';

import '../../data/divisions.dart';
import '../../data/mushaf.dart' show MushafRepo;
import '../fluency/fluency_store.dart';
import 'marks_model.dart';
import 'marks_store.dart';
import 'word_ref.dart';

/// Which marks are open (not fixed), fixed, or either.
enum ReviewStatus { open, fixed, any }

/// What a review goes over: the memorization marks, the fluency marks, or all.
enum ReviewScope { marks, fluency, all }

ReviewScope reviewScopeOf(String s) => switch (s) {
      'fluency' => ReviewScope.fluency,
      'all' => ReviewScope.all,
      _ => ReviewScope.marks,
    };

/// What to go back over: which kinds of mark, open or fixed, and where.
@immutable
class ReviewQuery {
  /// The kinds to include; empty = every kind.
  final Set<MarkType> types;
  final ReviewStatus status;

  /// Where: null = the whole book; else [division] number [number] (pages
  /// in [script]'s numbering).
  final Division? division;
  final int number;
  final String script;
  final ReviewScope scope;

  const ReviewQuery({
    this.types = const {},
    this.status = ReviewStatus.open,
    this.division,
    this.number = 1,
    this.script = 'uthmani',
    this.scope = ReviewScope.marks,
  });

  ReviewQuery copyWith({
    Set<MarkType>? types,
    ReviewStatus? status,
    Division? division,
    bool everywhere = false,
    int? number,
    String? script,
    ReviewScope? scope,
  }) =>
      ReviewQuery(
        types: types ?? this.types,
        status: status ?? this.status,
        division: everywhere ? null : division ?? this.division,
        number: number ?? this.number,
        script: script ?? this.script,
        scope: scope ?? this.scope,
      );

  bool wantsType(MarkType t) => types.isEmpty || types.contains(t);
}

/// The marks a [ReviewQuery] selects, in muṣḥaf order (word by word; marks
/// on the same word oldest first).
List<Mark> buildReviewQueue(
  MarksStore store,
  String bookId,
  ReviewQuery q, {
  int Function(WordRef)? pageOf,
  FluencyStore? fluency,
}) {
  final out = <Mark>[];
  bool inPlace(WordRef r) {
    final d = q.division;
    if (d == null) return true;
    final n = d == Division.page
        ? (pageOf == null ? -1 : pageOf(r))
        : divisionOf(d, r.surah, r.ayah);
    return n == q.number;
  }

  // The fluency marks, as marks of their own kinds (every one: they're not
  // fixed, they're read better).
  if (q.scope != ReviewScope.marks && fluency != null) {
    for (final f in fluency.marks) {
      if (!inPlace(f.ref)) continue;
      out.add(fluencyAsMark(f, bookId));
    }
  }
  final marks = q.scope == ReviewScope.fluency ? const <Mark>[] : store.marksOf(bookId);
  for (final m in marks) {
    if (!q.wantsType(m.type)) continue;
    final fixed = store.isFixed(m);
    if (q.status == ReviewStatus.open && fixed) continue;
    if (q.status == ReviewStatus.fixed && !fixed) continue;
    final d = q.division;
    if (d != null) {
      final r = m.ref;
      final n = d == Division.page
          ? (pageOf == null ? -1 : pageOf(r))
          : divisionOf(d, r.surah, r.ayah);
      if (n != q.number) continue;
    }
    out.add(m);
  }
  out.sort((a, b) {
    final c = a.ref.compareTo(b.ref);
    return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
  });
  return out;
}

/// [f] as Review shows it: a mark of its fluency kind (its id `fl:` and the
/// fluency mark's).
Mark fluencyAsMark(FluencyMark f, String bookId) => Mark(
      id: 'fl:${f.id}',
      bookId: bookId,
      ref: f.ref,
      type: switch (f.kind) {
        FluencyKind.word => MarkType.fluencySlow,
        FluencyKind.pair => MarkType.fluencyPair,
        FluencyKind.chunk => MarkType.fluencyChunk,
      },
      authorId: '',
      createdAt: f.addedAt,
      clientUpdated: f.addedAt,
    );

/// Review mode's state, shared by the muṣḥaf and the verse cards: the queue,
/// where in it the reader is, which kind the arrows step through, the
/// session fixes are made in, and undo.
class ReviewController extends ChangeNotifier {
  final MarksStore store;
  final String bookId;
  ReviewQuery query;
  List<Mark> _items;
  int _index = 0;
  String? sessionId;

  /// The kind the arrows step through; null = every kind in the queue.
  MarkType? only;

  /// Where the arrows step: only marks in [Division] number n (null: the
  /// whole queue).
  (Division, int)? where;

  /// [m]'s number in division [d] (pages in the query's script).
  int placeOf(Mark m, Division d) {
    final r = m.ref;
    return switch (d) {
      Division.page =>
        MushafRepo.pageOfWord(query.script, r.globalAyah, r.word <= 0 ? 0 : r.word - 1),
      Division.surah => r.surah,
      _ => divisionOf(d, r.surah, r.ayah),
    };
  }

  /// The places of division [d] the queue has marks in, with how many (of
  /// the kind the arrows step through), in order.
  List<(int, int)> placesOf(Division d) {
    final n = <int, int>{};
    for (final m in _items) {
      if (only != null && m.type != only) continue;
      final k = placeOf(m, d);
      n[k] = (n[k] ?? 0) + 1;
    }
    return [for (final k in n.keys.toList()..sort()) (k, n[k]!)];
  }

  final Set<String> _seen = {};
  final Set<String> _fixedHere = {};
  final List<(MarkOp, int)> _undo = [];
  bool _active = true;

  /// Where the fluency marks in the queue are kept (and rated).
  final FluencyStore? fluency;

  ReviewController({
    required this.store,
    required this.bookId,
    required this.query,
    required List<Mark> items,
    this.fluency,
  }) : _items = items {
    if (_items.isNotEmpty) _seen.add(_items.first.id);
  }

  /// Builds the queue for [query] and starts a review session in [bookId].
  factory ReviewController.start(
    MarksStore store,
    String bookId,
    ReviewQuery query, {
    int Function(WordRef)? pageOf,
    bool session = true,
    FluencyStore? fluency,
  }) {
    final c = ReviewController(
      store: store,
      bookId: bookId,
      query: query,
      fluency: fluency,
      items: buildReviewQueue(store, bookId, query, pageOf: pageOf, fluency: fluency),
    );
    final book = store.book(bookId);
    if (session && c._items.isNotEmpty && (book?.myRole.canMark ?? false)) {
      c.sessionId = store
          .startSession(
              bookId: bookId, kind: SessionKind.review, script: query.script)
          .id;
    }
    return c;
  }

  bool get active => _active;
  List<Mark> get items => _items;
  int get index => _index;
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  Mark? get current =>
      _index >= 0 && _index < _items.length ? _items[_index] : null;
  bool get canUndo => _undo.isNotEmpty;

  bool isFixed(Mark m) => store.isFixed(m);

  /// How many of the queue were looked at / fixed in this review / are
  /// still open.
  int get seenCount => _seen.length;
  int get fixedCount => _fixedHere.length;
  int get openCount => _items.where((m) => !store.isFixed(m)).length;

  bool _matches(Mark m) =>
      (only == null || m.type == only) &&
      (where == null || placeOf(m, where!.$1) == where!.$2);

  int _find(int from, int step) {
    for (var i = from; i >= 0 && i < _items.length; i += step) {
      if (_matches(_items[i])) return i;
    }
    return -1;
  }

  bool get hasNext => _find(_index + 1, 1) >= 0;
  bool get hasPrev => _find(_index - 1, -1) >= 0;

  void _go(int i) {
    if (i < 0 || i == _index) return;
    _index = i;
    _seen.add(_items[i].id);
    notifyListeners();
  }

  /// Next / previous mark of the [only] kind. Returns false at the end.
  bool next() {
    final i = _find(_index + 1, 1);
    _go(i);
    return i >= 0;
  }

  bool prev() {
    final i = _find(_index - 1, -1);
    _go(i);
    return i >= 0;
  }

  /// Jumps to item [i] of the queue.
  void goTo(int i) => _go(i.clamp(0, _items.length - 1));

  /// Arrows step through [t] only (null: everything); moves to the nearest
  /// such mark from here (this one, or the next, else the previous).
  void setOnly(MarkType? t) {
    only = t;
    final cur = current;
    if (cur == null || !_matches(cur)) {
      final i = _find(_index, 1);
      _go(i >= 0 ? i : _find(_index, -1));
    }
    notifyListeners();
  }

  /// Arrows step through the marks in [d] number [n] only (null: anywhere);
  /// moves to the nearest such mark from here.
  void setWhere((Division, int)? place) {
    where = place;
    final cur = current;
    if (cur == null || !_matches(cur)) {
      final i = _find(0, 1);
      if (i >= 0) _go(i);
    }
    notifyListeners();
  }

  /// Marks the current mark fixed (in the review session) and moves on to
  /// the next one. Returns false if there was nothing to fix.
  bool markFixed() {
    final m = current;
    if (m == null || !m.type.fixable || store.isFixed(m)) return false;
    final op = store.setFixed(m, true, sessionId: sessionId);
    if (op == null) return false;
    _undo.add((op, _index));
    _fixedHere.add(m.id);
    if (!next()) notifyListeners();
    return true;
  }

  /// Whether the current item is a fluency mark (rated, not fixed).
  bool get onFluency => current?.type.isFluency ?? false;

  /// Rates the current fluency mark ([Recall]: read at once, slowly, or
  /// wrong) and moves on. Returns false if it isn't one.
  bool rate(Recall r) {
    final m = current;
    final f = fluency;
    if (m == null || f == null || !m.type.isFluency) return false;
    final mark = f.marks.where((x) => 'fl:${x.id}' == m.id).firstOrNull;
    if (mark == null) return false;
    f.rate(mark.cardId, r);
    if (!next()) notifyListeners();
    return true;
  }

  /// Undoes the last fix and goes back to its mark.
  void undo() {
    if (_undo.isEmpty) return;
    final (op, at) = _undo.removeLast();
    store.undo(op);
    if (at < _items.length) _fixedHere.remove(_items[at].id);
    _index = at;
    notifyListeners();
  }

  /// Ends the review (the session closes).
  void end() {
    if (!_active) return;
    _active = false;
    final sid = sessionId;
    if (sid != null) store.endSession(bookId, sid);
    notifyListeners();
  }
}
