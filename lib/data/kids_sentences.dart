/// "Read the sentence" content for Kids Mode — ordinary Modern Standard
/// Arabic sentences authored for early readers, one per taught letter.
///
/// **Nothing renders these right now.** They were the second step of a letter
/// lesson, which meant a child who had just traced their first letter, and
/// knew no ḥarakāt, was shown a fully voweled sentence under the heading
/// "Read the sentence". A letter lesson is meet-the-shape → say it → trace it
/// now, and reading waits for the stages built for it.
///
/// Kept rather than deleted because they are reviewed, tested content that
/// would suit a later reading stage — the natural home is somewhere after
/// `qaidah.harakat`, once the marks on these words mean something. The only
/// thing in this file still in use is [kidsPraiseArabic].
///
/// This is deliberately NOT Qur'anic text: it is exempt from the
/// corpus-verbatim checks the rest of `lib/data/` is held to (see
/// `test/kids_mode_test.dart`), because there is no muṣḥaf source to check
/// it against. Like every hand-typed string in this app, it still needs a
/// native Arabic speaker's review pass before shipping — see the Kids Mode
/// plan's risks section. Vocabulary is chosen to avoid U+0622 (ALEF WITH
/// MADDA ABOVE) even though this file's Arabic renders with ScheherazadeNew
/// (which has that glyph, unlike UthmanicHafs) — simply because none of
/// these beginner words need it.
class KidsSentence {
  final String letter; // the letter this sentence reinforces, e.g. 'ب'
  final String sentence; // full sentence
  final String targetWord; // substring of [sentence] to highlight
  final String gloss; // English meaning of [targetWord]
  final String translit; // transliteration of [targetWord]
  const KidsSentence({
    required this.letter,
    required this.sentence,
    required this.targetWord,
    required this.gloss,
    required this.translit,
  });
}

const kidsSentences = <KidsSentence>[
  KidsSentence(
      letter: 'ا',
      sentence: 'الْبَابُ مَفْتُوحٌ',
      targetWord: 'الْبَابُ',
      gloss: 'the door',
      translit: 'al-bāb'),
  KidsSentence(
      letter: 'ب',
      sentence: 'هَذَا بَيْتٌ كَبِيرٌ',
      targetWord: 'بَيْتٌ',
      gloss: 'house',
      translit: 'bayt'),
  KidsSentence(
      letter: 'ت',
      sentence: 'التُّفَّاحَةُ لَذِيذَةٌ',
      targetWord: 'التُّفَّاحَةُ',
      gloss: 'the apple',
      translit: 'at-tuffāḥah'),
  KidsSentence(
      letter: 'ث',
      sentence: 'الثَّعْلَبُ ذَكِيٌّ',
      targetWord: 'الثَّعْلَبُ',
      gloss: 'the fox',
      translit: 'ath-thaʿlab'),
  KidsSentence(
      letter: 'ج',
      sentence: 'الْجَمَلُ فِي الصَّحْرَاءِ',
      targetWord: 'الْجَمَلُ',
      gloss: 'the camel',
      translit: 'al-jamal'),
  KidsSentence(
      letter: 'ح',
      sentence: 'الْقِطَّةُ تَشْرَبُ الْحَلِيبَ',
      targetWord: 'الْحَلِيبَ',
      gloss: 'the milk',
      translit: 'al-ḥalīb'),
  KidsSentence(
      letter: 'خ',
      sentence: 'الْخُبْزُ طَازَجٌ',
      targetWord: 'الْخُبْزُ',
      gloss: 'the bread',
      translit: 'al-khubz'),
  KidsSentence(
      letter: 'د',
      sentence: 'الدَّجَاجَةُ تَبِيضُ بَيْضًا',
      targetWord: 'الدَّجَاجَةُ',
      gloss: 'the hen',
      translit: 'ad-dajājah'),
  KidsSentence(
      letter: 'ذ',
      sentence: 'هَذَا ذَهَبٌ لَامِعٌ',
      targetWord: 'ذَهَبٌ',
      gloss: 'gold',
      translit: 'dhahab'),
  KidsSentence(
      letter: 'ر',
      sentence: 'رَأَيْتُ قَمَرًا فِي السَّمَاءِ',
      targetWord: 'قَمَرًا',
      gloss: 'a moon',
      translit: 'qamaran'),
  KidsSentence(
      letter: 'ز',
      sentence: 'الزَّهْرَةُ جَمِيلَةٌ',
      targetWord: 'الزَّهْرَةُ',
      gloss: 'the flower',
      translit: 'az-zahrah'),
  KidsSentence(
      letter: 'س',
      sentence: 'السَّمَكَةُ تَسْبَحُ فِي الْمَاءِ',
      targetWord: 'السَّمَكَةُ',
      gloss: 'the fish',
      translit: 'as-samakah'),
  KidsSentence(
      letter: 'ش',
      sentence: 'الشَّمْسُ سَاطِعَةٌ الْيَوْمَ',
      targetWord: 'الشَّمْسُ',
      gloss: 'the sun',
      translit: 'ash-shams'),
  KidsSentence(
      letter: 'ص',
      sentence: 'الصَّقْرُ يَطِيرُ عَالِيًا',
      targetWord: 'الصَّقْرُ',
      gloss: 'the falcon',
      translit: 'aṣ-ṣaqr'),
  KidsSentence(
      letter: 'ض',
      sentence: 'الضِّفْدَعُ يَقْفِزُ',
      targetWord: 'الضِّفْدَعُ',
      gloss: 'the frog',
      translit: 'aḍ-ḍifdaʿ'),
  KidsSentence(
      letter: 'ط',
      sentence: 'الطَّائِرُ يُغَرِّدُ فَوْقَ الشَّجَرَةِ',
      targetWord: 'الطَّائِرُ',
      gloss: 'the bird',
      translit: 'aṭ-ṭāʼir'),
  KidsSentence(
      letter: 'ظ',
      sentence: 'الظِّلُّ بَارِدٌ تَحْتَ الشَّجَرَةِ',
      targetWord: 'الظِّلُّ',
      gloss: 'the shade',
      translit: 'aẓ-ẓill'),
  KidsSentence(
      letter: 'ع',
      sentence: 'الْعَيْنُ تَرَى النُّورَ',
      targetWord: 'الْعَيْنُ',
      gloss: 'the eye',
      translit: 'al-ʿayn'),
  KidsSentence(
      letter: 'غ',
      sentence: 'الْغُرَابُ أَسْوَدُ',
      targetWord: 'الْغُرَابُ',
      gloss: 'the crow',
      translit: 'al-ghurāb'),
  KidsSentence(
      letter: 'ف',
      sentence: 'الْفِيلُ كَبِيرٌ جِدًّا',
      targetWord: 'الْفِيلُ',
      gloss: 'the elephant',
      translit: 'al-fīl'),
  KidsSentence(
      letter: 'ق',
      sentence: 'أَحْمَدُ يَحْمِلُ قَلَمًا أَزْرَقَ',
      targetWord: 'قَلَمًا',
      gloss: 'a pen',
      translit: 'qalaman'),
  KidsSentence(
      letter: 'ك',
      sentence: 'فَتَحْتُ الْكِتَابَ وَقَرَأْتُ',
      targetWord: 'الْكِتَابَ',
      gloss: 'the book',
      translit: 'al-kitāb'),
  KidsSentence(
      letter: 'ل',
      sentence: 'اللَّيْلُ هَادِئٌ',
      targetWord: 'اللَّيْلُ',
      gloss: 'the night',
      translit: 'al-layl'),
  KidsSentence(
      letter: 'م',
      sentence: 'الْمَاءُ بَارِدٌ وَعَذْبٌ',
      targetWord: 'الْمَاءُ',
      gloss: 'the water',
      translit: 'al-māʼ'),
  KidsSentence(
      letter: 'ن',
      sentence: 'النَّحْلَةُ تَصْنَعُ الْعَسَلَ',
      targetWord: 'النَّحْلَةُ',
      gloss: 'the bee',
      translit: 'an-naḥlah'),
  KidsSentence(
      letter: 'ه',
      sentence: 'الْهِلَالُ فِي السَّمَاءِ',
      targetWord: 'الْهِلَالُ',
      gloss: 'the crescent',
      translit: 'al-hilāl'),
  KidsSentence(
      letter: 'و',
      sentence: 'الْوَلَدُ يَلْعَبُ فِي الْحَدِيقَةِ',
      targetWord: 'الْوَلَدُ',
      gloss: 'the boy',
      translit: 'al-walad'),
  KidsSentence(
      letter: 'ي',
      sentence: 'الْيَدُ نَظِيفَةٌ',
      targetWord: 'الْيَدُ',
      gloss: 'the hand',
      translit: 'al-yad'),
];

/// The sentence reinforcing [letter], or **null** when none is authored.
///
/// Deliberately nullable: this used to fall back to `kidsSentences.first`, so
/// every letter without an entry — Alif included — silently taught بَيْتٌ, the
/// بـ sentence. A missing sentence now shortens the lesson to trace → result
/// instead of showing an unrelated word. `test/kids_sentences_test.dart`
/// asserts the set is in fact complete.
KidsSentence? sentenceForLetter(String letter) {
  for (final s in kidsSentences) {
    if (s.letter == letter) return s;
  }
  return null;
}

/// A short Arabic congratulation for the "Great job!" screen, alongside the
/// (localized) UI copy — the same decorative-Arabic-regardless-of-UI-language
/// treatment `home_screen.dart` gives its greeting banner. Gendered so it's
/// grammatically correct (أَحْسَنْتَ for a boy, أَحْسَنْتِ for a girl); a profile
/// with no gender set gets a real gender-neutral word instead of an
/// unvoweled compromise.
String kidsPraiseArabic(String gender) => switch (gender) {
      'm' => 'أَحْسَنْتَ!',
      'f' => 'أَحْسَنْتِ!',
      _ => 'رَائِعٌ!',
    };
