import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UthmanicHafs — the font every Uthmani-script data file renders with, via
/// `quranicStyle()` — covers every codepoint in the core Arabic block
/// (U+0600-U+06FF) *except* U+0622 ALEF WITH MADDA ABOVE, plus the
/// zero-width joining-control characters. Confirmed directly against the
/// bundled font file (`assets/fonts/UthmanicHafs.ttf`, dumped with
/// fontTools: `TTFont(...).getBestCmap()`).
///
/// U+0622 is not an arbitrary gap to work around — it is exactly the
/// precomposed character simplified (Imlāʾī) orthography uses for a
/// hamza-plus-madd alif, where Uthmani orthography always decomposes it into
/// hamza + fatḥah + a bare alif instead. A file in `lib/data/` using U+0622
/// is itself strong evidence of Imlāʾī (wrong-script) data — this test
/// caught exactly that bug once already (see the `maddah`/`madd4`/`madd6`
/// entries this pinned down in `tashkeel.dart`).
const _uthmanicHafsGaps = {0x0622};
const _zeroWidthControls = {0x200C, 0x200D, 0x200E, 0x200F};

bool _coveredByUthmanicHafs(int codepoint) {
  if (codepoint >= 0x0600 && codepoint <= 0x06FF) {
    return !_uthmanicHafsGaps.contains(codepoint);
  }
  return _zeroWidthControls.contains(codepoint);
}

void main() {
  test('every Arabic-range codepoint in lib/data/*.dart is covered by UthmanicHafs',
      () {
    final dataDir = Directory('lib/data');
    final files = dataDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty, reason: 'sanity check: lib/data/*.dart found');

    var checked = 0;
    for (final file in files) {
      final src = file.readAsStringSync();
      for (var i = 0; i < src.length; i++) {
        final cp = src.codeUnitAt(i);
        if (cp < 0x0600 || cp > 0x06FF) continue;
        checked++;
        expect(_coveredByUthmanicHafs(cp), isTrue,
            reason: '${file.path} contains U+${cp.toRadixString(16).toUpperCase()}, '
                'which UthmanicHafs has no glyph for — likely Imlāʾī '
                '(wrong-script) data. Context: '
                '"${src.substring((i - 8).clamp(0, src.length), (i + 8).clamp(0, src.length))}"');
      }
    }
    expect(checked, greaterThan(0),
        reason: 'sanity check: this test actually scanned some Arabic text');
  });
}
