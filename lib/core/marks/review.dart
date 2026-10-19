import 'package:flutter/foundation.dart';

import '../../data/divisions.dart';
import 'marks_model.dart';
import 'marks_store.dart';
import 'word_ref.dart';

/// Which marks are open (not fixed), fixed, or either.
enum ReviewStatus { open, fixed, any }

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

  const ReviewQuery({
    this.types = const {},
    this.status = ReviewStatus.open,
    this.division,
    this.number = 1,
    this.script = 'uthmani',
  });

  ReviewQuery copyWith({
    Set<MarkType>? types,
    ReviewStatus? status,
    Division? division,
    bool everywhere = false,
    int? number,
    String? script,
  }) =>
      ReviewQuery(
        types: types ?? this.types,
        status: status ?? this.status,
        division: everywhere ? null : division ?? this.division,
        number: number ?? this.number,
        script: script ?? this.script,
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
}) {
  final out = <Mark>[];
  for (final m in store.marksOf(bookId)) {
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

  final Set<String> _seen = {};
  final Set<String> _fixedHere = {};
  final List<(MarkOp, int)> _undo = [];
  bool _active = true;

  ReviewController({
    required this.store,
    required this.bookId,
    required this.query,
    required List<Mark> items,
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
  }) {
    final c = ReviewController(
      store: store,
      bookId: bookId,
      query: query,
      items: buildReviewQueue(store, bookId, query, pageOf: pageOf),
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

  bool _matches(Mark m) => only == null || m.type == only;

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
