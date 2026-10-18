/// Script-independent address of one Qur'anic word.
///
/// Words are numbered the way the 15-line muṣḥaf prints them (see
/// [MushafRepo]): the Madani and Indo-Pak texts agree on every āyah — 77,432
/// words in all — so a mark keyed by a [WordRef] lands on the same word in
/// both scripts. The numbering matches quran.com's word positions everywhere
/// except three āyahs; see qc_words.dart.
library;

/// The word-numbering scheme marks are stored in. Written into every marks
/// file and server book so a future renumbering can be migrated.
const wordScheme = 'mushaf15';

/// Āyahs per sūrah (Ḥafṣ, Kufan count), sūrah 1 first.
const surahAyahCounts = <int>[
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111,
  43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64,
  77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83,
  182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29,
  18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28,
  20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25,
  22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19,
  5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3,
  6, 3, 5, 4, 5, 6,
];

/// Global āyah index (0-based) of each sūrah's first āyah, plus a sentinel.
final List<int> _surahStart = () {
  final out = List<int>.filled(surahAyahCounts.length + 1, 0);
  for (var i = 0; i < surahAyahCounts.length; i++) {
    out[i + 1] = out[i] + surahAyahCounts[i];
  }
  return out;
}();

/// Total āyahs (6,236).
int get totalAyahs => _surahStart.last;

/// (sūrah, āyah) 1-based → global āyah index 0..6235.
int globalAyahIndex(int surah, int ayah) => _surahStart[surah - 1] + ayah - 1;

/// Global āyah index → (sūrah, āyah), both 1-based.
(int, int) surahAyahFromGlobal(int global) {
  var lo = 0, hi = surahAyahCounts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (_surahStart[mid] <= global) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return (lo + 1, global - _surahStart[lo] + 1);
}

class WordRef implements Comparable<WordRef> {
  final int surah; // 1..114
  final int ayah; // 1..n
  /// 1-based word in the āyah; 0 = the whole āyah (e.g. a skipped āyah).
  final int word;
  const WordRef(this.surah, this.ayah, this.word);

  /// From a muṣḥaf position: global āyah index + 0-based word index.
  factory WordRef.fromGlobal(int globalAyah, int word0) {
    final (s, a) = surahAyahFromGlobal(globalAyah);
    return WordRef(s, a, word0 + 1);
  }

  factory WordRef.fromKey(int key) =>
      WordRef(key ~/ 1000000, (key ~/ 1000) % 1000, key % 1000);

  /// Packed, sortable in muṣḥaf order: s*1e6 + a*1e3 + w.
  int get key => surah * 1000000 + ayah * 1000 + word;
  int get globalAyah => globalAyahIndex(surah, ayah);
  int get word0 => word - 1;
  bool get isWholeAyah => word == 0;

  /// The whole-āyah key for this word's āyah.
  WordRef get ayahRef => WordRef(surah, ayah, 0);

  @override
  int compareTo(WordRef other) => key.compareTo(other.key);
  @override
  bool operator ==(Object other) => other is WordRef && other.key == key;
  @override
  int get hashCode => key;
  @override
  String toString() => '$surah:$ayah:$word';
}
