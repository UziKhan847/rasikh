/// Side-by-side contrasts between the app's two bundled scripts — Madani
/// (Uthmānī, assets/quran/u/) and Indo-Pak (assets/quran/i/) — quoting the
/// SAME āyah from both corpora so the difference is visible in real text,
/// not asserted in prose. See test/script_diff_test.dart.
class ScriptDifference {
  final String id;
  final String topic;
  final String madaniWord; // verbatim from assets/quran/u/
  final String ref;
  final String indopakWord; // verbatim from assets/quran/i/, same ref
  final String note;

  const ScriptDifference(this.id, this.topic, this.madaniWord, this.ref,
      this.indopakWord, this.note);
}

const scriptDifferences = <ScriptDifference>[
  ScriptDifference('alif_wasla', 'Hamzat al-Waṣl', 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ', '1:1',
      'بِسۡمِ اللّٰهِ الرَّحۡمٰنِ الرَّحِيۡمِ', 'Madani writes hamzat al-waṣl as a distinct letter, ٱ (U+0671), 13,483 times in this muṣḥaf. Indo-Pak writes it as a plain ا every time — the reader has to know the word to know it\'s there.'),
  ScriptDifference('silent_alif_collapse', 'The Two Silent Alifs', 'وَيُطَافُ عَلَيۡهِم بِـَٔانِيَةٖ مِّن فِضَّةٖ وَأَكۡوَابٖ كَانَتۡ قَوَارِيرَا۠', '76:15',
      'وَيُطَافُ عَلَيۡهِمۡ بِاٰنِيَةٍ مِّنۡ فِضَّةٍ وَّاَكۡوَابٍ كَانَتۡ قَوَارِيۡرَا۠ۙ‏', 'Madani distinguishes two different silent-letter marks — a rectangular zero (sounded on stopping, dropped on continuing) here at 76:15, and a round mark (never sounded) at 76:16. Indo-Pak uses the same rounded-zero sign for both, collapsing a distinction Madani keeps.'),
  ScriptDifference('tanwin_wasl_spelling', 'Tanwīn Meeting Hamzat al-Waṣl', 'كُتِبَ عَلَيۡكُمۡ إِذَا حَضَرَ أَحَدَكُمُ ٱلۡمَوۡتُ إِن تَرَكَ خَيۡرًا ٱلۡوَصِيَّةُ لِلۡوَٰلِدَيۡنِ وَٱلۡأَقۡرَبِينَ بِٱلۡمَعۡرُوفِۖ حَقًّا عَلَى ٱلۡمُتَّقِينَ', '2:180',
      'كُتِبَ عَلَيۡكُمۡ اِذَا حَضَرَ اَحَدَكُمُ الۡمَوۡتُ اِنۡ تَرَكَ خَيۡرَاۚۖ اِۨلۡوَصِيَّةُ لِلۡوَالِدَيۡنِ وَالۡاَقۡرَبِيۡنَ بِالۡمَعۡرُوۡفِۚ حَقًّا عَلَي الۡمُتَّقِيۡنَؕ‏', 'Where two sākin sounds meet, Madani keeps the plain tanwīn mark and leaves the reader to supply the linking kasrah by rule. Indo-Pak spells the same seam differently, replacing the tanwīn with an explicit small نۨ (nūn) over the next word\'s alif.'),
  ScriptDifference('sajdah_glyph', 'The Sajdah Mark', 'إِنَّ ٱلَّذِينَ عِندَ رَبِّكَ لَا يَسۡتَكۡبِرُونَ عَنۡ عِبَادَتِهِۦ وَيُسَبِّحُونَهُۥ وَلَهُۥ يَسۡجُدُونَۤ۩', '7:206',
      'اِنَّ الَّذِيۡنَ عِنۡدَ رَبِّكَ لَا يَسۡتَكۡبِرُوۡنَ عَنۡ عِبَادَتِهٖ وَيُسَبِّحُوۡنَهٗ وَلَهٗ يَسۡجُدُوۡنَ‏', 'Madani marks every one of the 15 sajdah verses with ۩ directly in the text. The bundled Indo-Pak text carries no such mark at all — a reader would need an outside list of the 15 places.'),
  ScriptDifference('tanwin_alignment', 'Tanwīn Alignment', 'أَوۡ كَصَيِّبٖ مِّنَ ٱلسَّمَآءِ فِيهِ ظُلُمَٰتٞ وَرَعۡدٞ وَبَرۡقٞ يَجۡعَلُونَ أَصَٰبِعَهُمۡ فِيٓ ءَاذَانِهِم مِّنَ ٱلصَّوَٰعِقِ حَذَرَ ٱلۡمَوۡتِۚ وَٱللَّهُ مُحِيطُۢ بِٱلۡكَٰفِرِينَ', '2:19',
      'اَوۡ كَصَيِّبٍ مِّنَ السَّمَآءِ فِيۡهِ ظُلُمٰتٌ وَّرَعۡدٌ وَّبَرۡقٌۚ يَجۡعَلُوۡنَ اَصَابِعَهُمۡ فِيۡ اٰذَانِهِمۡ مِّنَ الصَّوَاعِقِ حَذَرَ الۡمَوۡتِؕ وَاللّٰهُ مُحِيۡطٌۭ بِالۡكٰفِرِيۡنَ', 'Madani writes tanwīn in its alternate, stacked shape by default here (ٖ ٞ ٞ) — the same shape tanwin_allographs.dart teaches as an idghām/ikhfā\' signal. Indo-Pak writes the same words with the plain, lined-up parallel shape (ٍ ٌ ٌ) instead — a whole-script alignment convention, not a tajwīd distinction.'),
  ScriptDifference('waqf_marks_differ', 'Which Waqf Marks Appear', '۞إِنَّ ٱللَّهَ لَا يَسۡتَحۡيِۦٓ أَن يَضۡرِبَ مَثَلٗا مَّا بَعُوضَةٗ فَمَا فَوۡقَهَاۚ فَأَمَّا ٱلَّذِينَ ءَامَنُواْ فَيَعۡلَمُونَ أَنَّهُ ٱلۡحَقُّ مِن رَّبِّهِمۡۖ وَأَمَّا ٱلَّذِينَ كَفَرُواْ فَيَقُولُونَ مَاذَآ أَرَادَ ٱللَّهُ بِهَٰذَا مَثَلٗاۘ يُضِلُّ بِهِۦ كَثِيرٗا وَيَهۡدِي بِهِۦ كَثِيرٗاۚ وَمَا يُضِلُّ بِهِۦٓ إِلَّا ٱلۡفَٰسِقِينَ', '2:26',
      'اِنَّ اللّٰهَ لَا يَسۡتَحۡيٖ اَنۡ يَّضۡرِبَ مَثَلًا مَّا بَعُوۡضَةً فَمَا فَوۡقَهَاؕ فَاَمَّا الَّذِيۡنَ اٰمَنُوۡا فَيَعۡلَمُوۡنَ اَنَّهُ الۡحَقُّ مِنۡ رَّبِّهِمۡۚ وَاَمَّا الَّذِيۡنَ كَفَرُوۡا فَيَقُوۡلُوۡنَ مَاذَا اَرَادَ اللّٰهُ بِهٰذَا مَثَلًاۘ يُضِلُّ بِهٖ كَثِيۡرًا وَّيَهۡدِيۡ بِهٖ كَثِيۡرًاؕ وَمَا يُضِلُّ بِهٖ اِلَّا الۡفٰسِقِيۡنَۙ‏', 'The same āyah carries different stop marks in each script: Madani marks ۞ (rubʿ al-ḥizb) at the start and ۘ (waqf lāzim) mid-verse; Indo-Pak carries neither, using its own sign repertoire (see script.waqf for the full comparison).'),
];
