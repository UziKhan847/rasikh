import '../marks/marks_model.dart';
import '../marks/marks_store.dart';
import '../marks/word_ref.dart';

/// Local records ↔ server rows. Field names match the PocketBase
/// collections in server/pb_migrations. Optional ints travel as -1 (a
/// PocketBase number field can't be null), optional ids as ''.
abstract final class Wire {
  static const collections = MarkKinds.all; // sessions, marks, mark_fixes, mark_comments, mark_links

  static String? _id(Object? v) => v is String && v.isNotEmpty ? v : null;
  static int _int(Object? v) => (v as num?)?.toInt() ?? 0;
  static int? _opt(Object? v) {
    final i = (v as num?)?.toInt();
    return i == null || i < 0 ? null : i;
  }

  static Map<String, dynamic> _sync(SyncRecord r) => {
        'id': r.id,
        'client_updated': r.clientUpdated,
        'deleted': r.deleted,
      };

  static void _readSync(SyncRecord r, Map<String, dynamic> w) {
    r.clientUpdated = _int(w['client_updated']);
    r.deleted = w['deleted'] == true;
    r.serverUpdated = w['updated'] as String?;
    r.dirty = false;
  }

  // ── books ──

  static Map<String, dynamic> book(MarkBook b, String ownerId) => {
        ..._sync(b),
        'name': b.name,
        'owner': ownerId,
        'made_at': b.createdAt,
        'word_scheme': wordScheme,
      };

  /// [me] decides this device's role in the book.
  static MarkBook bookFrom(Map<String, dynamic> w, String me) {
    final owner = w['owner'] as String? ?? '';
    final listeners = (w['listeners'] as List? ?? const []).cast<String>();
    final checkers = (w['checkers'] as List? ?? const []).cast<String>();
    final role = owner == me
        ? BookRole.owner
        : checkers.contains(me) && !listeners.contains(me)
            ? BookRole.checker
            : BookRole.listener;
    return MarkBook(
      id: w['id'] as String,
      name: w['name'] as String? ?? '',
      createdAt: _int(w['made_at']),
      ownerAccountId: owner,
      myRole: role,
      synced: true,
      clientUpdated: 0,
    ).._readSyncBook(w);
  }

  // ── records ──

  static Map<String, dynamic> toWire(String kind, SyncRecord r) =>
      switch (kind) {
        MarkKinds.session => _session(r as RecitationSession),
        MarkKinds.mark => _mark(r as Mark),
        MarkKinds.fix => _fix(r as MarkFix),
        MarkKinds.link => _link(r as MarkLink),
        _ => _comment(r as MarkComment),
      };

  static SyncRecord fromWire(String kind, Map<String, dynamic> w) =>
      switch (kind) {
        MarkKinds.session => _sessionFrom(w),
        MarkKinds.mark => _markFrom(w),
        MarkKinds.fix => _fixFrom(w),
        MarkKinds.link => _linkFrom(w),
        _ => _commentFrom(w),
      };

  /// Rows of several kinds as one [ChangeSet].
  static ChangeSet changeSet(String kind, Iterable<Map<String, dynamic>> rows) {
    final recs = [for (final w in rows) fromWire(kind, w)];
    return switch (kind) {
      MarkKinds.session =>
        ChangeSet(sessions: recs.cast<RecitationSession>()),
      MarkKinds.mark => ChangeSet(marks: recs.cast<Mark>()),
      MarkKinds.fix => ChangeSet(fixes: recs.cast<MarkFix>()),
      MarkKinds.link => ChangeSet(links: recs.cast<MarkLink>()),
      _ => ChangeSet(comments: recs.cast<MarkComment>()),
    };
  }

  static Map<String, dynamic> _session(RecitationSession s) => {
        ..._sync(s),
        'book': s.bookId,
        'created_by': s.createdBy,
        'started_at': s.startedAt,
        'ended_at': s.endedAt ?? -1,
        'listener_name': s.listenerName,
        'kind': s.kind.code,
        'script': s.script,
        'from_ayah': s.fromGlobalAyah ?? -1,
        'to_ayah': s.toGlobalAyah ?? -1,
        'note': s.note,
      };

  static RecitationSession _sessionFrom(Map<String, dynamic> w) =>
      RecitationSession(
        id: w['id'] as String,
        bookId: w['book'] as String,
        createdBy: w['created_by'] as String? ?? '',
        startedAt: _int(w['started_at']),
        endedAt: _opt(w['ended_at']),
        listenerName: w['listener_name'] as String? ?? '',
        kind: SessionKind.fromCode(w['kind'] as String?),
        script: w['script'] as String? ?? 'uthmani',
        fromGlobalAyah: _opt(w['from_ayah']),
        toGlobalAyah: _opt(w['to_ayah']),
        note: w['note'] as String? ?? '',
        clientUpdated: 0,
      ).._readSyncRec(w);

  static Map<String, dynamic> _mark(Mark m) => {
        ..._sync(m),
        'book': m.bookId,
        'session': m.sessionId ?? '',
        'surah': m.ref.surah,
        'ayah': m.ref.ayah,
        'word': m.ref.word,
        // Its last word, for a mark over several (0 0 0: one word).
        'to_surah': m.to?.surah ?? 0,
        'to_ayah': m.to?.ayah ?? 0,
        'to_word': m.to?.word ?? 0,
        'type': m.type.code,
        'comment': m.comment,
        'author': m.authorId,
        'author_name': m.authorName,
        'made_at': m.createdAt,
      };

  static Mark _markFrom(Map<String, dynamic> w) => Mark(
        id: w['id'] as String,
        bookId: w['book'] as String,
        sessionId: _id(w['session']),
        ref: WordRef(_int(w['surah']), _int(w['ayah']), _int(w['word'])),
        to: _int(w['to_surah']) <= 0
            ? null
            : WordRef(_int(w['to_surah']), _int(w['to_ayah']), _int(w['to_word'])),
        type: MarkType.fromCode(w['type'] as String?),
        comment: w['comment'] as String? ?? '',
        authorId: w['author'] as String? ?? '',
        authorName: w['author_name'] as String? ?? '',
        createdAt: _int(w['made_at']),
        clientUpdated: 0,
      ).._readSyncRec(w);

  static Map<String, dynamic> _fix(MarkFix f) => {
        ..._sync(f),
        'book': f.bookId,
        'mark': f.markId,
        'session': f.sessionId ?? '',
        'fixed_by': f.fixedBy,
        'fixed_by_name': f.fixedByName,
        'fixed_at': f.fixedAt,
      };

  static MarkFix _fixFrom(Map<String, dynamic> w) => MarkFix(
        id: w['id'] as String,
        markId: w['mark'] as String? ?? '',
        bookId: w['book'] as String,
        sessionId: _id(w['session']),
        fixedBy: w['fixed_by'] as String? ?? '',
        fixedByName: w['fixed_by_name'] as String? ?? '',
        fixedAt: _int(w['fixed_at']),
        clientUpdated: 0,
      ).._readSyncRec(w);

  static Map<String, dynamic> _link(MarkLink l) => {
        ..._sync(l),
        'book': l.bookId,
        'mark': l.markId,
        'surah': l.ref.surah,
        'ayah': l.ref.ayah,
        'word': l.ref.word,
        'author': l.authorId,
        'made_at': l.createdAt,
      };

  static MarkLink _linkFrom(Map<String, dynamic> w) => MarkLink(
        id: w['id'] as String,
        markId: w['mark'] as String? ?? '',
        bookId: w['book'] as String,
        ref: WordRef(_int(w['surah']), _int(w['ayah']), _int(w['word'])),
        authorId: w['author'] as String? ?? '',
        createdAt: _int(w['made_at']),
        clientUpdated: 0,
      ).._readSyncRec(w);

  static Map<String, dynamic> _comment(MarkComment c) => {
        ..._sync(c),
        'book': c.bookId,
        'mark': c.markId,
        'author': c.authorId,
        'author_name': c.authorName,
        'text': c.text,
        'made_at': c.createdAt,
      };

  static MarkComment _commentFrom(Map<String, dynamic> w) => MarkComment(
        id: w['id'] as String,
        markId: w['mark'] as String? ?? '',
        bookId: w['book'] as String,
        authorId: w['author'] as String? ?? '',
        authorName: w['author_name'] as String? ?? '',
        text: w['text'] as String? ?? '',
        createdAt: _int(w['made_at']),
        clientUpdated: 0,
      ).._readSyncRec(w);
}

extension on SyncRecord {
  void _readSyncRec(Map<String, dynamic> w) => Wire._readSync(this, w);
  void _readSyncBook(Map<String, dynamic> w) => Wire._readSync(this, w);
}

/// PocketBase's datetime format ("2026-10-15 09:30:00.123Z").
String pbTime(DateTime t) =>
    t.toUtc().toIso8601String().replaceFirst('T', ' ');

/// The pull cursor rewound a few seconds: rows committed out of order around
/// the last pull are fetched again (merging is idempotent).
String? rewind(String? cursor, {Duration by = const Duration(seconds: 5)}) {
  if (cursor == null) return null;
  final t = DateTime.tryParse(cursor);
  return t == null ? null : pbTime(t.subtract(by));
}
