import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/review.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/sync/wire.dart';
import 'package:rasikh/data/divisions.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/ui/bidi.dart';

/// One mark over many words; reviewing by place; Arabic inline in comments.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
  });
  tearDown(() => MarksStore.ayahWords = (_) => -1);

  Future<(MarksStore, String)> store() async {
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    return (m, m.ensureActiveBook('Me').id);
  }

  group('one mark over many words', () {
    test('across āyāt: on every word between, as one mark', () async {
      MarksStore.ayahWords = (g) => MushafRepo.wordCount('uthmani', g);
      final (m, b) = await store();
      // 2:255's last two words to 2:256's third.
      final n255 = MushafRepo.wordCount('uthmani', MushafRepo.globalAyahOf(2, 255));
      final from = WordRef(2, 255, n255 - 1), to = const WordRef(2, 256, 3);
      m.addMark(b, from, MarkType.mistake, to: to);
      expect(m.marksOf(b), hasLength(1), reason: 'one mark');
      for (final w in [from, WordRef(2, 255, n255), const WordRef(2, 256, 1), to]) {
        expect(m.marksAt(b, w), hasLength(1), reason: '${w.surah}:${w.ayah}:${w.word}');
      }
      expect(m.marksAt(b, const WordRef(2, 256, 4)), isEmpty);
      expect(m.marksAt(b, WordRef(2, 255, n255 - 2)), isEmpty);
      expect(m.visuals(b).length, 5, reason: "two words of 2:255, three of 2:256");
      // A step on any of its words steps it, the whole of it.
      m.cycle(b, const WordRef(2, 256, 1));
      expect(m.marksOf(b).single.type, isNot(MarkType.mistake));
    });

    test('before the text is loaded: on its ends, then on all once it is', () async {
      final (m, b) = await store();
      m.addMark(b, const WordRef(2, 255, 50), MarkType.mistake, to: const WordRef(2, 256, 2));
      expect(m.marksAt(b, const WordRef(2, 256, 1)), isEmpty);
      expect(m.marksAt(b, const WordRef(2, 256, 2)), hasLength(1));
      MarksStore.ayahWords = (g) => MushafRepo.wordCount('uthmani', g);
      m.respan();
      expect(m.marksAt(b, const WordRef(2, 256, 1)), hasLength(1));
    });

    test('kept, and sent and received, with its last word', () async {
      final (m, b) = await store();
      m.addMark(b, const WordRef(3, 7, 2), MarkType.tajwid, to: const WordRef(3, 7, 5));
      final mark = m.marksOf(b).single;
      final back = Mark.fromJson(mark.toJson());
      expect(back.to, const WordRef(3, 7, 5));
      final wire = Wire.fromWire(MarkKinds.mark, {
        ...Wire.toWire(MarkKinds.mark, mark),
        'id': mark.id,
      }) as Mark;
      expect(wire.to, const WordRef(3, 7, 5));
      // One word: no end.
      m.addMark(b, const WordRef(3, 8, 1), MarkType.mistake, to: const WordRef(3, 8, 1));
      expect(m.marksAt(b, const WordRef(3, 8, 1)).single.to, isNull);
    });
  });

  test('review by place: the arrows step only through the sūrah (juzʼ, '
      'manzil…) chosen, and its places are listed with counts', () async {
    final (m, b) = await store();
    m.addMark(b, const WordRef(2, 10, 1), MarkType.mistake);
    m.addMark(b, const WordRef(2, 20, 1), MarkType.mistake);
    m.addMark(b, const WordRef(18, 60, 2), MarkType.tajwid);
    m.addMark(b, const WordRef(36, 1, 1), MarkType.mistake);
    final c = ReviewController.start(m, b, const ReviewQuery(), session: false);
    expect(c.placesOf(Division.surah), [(2, 2), (18, 1), (36, 1)]);
    expect(c.placesOf(Division.manzil).map((e) => e.$1), containsAll([1, 4, 5]));
    c.setWhere((Division.surah, 18));
    expect(c.current!.ref, const WordRef(18, 60, 2));
    expect(c.hasNext, isFalse);
    expect(c.hasPrev, isFalse);
    c.setWhere((Division.juz, 1));
    expect(c.current!.ref.surah, 2);
    expect(c.next(), isTrue);
    expect(c.current!.ref, const WordRef(2, 20, 1));
    expect(c.hasNext, isFalse);
    c.setWhere(null);
    expect(c.hasNext, isTrue);
  });

  test('Arabic in an English comment stays in its place', () {
    const s = 'Read النور 2 times, then الرحمن.';
    final out = isolateArabic(s);
    expect(out, 'Read \u2067النور\u2069 2 times, then \u2067الرحمن\u2069.');
    expect(directionOf(s), TextDirection.ltr);
    expect(directionOf('هنا mistake'), TextDirection.rtl);
    expect(isolateArabic('كله عربي'), 'كله عربي', reason: 'all Arabic: as it is');
    expect(isolateArabic('all English'), 'all English');
  });
}
