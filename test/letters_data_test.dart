import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';

/// [ArabicLetter.exampleWord] must be a verbatim substring of the bundled
/// Uthmani text at [ArabicLetter.exampleRef], and every
/// [letterExamples] word must be a verbatim substring of *some* āyah in the
/// bundled corpus (no single ref is tracked for these — any real occurrence
/// is a valid teaching example). Both were originally hand-typed in
/// simplified (Imlāʾī) orthography that never matched the Uthmani script the
/// rest of the app renders.
void main() {
  test('every exampleWord is a verbatim substring of its Uthmani āyah', () {
    for (final letter in letters) {
      final parts = letter.exampleRef.split(':');
      final surah = int.parse(parts[0]);
      final ayahNum = int.parse(parts[1]);
      final ayahs = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      final ayah = ayahs[ayahNum - 1];
      expect(ayah.contains(letter.exampleWord), isTrue,
          reason: 'Letter "${letter.char}" exampleWord '
              '(${letter.exampleRef}) is not a substring of the bundled '
              'Uthmani āyah.\n  exampleWord: ${letter.exampleWord}\n'
              '  āyah:        $ayah');
    }
  });

  test('every letterExamples word is a verbatim substring of some Uthmani āyah',
      () {
    // Build one big haystack of every ayah in the corpus once, rather than
    // re-reading 114 files per word.
    final buf = StringBuffer();
    for (var s = 1; s <= 114; s++) {
      final ayahs = (jsonDecode(
              File('assets/quran/u/$s.json').readAsStringSync()) as List)
          .cast<String>();
      buf.writeAll(ayahs);
    }
    final corpus = buf.toString();

    letterExamples.forEach((char, examples) {
      for (final ex in examples) {
        expect(corpus.contains(ex.word), isTrue,
            reason: 'Letter "$char" ${ex.position} example is not found in '
                'any bundled Uthmani āyah.\n  word: ${ex.word}');
      }
    });
  });
}
