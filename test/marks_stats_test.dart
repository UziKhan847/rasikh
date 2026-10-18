import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_model.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_stats.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';

void main() {
  test('counts by bucket, sūrah, juzʼ, page, session; problem words',
      () async {
    var t = DateTime(2026, 10, 1, 9).millisecondsSinceEpoch;
    final store = MarksStore(
        persistence: MemoryMarksPersistence(),
        clock: () => t,
        saveDelay: Duration.zero);
    await store.load();
    final b = store.ensureActiveBook('b').id;
    final s1 = store.startSession(
        bookId: b, script: 'uthmani', kind: SessionKind.sabaq);
    store.addMark(b, const WordRef(1, 2, 1), MarkType.mistake, sessionId: s1.id);
    store.addMark(b, const WordRef(1, 2, 1), MarkType.doubt, sessionId: s1.id);
    store.addMark(b, const WordRef(2, 3, 2), MarkType.tajwid, sessionId: s1.id);
    store.addMark(b, const WordRef(2, 3, 2), MarkType.note,
        sessionId: s1.id, comment: 'n');
    t += const Duration(days: 2).inMilliseconds;
    final s2 = store.startSession(
        bookId: b, script: 'uthmani', kind: SessionKind.sabqi);
    store.fix(b, const WordRef(1, 2, 1), sessionId: s2.id);
    store.addMark(b, const WordRef(30 + 48, 1, 1), MarkType.hesitation,
        sessionId: s2.id); // 78:1, juzʼ 30

    MarkStats run([MarkQuery q = const MarkQuery()]) => computeStats(
          marks: store.marksOf(b),
          fixes: store.fixesOf(b),
          sessions: store.sessionsOf(b),
          q: q,
          pageCount: 604,
          pageOf: (r) => r.surah == 1 ? 1 : (r.surah == 2 ? 2 : 582),
          juzOf: (s, a) => s == 78 ? 30 : 1,
        );

    final all = run();
    expect(all.total, 4); // notes excluded by default
    expect(all.fixed, 2);
    expect(all.open, 2);
    expect(all.fixRate, .5);
    expect(all.byBucket[statBuckets.length - 1], 2); // fixed bucket
    expect(all.byBucket[statBuckets.indexOf(MarkType.tajwid)], 1);
    expect(all.bySurah[0].reduce((a, b) => a + b), 2);
    expect(all.byJuz[29][statBuckets.indexOf(MarkType.hesitation)], 1);
    expect(all.byPage[0], 2);
    expect(all.byPage[581], 1);
    expect(all.sessions.map((s) => (s.marks, s.fixes)), [(3, 0), (1, 2)]);
    expect(all.problemWords.single.ref, const WordRef(1, 2, 1));
    expect(all.problemWords.single.open, isFalse);
    // Open marks over time: day 1 ends with 3 open, day 3 with 2.
    expect(all.openOverTime.map((e) => e.$2), [3, 2]);

    expect(run(const MarkQuery(status: MarkStatus.open)).total, 2);
    expect(run(const MarkQuery(kind: SessionKind.sabqi)).total, 1);
    expect(run(MarkQuery(since: t - 1000)).total, 1);
    expect(
        run(const MarkQuery(types: {MarkType.note})).byBucket[
            statBuckets.indexOf(MarkType.note)],
        1);
  });
}
