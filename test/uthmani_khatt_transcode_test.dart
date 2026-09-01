import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';

/// Mirrors `QuranRepo._transcodeUthmaniKhatt` (lib/data/quran.dart) — private,
/// so reimplemented here against the same map, the same way
/// [indopak_transcode_test.dart] does for the Indo-Pak one.
const _map = {'ٗ': 'ࣰ', 'ٞ': 'ࣱ', 'ٖ': 'ࣲ', 'ۤ': 'ٓ'};
String _transcode(String s) {
  var out = s;
  for (final e in _map.entries) {
    out = out.replaceAll(e.key, e.value);
  }
  return out;
}

/// DigitalKhattV2.otf — the 15-line muṣḥaf's Uthmani face, and now the card
/// reader's second Madani choice — has no glyph for the four marks the Tanzil
/// Uthmani corpus uses for the open tanwīn and the small high madda, so they
/// are transcoded to the codepoints the font (and the muṣḥaf's own corpus)
/// actually carry.
///
/// This must be a 1:1, position-preserving substitution: tajwīd spans
/// (assets/quran/t/) are character offsets into this exact string, and
/// word-by-word audio alignment depends on [QuranRepo.tokenize] producing the
/// same word count before and after. A future edit to the glyph map that broke
/// either invariant would silently misalign tajwīd colors or word-sync audio,
/// with no visible error — this test is what would catch it.
void main() {
  test('Uthmani→DigitalKhatt transcode preserves length, tokens, word ranges',
      () {
    var checked = 0, substituted = 0;
    for (var surah = 1; surah <= 114; surah++) {
      final ayahs = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      for (final ayah in ayahs) {
        final t = _transcode(ayah);
        expect(t.length, ayah.length,
            reason: 'surah $surah: transcode changed character count');
        expect(QuranRepo.tokenize(t).length, QuranRepo.tokenize(ayah).length,
            reason: 'surah $surah: transcode changed word count — this '
                'would desync word-by-word audio');
        expect(QuranRepo.wordRanges(t), QuranRepo.wordRanges(ayah),
            reason: 'surah $surah: transcode moved a word boundary — this '
                'would misalign tajwīd spans');
        for (final bad in _map.keys) {
          expect(t.contains(bad), isFalse,
              reason: 'surah $surah: a codepoint DigitalKhattV2 has no glyph '
                  'for survived the transcode');
        }
        for (final ch in ayah.split('')) {
          if (_map.containsKey(ch)) substituted++;
        }
        checked++;
      }
    }
    expect(checked, 6236, reason: 'sanity check on total āyah count covered');
    // Measured against the corpus: 2901 + 1807 + 1935 + 26. Pinned so a map
    // that silently stopped matching (a normalisation change upstream, say)
    // fails loudly instead of quietly rendering nothing.
    expect(substituted, 6669);
  });

  test('the small high madda substitution is confined to the sajdah verses',
      () {
    // The one row of the map that is an approximation rather than an exact
    // re-encoding (U+06E4 -> U+0653, a full-size maddah for a small high one),
    // so what it touches is worth stating explicitly.
    final hits = <String>[];
    for (var surah = 1; surah <= 114; surah++) {
      final ayahs = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      for (var i = 0; i < ayahs.length; i++) {
        if (ayahs[i].contains('ۤ')) hits.add('$surah:${i + 1}');
      }
    }
    expect(hits, [
      '7:206', '13:15', '16:49', '17:107', '19:58', '22:18', '22:77',
      '25:60', '27:25', '32:15', '38:24', '41:37', '53:62', '84:21', '96:19',
    ]);
  });
}
