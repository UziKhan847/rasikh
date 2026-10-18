import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';

/// The bug: وَٱدْعُوا۟ (2:23) shows the correct mark on its silent trailing
/// alif in the 15-line muṣḥaf but a stray-looking sukūn on it in the card
/// reader. The two views of the same muṣḥaf disagree because their two text
/// corpora encode "this letter is written but not pronounced" differently —
/// the reader's `assets/quran/u/` uses **U+0652 ARABIC SUKUN**, the muṣḥaf's
/// own corpus uses **U+06DF ARABIC SMALL HIGH ROUNDED ZERO**, Unicode's actual
/// mark for exactly this ("used in the Qurʼān to indicate a letter that is
/// not pronounced"). Sukūn means "no vowel on an otherwise pronounced
/// consonant" — wrong for a letter that isn't pronounced at all.
///
/// Mirrors `QuranRepo._fixSilentLetterMark` (lib/data/quran.dart) — private,
/// so reimplemented here against the same substitution, the same way
/// [indopak_transcode_test.dart] does for its transcode.
String _fix(String s) => s.replaceAll('ْ', '۟');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the reported word renders the silent-letter mark, not a sukūn',
      () async {
    final ayahs = await QuranRepo.ayahs(2, 'uthmani');
    final ayah23 = ayahs[22]; // 2:23, already fixed on load
    final word = ayah23.split(' ').firstWhere((w) => w.contains('دۡعُوا'));
    expect(word.contains('ْ'), isFalse,
        reason: 'the trailing alif of $word should not carry U+0652 SUKUN');
    expect(word.contains('۟'), isTrue,
        reason: 'the trailing alif of $word should carry U+06DF, matching '
            'the 15-line muṣḥaf');
  });

  test(
      'U+0652 never appears on ا, و or ي anywhere else — the substitution '
      'cannot misfire on a real sukūn', () async {
    // The corpus's regular sukūn on a real consonant is the entirely
    // separate U+06E1; confirmed once, offline, across the whole corpus, that
    // U+0652 there is used ONLY on these three weak letters, standing in for
    // a written-but-silent letter every time. If that ever stopped being
    // true — a future Tanzil update, say — this test is what would notice.
    for (var surah = 1; surah <= 114; surah++) {
      final raw = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      for (final ayah in raw) {
        for (var i = 0; i < ayah.length; i++) {
          if (ayah[i] != 'ْ') continue;
          final base = i > 0 ? ayah[i - 1] : '';
          expect('اوي'.contains(base), isTrue,
              reason: 'surah $surah: U+0652 sits on an unexpected base '
                  '${base.isEmpty ? '(none)' : base} — the blanket '
                  'substitution to U+06DF would be wrong here');
        }
      }
    }
  });

  test('the fix is 1:1 and length-preserving, like the Indo-Pak one',
      () async {
    var checked = 0;
    for (var surah = 1; surah <= 114; surah++) {
      final raw = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      for (final ayah in raw) {
        final fixed = _fix(ayah);
        expect(fixed.length, ayah.length);
        expect(QuranRepo.tokenize(fixed).length, QuranRepo.tokenize(ayah).length,
            reason: 'surah $surah: the fix must not desync word-by-word audio');
        expect(fixed.contains('ْ'), isFalse);
        checked++;
      }
    }
    expect(checked, 6236);
  });

  test('the fix applies everywhere Uthmani text loads, not just the reader',
      () async {
    // Not a font-compatibility question — every bundled Arabic face has real
    // glyphs for both marks — so the downloads manager, which never renders
    // through DigitalKhattV2, still needs the correct mark.
    final words = await QuranRepo.words(2, 'uthmani');
    final word = words[22].firstWhere((w) => w.contains('دۡعُوا'));
    expect(word.contains('ْ'), isFalse);
    expect(word.contains('۟'), isTrue);
  });
}
