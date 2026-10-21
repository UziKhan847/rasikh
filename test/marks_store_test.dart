import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';

class _Clock {
  int t = 1700000000000;
  int call() => t;
}

({MarksStore store, MemoryMarksPersistence files, _Clock clock}) _make(
    [MemoryMarksPersistence? files]) {
  final f = files ?? MemoryMarksPersistence();
  final c = _Clock();
  var n = 0;
  final s = MarksStore(
      persistence: f,
      clock: c.call,
      newId: () => 'id${(n++).toString().padLeft(13, '0')}',
      saveDelay: Duration.zero);
  return (store: s, files: f, clock: c);
}

const w1 = WordRef(2, 255, 3);
const w2 = WordRef(2, 255, 4);

void main() {
  test('first load creates an identity; ensureActiveBook makes a book',
      () async {
    final (:store, :files, clock: _) = _make();
    await store.load();
    expect(store.me.id, isNotEmpty);
    expect(store.activeBook, isNull);
    final b = store.ensureActiveBook('My recitation');
    expect(store.activeBookId, b.id);
    expect(store.ensureActiveBook('x').id, b.id);
    await store.flush();
    expect(files.files.keys, containsAll(['index.json', 'book_${b.id}.json']));
  });

  test('toggle: same pen in the same session removes; other pens stack',
      () async {
    final (:store, files: _, clock: _) = _make();
    await store.load();
    final b = store.ensureActiveBook('b').id;
    final s = store.startSession(bookId: b, script: 'uthmani').id;
    store.toggle(b, w1, MarkType.mistake, sessionId: s);
    expect(store.marksAt(b, w1), hasLength(1));
    store.toggle(b, w1, MarkType.mistake, sessionId: s);
    expect(store.marksAt(b, w1), isEmpty);
    store.toggle(b, w1, MarkType.hesitation, sessionId: s);
    store.toggle(b, w1, MarkType.doubt, sessionId: s);
    expect(store.marksAt(b, w1), hasLength(2));
    // Priority: doubt outranks hesitation.
    expect(store.visuals(b)[w1.key]!.open, MarkType.doubt);
    // A later session marking the same mistake again is a new mark.
    final s2 = store.startSession(bookId: b, script: 'indopak').id;
    store.toggle(b, w1, MarkType.doubt, sessionId: s2);
    expect(store.marksAt(b, w1), hasLength(3));
  });

  test('cycle: a tap steps the mark mistake → tajwīd → hesitation → doubt → off',
      () async {
    final (:store, files: _, clock: _) = _make();
    await store.load();
    final b = store.ensureActiveBook('b').id;
    final s = store.startSession(bookId: b, script: 'uthmani').id;
    final ops = <MarkOp>[];
    for (final want in [...MarkType.pens, null]) {
      final (op, type) = store.cycle(b, w1, sessionId: s);
      ops.add(op);
      expect(type, want);
      final marks = store.marksAt(b, w1);
      if (want == null) {
        expect(marks, isEmpty);
      } else {
        expect(marks.single.type, want, reason: 'one mark, re-typed');
      }
    }
    // Undo walks back through the same steps.
    for (final want in [...MarkType.pens.reversed]) {
      store.undo(ops.removeLast());
      expect(store.marksAt(b, w1).single.type, want);
    }

    // Another session's mark, and a fixed mark, are left alone: the tap
    // starts a fresh mark of this session's.
    final s2 = store.startSession(bookId: b, script: 'uthmani').id;
    store.cycle(b, w2, sessionId: s2);
    store.fix(b, w2, sessionId: s2);
    final (_, type) = store.cycle(b, w2, sessionId: s2);
    expect(type, MarkType.mistake);
    expect(store.marksAt(b, w2), hasLength(2));
    expect(store.cycle(b, w1, sessionId: s2).$2, MarkType.mistake);
    expect(store.marksAt(b, w1), hasLength(2));
  });

  test('fix promotes open marks; fixed shows when nothing else is open',
      () async {
    final (:store, files: _, :clock) = _make();
    await store.load();
    final b = store.ensureActiveBook('b').id;
    store.addMark(b, w1, MarkType.mistake);
    store.addMark(b, w1, MarkType.note, comment: 'watch the madd');
    clock.t += 1000;
    final op = store.fix(b, w1)!;
    expect(op.changes, hasLength(1)); // the note isn't fixable
    final v = store.visuals(b)[w1.key]!;
    expect(v.open, MarkType.note);
    expect(v.fixed, isTrue);
    expect(v.hasComment, isTrue);
    final m = store.marksAt(b, w1).first;
    expect(store.isFixed(m), isTrue);
    expect(store.fixOf(m)!.fixedAt, clock.t);
    expect(store.fix(b, w1), isNull); // nothing left to fix
    store.setFixed(m, false);
    expect(store.isFixed(m), isFalse);
    expect(store.visuals(b)[w1.key]!.open, MarkType.mistake);
    // showFixed=false hides a word whose only marks are fixed.
    store.addMark(b, w2, MarkType.tajwid);
    store.fix(b, w2);
    expect(store.visuals(b, showFixed: false).containsKey(w2.key), isFalse);
    expect(store.visuals(b)[w2.key]!.fixed, isTrue);
  });

  test('undo reverts add, delete, edits and fixes', () async {
    final (:store, files: _, :clock) = _make();
    await store.load();
    final b = store.ensureActiveBook('b').id;
    final add = store.addMark(b, w1, MarkType.mistake);
    store.undo(add);
    expect(store.marksAt(b, w1), isEmpty);
    store.addMark(b, w1, MarkType.mistake);
    final m = store.marksAt(b, w1).single;
    clock.t += 5;
    final edit = store.setComment(m, 'ā not a');
    expect(store.marksAt(b, w1).single.comment, 'ā not a');
    store.undo(edit);
    expect(store.marksAt(b, w1).single.comment, '');
    final fix = store.fix(b, w1)!;
    store.undo(fix);
    expect(store.isFixed(store.marksAt(b, w1).single), isFalse);
    final del = store.deleteMark(store.marksAt(b, w1).single);
    expect(store.marksAt(b, w1), isEmpty);
    store.undo(del);
    expect(store.marksAt(b, w1), hasLength(1));
  });

  test('synced records leave tombstones; local ones are dropped', () async {
    final (:store, files: _, clock: _) = _make();
    await store.load();
    final b = store.ensureActiveBook('b').id;
    store.addMark(b, w1, MarkType.mistake);
    store.deleteMark(store.marksAt(b, w1).single);
    expect(store.dirtyRecords(b)[MarkKinds.mark], isEmpty);
    store.setBookSynced(b, ownerAccountId: 'acct');
    store.addMark(b, w1, MarkType.mistake);
    store.deleteMark(store.marksAt(b, w1).single);
    final dirty = store.dirtyRecords(b)[MarkKinds.mark]!;
    expect(dirty.single.deleted, isTrue);
  });

  test('sessions idle for over 2 h close at their last activity', () async {
    final (:store, files: _, :clock) = _make();
    await store.load();
    final b = store.ensureActiveBook('b').id;
    final s = store.startSession(bookId: b, script: 'uthmani');
    clock.t += 60 * 1000;
    store.addMark(b, w1, MarkType.mistake, sessionId: s.id);
    final lastMark = clock.t;
    expect(store.openSession(b)?.id, s.id);
    clock.t += const Duration(hours: 3).inMilliseconds;
    expect(store.openSession(b), isNull);
    expect(store.session(b, s.id)!.endedAt, lastMark);
  });

  test('persists and reloads; a corrupt book file is set aside', () async {
    final (:store, :files, clock: _) = _make();
    await store.load();
    final b = store.ensureActiveBook('Zayd').id;
    store.startSession(bookId: b, script: 'indopak', kind: SessionKind.sabqi);
    store.addMark(b, w1, MarkType.doubt, comment: 'needed prompting');
    store.fix(b, w1);
    await store.flush();

    final again = _make(files).store;
    await again.load();
    expect(again.me.id, store.me.id);
    expect(again.activeBook!.name, 'Zayd');
    final m = again.marksAt(b, w1).single;
    expect(m.type, MarkType.doubt);
    expect(m.comment, 'needed prompting');
    expect(again.isFixed(m), isTrue);
    expect(again.sessionsOf(b).single.kind, SessionKind.sabqi);

    files.files['book_$b.json'] = '{not json';
    final third = _make(files).store;
    await third.load();
    expect(files.quarantined, ['book_$b.json']);
    expect(third.marksAt(b, w1), isEmpty);
    expect(third.book(b), isNotNull);
  });

  test('export → import into another device merges, idempotently', () async {
    final a = _make().store;
    await a.load();
    final b = a.ensureActiveBook('Student').id;
    a.addMark(b, w1, MarkType.mistake);
    a.addMark(b, w2, MarkType.tajwid);
    final payload =
        jsonDecode(jsonEncode(a.exportJson())) as Map<String, dynamic>;

    final other = _make().store;
    await other.load();
    final r1 = other.importJson(payload);
    expect(r1.added, 3); // the book + two marks
    expect(other.marksAt(b, w1), hasLength(1));
    final r2 = other.importJson(payload);
    expect(r2.changed, 0);
  });

  test('merge: newer remote wins, newer unpushed local edit is kept',
      () async {
    final (:store, files: _, :clock) = _make();
    await store.load();
    final b = store.ensureActiveBook('b').id;
    store.addMark(b, w1, MarkType.mistake);
    final m = store.marksAt(b, w1).single;
    final remote = Mark.fromJson({...m.toJson(), 'comment': 'from server'})
      ..clientUpdated = m.clientUpdated + 10;
    store.merge(ChangeSet(marks: [remote]), fromServer: true);
    expect(store.marksAt(b, w1).single.comment, 'from server');
    expect(store.marksAt(b, w1).single.dirty, isFalse);

    clock.t += 1000;
    store.setComment(store.marksAt(b, w1).single, 'local edit');
    final stale = Mark.fromJson({...m.toJson(), 'comment': 'stale'})
      ..clientUpdated = m.clientUpdated + 20;
    store.merge(ChangeSet(marks: [stale]), fromServer: true);
    expect(store.marksAt(b, w1).single.comment, 'local edit');
  });

  test('mutashābih links: toggle, show on both sides, persist, go with '
      'their mark, export and import', () async {
    final (:store, :files, :clock) = _make();
    await store.load();
    final b = store.ensureActiveBook('Me').id;
    const other = WordRef(3, 2, 1), ayah = WordRef(20, 8, 0);
    store.addMark(b, w1, MarkType.mutashabih, comment: 'The first has wāw');
    final m = store.mutashabihatOf(b).single;
    clock.t += 10;
    store.toggleLink(m, other);
    clock.t += 10;
    store.toggleLink(m, ayah);
    expect(store.linksOf(m).map((l) => l.ref), [other, ayah]);
    // The partners are drawn as mutashābih too.
    expect(store.visuals(b)[other.key]?.open, MarkType.mutashabih);
    expect(store.visuals(b)[ayah.key]?.open, MarkType.mutashabih);
    // Tapping a linked passage again unlinks it.
    store.toggleLink(m, ayah);
    expect(store.linksOf(m).map((l) => l.ref), [other]);
    expect(store.visuals(b)[ayah.key], isNull);

    await store.flush();
    final (store: again, files: _, clock: _) = _make(files);
    await again.load();
    final m2 = again.mutashabihatOf(b).single;
    expect(again.linksOf(m2).single.ref, other);

    final copy = jsonDecode(jsonEncode(again.exportJson())) as Map<String, dynamic>;
    final (store: fresh, files: _, clock: _) = _make();
    await fresh.load();
    fresh.importJson(copy);
    expect(fresh.linksOf(fresh.mutashabihatOf(b).single).single.ref, other);

    // Deleting the mark takes its links; undo brings them back.
    final op = again.deleteMark(m2);
    expect(again.linksOf(m2), isEmpty);
    expect(again.visuals(b)[other.key], isNull);
    again.undo(op);
    expect(again.linksOf(again.mutashabihatOf(b).single).single.ref, other);
  });
}
