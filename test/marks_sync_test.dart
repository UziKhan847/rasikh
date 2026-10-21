import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/sync/memory_backend.dart';
import 'package:qiraah_arabiyyah/core/sync/sync_backend.dart';
import 'package:qiraah_arabiyyah/core/sync/sync_engine.dart';

/// One device: its own store and engine, talking to a shared server.
class _Device {
  final MarksStore store;
  final MemorySyncBackend backend;
  final SyncEngine engine;
  _Device._(this.store, this.backend, this.engine);

  static int _clock = DateTime(2026, 10, 1).millisecondsSinceEpoch;

  static Future<_Device> make(MemoryServer server) async {
    final store = MarksStore(
        persistence: MemoryMarksPersistence(),
        clock: () => _clock += 1000,
        saveDelay: const Duration(hours: 1));
    await store.load();
    final backend = MemorySyncBackend(server);
    final engine = SyncEngine(store: store, backend: backend);
    return _Device._(store, backend, engine);
  }

  void dispose() => engine.dispose();
}

const w1 = WordRef(2, 255, 3);
const w2 = WordRef(67, 1, 2);

void main() {
  late MemoryServer server;
  late _Device reciter, listener;

  setUp(() async {
    server = MemoryServer();
    reciter = await _Device.make(server);
    listener = await _Device.make(server);
  });

  tearDown(() {
    reciter.dispose();
    listener.dispose();
  });

  Future<String> sharedBook() async {
    await reciter.engine.signUp('zayd', 'pw-zayd-1', displayName: 'Zayd');
    final book = reciter.store.ensureActiveBook('Zayd').id;
    await reciter.engine.enableSync(book);
    final inv = await reciter.engine.invite(book, BookRole.listener);
    await listener.engine.signUp('ustadh', 'pw-ustadh-1', displayName: 'Ustadh');
    await listener.engine.join(inv.code);
    return book;
  }

  test('sign-up keeps the local id; a local book uploads with its marks',
      () async {
    final b = reciter.store.ensureActiveBook('Mine').id;
    reciter.store.addMark(b, w1, MarkType.mistake);
    await reciter.engine.signUp('zayd', 'pw-zayd-1');
    expect(reciter.engine.account!.id, reciter.store.me.id);
    await reciter.engine.enableSync(b);
    expect(server.tables['marks']!.values.single['author'],
        reciter.store.me.id);
    expect(reciter.store.dirtyRecords(b)['marks'], isEmpty);
    expect(reciter.engine.status, SyncStatus.idle);
  });

  test('a listener joins by code, marks; the reciter receives them', () async {
    final book = await sharedBook();
    expect(listener.store.book(book)!.myRole, BookRole.listener);
    expect(listener.store.activeBookId, book);

    final s = listener.store
        .startSession(bookId: book, script: 'indopak', listenerName: 'Ustadh');
    listener.store.toggle(book, w1, MarkType.doubt, sessionId: s.id);
    listener.store.addMark(book, w2, MarkType.tajwid, sessionId: s.id);
    await listener.engine.syncNow();
    await reciter.engine.syncNow();

    final got = reciter.store.marksAt(book, w1).single;
    expect(got.type, MarkType.doubt);
    expect(got.authorId, listener.engine.account!.id);
    expect(reciter.store.sessionsOf(book).single.listenerName, 'Ustadh');
    expect(reciter.store.marksAt(book, w2), hasLength(1));
  });

  test('a fix by the listener and a comment edit by the author both survive',
      () async {
    final book = await sharedBook();
    reciter.store.addMark(book, w1, MarkType.mistake);
    await reciter.engine.syncNow();
    await listener.engine.syncNow();

    // Concurrently: listener fixes it, reciter (author) comments on it.
    listener.store.fix(book, w1);
    final mine = reciter.store.marksAt(book, w1).single;
    reciter.store.setComment(mine, 'ā, not a');
    await listener.engine.syncNow();
    await reciter.engine.syncNow();
    await listener.engine.syncNow();

    for (final d in [reciter, listener]) {
      final m = d.store.marksAt(book, w1).single;
      expect(m.comment, 'ā, not a');
      expect(d.store.isFixed(m), isTrue);
    }
  });

  test('a listener cannot edit or delete the reciter\'s mark', () async {
    final book = await sharedBook();
    reciter.store.addMark(book, w1, MarkType.mistake);
    await reciter.engine.syncNow();
    await listener.engine.syncNow();

    final theirs = listener.store.marksAt(book, w1).single;
    listener.store.setType(theirs, MarkType.hesitation);
    await listener.engine.syncNow();
    expect(server.tables['marks']!.values.single['type'], 'mistake');
    // The refused edit isn't retried forever.
    expect(listener.store.dirtyRecords(book)['marks'], isEmpty);
  });

  test('checkers may comment but not mark', () async {
    await reciter.engine.signUp('zayd', 'pw-zayd-1');
    final book = reciter.store.ensureActiveBook('Zayd').id;
    reciter.store.addMark(book, w1, MarkType.mistake);
    await reciter.engine.enableSync(book);
    final inv = await reciter.engine.invite(book, BookRole.checker);
    final checker = await _Device.make(server);
    addTearDown(checker.dispose);
    await checker.engine.signUp('mum', 'pw-mum-123');
    await checker.engine.join(inv.code);
    expect(checker.store.book(book)!.myRole, BookRole.checker);

    final m = checker.store.marksAt(book, w1).single;
    checker.store.addComment(m, 'Practise this tonight');
    checker.store.addMark(book, w2, MarkType.mistake);
    await checker.engine.syncNow();
    await reciter.engine.syncNow();
    expect(reciter.store.commentsOn(reciter.store.marksAt(book, w1).single)
        .single.text, 'Practise this tonight');
    expect(reciter.store.marksAt(book, w2), isEmpty);
  });

  test('deletions propagate as tombstones; offline edits replay', () async {
    final book = await sharedBook();
    reciter.store.addMark(book, w1, MarkType.mistake);
    await reciter.engine.syncNow();
    await listener.engine.syncNow();
    expect(listener.store.marksAt(book, w1), hasLength(1));

    reciter.backend.offline = true;
    reciter.store.deleteMark(reciter.store.marksAt(book, w1).single);
    reciter.store.addMark(book, w2, MarkType.hesitation);
    await reciter.engine.syncNow();
    expect(reciter.engine.status, SyncStatus.offline);

    reciter.backend.offline = false;
    await reciter.engine.syncNow();
    await listener.engine.syncNow();
    expect(listener.store.marksAt(book, w1), isEmpty);
    expect(listener.store.marksAt(book, w2), hasLength(1));
  });

  test('pulling twice changes nothing (idempotent, overlapping cursor)',
      () async {
    final book = await sharedBook();
    reciter.store.addMark(book, w1, MarkType.mistake);
    await reciter.engine.syncNow();
    await listener.engine.syncNow();
    final v = listener.store.version;
    await listener.engine.syncNow();
    expect(listener.store.marksAt(book, w1), hasLength(1));
    // Only sync bookkeeping, no new data.
    expect(listener.store.marksOf(book).length, 1);
    expect(listener.store.version - v, lessThan(3));
  });

  test('live: the reciter sees a listener\'s mark without polling', () async {
    final book = await sharedBook();
    await reciter.engine.syncNow(); // starts watching the active book
    listener.store.addMark(book, w2, MarkType.doubt);
    await listener.engine.syncNow();
    await Future<void>.delayed(Duration.zero);
    expect(reciter.store.marksAt(book, w2), hasLength(1));
  });

  test('revoked access removes the book from the listener', () async {
    final book = await sharedBook();
    await reciter.engine
        .removeMember(book, listener.engine.account!.id);
    await listener.engine.syncNow();
    expect(listener.store.book(book), isNull);
  });

  test('deleting an account anonymises its marks in others\' books',
      () async {
    final book = await sharedBook();
    listener.store.addMark(book, w1, MarkType.doubt);
    await listener.engine.syncNow();
    await listener.engine.deleteAccount();
    expect(listener.engine.status, SyncStatus.signedOut);
    expect(listener.store.book(book), isNull);
    final row = server.tables['marks']!.values.single;
    expect(row['author'], '');
    expect(row['author_name'], 'Deleted user');
    await reciter.engine.syncNow();
    expect(reciter.store.marksAt(book, w1), hasLength(1));
  });

  test('mutashābih links sync, unlinking too', () async {
    final book = await sharedBook();
    reciter.store.addMark(book, w1, MarkType.mutashabih);
    final m = reciter.store.mutashabihatOf(book).single;
    reciter.store.toggleLink(m, w2);
    reciter.store.toggleLink(m, const WordRef(3, 2, 0));
    await reciter.engine.syncNow();
    await listener.engine.syncNow();
    final got = listener.store.mutashabihatOf(book).single;
    expect(listener.store.linksOf(got).map((l) => l.ref),
        [w2, const WordRef(3, 2, 0)]);

    reciter.store.toggleLink(m, w2);
    await reciter.engine.syncNow();
    await listener.engine.syncNow();
    expect(listener.store.linksOf(got).single.ref, const WordRef(3, 2, 0));
  });

  test('usernames are unique; wrong passwords fail', () async {
    await reciter.engine.signUp('zayd', 'pw-zayd-1');
    expect(() => listener.engine.signUp('zayd', 'x'),
        throwsA(isA<SyncException>()
            .having((e) => e.error, 'error', SyncError.taken)));
    expect(() => listener.engine.signIn('zayd', 'wrong'),
        throwsA(isA<SyncException>()
            .having((e) => e.error, 'error', SyncError.invalid)));
  });
}
