import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/core/marks/card_align.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';

/// card_align.g.dart (from tools/marks/gen_card_align.py) must agree with the
/// app's own tokenizer and the muṣḥaf data: a mark made in the card reader
/// lands on the right muṣḥaf word and vice versa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
    await MushafRepo.ensure('indopak');
  });

  for (final script in ['uthmani', 'indopak']) {
    test('$script: every āyah is 1:1 or has a covering alignment', () async {
      var differ = 0;
      for (var s = 1; s <= 114; s++) {
        // Both faces the reader can use tokenize the same way.
        for (final font in ['UthmanicHafs', 'DigitalKhattV2']) {
          if (script == 'indopak' && font == 'DigitalKhattV2') continue;
          final words = await QuranRepo.words(s, script, font: font);
          for (var a = 0; a < words.length; a++) {
            final g = globalAyahIndex(s, a + 1);
            final card = words[a].length;
            final m = MushafRepo.wordCount(script, g);
            if (!cardAlignDiffers(script, g)) {
              expect(card, m, reason: '$script $s:${a + 1}');
              continue;
            }
            if (font == 'UthmanicHafs') differ++;
            var next = 0;
            for (var w = 0; w < card; w++) {
              final (first, last) = cardToMushaf(script, g, w);
              expect(first, lessThanOrEqualTo(last));
              // Contiguous: each card word starts where the last ended (or
              // on the same muṣḥaf word, when the card splits one).
              expect(first, inInclusiveRange(next - 1, next),
                  reason: '$script $s:${a + 1} word $w');
              next = last + 1;
            }
            expect(next, m, reason: '$script $s:${a + 1} covers all words');
          }
        }
      }
      expect(differ, script == 'uthmani' ? 7 : 87);
    });
  }

  test('known cases', () {
    // 15:7 لَّوۡمَا → لَّوْ مَا
    expect(cardToMushaf('uthmani', globalAyahIndex(15, 7), 0), (0, 1));
    expect(cardToMushaf('uthmani', globalAyahIndex(15, 7), 1), (2, 2));
    // 37:130 إِلۡ | يَاسِينَ → إِلْ يَاسِينَ
    expect(cardToMushaf('uthmani', globalAyahIndex(37, 130), 2), (2, 2));
    expect(cardToMushaf('uthmani', globalAyahIndex(37, 130), 3), (2, 2));
    expect(cardToMushaf('uthmani', 0, 3), (3, 3));
  });
}
