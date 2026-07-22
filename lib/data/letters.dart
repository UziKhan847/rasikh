/// The 28 letters with contextual forms, i'jam (dot) data, similar-shape
/// groups (the core of the dyslexia drills), and a Qur'anic example word.
class ArabicLetter {
  final String char; // isolated
  final String name; // e.g. "Bā’"
  final String translit; // consonant value, e.g. "b"
  final int dotCount;
  final String dotPos; // 'above' | 'below' | 'inside' | 'none'
  final String? similarGroup; // letters that share a skeleton (rasm)
  final String exampleWord; // from the Qur'an
  final String exampleRef; // surah:ayah
  final String glyphId; // tracing glyph family id

  const ArabicLetter({
    required this.char,
    required this.name,
    required this.translit,
    required this.dotCount,
    required this.dotPos,
    required this.similarGroup,
    required this.exampleWord,
    required this.exampleRef,
    required this.glyphId,
  });

  // Contextual forms via the tatweel joiner — renders true initial /
  // medial / final shapes in any Arabic-shaping text engine.
  String get initial => '$char\u0640';
  String get medial => '\u0640$char\u0640';
  String get finalForm => '\u0640$char';
}

const letters = <ArabicLetter>[
  ArabicLetter(char: 'ا', name: 'Alif', translit: 'ā', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'أَحَدٌ', exampleRef: '112:1', glyphId: 'alif'),
  ArabicLetter(char: 'ب', name: 'Bā’', translit: 'b', dotCount: 1, dotPos: 'below', similarGroup: 'boat', exampleWord: 'بِسْمِ', exampleRef: '1:1', glyphId: 'ba'),
  ArabicLetter(char: 'ت', name: 'Tā’', translit: 't', dotCount: 2, dotPos: 'above', similarGroup: 'boat', exampleWord: 'تَبَّتْ', exampleRef: '111:1', glyphId: 'ba'),
  ArabicLetter(char: 'ث', name: 'Thā’', translit: 'th', dotCount: 3, dotPos: 'above', similarGroup: 'boat', exampleWord: 'ثُمَّ', exampleRef: '78:5', glyphId: 'ba'),
  ArabicLetter(char: 'ج', name: 'Jīm', translit: 'j', dotCount: 1, dotPos: 'inside', similarGroup: 'jim', exampleWord: 'جَاءَ', exampleRef: '110:1', glyphId: 'jim'),
  ArabicLetter(char: 'ح', name: 'Ḥā’', translit: 'ḥ', dotCount: 0, dotPos: 'none', similarGroup: 'jim', exampleWord: 'الْحَمْدُ', exampleRef: '1:2', glyphId: 'jim'),
  ArabicLetter(char: 'خ', name: 'Khā’', translit: 'kh', dotCount: 1, dotPos: 'above', similarGroup: 'jim', exampleWord: 'خَلَقَ', exampleRef: '96:1', glyphId: 'jim'),
  ArabicLetter(char: 'د', name: 'Dāl', translit: 'd', dotCount: 0, dotPos: 'none', similarGroup: 'dal', exampleWord: 'دِينِ', exampleRef: '109:6', glyphId: 'dal'),
  ArabicLetter(char: 'ذ', name: 'Dhāl', translit: 'dh', dotCount: 1, dotPos: 'above', similarGroup: 'dal', exampleWord: 'ذَٰلِكَ', exampleRef: '2:2', glyphId: 'dal'),
  ArabicLetter(char: 'ر', name: 'Rā’', translit: 'r', dotCount: 0, dotPos: 'none', similarGroup: 'ra', exampleWord: 'رَبِّ', exampleRef: '1:2', glyphId: 'ra'),
  ArabicLetter(char: 'ز', name: 'Zāy', translit: 'z', dotCount: 1, dotPos: 'above', similarGroup: 'ra', exampleWord: 'زُلْزِلَتِ', exampleRef: '99:1', glyphId: 'ra'),
  ArabicLetter(char: 'س', name: 'Sīn', translit: 's', dotCount: 0, dotPos: 'none', similarGroup: 'sin', exampleWord: 'سَلَامٌ', exampleRef: '97:5', glyphId: 'sin'),
  ArabicLetter(char: 'ش', name: 'Shīn', translit: 'sh', dotCount: 3, dotPos: 'above', similarGroup: 'sin', exampleWord: 'شَهْرٍ', exampleRef: '97:3', glyphId: 'sin'),
  ArabicLetter(char: 'ص', name: 'Ṣād', translit: 'ṣ', dotCount: 0, dotPos: 'none', similarGroup: 'sad', exampleWord: 'الصَّمَدُ', exampleRef: '112:2', glyphId: 'sad'),
  ArabicLetter(char: 'ض', name: 'Ḍād', translit: 'ḍ', dotCount: 1, dotPos: 'above', similarGroup: 'sad', exampleWord: 'الضَّالِّينَ', exampleRef: '1:7', glyphId: 'sad'),
  ArabicLetter(char: 'ط', name: 'Ṭā’', translit: 'ṭ', dotCount: 0, dotPos: 'none', similarGroup: 'ta', exampleWord: 'طه', exampleRef: '20:1', glyphId: 'tah'),
  ArabicLetter(char: 'ظ', name: 'Ẓā’', translit: 'ẓ', dotCount: 1, dotPos: 'above', similarGroup: 'ta', exampleWord: 'عَظِيمٌ', exampleRef: '2:7', glyphId: 'tah'),
  ArabicLetter(char: 'ع', name: '‘Ayn', translit: 'ʿ', dotCount: 0, dotPos: 'none', similarGroup: 'ayn', exampleWord: 'الْعَالَمِينَ', exampleRef: '1:2', glyphId: 'ayn'),
  ArabicLetter(char: 'غ', name: 'Ghayn', translit: 'gh', dotCount: 1, dotPos: 'above', similarGroup: 'ayn', exampleWord: 'غَيْرِ', exampleRef: '1:7', glyphId: 'ayn'),
  ArabicLetter(char: 'ف', name: 'Fā’', translit: 'f', dotCount: 1, dotPos: 'above', similarGroup: 'fa', exampleWord: 'الْفَلَقِ', exampleRef: '113:1', glyphId: 'fa'),
  ArabicLetter(char: 'ق', name: 'Qāf', translit: 'q', dotCount: 2, dotPos: 'above', similarGroup: 'fa', exampleWord: 'قُلْ', exampleRef: '112:1', glyphId: 'qaf'),
  ArabicLetter(char: 'ك', name: 'Kāf', translit: 'k', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'الْكَوْثَرَ', exampleRef: '108:1', glyphId: 'kaf'),
  ArabicLetter(char: 'ل', name: 'Lām', translit: 'l', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'لَهَبٍ', exampleRef: '111:1', glyphId: 'lam'),
  ArabicLetter(char: 'م', name: 'Mīm', translit: 'm', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'مَالِكِ', exampleRef: '1:4', glyphId: 'mim'),
  ArabicLetter(char: 'ن', name: 'Nūn', translit: 'n', dotCount: 1, dotPos: 'above', similarGroup: 'boat', exampleWord: 'نَعْبُدُ', exampleRef: '1:5', glyphId: 'nun'),
  ArabicLetter(char: 'ه', name: 'Hā’', translit: 'h', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'هُوَ', exampleRef: '112:1', glyphId: 'ha'),
  ArabicLetter(char: 'و', name: 'Wāw', translit: 'w', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'وَالْعَصْرِ', exampleRef: '103:1', glyphId: 'waw'),
  ArabicLetter(char: 'ي', name: 'Yā’', translit: 'y', dotCount: 2, dotPos: 'below', similarGroup: 'boat', exampleWord: 'يَوْمِ', exampleRef: '1:4', glyphId: 'ya'),
];

/// Look-alike families used by the dyslexia discrimination drills.
/// Each set differs only by dots or tiny shape details.
const similarFamilies = <String, List<String>>{
  'boat': ['ب', 'ت', 'ث', 'ن', 'ي'],
  'jim': ['ج', 'ح', 'خ'],
  'dal': ['د', 'ذ'],
  'ra': ['ر', 'ز'],
  'sin': ['س', 'ش'],
  'sad': ['ص', 'ض'],
  'ta': ['ط', 'ظ'],
  'ayn': ['ع', 'غ'],
  'fa': ['ف', 'ق'],
  'cross': ['د', 'ر', 'و'], // shape confusion across families
};

ArabicLetter letterFor(String char) =>
    letters.firstWhere((l) => l.char == char);

/// Short vowels used to build syllables in Qaidah drills.
const harakat = <(String mark, String name, String sound)>[
  ('\u064E', 'Fatḥah', 'a'),
  ('\u0650', 'Kasrah', 'i'),
  ('\u064F', 'Ḍammah', 'u'),
];

const tanwin = <(String mark, String name, String sound)>[
  ('\u064B', 'Fatḥatān', 'an'),
  ('\u064D', 'Kasratān', 'in'),
  ('\u064C', 'Ḍammatān', 'un'),
];

/// Three real-word examples per letter — beginning · middle · end position.
/// Sourced from the desktop reference; used by the letter-detail screens.
class LetterExample {
  final String position; // 'beginning' | 'middle' | 'end'
  final String word;
  final String translit;
  const LetterExample(this.position, this.word, this.translit);
}

const Map<String, List<LetterExample>> letterExamples = {
  'ا': [LetterExample('beginning', 'أَحَد', 'aḥad'), LetterExample('middle', 'سَأَل', 'saʾala'), LetterExample('end', 'دَعَا', 'daʿā')],
  'ب': [LetterExample('beginning', 'بَيْت', 'bayt'), LetterExample('middle', 'كَبِير', 'kabīr'), LetterExample('end', 'قَلْب', 'qalb')],
  'ت': [LetterExample('beginning', 'تَمْر', 'tamr'), LetterExample('middle', 'كِتَاب', 'kitāb'), LetterExample('end', 'بَيْت', 'bayt')],
  'ث': [LetterExample('beginning', 'ثَوْب', 'thawb'), LetterExample('middle', 'كَثِير', 'kathīr'), LetterExample('end', 'حَدِيث', 'ḥadīth')],
  'ج': [LetterExample('beginning', 'جَبَل', 'jabal'), LetterExample('middle', 'رَجُل', 'rajul'), LetterExample('end', 'تَاج', 'tāj')],
  'ح': [LetterExample('beginning', 'حَبْل', 'ḥabl'), LetterExample('middle', 'رَحْمَة', 'raḥmah'), LetterExample('end', 'صُلْح', 'ṣulḥ')],
  'خ': [LetterExample('beginning', 'خُبْز', 'khubz'), LetterExample('middle', 'نَخْل', 'nakhl'), LetterExample('end', 'تَارِيخ', 'tārīkh')],
  'د': [LetterExample('beginning', 'دَار', 'dār'), LetterExample('middle', 'بَدْر', 'badr'), LetterExample('end', 'يَد', 'yad')],
  'ذ': [LetterExample('beginning', 'ذَهَب', 'dhahab'), LetterExample('middle', 'نَذِير', 'nadhīr'), LetterExample('end', 'لَذِيذ', 'ladhīdh')],
  'ر': [LetterExample('beginning', 'رَأْس', 'raʾs'), LetterExample('middle', 'كَرِيم', 'karīm'), LetterExample('end', 'نَهْر', 'nahr')],
  'ز': [LetterExample('beginning', 'زَيْت', 'zayt'), LetterExample('middle', 'عَزِيز', 'ʿazīz'), LetterExample('end', 'كَنْز', 'kanz')],
  'س': [LetterExample('beginning', 'سَمَاء', 'samāʾ'), LetterExample('middle', 'مَسْجِد', 'masjid'), LetterExample('end', 'شَمْس', 'shams')],
  'ش': [LetterExample('beginning', 'شَمْس', 'shams'), LetterExample('middle', 'بَشَر', 'bashar'), LetterExample('end', 'عَرْش', 'ʿarsh')],
  'ص': [LetterExample('beginning', 'صَبْر', 'ṣabr'), LetterExample('middle', 'بَصَر', 'baṣar'), LetterExample('end', 'إِخْلَاص', 'ikhlāṣ')],
  'ض': [LetterExample('beginning', 'ضَوْء', 'ḍawʾ'), LetterExample('middle', 'فَضْل', 'faḍl'), LetterExample('end', 'أَرْض', 'arḍ')],
  'ط': [LetterExample('beginning', 'طَرِيق', 'ṭarīq'), LetterExample('middle', 'بَطَل', 'baṭal'), LetterExample('end', 'رِبَاط', 'ribāṭ')],
  'ظ': [LetterExample('beginning', 'ظِلّ', 'ẓill'), LetterExample('middle', 'نَظَر', 'naẓar'), LetterExample('end', 'حِفْظ', 'ḥifẓ')],
  'ع': [LetterExample('beginning', 'عِلْم', 'ʿilm'), LetterExample('middle', 'نَعَم', 'naʿam'), LetterExample('end', 'سَمِيع', 'samīʿ')],
  'غ': [LetterExample('beginning', 'غَيْم', 'ghaym'), LetterExample('middle', 'صَغِير', 'ṣaghīr'), LetterExample('end', 'بَلَاغ', 'balāgh')],
  'ف': [LetterExample('beginning', 'فَجْر', 'fajr'), LetterExample('middle', 'نَفْس', 'nafs'), LetterExample('end', 'سَيْف', 'sayf')],
  'ق': [LetterExample('beginning', 'قَلَم', 'qalam'), LetterExample('middle', 'بَقَرَة', 'baqarah'), LetterExample('end', 'حَقّ', 'ḥaqq')],
  'ك': [LetterExample('beginning', 'كَلْب', 'kalb'), LetterExample('middle', 'مَكَان', 'makān'), LetterExample('end', 'مَلِك', 'malik')],
  'ل': [LetterExample('beginning', 'لَيْل', 'layl'), LetterExample('middle', 'قَلَم', 'qalam'), LetterExample('end', 'رَجُل', 'rajul')],
  'م': [LetterExample('beginning', 'مَاء', 'māʾ'), LetterExample('middle', 'عَمَل', 'ʿamal'), LetterExample('end', 'قَلَم', 'qalam')],
  'ن': [LetterExample('beginning', 'نُور', 'nūr'), LetterExample('middle', 'جَنَّة', 'jannah'), LetterExample('end', 'لَبَن', 'laban')],
  'ه': [LetterExample('beginning', 'هُدَى', 'hudā'), LetterExample('middle', 'نَهْر', 'nahr'), LetterExample('end', 'وَجْه', 'wajh')],
  'و': [LetterExample('beginning', 'وَرْد', 'ward'), LetterExample('middle', 'نُور', 'nūr'), LetterExample('end', 'دَلْو', 'dalw')],
  'ي': [LetterExample('beginning', 'يَد', 'yad'), LetterExample('middle', 'بَيْت', 'bayt'), LetterExample('end', 'كُرْسِيّ', 'kursiyy')],
};

/// Human-readable dot description for the letter-detail 'DOTS' card.
