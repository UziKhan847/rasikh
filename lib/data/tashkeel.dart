/// Every mark of tashkīl, its timing in counts (ḥarakāt), and a Qur'anic
/// example. Counts of 0 mean "no vowel" (sukūn); -1 means "see note".
class TashkilItem {
  final String id;
  final String mark; // mark on a carrier, e.g. بَ
  final String name;
  final String sound;
  final int counts; // duration in ḥarakāt
  final String note;
  final String example; // Qur'anic word
  final String ref;
  final String highlight; // substring of example carrying the mark

  const TashkilItem(this.id, this.mark, this.name, this.sound, this.counts,
      this.note, this.example, this.ref, this.highlight);
}

const tashkil = <TashkilItem>[
  TashkilItem('fatha', 'بَ', 'Fatḥah', 'ba', 1,
      'A short “a”. A small stroke above the letter — one count, like one clap.',
      'خَلَقَ', '96:1', 'خَ'),
  TashkilItem('kasra', 'بِ', 'Kasrah', 'bi', 1,
      'A short “i”. A small stroke below the letter — one count.',
      'بِسْمِ', '1:1', 'بِ'),
  TashkilItem('damma', 'بُ', 'Ḍammah', 'bu', 1,
      'A short “u”. A tiny wāw above the letter — one count.',
      'هُوَ', '112:1', 'هُ'),
  TashkilItem('sukun', 'بْ', 'Sukūn', 'b', 0,
      'No vowel: the letter is “cut”. Join it to the vowel before it.',
      'أَنْعَمْتَ', '1:7', 'نْ'),
  TashkilItem('shadda', 'بّ', 'Shaddah', 'bb', 1,
      'Doubling: the letter is pronounced twice — first with sukūn, then with its vowel.',
      'إِيَّاكَ', '1:5', 'يَّ'),
  TashkilItem('fathatan', 'بًا', 'Fatḥatān', 'ban', 1,
      'Tanwīn of fatḥ: an extra “n” sound. Two strokes above.',
      'خَيْرًا', '99:7', 'رًا'),
  TashkilItem('kasratan', 'بٍ', 'Kasratān', 'bin', 1,
      'Tanwīn of kasr: “-in”. Two strokes below.',
      'يَوْمَئِذٍ', '99:4', 'ذٍ'),
  TashkilItem('dammatan', 'بٌ', 'Ḍammatān', 'bun', 1,
      'Tanwīn of ḍamm: “-un”. Two tiny wāws above.',
      'أَحَدٌ', '112:1', 'دٌ'),
  TashkilItem('madd2', 'بَا', 'Madd Ṭabī‘ī', 'bā', 2,
      'Natural lengthening with ا / و / ي — exactly TWO counts. Never rush it, never stretch it.',
      'قَالَ', '2:30', 'قَا'),
  TashkilItem('lin', 'بَوْ', 'Ḥurūf Līn', 'baw / bay', 2,
      'Soft wāw or yā’ with sukūn after a fatḥah — a gentle glide.',
      'خَوْفٍ', '106:4', 'خَوْ'),
  TashkilItem('maddah', 'آ', 'Maddah (آ)', '’ā', 2,
      'Hamzah followed by alif written as one sign — read with madd.',
      'آمَنُوا', '2:9', 'آ'),
  TashkilItem('madd4', 'بَآءَ', 'Madd Muttaṣil', 'bāā’', 4,
      'Madd letter meets hamzah in the SAME word — stretch FOUR (to five) counts. Obligatory.',
      'جَآءَ', '110:1', 'جَآءَ'),
  TashkilItem('madd45', 'ـا أَ', 'Madd Munfaṣil', 'ā + ’a', 4,
      'Madd at the end of a word, hamzah starts the NEXT word — four (to five) counts in Ḥafṣ.',
      'إِنَّآ أَنزَلْنَاهُ', '97:1', 'آ أَ'),
  TashkilItem('madd6', 'بَآدّ', 'Madd Lāzim', 'bāādd', 6,
      'Madd followed by a permanent sukūn or shaddah — SIX full counts, the longest stretch.',
      'الضَّآلِّينَ', '1:7', 'ضَّآلِّ'),
  TashkilItem('madd246', 'ـِينْ', 'Madd ‘Āriḍ', '-īīn', 2,
      'Stopping turns the last vowel into sukūn after a madd letter — 2, 4 or 6 counts (be consistent).',
      'الْعَالَمِينَ', '1:2', 'مِينَ'),
  TashkilItem('wasl', 'ٱ', 'Hamzat al-Waṣl', '—', 0,
      'Pronounced when you START with it, silent when you join from the previous word.',
      'ٱهْدِنَا', '1:6', 'ٱ'),
];
