/// Muṣḥaf ↔ quran.com word numbering.
///
/// The 15-line muṣḥaf's word numbering (both scripts) matches quran.com's in
/// 6,233 of 6,236 āyahs. In the other three quran.com treats بَعْدَ مَا as ONE
/// word where the muṣḥaf prints two. Word-by-word audio files and recitation
/// timings use quran.com positions, so they go through these helpers.
library;

/// Global āyah index → 0-based muṣḥaf index of بَعْدَ; the following مَا is
/// part of the same quran.com word.
const _joined = <int, int>{
  187: 2, // 2:181
  1165: 3, // 8:6
  1743: 7, // 13:37
};

/// 0-based muṣḥaf word → 0-based quran.com word.
int qcWordOf(int globalAyah, int word0) {
  final j = _joined[globalAyah];
  if (j == null || word0 <= j) return word0;
  return word0 - 1;
}

/// 0-based quran.com word → 0-based muṣḥaf word (the first of a joined pair).
int mushafWordOfQc(int globalAyah, int qc0) {
  final j = _joined[globalAyah];
  if (j == null || qc0 <= j) return qc0;
  return qc0 + 1;
}

/// The āyahs where the numbering differs (for tests and exports).
Iterable<int> get qcJoinedAyahs => _joined.keys;
