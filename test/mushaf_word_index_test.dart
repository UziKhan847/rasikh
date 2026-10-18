import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/core/marks/qc_words.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';

/// Word marks are keyed by (sūrah, āyah, word) and must land on the same word
/// in the Madani and the Indo-Pak muṣḥaf. That only holds while both texts
/// number their words identically — guard it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
    await MushafRepo.ensure('indopak');
  });

  test('both scripts: 77,432 words, identical per-āyah counts', () {
    var u = 0, i = 0;
    for (var g = 0; g <= MushafRepo.lastGlobalAyah; g++) {
      final cu = MushafRepo.wordCount('uthmani', g);
      final ci = MushafRepo.wordCount('indopak', g);
      expect(cu, ci, reason: 'āyah $g');
      u += cu;
      i += ci;
    }
    expect(u, 77432);
    expect(i, 77432);
  });

  test('a ۞-prefixed word is a real word, not an āyah marker', () {
    // 2:26 begins '۞إِنَّ' in the Uthmani text.
    final g = MushafRepo.globalAyahOf(2, 26);
    expect(MushafRepo.wordText('uthmani', g, 0), startsWith('۞'));
    var seen = 0;
    for (var p = 1; p <= MushafRepo.pageCountSync('uthmani'); p++) {
      for (final ln in MushafRepo.pageSync('uthmani', p)!) {
        for (final w in ln.words) {
          if (w.text.contains('۞')) {
            expect(w.isMarker, isFalse, reason: w.text);
            seen++;
          }
          if (w.isMarker) expect(w.text, startsWith('۝'));
        }
      }
    }
    expect(seen, 199);
  });

  test('pageOfWord: in range, never decreasing, consistent with pages', () {
    for (final script in ['uthmani', 'indopak']) {
      final total = MushafRepo.pageCountSync(script);
      expect(total, script == 'uthmani' ? 604 : 610);
      var last = 1;
      for (var g = 0; g <= MushafRepo.lastGlobalAyah; g++) {
        for (var w = 0; w < MushafRepo.wordCount(script, g); w++) {
          final p = MushafRepo.pageOfWord(script, g, w);
          expect(p, inInclusiveRange(last, total));
          last = p;
        }
      }
      // Every printed word reports the page it is printed on.
      for (final p in [1, 2, 50, 300, total]) {
        for (final ln in MushafRepo.pageSync(script, p)!) {
          for (final wd in ln.words.where((w) => !w.isMarker)) {
            expect(MushafRepo.pageOfWord(script, wd.ayah, wd.wordIdx), p);
            expect(MushafRepo.wordText(script, wd.ayah, wd.wordIdx), wd.text);
          }
        }
      }
    }
  });

  test('āyah-count table matches meta.json; WordRef round-trips', () async {
    final meta = jsonDecode(await rootBundle.loadString('assets/quran/meta.json'))
        as List;
    expect([for (final m in meta) m['ayahs'] as int], surahAyahCounts);
    expect(totalAyahs, 6236);
    for (final g in [0, 6, 7, 293, 1165, 6235]) {
      final (s, a) = surahAyahFromGlobal(g);
      expect(MushafRepo.surahAyahOf(g), (s, a));
      expect(globalAyahIndex(s, a), g);
    }
    const r = WordRef(2, 255, 3);
    expect(WordRef.fromKey(r.key), r);
    expect(WordRef.fromGlobal(r.globalAyah, 2), r);
    expect(const WordRef(2, 255, 3).key < const WordRef(2, 256, 1).key, isTrue);
    expect(const WordRef(114, 6, 0).key < const WordRef(114, 6, 1).key, isTrue);
  });

  test('quran.com numbering differs only where بَعْدَ مَا is one word', () {
    expect(qcJoinedAyahs.map(surahAyahFromGlobal).toList(),
        [(2, 181), (8, 6), (13, 37)]);
    for (final g in qcJoinedAyahs) {
      final n = MushafRepo.wordCount('uthmani', g);
      final j = [
        for (var w = 0; w < n; w++)
          if (MushafRepo.wordText('uthmani', g, w).startsWith('بَعْدَ')) w
      ].single;
      expect(qcWordOf(g, j), qcWordOf(g, j + 1)); // بَعْدَ مَا → one word
      expect(qcWordOf(g, n - 1), n - 2);
      expect(mushafWordOfQc(g, qcWordOf(g, n - 1)), n - 1);
    }
    expect(qcWordOf(0, 3), 3);
  });
}
