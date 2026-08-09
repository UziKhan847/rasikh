/// Every mark of tashkīl, its timing in counts (ḥarakāt), and a Qur'anic
/// example. Counts of 0 mean "no vowel" (sukūn); -1 means "see note".
class TashkilItem {
  final String id;
  final String mark; // mark on a carrier, e.g. بَ
  final String name;
  final String sound;
  final int counts; // duration in ḥarakāt
  final String note;
  final String example; // Qur'anic word (verbatim Uthmani, see test/tashkeel_data_test.dart)
  final String ref;
  final String highlight; // substring of example carrying the mark
  final List<(String, String, String)> moreExamples; // several, not just one

  const TashkilItem(this.id, this.mark, this.name, this.sound, this.counts,
      this.note, this.example, this.ref, this.highlight,
      [this.moreExamples = const []]);
}

const tashkil = <TashkilItem>[
  TashkilItem('fatha', 'بَ', 'Fatḥah', 'ba', 1,
      'A short “a”. A small stroke above the letter — one count, like one clap.',
      'خَلَقَ', '96:1', 'خَ', [('ٱللَّهِ', '1:1', 'َّ'), ('ٱلرَّحۡمَٰنِ', '1:1', 'َّ'), ('ٱلرَّحِيمِ', '1:1', 'َّ')]),
  TashkilItem('kasra', 'بِ', 'Kasrah', 'bi', 1,
      'A short “i”. A small stroke below the letter — one count.',
      'بِسۡمِ', '1:1', 'بِ', [('ٱللَّهِ', '1:1', 'هِ'), ('ٱلرَّحۡمَٰنِ', '1:1', 'نِ'), ('ٱلرَّحِيمِ', '1:1', 'حِ')]),
  TashkilItem('damma', 'بُ', 'Ḍammah', 'bu', 1,
      'A short “u”. A tiny wāw above the letter — one count.',
      'هُوَ', '112:1', 'هُ', [('ٱلۡحَمۡدُ', '1:2', 'دُ'), ('نَعۡبُدُ', '1:5', 'بُ'), ('نَسۡتَعِينُ', '1:5', 'نُ')]),
  TashkilItem('sukun', 'بۡ', 'Sukūn', 'b', 0,
      'No vowel: the letter is sākin. Join it to the vowel before it.',
      'أَنۡعَمۡتَ', '1:7', 'نۡ', [('بِسۡمِ', '1:1', 'سۡ'), ('ٱلرَّحۡمَٰنِ', '1:1', 'حۡ'), ('ٱلۡحَمۡدُ', '1:2', 'لۡ')]),
  TashkilItem('shadda', 'بّ', 'Shaddah', 'bb', 1,
      'Doubling: the letter is pronounced twice — first with sukūn, then with its vowel.',
      'إِيَّاكَ', '1:5', 'يَّ', [('ٱللَّهِ', '1:1', 'لّ'), ('ٱلرَّحۡمَٰنِ', '1:1', 'رّ'), ('ٱلرَّحِيمِ', '1:1', 'رّ')]),
  TashkilItem('fathatan', 'بً', 'Fatḥatān', 'ban', 1,
      'Tanwīn of fatḥ: an extra “n” sound. Two strokes above — see tanwin_allographs.dart for the alternate stacked shape and what it signals.',
      'رَغَدًا', '2:35', 'دًا', [('قِرَدَةً', '2:65', 'ةً'), ('شَهَٰدَةً', '2:140', 'ةً'), ('لَكَبِيرَةً', '2:143', 'ةً')]),
  TashkilItem('kasratan', 'بٍ', 'Kasratān', 'bin', 1,
      'Tanwīn of kasr: “-in”. Two strokes below — see tanwin_allographs.dart for the alternate stacked shape and what it signals.',
      'شَيۡءٍ', '2:29', 'ءٍ', [('لِبَعۡضٍ', '2:36', 'ضٍ'), ('بِغَٰفِلٍ', '2:74', 'لٍ'), ('بِغَضَبٍ', '2:90', 'بٍ')]),
  TashkilItem('dammatan', 'بٌ', 'Ḍammatān', 'bun', 1,
      'Tanwīn of ḍamm: “-un”. Two tiny wāws above — see tanwin_allographs.dart for the alternate stacked shape and what it signals.',
      'أَحَدٌ', '112:1', 'دٌ', [('عَذَابٌ', '2:7', 'بٌ'), ('بُكۡمٌ', '2:18', 'مٌ'), ('وَمَتَٰعٌ', '2:36', 'عٌ')]),
  TashkilItem('madd2', 'بَا', 'Madd Ṭabī‘ī', 'bā', 2,
      'Natural lengthening with ا / و / ي — exactly TWO counts. Never rush it, never stretch it.',
      'قَالَ', '2:30', 'قَا', [('ٱلرَّحِيمِ', '1:1', 'ي'), ('ٱلۡعَٰلَمِينَ', '1:2', 'ي')]),
  TashkilItem('lin', 'بَوۡ', 'Madd Līn', 'baw / bay', 2,
      'Soft wāw or yā’ with sukūn after a fatḥah — a gentle glide.',
      'خَوۡفِۭ', '106:4', 'خَوۡ', [('يَوۡمِ', '1:4', 'يَوۡ'), ('عَلَيۡهِمۡ', '1:7', 'لَيۡ'), ('غَيۡرِ', '1:7', 'غَيۡ')]),
  TashkilItem('maddah', 'ءَا', 'Maddah (ءَا)', '’ā', 2,
      'Hamzah followed by alif written as one sign — read with madd.',
      'ءَامَنُواْ', '2:9', 'ءَا', [('ءَامَنَّا', '2:8', 'ءَا'), ('ءَامِنُواْ', '2:13', 'ءَا'), ('ءَامَنَ', '2:13', 'ءَا')]),
  TashkilItem('madd4', 'بَآءَ', 'Madd Muttaṣil', 'bāā’', 4,
      'Madd letter meets hamzah in the SAME word — stretch FOUR (to five) counts. Obligatory.',
      'جَآءَ', '110:1', 'جَآءَ', [('ٱهۡدِنَا', '1:6', 'ا'), ('وَلَا', '1:7', 'ا'), ('لَا', '2:2', 'ا')]),
  TashkilItem('madd45', 'ـآ أَ', 'Madd Munfaṣil', 'ā + ’a', 4,
      'Madd at the end of a word, hamzah starts the NEXT word — four (to five) counts in Ḥafṣ.',
      'إِنَّآ أَنزَلۡنَٰهُ', '97:1', 'آ', [('بَغۡيًا أَن', '2:90', 'ًا أ'), ('هُودًا أَوۡ', '2:111', 'ًا أ'), ('بَلَدًا ءَامِنٗا', '2:126', 'ًا ء')]),
  TashkilItem('madd6', 'بَآدّ', 'Madd Lāzim', 'bāādd', 6,
      'Madd followed by a permanent sukūn or shaddah — SIX full counts, the longest stretch.',
      'ٱلضَّآلِّينَ', '1:7', 'ضَّآلِّ', [('يَوۡمِ', '1:4', 'وۡ'), ('إِيَّاكَ', '1:5', 'يّ'), ('وَإِيَّاكَ', '1:5', 'يّ')]),
  TashkilItem('madd246', 'ـِينۡ', 'Madd ‘Āriḍ', '-īīn', 2,
      'Stopping turns the last vowel into sukūn after a madd letter — 2, 4 or 6 counts (be consistent).',
      'ٱلۡعَٰلَمِينَ', '1:2', 'مِينَ', [('ٱهۡدِنَا', '1:6', 'ا'), ('وَلَا', '1:7', 'ا'), ('لَا', '2:2', 'ا')]),
  TashkilItem('wasl', 'ٱ', 'Hamzat al-Waṣl', '—', 0,
      'Pronounced when you START with it, silent when you join from the previous word.',
      'ٱهۡدِنَا', '1:6', 'ٱ', [('ٱللَّهِ', '1:1', 'ٱ'), ('ٱلرَّحۡمَٰنِ', '1:1', 'ٱ'), ('ٱلرَّحِيمِ', '1:1', 'ٱ')]),
];
