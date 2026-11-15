import 'package:flutter_test/flutter_test.dart';
import 'package:rasikh/core/audio.dart';

/// Real payloads from
/// `api.quran.com/api/v4/recitations/{7|6}/by_chapter/2?fields=segments`.
/// Each row is `[segmentIdx0, wordPos1Based, startMs, endMs]` — the segment
/// index is NOT the word index (see 2:20 below), which is what this pins down.
void main() {
  group('AyahAudio.normaliseSegments', () {
    test('single-word verse (2:1 muqattaʿāt) keeps its one segment', () {
      // Regression: the old parser read segmentIdx 0 as "word position 0",
      // dropped the row, returned null, and the UI claimed the timings were
      // unavailable offline.
      final segs = AyahAudio.normaliseSegments([
        [0, 1, 30, 7080],
      ]);
      expect(segs, isNotNull);
      expect(segs, hasLength(1));
      expect(segs!.first, [0, 30, 7080]);
    });

    test('every word of 2:2 gets a segment, including the last', () {
      final segs = AyahAudio.normaliseSegments([
        [0, 1, 150, 860],
        [1, 2, 870, 1820],
        [2, 3, 1830, 2130],
        [3, 4, 2140, 2680],
        [4, 5, 2690, 4980],
        [5, 6, 4990, 5180],
        [6, 7, 5190, 8610],
      ]);
      expect(segs, hasLength(7)); // was 6 — the first row used to be dropped
      expect(segs!.first, [0, 150, 860]);
      expect(segs.last, [6, 5190, 8610]); // the 7th word now exists
    });

    test('word position wins over segment index when they diverge (2:20)', () {
      // The reciter ran words 6 and 7 together: segment 5 carries word 7 and
      // there is no segment 6. Keying off the segment index would drift every
      // later word one place early.
      final segs = AyahAudio.normaliseSegments([
        [4, 5, 4100, 6280],
        [5, 7, 6290, 9760],
        [7, 8, 9770, 10240],
      ]);
      expect(segs!.map((s) => s[0]), [4, 6, 7]);
    });

    test('legacy 3-element rows still parse as [wordPos, start, end]', () {
      final segs = AyahAudio.normaliseSegments([
        [1, 150, 860],
        [2, 870, 1820],
      ]);
      expect(segs, hasLength(2));
      expect(segs!.first, [0, 150, 860]);
    });

    test('malformed and zero-length rows are skipped', () {
      expect(AyahAudio.normaliseSegments([
        [0],
        'nonsense',
        [0, 1, 500, 500], // end == start
      ]), isNull);
    });
  });

  group('AyahAudio.wordAt', () {
    final alafasy22 = AyahAudio.normaliseSegments([
      [0, 1, 150, 860],
      [1, 2, 870, 1820],
      [2, 3, 1830, 2130],
      [3, 4, 2140, 2680],
      [4, 5, 2690, 4980],
      [5, 6, 4990, 5180],
      [6, 7, 5190, 8610],
    ]);

    int at(int ms) =>
        AyahAudio.wordAtIn(alafasy22, Duration(milliseconds: ms));

    test('nothing is lit before the first word starts', () {
      expect(at(0), -1);
      expect(at(100), -1);
    });

    test('walks the verse word by word', () {
      expect(at(500), 0);
      expect(at(1000), 1);
      expect(at(3000), 4);
    });

    test('the last word holds through the trailing silence', () {
      expect(at(6000), 6);
      expect(at(8610), 6);
      expect(at(99000), 6);
    });

    test('a word stays lit across an inter-word gap', () {
      // Ḥuṣarī 2:2 pauses 6100→7300 ms between words 4 and 5.
      final husary = AyahAudio.normaliseSegments([
        [3, 4, 3750, 6100],
        [4, 5, 7300, 7860],
      ]);
      expect(AyahAudio.wordAtIn(husary, const Duration(milliseconds: 6700)), 3);
      expect(AyahAudio.wordAtIn(husary, const Duration(milliseconds: 7300)), 4);
    });

    test('no timings means no highlight', () {
      expect(AyahAudio.wordAtIn(null, const Duration(milliseconds: 500)), -1);
    });
  });
}
