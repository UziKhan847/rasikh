import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/review.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/data/divisions.dart';

/// Review mode's queue (which marks, in what order) and its controller
/// (arrows by kind, fix-and-advance, undo, the review session).
Future<(MarksStore, String)> _store() async {
  final m = MarksStore(
      persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
  await m.load();
  final b = m.ensureActiveBook('Me').id;
  // Added out of order on purpose.
  m.addMark(b, const WordRef(2, 255, 3), MarkType.mistake);
  m.addMark(b, const WordRef(1, 2, 2), MarkType.doubt);
  m.addMark(b, const WordRef(2, 5, 1), MarkType.mistake);
  m.addMark(b, const WordRef(2, 30, 4), MarkType.tajwid);
  m.addMark(b, const WordRef(114, 1, 1), MarkType.note);
  m.addMark(b, const WordRef(2, 255, 3), MarkType.doubt);
  m.fix(b, const WordRef(2, 30, 4));
  return (m, b);
}

List<String> _refs(List<Mark> ms) =>
    [for (final m in ms) '${m.ref.surah}:${m.ref.ayah}:${m.ref.word} ${m.type.code}'];

void main() {
  test('the queue: muṣḥaf order, by kind, status and division', () async {
    final (m, b) = await _store();
    expect(_refs(buildReviewQueue(m, b, const ReviewQuery())), [
      '1:2:2 doubt',
      '2:5:1 mistake',
      '2:255:3 mistake',
      '2:255:3 doubt',
      '114:1:1 note',
    ]);
    expect(
        _refs(buildReviewQueue(
            m, b, const ReviewQuery(types: {MarkType.mistake}))),
        ['2:5:1 mistake', '2:255:3 mistake']);
    expect(
        _refs(buildReviewQueue(
            m, b, const ReviewQuery(status: ReviewStatus.fixed))),
        ['2:30:4 tajwid']);
    expect(
        buildReviewQueue(m, b, const ReviewQuery(status: ReviewStatus.any)),
        hasLength(6));
    expect(
        _refs(buildReviewQueue(m, b,
            const ReviewQuery(division: Division.juz, number: 3))),
        ['2:255:3 mistake', '2:255:3 doubt']);
    expect(
        _refs(buildReviewQueue(m, b,
            const ReviewQuery(division: Division.hizb, number: 1))),
        ['1:2:2 doubt', '2:5:1 mistake']);
    // Pages come from the caller (they depend on the script).
    expect(
        buildReviewQueue(m, b,
            const ReviewQuery(division: Division.page, number: 42),
            pageOf: (r) => r.surah == 2 && r.ayah == 255 ? 42 : 1),
        hasLength(2));
  });

  test('arrows by kind; fixing moves on; undo comes back', () async {
    final (m, b) = await _store();
    final c = ReviewController.start(m, b, const ReviewQuery());
    expect(c.length, 5);
    expect(c.sessionId, isNotNull);
    expect(m.session(b, c.sessionId!)!.kind, SessionKind.review);
    expect(c.current!.type, MarkType.doubt); // 1:2

    // Only mistakes: from the first item, the arrows find 2:5 then 2:255.
    c.setOnly(MarkType.mistake);
    expect(c.current!.ref, const WordRef(2, 5, 1));
    expect(c.next(), isTrue);
    expect(c.current!.ref, const WordRef(2, 255, 3));
    expect(c.next(), isFalse); // no more mistakes
    expect(c.prev(), isTrue);
    expect(c.current!.ref, const WordRef(2, 5, 1));

    // Fix it: recorded in the review session, and on to the next mistake.
    final fixedMark = c.current!;
    expect(c.markFixed(), isTrue);
    expect(m.isFixed(fixedMark), isTrue);
    expect(m.fixOf(fixedMark)!.sessionId, c.sessionId);
    expect(c.current!.ref, const WordRef(2, 255, 3));
    expect(c.fixedCount, 1);
    expect(c.openCount, 4);

    c.undo();
    expect(m.isFixed(fixedMark), isFalse);
    expect(c.current!.id, fixedMark.id);
    expect(c.fixedCount, 0);

    // Notes can't be fixed.
    c.setOnly(MarkType.note);
    expect(c.current!.type, MarkType.note);
    expect(c.markFixed(), isFalse);

    c.end();
    expect(m.session(b, c.sessionId!)!.endedAt, isNotNull);
    expect(c.active, isFalse);
  });

  test('an empty queue starts no session', () async {
    final (m, b) = await _store();
    final c = ReviewController.start(
        m, b, const ReviewQuery(types: {MarkType.hesitation}));
    expect(c.isEmpty, isTrue);
    expect(c.sessionId, isNull);
    expect(c.current, isNull);
    expect(c.next(), isFalse);
  });
}
