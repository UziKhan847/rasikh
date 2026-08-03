import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';

/// Mirrors `QuranRepo._transcodeIndopak` (lib/data/quran.dart) — private, so
/// reimplemented here against the same map, same as [tajweed_data_test.dart]
/// reads asset JSON directly rather than reaching into private internals.
const _map = {'ۡ': 'ْ', '۠': '۟'};
String _transcode(String s) {
  var out = s;
  for (final e in _map.entries) {
    out = out.replaceAll(e.key, e.value);
  }
  return out;
}

/// The reader's Indo-Pak font (DigitalKhattIndoPak.otf) has no glyph for
/// U+06E1/U+06E0, the codepoints this text corpus uses for sukūn and one
/// small-mark variant — so they're transcoded to the codepoints the font
/// (and the 15-line muṣḥaf's own corpus) actually use. This must be a 1:1,
/// position-preserving substitution: tajwīd spans (assets/quran/t_indopak/)
/// are character offsets into this exact string, and word-by-word audio
/// alignment depends on [QuranRepo.tokenize] producing the same word count
/// before and after. A future edit to the glyph map that broke either
/// invariant would silently misalign tajwīd colors or word-sync audio, with
/// no visible error — this test is what would catch it.
void main() {
  test('Indo-Pak glyph transcode preserves length, tokenization, and word ranges',
      () {
    var checked = 0;
    for (var surah = 1; surah <= 114; surah++) {
      final ayahs = (jsonDecode(
              File('assets/quran/i/$surah.json').readAsStringSync()) as List)
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
        expect(t.contains('ۡ') || t.contains('۠'), isFalse,
            reason: 'surah $surah: a glyph DigitalKhattIndoPak has no glyph '
                'for survived the transcode');
        checked++;
      }
    }
    expect(checked, 6236, reason: 'sanity check on total āyah count covered');
  });
}
