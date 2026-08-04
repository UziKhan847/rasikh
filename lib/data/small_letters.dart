/// Small/superscript letters that stand for a sound but aren't full-size
/// consonants: the dagger alif (a compact madd alif), and the small wāw /
/// small yāʾ that ride a ḍammah or kasrah at a word's end. All three are
/// common in the muṣḥaf but were previously handled only as regex
/// diacritics-to-strip in quran.dart, never taught.
class SmallLetter {
  final String id;
  final String name;
  final String note;
  final String mark; // the combining character itself
  final String example; // verbatim Uthmani word
  final String ref; // surah:ayah
  final String highlight; // substring of example carrying the mark

  const SmallLetter(this.id, this.name, this.note, this.mark, this.example,
      this.ref, this.highlight);
}

const smallLetters = <SmallLetter>[
  SmallLetter('dagger_alif', 'Dagger Alif',
      'A tiny raised alif standing in for a full alif of madd — same sound, compact spelling. Very common: over 9,700 in the muṣḥaf.',
      'ٰ', 'مَٰلِكِ', '1:4', 'مَٰ'),
  SmallLetter('small_waw', 'Small Wāw',
      'A tiny wāw riding a ḍammah — a brief rounding of the vowel at word end, not a full extra count.',
      'ۥ', 'حَوۡلَهُۥ', '2:17', 'هُۥ'),
  SmallLetter('small_yeh', 'Small Yāʾ',
      'A tiny yāʾ riding a kasrah — the mirror of the small wāw, a brief rounding at word end.',
      'ۦ', 'بِهِۦ', '2:22', 'هِۦ'),
];
