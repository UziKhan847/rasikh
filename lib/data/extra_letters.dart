import 'letters.dart';

/// Characters the muṣḥaf uses constantly but the 28-letter alphabet does
/// not cover: the hamza and its four seated forms, tāʼ marbūṭah, alif
/// maqṣūrah, and alif al-waṣl. Deliberately a SEPARATE list from [letters]
/// rather than appended to it — `letters.length` is the denominator for the
/// "N of 28 letters explored" hero stat and the `itemCount` of several
/// grids, and `letterFor()` throws on an unrecognised char, so widening the
/// 28-list would silently break both. Use [letterForAny] to look up a
/// character that might be in either list.
///
/// U+0622 (ALEF WITH MADDA ABOVE) is deliberately absent — it has zero
/// occurrences in the bundled Uthmani corpus; Ḥafṣ decomposes it to hamza +
/// fatḥah + bare alif (see tashkeel.dart's `maddah` entry) or to alif +
/// U+0653 MADDAH ABOVE, never the precomposed Imlāʼī form.
const extraLetters = <ArabicLetter>[
  ArabicLetter(char: 'ء', name: 'Hamzah', translit: 'ʼ', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'سَوَآءٌ', exampleRef: '2:6', glyphId: 'hamza'),
  ArabicLetter(char: 'أ', name: 'Alif with Hamzah Above', translit: 'a', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'أُنزِلَ', exampleRef: '2:4', glyphId: 'alef_hamza'),
  ArabicLetter(char: 'إ', name: 'Alif with Hamzah Below', translit: 'i', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'إِيَّاكَ', exampleRef: '1:5', glyphId: 'alef_hamza'),
  ArabicLetter(char: 'ؤ', name: 'Wāw with Hamzah', translit: 'u', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'يُؤۡخَذُ', exampleRef: '2:48', glyphId: 'waw_hamza'),
  ArabicLetter(char: 'ئ', name: 'Yāʼ with Hamzah', translit: 'i', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'شِئۡتُمۡ', exampleRef: '2:58', glyphId: 'yeh_hamza'),
  ArabicLetter(char: 'ة', name: 'Tāʼ Marbūṭah', translit: 'h/t', dotCount: 2, dotPos: 'above', similarGroup: null, exampleWord: 'ثَمَرَةٖ', exampleRef: '2:25', glyphId: 'ta_marbuta'),
  ArabicLetter(char: 'ى', name: 'Alif Maqṣūrah', translit: 'ā', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'هُدٗى', exampleRef: '2:2', glyphId: 'alef_maksura'),
  ArabicLetter(char: 'ٱ', name: 'Alif al-Waṣl', translit: 'a/–', dotCount: 0, dotPos: 'none', similarGroup: null, exampleWord: 'ٱللَّهِ', exampleRef: '1:1', glyphId: 'alef_wasla'),
];

/// Looks up a character in [letters] first, then [extraLetters]. Returns
/// null instead of throwing when the character is in neither — unlike
/// [letterFor], which is only ever called with a known-28 character.

/// A short note on how/when each extra letter is actually read — shown on
/// its Learn-phase lesson page alongside its makhraj cross-link.
const Map<String, String> extraLetterNotes = {
  'ء': 'A glottal stop with no seat of its own — written bare when it opens a word after a long vowel, or floats between two vowels mid-word.',
  'أ': 'Hamzah seated on an alif, written above it — used when the hamzah itself carries a fatḥah or ḍammah.',
  'إ': 'Hamzah seated on an alif, written below it — used when the hamzah itself carries a kasrah.',
  'ؤ': 'Hamzah seated on a wāw — used when the hamzah carries or follows a ḍammah.',
  'ئ': 'Hamzah seated on a dotless yāʼ — used when the hamzah carries or follows a kasrah.',
  'ة': 'The feminine ending. Read as a plain ت when recitation continues into the next word (waṣl); read as a silent ه when you stop (waqf) — the -t sound never carries over into a pause.',
  'ى': 'A madd letter written without the two dots of a full yāʼ — pronounced exactly like a plain alif of madd.',
  'ٱ': 'A hamzah with no vowel of its own. Sounded, lightly, only when you START with it; silent — and unmarked in plain text — when you join it from the word before.',
};

/// Each extra letter's articulation point — a separate map from
/// [makhrajOfLetter] (test/tajwid_symbols_data_test.dart pins that one at
/// exactly 29 entries: the 28 core letters + hamzah), the same reason
/// [extraLetters] is a separate list from [letters]. تāʼ marbūṭah maps to
/// its joined (ت) reading, since that is how it is read whenever recitation
/// continues past it — see its note for the pausal ه alternative.
const Map<String, String> makhrajOfExtraLetter = {
  'ء': 'halq_aqsa',
  'أ': 'halq_aqsa',
  'إ': 'halq_aqsa',
  'ؤ': 'halq_aqsa',
  'ئ': 'halq_aqsa',
  'ة': 'lisan_tarf_tdt',
  'ى': 'jawf',
  'ٱ': 'halq_aqsa',
};

/// 2-3 more real corpus examples per extra letter, beyond its single
/// `exampleWord` — same "several examples, not just one" shape the rest of
/// the Learn phase uses. Highlight is the character itself.
const Map<String, List<(String, String, String)>> extraLetterMoreExamples = {
  'ء': [('ءَأَنذَرۡتَهُمۡ', '2:6', 'ء'), ('ءَامَنَّا', '2:8', 'ء'), ('ءَامَنُواْ', '2:9', 'ء')],
  'أ': [('أَنۡعَمۡتَ', '1:7', 'أ'), ('وَبِٱلۡأٓخِرَةِ', '2:4', 'أ'), ('أُوْلَـٰٓئِكَ', '2:5', 'أ')],
  'إ': [('وَإِيَّاكَ', '1:5', 'إ'), ('إِلَيۡكَ', '2:4', 'إ'), ('إِنَّ', '2:6', 'إ')],
  'ؤ': [('يُؤۡمِنُونَ', '2:3', 'ؤ'), ('بِمُؤۡمِنِينَ', '2:8', 'ؤ'), ('أَنُؤۡمِنُ', '2:13', 'ؤ')],
  'ئ': [('أُوْلَـٰٓئِكَ', '2:5', 'ئ'), ('وَأُوْلَـٰٓئِكَ', '2:5', 'ئ'), ('يَسۡتَهۡزِئُ', '2:15', 'ئ')],
  'ة': [('ٱلصَّلَوٰةَ', '2:3', 'ة'), ('وَبِٱلۡأٓخِرَةِ', '2:4', 'ة'), ('غِشَٰوَةٞۖ', '2:7', 'ة')],
  'ى': [('عَلَىٰ', '2:5', 'ى'), ('وَعَلَىٰ', '2:7', 'ى'), ('وَعَلَىٰٓ', '2:7', 'ى')],
  'ٱ': [('ٱلرَّحۡمَٰنِ', '1:1', 'ٱ'), ('ٱلرَّحِيمِ', '1:1', 'ٱ'), ('ٱلۡحَمۡدُ', '1:2', 'ٱ')],
};

ArabicLetter? letterForAny(String ch) {
  for (final l in letters) {
    if (l.char == ch) return l;
  }
  for (final l in extraLetters) {
    if (l.char == ch) return l;
  }
  return null;
}
