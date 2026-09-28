import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/data/word_pool.dart';

/// The tamrīn helper: real words filtered by which mark they carry, WITH the
/// coordinates their own recording needs — unlike [quranicExampleWords]'s
/// pool, which carries none.
void main() {
  // A tiny hand-built corpus: surah -> ayahs -> words, mirroring
  // QuranRepo.words's own shape.
  final corpus = {
    1: [
      ['بِسۡمِ', 'ٱللَّهِ', 'ٱلرَّحۡمَٰنِ'], // sukūn (سۡ), shaddah (لَّ, رَّ)
      [
        'قُلۡ',
        'هُوَ',
        'ٱللَّهُ',
        'أَحَدٌ',
      ], // sukūn (لۡ), shaddah (لَّ), damma (دٌ has no plain damma… ), fatha
    ],
    2: [
      ['خَلَقَ'], // two fatḥahs, no sukūn/shaddah
    ],
  };

  group('kidsMarkHighlightIn', () {
    test('finds the mark and includes its base letter', () {
      expect(kidsMarkHighlightIn('sukun', 'بِسۡمِ'), 'سۡ');
      expect(kidsMarkHighlightIn('shadda', 'ٱللَّهِ'), 'لَّ');
      expect(kidsMarkHighlightIn('fatha', 'خَلَقَ'), 'خَ');
    });

    test('returns empty when the word does not carry the mark', () {
      expect(kidsMarkHighlightIn('sukun', 'خَلَقَ'), isEmpty);
      expect(kidsMarkHighlightIn('shadda', 'خَلَقَ'), isEmpty);
    });

    test('an unsupported mark id (a tanwīn) returns empty, never throws', () {
      expect(kidsMarkHighlightIn('fathatan', 'رَغَدًا'), isEmpty);
    });

    test('the highlight is always a real substring of the word', () {
      for (final ayahs in corpus.values) {
        for (final ayah in ayahs) {
          for (final w in ayah) {
            for (final id in ['fatha', 'kasra', 'damma', 'sukun', 'shadda']) {
              final hl = kidsMarkHighlightIn(id, w);
              if (hl.isEmpty) continue;
              expect(w.contains(hl), isTrue, reason: '$id in $w -> $hl');
            }
          }
        }
      }
    });
  });

  group('kidsWordsWithMark', () {
    test('only returns words that actually carry one of the marks', () {
      final words = kidsWordsWithMark(
        corpus,
        const ['sukun'],
        math.Random(1),
        count: 20,
      );
      expect(words, isNotEmpty);
      for (final w in words) {
        expect(
          kidsMarkHighlightIn('sukun', w.word),
          isNotEmpty,
          reason: w.word,
        );
      }
    });

    test('carries real (surah, ayah, index) coordinates', () {
      final words = kidsWordsWithMark(
        corpus,
        const ['shadda'],
        math.Random(1),
        count: 20,
      );
      for (final w in words) {
        final ayahs = corpus[w.surah]!;
        expect(w.ayah, inInclusiveRange(1, ayahs.length));
        final wordsInAyah = ayahs[w.ayah - 1];
        expect(w.index, inInclusiveRange(1, wordsInAyah.length));
        // The coordinate really points AT this word.
        expect(wordsInAyah[w.index - 1], w.word);
      }
    });

    test('mixing several mark ids draws from all of them (OR, not AND)', () {
      final words = kidsWordsWithMark(
        corpus,
        const ['fatha', 'sukun', 'shadda'],
        math.Random(1),
        count: 20,
      );
      final ids = <String>{};
      for (final w in words) {
        for (final id in ['fatha', 'sukun', 'shadda']) {
          if (kidsMarkHighlightIn(id, w.word).isNotEmpty) ids.add(id);
        }
      }
      expect(ids.length, greaterThan(1));
    });

    test('never returns the same word twice in one round', () {
      final words = kidsWordsWithMark(
        corpus,
        const ['fatha', 'sukun', 'shadda', 'damma', 'kasra'],
        math.Random(2),
        count: 50,
      );
      expect(words.map((w) => w.word).toSet().length, words.length);
    });

    test('respects count, and returns fewer if the corpus has fewer', () {
      final words = kidsWordsWithMark(
        corpus,
        const ['sukun'],
        math.Random(1),
        count: 2,
      );
      expect(words.length, lessThanOrEqualTo(2));
    });

    test('an empty corpus or an unmatched mark gives an empty list, not a '
        'crash', () {
      expect(kidsWordsWithMark({}, const ['sukun'], math.Random()), isEmpty);
      expect(
        kidsWordsWithMark(corpus, const ['fathatan'], math.Random()),
        isEmpty,
      );
    });
  });
}
