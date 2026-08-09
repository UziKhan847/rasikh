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
  final List<(String, String, String)> moreExamples; // several, not just one

  const SmallLetter(this.id, this.name, this.note, this.mark, this.example,
      this.ref, this.highlight, [this.moreExamples = const []]);
}

const smallLetters = <SmallLetter>[
  SmallLetter('dagger_alif', 'Dagger Alif',
      'A tiny raised alif standing in for a full alif of madd — same sound, compact spelling. Very common: over 9,700 in the muṣḥaf. Read exactly like a full alif of madd: a plain two-count lengthening, no different from ا written full-size.',
      'ٰ', 'مَٰلِكِ', '1:4', 'مَٰ', [('ٱلرَّحۡمَٰنِ', '1:1', 'َٰ'), ('ٱلۡعَٰلَمِينَ', '1:2', 'َٰ'), ('ٱلصِّرَٰطَ', '1:6', 'َٰ'), ('صِرَٰطَ', '1:7', 'َٰ')]),
  SmallLetter('small_waw', 'Small Wāw',
      'A tiny wāw riding a ḍammah — a brief rounding of the vowel at word end, not a full extra count. Marks the ṣilah (connecting vowel) on a final هُ — the ḍammah is lightly rounded toward "ū" rather than cut short.',
      'ۥ', 'حَوۡلَهُۥ', '2:17', 'هُۥ', [('إِنَّهُۥ', '2:37', 'ُۥ'), ('وَرَحۡمَتُهُۥ', '2:64', 'ُۥ'), ('يُحَرِّفُونَهُۥ', '2:75', 'ُۥ'), ('عَهۡدَهُۥٓۖ', '2:80', 'ُۥ')]),
  SmallLetter('small_yeh', 'Small Yāʾ',
      'A tiny yāʾ riding a kasrah — the mirror of the small wāw, a brief rounding at word end. Marks the ṣilah (connecting vowel) on a final هِ — the kasrah is lightly extended toward "ī" rather than cut short.',
      'ۦ', 'بِهِۦ', '2:22', 'هِۦ', [('مِّثۡلِهِۦ', '2:23', 'ِۦ'), ('يَسۡتَحۡيِۦٓ', '2:26', 'ِۦ'), ('بِهِۦٓ', '2:26', 'ِۦ'), ('مِيثَٰقِهِۦ', '2:27', 'ِۦ')]),
];
