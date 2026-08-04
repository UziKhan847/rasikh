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
ArabicLetter? letterForAny(String ch) {
  for (final l in letters) {
    if (l.char == ch) return l;
  }
  for (final l in extraLetters) {
    if (l.char == ch) return l;
  }
  return null;
}
