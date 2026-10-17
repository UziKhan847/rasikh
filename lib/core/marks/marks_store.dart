import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'marks_model.dart';
import 'marks_persistence.dart';
import 'word_ref.dart';

/// An undoable edit: every record it touched, as it was before.
class MarkOp {
  final String bookId;
  final List<(String kind, String id, Map<String, dynamic>? before)> changes;
  const MarkOp(this.bookId, this.changes);
  bool get isEmpty => changes.isEmpty;
}

/// Records arriving from elsewhere (the server, or a backup / shared file).
class ChangeSet {
  final List<MarkBook> books;
  final List<RecitationSession> sessions;
  final List<Mark> marks;
  final List<MarkFix> fixes;
  final List<MarkComment> comments;
  ChangeSet({
    this.books = const [],
    this.sessions = const [],
    this.marks = const [],
    this.fixes = const [],
    this.comments = const [],
  });
  bool get isEmpty =>
      books.isEmpty &&
      sessions.isEmpty &&
      marks.isEmpty &&
      fixes.isEmpty &&
      comments.isEmpty;
}

class MergeResult {
  int added = 0, updated = 0, kept = 0;
  int get changed => added + updated;
}

/// Kinds as used in [MarkOp] and in the sync layer.
abstract final class MarkKinds {
  static const session = 'sessions';
  static const mark = 'marks';
  static const fix = 'mark_fixes';
  static const comment = 'mark_comments';
  static const all = [session, mark, fix, comment];
}

class _BookData {
  MarkBook book;
  final sessions = <String, RecitationSession>{};
  final marks = <String, Mark>{};
  final fixes = <String, MarkFix>{};
  final comments = <String, MarkComment>{};

  /// Pull cursor per collection kind (opaque to the store).
  final cursors = <String, String>{};

  _BookData(this.book);

  // ── derived, rebuilt lazily after any change ──
  Map<int, List<Mark>>? _byWord;
  Map<String, MarkFix>? _fixByMark;
  final Map<bool, Map<int, MarkVisual>> _visuals = {};

  void invalidate() {
    _byWord = null;
    _fixByMark = null;
    _visuals.clear();
  }

  Map<int, List<Mark>> get byWord {
    final cached = _byWord;
    if (cached != null) return cached;
    final out = <int, List<Mark>>{};
    for (final m in marks.values) {
      if (m.deleted) continue;
      (out[m.ref.key] ??= []).add(m);
    }
    for (final l in out.values) {
      l.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return _byWord = out;
  }

  Map<String, MarkFix> get fixByMark {
    final cached = _fixByMark;
    if (cached != null) return cached;
    final out = <String, MarkFix>{};
    for (final f in fixes.values) {
      if (f.deleted) continue;
      final prev = out[f.markId];
      if (prev == null || f.fixedAt < prev.fixedAt) out[f.markId] = f;
    }
    return _fixByMark = out;
  }

  Map<String, Map<String, dynamic>> recordMap(String kind) => switch (kind) {
        MarkKinds.session => {
            for (final e in sessions.entries) e.key: e.value.toJson()
          },
        MarkKinds.mark => {for (final e in marks.entries) e.key: e.value.toJson()},
        MarkKinds.fix => {for (final e in fixes.entries) e.key: e.value.toJson()},
        _ => {for (final e in comments.entries) e.key: e.value.toJson()},
      };

  SyncRecord? find(String kind, String id) => switch (kind) {
        MarkKinds.session => sessions[id],
        MarkKinds.mark => marks[id],
        MarkKinds.fix => fixes[id],
        _ => comments[id],
      };

  void put(String kind, Map<String, dynamic> j) {
    switch (kind) {
      case MarkKinds.session:
        final r = RecitationSession.fromJson(j);
        sessions[r.id] = r;
      case MarkKinds.mark:
        final r = Mark.fromJson(j);
        marks[r.id] = r;
      case MarkKinds.fix:
        final r = MarkFix.fromJson(j);
        fixes[r.id] = r;
      default:
        final r = MarkComment.fromJson(j);
        comments[r.id] = r;
    }
  }

  void remove(String kind, String id) {
    switch (kind) {
      case MarkKinds.session:
        sessions.remove(id);
      case MarkKinds.mark:
        marks.remove(id);
      case MarkKinds.fix:
        fixes.remove(id);
      default:
        comments.remove(id);
    }
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'wordScheme': wordScheme,
        'sessions': [for (final r in sessions.values) r.toJson()],
        'marks': [for (final r in marks.values) r.toJson()],
        'fixes': [for (final r in fixes.values) r.toJson()],
        'comments': [for (final r in comments.values) r.toJson()],
        if (cursors.isNotEmpty) 'cursors': cursors,
      };

  void readJson(Map<String, dynamic> j) {
    for (final r in (j['sessions'] as List? ?? const [])) {
      put(MarkKinds.session, (r as Map).cast<String, dynamic>());
    }
    for (final r in (j['marks'] as List? ?? const [])) {
      put(MarkKinds.mark, (r as Map).cast<String, dynamic>());
    }
    for (final r in (j['fixes'] as List? ?? const [])) {
      put(MarkKinds.fix, (r as Map).cast<String, dynamic>());
    }
    for (final r in (j['comments'] as List? ?? const [])) {
      put(MarkKinds.comment, (r as Map).cast<String, dynamic>());
    }
    final c = j['cursors'];
    if (c is Map) cursors.addAll(c.cast<String, String>());
    invalidate();
  }
}

/// Every reciter's marks on this device: books, sessions, marks, fixes and
/// comments. Local-first — it works fully offline; the sync engine (if the
/// user signs in) pushes and merges through [merge] / [dirtyRecords].
class MarksStore extends ChangeNotifier {
  MarksStore({
    MarksPersistence? persistence,
    int Function()? clock,
    String Function()? newId,
    this.saveDelay = const Duration(milliseconds: 400),
  })  : _persist = persistence ?? MarksPersistence.platformDefault(),
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _newId = newId ?? newRecordId;

  final MarksPersistence _persist;
  final int Function() _clock;
  final String Function() _newId;
  final Duration saveDelay;

  /// A session with no marks for this long is treated as over.
  static const sessionIdle = Duration(hours: 2);

  static const _indexFile = 'index.json';
  static String _bookFile(String id) => 'book_$id.json';

  final Map<String, _BookData> _books = {};
  LocalIdentity _me = LocalIdentity(id: '');
  String? _activeBookId;
  bool _ready = false;
  int _version = 0;

  // pending writes
  final Set<String> _dirtyFiles = {};
  Timer? _saveTimer;
  Future<void>? _saving;

  bool get ready => _ready;

  /// Bumps on every change; a cheap memo key for derived data.
  int get version => _version;
  int now() => _clock();

  /// Called after every local edit (the sync engine listens to schedule a
  /// push for synced books).
  void Function(String bookId)? onLocalEdit;

  // ── load / save ────────────────────────────────────────────────────────

  Future<void> load() async {
    Map<String, dynamic>? index;
    final raw = await _persist.read(_indexFile);
    if (raw != null) {
      try {
        index = (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {
        await _persist.quarantine(_indexFile);
      }
    }
    if (index != null) {
      final me = index['me'];
      if (me is Map) _me = LocalIdentity.fromJson(me.cast<String, dynamic>());
      _activeBookId = index['active'] as String?;
      for (final b in (index['books'] as List? ?? const [])) {
        final book = MarkBook.fromJson((b as Map).cast<String, dynamic>());
        final data = _BookData(book);
        final braw = await _persist.read(_bookFile(book.id));
        if (braw != null) {
          try {
            data.readJson((jsonDecode(braw) as Map).cast<String, dynamic>());
          } catch (_) {
            await _persist.quarantine(_bookFile(book.id));
          }
        }
        _books[book.id] = data;
      }
    }
    if (_me.id.isEmpty) {
      _me = LocalIdentity(id: _newId());
      _dirtyFiles.add(_indexFile);
      _scheduleSave();
    }
    _ready = true;
    _version++;
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(flush()));
  }

  /// Write any pending changes now (app paused, tests).
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    while (_saving != null) {
      await _saving;
    }
    if (_dirtyFiles.isEmpty) return;
    final files = _dirtyFiles.toList();
    _dirtyFiles.clear();
    final done = Completer<void>();
    _saving = done.future;
    try {
      for (final f in files) {
        if (f == _indexFile) {
          await _persist.write(_indexFile, jsonEncode(_indexJson()));
        } else {
          final id = f.substring(5, f.length - 5); // book_<id>.json
          final data = _books[id];
          if (data == null) {
            await _persist.delete(f);
          } else {
            await _persist.write(f, jsonEncode(data.toJson()));
          }
        }
      }
    } finally {
      _saving = null;
      done.complete();
    }
  }

  Map<String, dynamic> _indexJson() => {
        'v': 1,
        'wordScheme': wordScheme,
        'me': _me.toJson(),
        if (_activeBookId != null) 'active': _activeBookId,
        'books': [for (final d in _books.values) d.book.toJson()],
      };

  void _changed(String? bookId, {bool index = false, bool local = true}) {
    _version++;
    if (bookId != null) {
      _books[bookId]?.invalidate();
      _dirtyFiles.add(_bookFile(bookId));
    }
    if (index) _dirtyFiles.add(_indexFile);
    _scheduleSave();
    notifyListeners();
    if (local && bookId != null) onLocalEdit?.call(bookId);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ── identity ───────────────────────────────────────────────────────────

  LocalIdentity get me => _me;

  /// The author id stamped on new records.
  String get authorId => _me.accountId ?? _me.id;

  void renameMe(String name) {
    _me.displayName = name.trim();
    _changed(null, index: true, local: false);
  }

  /// Signed in (or out). On first sign-in with a different account id, every
  /// record this device authored is re-stamped with the account id.
  void setAccount({String? accountId, String? username}) {
    final old = authorId;
    _me.accountId = accountId;
    _me.username = username;
    final neu = authorId;
    if (old != neu && accountId != null) {
      for (final d in _books.values) {
        var touched = false;
        for (final m in d.marks.values.toList()) {
          if (m.authorId == old) {
            d.marks[m.id] = Mark.fromJson({...m.toJson(), 'author': neu})
              ..dirty = true;
            touched = true;
          }
        }
        for (final f in d.fixes.values.toList()) {
          if (f.fixedBy == old) {
            d.fixes[f.id] = MarkFix.fromJson({...f.toJson(), 'by': neu})
              ..dirty = true;
            touched = true;
          }
        }
        for (final s in d.sessions.values.toList()) {
          if (s.createdBy == old) {
            d.sessions[s.id] =
                RecitationSession.fromJson({...s.toJson(), 'by': neu})
                  ..dirty = true;
            touched = true;
          }
        }
        if (touched) {
          d.invalidate();
          _dirtyFiles.add(_bookFile(d.book.id));
        }
      }
    }
    _changed(null, index: true, local: false);
  }

  // ── books ──────────────────────────────────────────────────────────────

  List<MarkBook> get books => [
        for (final d in _books.values)
          if (!d.book.deleted) d.book
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  MarkBook? book(String id) {
    final b = _books[id]?.book;
    return b == null || b.deleted ? null : b;
  }

  String? get activeBookId {
    final id = _activeBookId;
    if (id != null && book(id) != null) return id;
    final all = books;
    return all.isEmpty ? null : all.first.id;
  }

  MarkBook? get activeBook {
    final id = activeBookId;
    return id == null ? null : book(id);
  }

  /// The active book, creating a first one ([defaultName]) if there is none —
  /// no setup screen before the first mark.
  MarkBook ensureActiveBook(String defaultName) =>
      activeBook ?? createBook(defaultName);

  MarkBook createBook(String name, {bool activate = true}) {
    final t = now();
    final b = MarkBook(
        id: _newId(), name: name.trim(), createdAt: t, clientUpdated: t);
    _books[b.id] = _BookData(b);
    if (activate) _activeBookId = b.id;
    _changed(b.id, index: true);
    return b;
  }

  void renameBook(String id, String name) {
    final b = book(id);
    if (b == null) return;
    b.name = name.trim();
    b.touch(now());
    _changed(id, index: true);
  }

  void setActiveBook(String id) {
    if (book(id) == null || _activeBookId == id) return;
    _activeBookId = id;
    _changed(null, index: true, local: false);
  }

  /// Deletes a book and everything in it. A synced book leaves a tombstone so
  /// the sync engine can remove it on the server too.
  void deleteBook(String id) {
    final d = _books[id];
    if (d == null) return;
    if (d.book.synced) {
      d.book
        ..deleted = true
        ..touch(now());
      d.sessions.clear();
      d.marks.clear();
      d.fixes.clear();
      d.comments.clear();
      d.cursors.clear();
    } else {
      _books.remove(id);
    }
    if (_activeBookId == id) _activeBookId = null;
    _changed(id, index: true);
  }

  /// Drops a book from this device only (e.g. after leaving a shared book).
  void forgetBook(String id) {
    if (_books.remove(id) == null) return;
    if (_activeBookId == id) _activeBookId = null;
    _changed(id, index: true, local: false);
  }

  // ── sessions ───────────────────────────────────────────────────────────

  List<RecitationSession> sessionsOf(String bookId) => [
        for (final s in _books[bookId]?.sessions.values ?? const <RecitationSession>[])
          if (!s.deleted) s
      ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  RecitationSession? session(String bookId, String id) {
    final s = _books[bookId]?.sessions[id];
    return s == null || s.deleted ? null : s;
  }

  int _lastActivity(_BookData d, RecitationSession s) {
    var last = s.startedAt;
    for (final m in d.marks.values) {
      if (m.sessionId == s.id && m.createdAt > last) last = m.createdAt;
    }
    for (final f in d.fixes.values) {
      if (f.sessionId == s.id && f.fixedAt > last) last = f.fixedAt;
    }
    return last;
  }

  /// This device's open session in [bookId], if any. Sessions idle for over
  /// [sessionIdle] are closed here (at their last activity).
  RecitationSession? openSession(String bookId) {
    final d = _books[bookId];
    if (d == null) return null;
    RecitationSession? open;
    for (final s in d.sessions.values) {
      if (s.deleted || !s.isOpen || s.createdBy != authorId) continue;
      final last = _lastActivity(d, s);
      if (now() - last > sessionIdle.inMilliseconds) {
        s.endedAt = last;
        s.touch(now());
        d.invalidate();
        _dirtyFiles.add(_bookFile(bookId));
        _scheduleSave();
        continue;
      }
      if (open == null || s.startedAt > open.startedAt) open = s;
    }
    return open;
  }

  RecitationSession startSession({
    required String bookId,
    String listenerName = '',
    SessionKind kind = SessionKind.none,
    required String script,
  }) {
    final d = _books[bookId]!;
    final t = now();
    for (final s in d.sessions.values) {
      if (!s.deleted && s.isOpen && s.createdBy == authorId) {
        s.endedAt = t;
        s.touch(t);
      }
    }
    final s = RecitationSession(
      id: _newId(),
      bookId: bookId,
      createdBy: authorId,
      startedAt: t,
      listenerName: listenerName.trim(),
      kind: kind,
      script: script,
      clientUpdated: t,
    );
    d.sessions[s.id] = s;
    _changed(bookId);
    return s;
  }

  void endSession(String bookId, String id,
      {int? fromGlobalAyah, int? toGlobalAyah, String? note}) {
    final s = session(bookId, id);
    if (s == null) return;
    s.endedAt ??= now();
    if (fromGlobalAyah != null) s.fromGlobalAyah = fromGlobalAyah;
    if (toGlobalAyah != null) s.toGlobalAyah = toGlobalAyah;
    if (note != null) s.note = note.trim();
    s.touch(now());
    _changed(bookId);
  }

  void updateSession(String bookId, String id,
      {String? listenerName, SessionKind? kind, String? note}) {
    final s = session(bookId, id);
    if (s == null) return;
    if (listenerName != null) s.listenerName = listenerName.trim();
    if (kind != null) s.kind = kind;
    if (note != null) s.note = note.trim();
    s.touch(now());
    _changed(bookId);
  }

  void deleteSession(String bookId, String id) {
    final d = _books[bookId];
    final s = d?.sessions[id];
    if (d == null || s == null) return;
    _drop(d, MarkKinds.session, s);
    _changed(bookId);
  }

  // ── reading marks ──────────────────────────────────────────────────────

  Iterable<Mark> marksOf(String bookId) =>
      (_books[bookId]?.marks.values ?? const <Mark>[]).where((m) => !m.deleted);
  Iterable<MarkFix> fixesOf(String bookId) =>
      (_books[bookId]?.fixes.values ?? const <MarkFix>[]).where((f) => !f.deleted);
  Iterable<MarkComment> commentsOf(String bookId) =>
      (_books[bookId]?.comments.values ?? const <MarkComment>[])
          .where((c) => !c.deleted);

  /// Marks on one word (oldest first).
  List<Mark> marksAt(String bookId, WordRef ref) =>
      _books[bookId]?.byWord[ref.key] ?? const [];

  MarkFix? fixOf(Mark m) => _books[m.bookId]?.fixByMark[m.id];
  bool isFixed(Mark m) => fixOf(m) != null;

  List<MarkComment> commentsOn(Mark m) => [
        for (final c in _books[m.bookId]?.comments.values ?? const <MarkComment>[])
          if (!c.deleted && c.markId == m.id) c
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  bool hasMarks(String bookId) => marksOf(bookId).isNotEmpty;

  /// How each marked word in [bookId] should be drawn, by [WordRef.key].
  Map<int, MarkVisual> visuals(String bookId, {bool showFixed = true}) {
    final d = _books[bookId];
    if (d == null) return const {};
    final cached = d._visuals[showFixed];
    if (cached != null) return cached;
    final fixed = d.fixByMark;
    final out = <int, MarkVisual>{};
    d.byWord.forEach((key, list) {
      MarkType? open;
      var anyFixed = false, comment = false;
      for (final m in list) {
        if (m.comment.isNotEmpty || m.type == MarkType.note) comment = true;
        if (fixed.containsKey(m.id)) {
          anyFixed = true;
        } else if (open == null ||
            MarkVisual.priority.indexOf(m.type) <
                MarkVisual.priority.indexOf(open)) {
          open = m.type;
        }
      }
      if (open == null && !(anyFixed && showFixed)) return;
      out[key] = MarkVisual(
          open: open,
          fixed: anyFixed && showFixed,
          hasComment: comment,
          count: list.length);
    });
    d._visuals[showFixed] = out;
    return out;
  }

  // ── editing ────────────────────────────────────────────────────────────

  _BookData _data(String bookId) {
    final d = _books[bookId];
    if (d == null || d.book.deleted) {
      throw StateError('no such mark book: $bookId');
    }
    return d;
  }

  /// Delete: a record the server has seen becomes a tombstone (so the
  /// deletion syncs); one that never left this device is simply dropped.
  void _drop(_BookData d, String kind, SyncRecord r) {
    if (r.serverUpdated == null && !d.book.synced) {
      d.remove(kind, r.id);
    } else {
      r.deleted = true;
      r.touch(now());
    }
  }

  (String, String, Map<String, dynamic>?) _snap(
          _BookData d, String kind, String id) =>
      (kind, id, d.find(kind, id)?.toJson());

  /// Adds a mark of [type] on [ref] — or, if this same pen already marked
  /// this word in this session, takes that mark off again.
  MarkOp toggle(String bookId, WordRef ref, MarkType type,
      {String? sessionId}) {
    final d = _data(bookId);
    for (final m in d.byWord[ref.key] ?? const <Mark>[]) {
      if (m.type == type &&
          m.sessionId == sessionId &&
          m.authorId == authorId &&
          !d.fixByMark.containsKey(m.id)) {
        final op = MarkOp(bookId, [_snap(d, MarkKinds.mark, m.id)]);
        _drop(d, MarkKinds.mark, m);
        _changed(bookId);
        return op;
      }
    }
    return addMark(bookId, ref, type, sessionId: sessionId);
  }

  MarkOp addMark(String bookId, WordRef ref, MarkType type,
      {String? sessionId, String comment = ''}) {
    final d = _data(bookId);
    final t = now();
    final m = Mark(
      id: _newId(),
      bookId: bookId,
      sessionId: sessionId,
      ref: ref,
      type: type,
      comment: comment.trim(),
      authorId: authorId,
      authorName: _me.displayName,
      createdAt: t,
      clientUpdated: t,
    );
    d.marks[m.id] = m;
    _changed(bookId);
    return MarkOp(bookId, [(MarkKinds.mark, m.id, null)]);
  }

  /// Marks every open (unfixed) mark on [ref] as fixed. Null if none.
  MarkOp? fix(String bookId, WordRef ref, {String? sessionId}) {
    final d = _data(bookId);
    final changes = <(String, String, Map<String, dynamic>?)>[];
    final t = now();
    for (final m in d.byWord[ref.key] ?? const <Mark>[]) {
      if (!m.type.fixable || d.fixByMark.containsKey(m.id)) continue;
      final f = MarkFix(
        id: _newId(),
        markId: m.id,
        bookId: bookId,
        sessionId: sessionId,
        fixedBy: authorId,
        fixedByName: _me.displayName,
        fixedAt: t,
        clientUpdated: t,
      );
      d.fixes[f.id] = f;
      changes.add((MarkKinds.fix, f.id, null));
    }
    if (changes.isEmpty) return null;
    _changed(bookId);
    return MarkOp(bookId, changes);
  }

  /// Fix (or un-fix) one mark.
  MarkOp? setFixed(Mark m, bool fixed, {String? sessionId}) {
    final d = _data(m.bookId);
    if (fixed) {
      if (!m.type.fixable || d.fixByMark.containsKey(m.id)) return null;
      final t = now();
      final f = MarkFix(
        id: _newId(),
        markId: m.id,
        bookId: m.bookId,
        sessionId: sessionId,
        fixedBy: authorId,
        fixedByName: _me.displayName,
        fixedAt: t,
        clientUpdated: t,
      );
      d.fixes[f.id] = f;
      _changed(m.bookId);
      return MarkOp(m.bookId, [(MarkKinds.fix, f.id, null)]);
    }
    final changes = <(String, String, Map<String, dynamic>?)>[];
    for (final f in d.fixes.values.toList()) {
      if (f.markId != m.id || f.deleted) continue;
      changes.add(_snap(d, MarkKinds.fix, f.id));
      _drop(d, MarkKinds.fix, f);
    }
    if (changes.isEmpty) return null;
    _changed(m.bookId);
    return MarkOp(m.bookId, changes);
  }

  MarkOp setComment(Mark m, String text) => _editMark(m, (m) {
        m.comment = text.trim();
      });

  MarkOp setType(Mark m, MarkType type) => _editMark(m, (m) => m.type = type);

  MarkOp _editMark(Mark m, void Function(Mark) edit) {
    final d = _data(m.bookId);
    final op = MarkOp(m.bookId, [_snap(d, MarkKinds.mark, m.id)]);
    final live = d.marks[m.id];
    if (live == null) return const MarkOp('', []);
    edit(live);
    live.touch(now());
    _changed(m.bookId);
    return op;
  }

  MarkOp deleteMark(Mark m) {
    final d = _data(m.bookId);
    final live = d.marks[m.id];
    if (live == null) return const MarkOp('', []);
    final changes = [_snap(d, MarkKinds.mark, m.id)];
    for (final f in d.fixes.values.toList()) {
      if (f.markId == m.id && !f.deleted) {
        changes.add(_snap(d, MarkKinds.fix, f.id));
        _drop(d, MarkKinds.fix, f);
      }
    }
    _drop(d, MarkKinds.mark, live);
    _changed(m.bookId);
    return MarkOp(m.bookId, changes);
  }

  MarkComment addComment(Mark m, String text) {
    final d = _data(m.bookId);
    final t = now();
    final c = MarkComment(
      id: _newId(),
      markId: m.id,
      bookId: m.bookId,
      authorId: authorId,
      authorName: _me.displayName,
      text: text.trim(),
      createdAt: t,
      clientUpdated: t,
    );
    d.comments[c.id] = c;
    _changed(m.bookId);
    return c;
  }

  void deleteComment(MarkComment c) {
    final d = _data(c.bookId);
    _drop(d, MarkKinds.comment, c);
    _changed(c.bookId);
  }

  /// Reverts [op]: each touched record goes back to how it was (records the
  /// op created are removed again).
  void undo(MarkOp op) {
    if (op.isEmpty) return;
    final d = _books[op.bookId];
    if (d == null) return;
    for (final (kind, id, before) in op.changes.reversed) {
      final cur = d.find(kind, id);
      if (before == null) {
        if (cur != null) _drop(d, kind, cur);
      } else {
        d.put(kind, before);
        // Restoring is itself an edit that must win over the deletion.
        d.find(kind, id)!.touch(now());
      }
    }
    _changed(op.bookId);
  }

  // ── merge / sync support ───────────────────────────────────────────────

  /// Merges records from the server or a backup. Last writer wins on
  /// `clientUpdated`; a local copy with unpushed edits that are newer is kept.
  /// Idempotent: merging the same set twice changes nothing.
  MergeResult merge(ChangeSet cs, {bool fromServer = false}) {
    final res = MergeResult();
    final touched = <String>{};
    var index = false;
    for (final b in cs.books) {
      final cur = _books[b.id];
      if (cur == null) {
        if (b.deleted) continue;
        b.dirty = !fromServer;
        _books[b.id] = _BookData(b);
        res.added++;
        index = true;
      } else if (_wins(cur.book, b)) {
        b.dirty = !fromServer;
        cur.book = b;
        res.updated++;
        index = true;
      } else {
        if (fromServer) cur.book.serverUpdated ??= b.serverUpdated;
        res.kept++;
      }
    }
    void mergeKind(String kind, Iterable<SyncRecord> incoming) {
      for (final r in incoming) {
        final d = _books[r.bookId];
        if (d == null || d.book.deleted) continue;
        final cur = d.find(kind, r.id);
        if (cur == null) {
          if (r.deleted && !fromServer) continue;
          r.dirty = !fromServer;
          d.put(kind, r.toJson());
          res.added++;
          touched.add(r.bookId);
        } else if (_wins(cur, r)) {
          r.dirty = !fromServer;
          d.put(kind, r.toJson());
          res.updated++;
          touched.add(r.bookId);
        } else {
          if (fromServer && cur.serverUpdated == null) {
            cur.serverUpdated = r.serverUpdated;
            touched.add(r.bookId);
          }
          res.kept++;
        }
      }
    }

    mergeKind(MarkKinds.session, cs.sessions);
    mergeKind(MarkKinds.mark, cs.marks);
    mergeKind(MarkKinds.fix, cs.fixes);
    mergeKind(MarkKinds.comment, cs.comments);
    if (touched.isEmpty && !index) return res;
    _version++;
    for (final id in touched) {
      _books[id]?.invalidate();
      _dirtyFiles.add(_bookFile(id));
    }
    if (index) _dirtyFiles.add(_indexFile);
    _scheduleSave();
    notifyListeners();
    return res;
  }

  static bool _wins(SyncRecord local, SyncRecord incoming) {
    if (local.dirty && local.clientUpdated >= incoming.clientUpdated) {
      return false;
    }
    if (incoming.clientUpdated != local.clientUpdated) {
      return incoming.clientUpdated > local.clientUpdated;
    }
    // Same timestamp: identical content is a no-op; otherwise take the
    // incoming copy only if the local one has nothing unpushed.
    if (jsonEncode(local.toJson()..removeWhere(_syncKey)) ==
        jsonEncode(incoming.toJson()..removeWhere(_syncKey))) {
      return local.deleted != incoming.deleted;
    }
    return !local.dirty;
  }

  static bool _syncKey(String k, Object? _) =>
      k == 'su' || k == 'dirty' || k == 'cu';

  /// Records in [bookId] with unpushed edits, by kind.
  Map<String, List<SyncRecord>> dirtyRecords(String bookId) {
    final d = _books[bookId];
    if (d == null) return const {};
    return {
      MarkKinds.session: [...d.sessions.values.where((r) => r.dirty)],
      MarkKinds.mark: [...d.marks.values.where((r) => r.dirty)],
      MarkKinds.fix: [...d.fixes.values.where((r) => r.dirty)],
      MarkKinds.comment: [...d.comments.values.where((r) => r.dirty)],
    };
  }

  /// The server accepted [r] (as of [serverUpdated]); clear its dirty flag
  /// unless it was edited again meanwhile.
  void markPushed(String kind, String bookId, String id, int clientUpdated,
      String? serverUpdated) {
    final d = _books[bookId];
    final r = kind == 'books' ? d?.book : d?.find(kind, id);
    if (r == null) return;
    if (r.clientUpdated == clientUpdated) r.dirty = false;
    r.serverUpdated = serverUpdated ?? r.serverUpdated;
    _dirtyFiles.add(kind == 'books' ? _indexFile : _bookFile(bookId));
    _scheduleSave();
  }

  /// Marks a local book as synced (owned by [ownerAccountId]).
  void setBookSynced(String bookId, {required String ownerAccountId}) {
    final b = book(bookId);
    if (b == null) return;
    b.synced = true;
    b.ownerAccountId = ownerAccountId;
    b.touch(now());
    final d = _books[bookId]!;
    for (final kind in MarkKinds.all) {
      for (final id in d.recordMap(kind).keys) {
        d.find(kind, id)!.dirty = true;
      }
    }
    _changed(bookId, index: true);
  }

  /// Synced books, including deleted ones still to be removed on the server.
  List<MarkBook> get syncedBooks => [
        for (final d in _books.values)
          if (d.book.synced) d.book
      ];

  /// A book as the server lists it: added if new; its role, owner and (unless
  /// renamed here since) name brought up to date.
  void upsertRemoteBook(MarkBook remote) {
    final cur = _books[remote.id];
    if (cur == null) {
      _books[remote.id] = _BookData(remote..dirty = false);
    } else {
      final b = cur.book;
      if (b.deleted) return; // our deletion is on its way
      final before = jsonEncode(b.toJson());
      b
        ..synced = true
        ..myRole = remote.myRole
        ..ownerAccountId = remote.ownerAccountId;
      if (!b.dirty || remote.clientUpdated > b.clientUpdated) {
        b
          ..name = remote.name
          ..clientUpdated = remote.clientUpdated
          ..dirty = false;
      }
      b.serverUpdated = remote.serverUpdated;
      // Every sync poll lists the books: only a real change may notify
      // (and rebuild every screen showing marks).
      if (jsonEncode(b.toJson()) == before) return;
    }
    _version++;
    _dirtyFiles.add(_indexFile);
    _scheduleSave();
    notifyListeners();
  }

  /// Back to a local-only book (account deleted / signed out of a server):
  /// its data stays, sync state is cleared.
  void unsyncBook(String bookId) {
    final d = _books[bookId];
    if (d == null) return;
    if (d.book.deleted) {
      forgetBook(bookId);
      return;
    }
    d.book
      ..synced = false
      ..ownerAccountId = null
      ..myRole = BookRole.owner
      ..serverUpdated = null;
    for (final kind in MarkKinds.all) {
      for (final id in d.recordMap(kind).keys) {
        d.find(kind, id)!
          ..serverUpdated = null
          ..dirty = true;
      }
    }
    d.cursors.clear();
    _changed(bookId, index: true, local: false);
  }

  String? cursor(String bookId, String kind) => _books[bookId]?.cursors[kind];
  void setCursor(String bookId, String kind, String cursor) {
    final d = _books[bookId];
    if (d == null) return;
    d.cursors[kind] = cursor;
    _dirtyFiles.add(_bookFile(bookId));
    _scheduleSave();
  }

  // ── backup / share ─────────────────────────────────────────────────────

  /// Everything (or one book) as JSON, for backups and sharing a book file.
  Map<String, dynamic> exportJson({String? bookId}) => {
        'v': 1,
        'wordScheme': wordScheme,
        'books': [
          for (final d in _books.values)
            if (!d.book.deleted && (bookId == null || d.book.id == bookId))
              {'book': d.book.toJson(), ...d.toJson()..remove('cursors')}
        ],
      };

  /// Merges an [exportJson] payload (never replaces what's here).
  MergeResult importJson(Map<String, dynamic> j) {
    final books = <MarkBook>[];
    final sessions = <RecitationSession>[];
    final marks = <Mark>[];
    final fixes = <MarkFix>[];
    final comments = <MarkComment>[];
    for (final raw in (j['books'] as List? ?? const [])) {
      final b = (raw as Map).cast<String, dynamic>();
      books.add(MarkBook.fromJson((b['book'] as Map).cast<String, dynamic>())
        ..synced = false);
      for (final r in (b['sessions'] as List? ?? const [])) {
        sessions.add(RecitationSession.fromJson((r as Map).cast()));
      }
      for (final r in (b['marks'] as List? ?? const [])) {
        marks.add(Mark.fromJson((r as Map).cast()));
      }
      for (final r in (b['fixes'] as List? ?? const [])) {
        fixes.add(MarkFix.fromJson((r as Map).cast()));
      }
      for (final r in (b['comments'] as List? ?? const [])) {
        comments.add(MarkComment.fromJson((r as Map).cast()));
      }
    }
    // A book we already have keeps its own sync state.
    for (final b in books) {
      final cur = _books[b.id]?.book;
      if (cur != null) {
        b
          ..synced = cur.synced
          ..ownerAccountId = cur.ownerAccountId
          ..myRole = cur.myRole;
      }
    }
    return merge(ChangeSet(
        books: books,
        sessions: sessions,
        marks: marks,
        fixes: fixes,
        comments: comments));
  }
}

/// Puts the [MarksStore] in the widget tree.
class MarksScope extends InheritedNotifier<MarksStore> {
  const MarksScope({super.key, required MarksStore store, required super.child})
      : super(notifier: store);

  /// Null where no store is provided (e.g. widget tests of other screens):
  /// marks UI then simply doesn't show.
  static MarksStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarksScope>()?.notifier;

  static MarksStore of(BuildContext context) => maybeOf(context)!;
}
