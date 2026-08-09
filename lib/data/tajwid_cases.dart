/// Special tajwīd cases tied to a specific, exact spot in the muṣḥaf — each
/// found mechanically by a unique codepoint (see test/tajwid_symbols_data_test.dart),
/// not chosen by hand. Saktah and "sīn written over ṣād" share one codepoint
/// (U+06DC); they're told apart by what precedes the mark — ص for the sīn/ṣād
/// case, anything else for saktah. Several cases occur at more than one spot in
/// the muṣḥaf (5 saktahs, 3 sīn/ṣād spots, 2 al-ān verses) — those are ONE entry
/// each with [moreExamples] holding the rest, not near-duplicate entries; the
/// truly unique cases (ishmām, tashīl, imālah, the single-nūn spelling) are
/// exactly that — one real occurrence in the whole muṣḥaf, shown honestly rather
/// than padded.
class TajwidCase {
  final String id;
  final String name;
  final String arabicName;
  final String note;
  final String example;
  final String ref;
  final String highlight;
  final List<(String, String, String)> moreExamples;

  const TajwidCase(this.id, this.name, this.arabicName, this.note, this.example,
      this.ref, this.highlight, [this.moreExamples = const []]);
}

const tajwidCases = <TajwidCase>[
  TajwidCase('saktah', 'Saktah', 'سَكْتَة',
      'A brief pause, without breaking waḍū’ or breath, marked at five places in this muṣḥaf — no ghunnah, no vowel, just silence.', 'عِوَجَاۜ', '18:1', 'اۜ', [('مَّرۡقَدِنَاۜۗ', '36:52', 'اۜ'), ('مَالِيَهۡۜ', '69:28', 'ۡۜ'), ('مَنۡۜ', '75:27', 'ۡۜ'), ('بَلۡۜ', '83:14', 'ۡۜ')]),
  TajwidCase('sin_over_sad', 'Sīn Written Over Ṣād', 'السِّين فَوْقَ الصَّاد',
      'A small سۜ above the ص marks a letter that some early reciters read as س — both pronunciations are valid; Ḥafṣ reads it as ص.', 'وَيَبۡصُۜطُ', '2:245', 'صۜ', [('بَصۜۡطَةٗۖ', '7:69', 'صۜ'), ('ٱلۡمُصَۜيۡطِرُونَ', '52:37', 'صۜ')]),
  TajwidCase('al_an', 'The Exceptional Word al-Ān', 'ءَآلۡـَٰٔنَ',
      'Ishmām is recited on this word’s first hamzah in both its occurrences — an irregular spelling classical tajwīd singles out by name.', 'ءَآلۡـَٰٔنَ', '10:51', 'ـَٔ', [('ءَآلۡـَٰٔنَ', '10:91', 'ـَٔ')]),
  TajwidCase('ishmam', 'Ishmām', 'إِشْمَام',
      'Rounding the lips (silently) toward ḍammah right after pronouncing a sākin letter with sukūn — a trace of a vowel that isn’t voiced.', 'تَأۡمَ۬نَّا', '12:11', 'َ۬'),
  TajwidCase('tashil', 'Tashīl', 'تَسْهِيل',
      'Softening a second hamzah between two hamzahs in the same word — neither a full hamzah nor a full vowel, something in between.', 'ءَا۬عۡجَمِيّٞ', '41:44', 'ا۬'),
  TajwidCase('imalah', 'Imālah', 'إِمَالَة',
      'Leaning a fatḥah toward a kasrah, and the alif after it toward a yā’ — the one word in the muṣḥaf marked this way: مَجْرَاهَا in Sūrat Hūd.', 'مَجۡرٜىٰهَا', '11:41', 'رٜ'),
  TajwidCase('single_nun', 'The Doubled Nūn Written Once', 'إِخْفَاء بِغُنَّة (نُنجِى)',
      'ننجى is spelled with a single ن carrying a small نۨ above it standing in for the second — one of the muṣḥaf’s rare compressed spellings.', 'نُـۨجِي', '21:88', 'ـۨج'),
];
