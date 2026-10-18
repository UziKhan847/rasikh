import 'card_align.g.dart';

/// The card reader's word numbering ↔ the muṣḥaf's (which marks use).
///
/// The reader shows the Tanzil text, which splits words differently from the
/// 15-line muṣḥaf in a few āyahs: لَّوۡمَا (15:7) is one card word but two
/// muṣḥaf words; in Indo-Pak the card text breaks words at an iqlāb mark
/// (اَنۭۡ بِئۡهُمۡ) where the muṣḥaf has one. Everywhere else they are 1:1.
/// Indices are 0-based; [globalAyah] is 0..6235.
Map<int, List<int>> _table(String script) =>
    script == 'indopak' ? cardAlignIndopak : cardAlignUthmani;

/// Muṣḥaf words (first, last) shown as card word [cardWord].
(int, int) cardToMushaf(String script, int globalAyah, int cardWord) {
  final t = _table(script)[globalAyah];
  if (t == null || cardWord * 2 + 1 >= t.length) return (cardWord, cardWord);
  return (t[cardWord * 2], t[cardWord * 2 + 1]);
}

/// Whether the two numberings differ in this āyah.
bool cardAlignDiffers(String script, int globalAyah) =>
    _table(script).containsKey(globalAyah);
