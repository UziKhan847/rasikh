import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Glyph-coverage guard for **DigitalKhattV2.otf**, the 15-line muṣḥaf's
/// Uthmani face and the card reader's second Madani choice.
///
/// The sibling test [quranic_font_coverage_test.dart] pins UthmanicHafs
/// against `lib/data/`; nothing guarded either DigitalKhatt face, and they are
/// far sparser — **90 codepoints** against UthmanicHafs' 608, because they were
/// cut for one specific muṣḥaf corpus rather than for Arabic in general. A mark
/// outside that set renders as nothing at all, silently.
///
/// This is what makes `QuranRepo._transcodeUthmaniKhatt` necessary rather than
/// cosmetic: as shipped, `assets/quran/u/` carries 6,669 characters this font
/// cannot draw. The test asserts the transcode closes the gap completely.
///
/// The cmap below is the font's own, dumped with fontTools
/// (`TTFont('assets/fonts/DigitalKhattV2.otf').getBestCmap()`) and folded into
/// runs — the same "constant derived offline, with its provenance recorded"
/// pattern the UthmanicHafs test uses, since fontTools is not reachable from a
/// Dart test. Regenerate it if the font is ever replaced.
const _digitalKhattV2Cmap = <(int, int)>[
  (0x000a, 0x000a), (0x0020, 0x0020), (0x034f, 0x034f), (0x0621, 0x063a),
  (0x0640, 0x0655), (0x065c, 0x065c), (0x0660, 0x0669), (0x0670, 0x0671),
  (0x06d6, 0x06e3), (0x06e5, 0x06e9), (0x06ec, 0x06ed), (0x08f0, 0x08f3),
  (0x200d, 0x200d),
];

bool _covered(int cp) {
  for (final (a, b) in _digitalKhattV2Cmap) {
    if (cp >= a && cp <= b) return true;
  }
  return false;
}

const _map = {'ٗ': 'ࣰ', 'ٞ': 'ࣱ', 'ٖ': 'ࣲ', 'ۤ': 'ٓ'};
String _transcode(String s) {
  // The silent-letter fix (`_fixSilentLetterMark`) runs on every Uthmani
  // load, before the DigitalKhatt-specific map below — mirrored here so this
  // simulates the actual text DigitalKhattV2 receives, not an intermediate
  // form it never sees.
  var out = s.replaceAll('ْ', '۟');
  for (final e in _map.entries) {
    out = out.replaceAll(e.key, e.value);
  }
  return out;
}

/// U+2009 THIN SPACE, one occurrence, inside a word in 2:72. Missing from
/// UthmanicHafs too, so it is not something switching face introduced — and it
/// is whitespace, so it costs a space, not a letter. Listed here rather than
/// silently skipped: see the note in `quran_screen.dart` about the same
/// character desyncing `wordRanges` from `tokenize` in that āyah.
const _knownGaps = {0x2009};

void main() {
  test('the transcoded Uthmani corpus is fully covered by DigitalKhattV2', () {
    final missing = <int, int>{};
    var checked = 0;
    for (var surah = 1; surah <= 114; surah++) {
      final ayahs = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      for (final ayah in ayahs) {
        for (final cp in _transcode(ayah).runes) {
          checked++;
          if (!_covered(cp) && !_knownGaps.contains(cp)) {
            missing[cp] = (missing[cp] ?? 0) + 1;
          }
        }
      }
    }
    expect(checked, greaterThan(300000), reason: 'sanity: corpus was read');
    expect(
        missing,
        isEmpty,
        reason: 'DigitalKhattV2 has no glyph for '
            '${missing.keys.map((c) => 'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')}').join(', ')} '
            '— either the transcode map or this cmap needs updating');
  });

  test('without the transcode the same corpus is NOT covered', () {
    // The guard on the guard: if this ever passes, the transcode has become a
    // no-op and the test above is proving nothing.
    final missing = <int>{};
    for (var surah = 1; surah <= 114; surah++) {
      final ayahs = (jsonDecode(
              File('assets/quran/u/$surah.json').readAsStringSync()) as List)
          .cast<String>();
      for (final ayah in ayahs) {
        for (final cp in ayah.runes) {
          if (!_covered(cp) && !_knownGaps.contains(cp)) missing.add(cp);
        }
      }
    }
    expect(missing, {0x0656, 0x0657, 0x065E, 0x06E4});
  });
}
