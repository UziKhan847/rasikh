/// Ṣifāt — the characteristics of a letter's sound, independent of where
/// it's articulated. Five axes are (near-)opposed pairs, linked by [opposite];
/// every letter takes one side of each of the five axes (shiddah's axis has a
/// genuine third, middle value, tawassuṭ, rather than a clean binary — see its
/// note). The rest are standalone qualities some letters carry and others
/// don't.
class Sifah {
  final String id;
  final String name;
  final String arabicName;
  final String opposite; // the paired axis id; '' for a standalone quality
  final String letters;
  final String note;
  // One real corpus word per member letter (letter, word, ref, highlight).
  final List<(String, String, String, String)> examples;

  const Sifah(this.id, this.name, this.arabicName, this.opposite, this.letters, this.note,
      [this.examples = const []]);
}

const sifat = <Sifah>[
  Sifah('hams', 'Hams', 'هَمْس', 'jahr', 'فحثهشخصسكت',
      'The breath flows freely through — the vocal cords stay relaxed. Mnemonic: فحثه شخص سكت.', [('ف', 'ٱلۡفَلَقِ', '113:1', 'فَ'), ('ح', 'ٱلۡحَمۡدُ', '1:2', 'حَ'), ('ث', 'ثُمَّ', '78:5', 'ثُ'), ('ه', 'هُوَ', '112:1', 'هُ'), ('ش', 'شَهۡرٖ', '97:3', 'شَ')]),
  Sifah('jahr', 'Jahr', 'جَهْر', 'hams', 'ءابجدذرزضطظعغقلمنوي',
      'The breath is held back — the vocal cords vibrate and the sound rings.', [('ء', 'سَوَآءٌ', '2:6', 'ءٌ'), ('ا', 'إِيَّاكَ', '1:5', 'ا'), ('ب', 'بِسۡمِ', '1:1', 'بِ'), ('ج', 'جَآءَ', '110:1', 'جَ'), ('د', 'دِينِ', '109:6', 'دِ')]),
  Sifah('shidda', 'Shiddah', 'شِدَّة', 'rakhawa', 'ءجدقطبكت',
      'The sound stops completely for an instant — a full plosive. Mnemonic: أجد قطب كت.', [('ء', 'سَوَآءٌ', '2:6', 'ءٌ'), ('ج', 'جَآءَ', '110:1', 'جَ'), ('د', 'دِينِ', '109:6', 'دِ'), ('ق', 'قُلۡ', '112:1', 'قُ'), ('ط', 'طه', '20:1', 'ط')]),
  Sifah('tawassut', 'Tawassuṭ', 'تَوَسُّط', '', 'لنعمر',
      'Neither a full stop nor a free flow — partway between shiddah and rakhāwah. Mnemonic: لن عمر.', [('ل', 'لَهَبٖ', '111:1', 'لَ'), ('ن', 'نَعۡبُدُ', '1:5', 'نَ'), ('ع', 'ٱلۡعَٰلَمِينَ', '1:2', 'عَٰ'), ('م', 'مَٰلِكِ', '1:4', 'مَٰ'), ('ر', 'رَبِّ', '1:2', 'رَ')]),
  Sifah('rakhawa', 'Rakhāwah', 'رَخَاوَة', 'shidda', 'اثحخذزسشصضظغفهوي',
      'The sound flows freely the whole time the letter is held — a fricative.', [('ا', 'إِيَّاكَ', '1:5', 'ا'), ('ث', 'ثُمَّ', '78:5', 'ثُ'), ('ح', 'ٱلۡحَمۡدُ', '1:2', 'حَ'), ('خ', 'خَلَقَ', '96:1', 'خَ'), ('ذ', 'ذَٰلِكَ', '2:2', 'ذَٰ')]),
  Sifah('istila', 'Isti‘lā’', 'اسْتِعْلَاء', 'istifal', 'خصضغطقظ',
      'The back of the tongue rises toward the soft palate — a heavy, full sound. Mnemonic: خص ضغط قظ. The same seven letters as the Tafkhīm rule.', [('خ', 'خَلَقَ', '96:1', 'خَ'), ('ص', 'ٱلصَّمَدُ', '112:2', 'صَّ'), ('ض', 'ٱلضَّآلِّينَ', '1:7', 'ضَّ'), ('غ', 'غَيۡرِ', '1:7', 'غَ'), ('ط', 'طه', '20:1', 'ط')]),
  Sifah('istifal', 'Istifāl', 'اسْتِفَال', 'istila', 'ءابتثجحدذرزسشعفكلمنهوي',
      'The tongue stays low in the mouth — a light sound, the default state.', [('ء', 'سَوَآءٌ', '2:6', 'ءٌ'), ('ا', 'إِيَّاكَ', '1:5', 'ا'), ('ب', 'بِسۡمِ', '1:1', 'بِ'), ('ت', 'تَبَّتۡ', '111:1', 'تَ'), ('ث', 'ثُمَّ', '78:5', 'ثُ')]),
  Sifah('itbaq', 'Iṭbāq', 'إِطْبَاق', 'infitah', 'صضطظ',
      'The tongue presses along its whole length against the palate, sealing the sound in — the heaviest four letters.', [('ص', 'ٱلصَّمَدُ', '112:2', 'صَّ'), ('ض', 'ٱلضَّآلِّينَ', '1:7', 'ضَّ'), ('ط', 'طه', '20:1', 'ط'), ('ظ', 'عَظِيمٞ', '2:7', 'ظِ')]),
  Sifah('infitah', 'Infitāḥ', 'انْفِتَاح', 'itbaq', 'ءابتثجحخدذرزسشعغفقكلمنهوي',
      'The tongue leaves a gap against the palate — most letters, including the other three isti‘lā’ letters.', [('ء', 'سَوَآءٌ', '2:6', 'ءٌ'), ('ا', 'إِيَّاكَ', '1:5', 'ا'), ('ب', 'بِسۡمِ', '1:1', 'بِ'), ('ت', 'تَبَّتۡ', '111:1', 'تَ'), ('ث', 'ثُمَّ', '78:5', 'ثُ')]),
  Sifah('idhlaq', 'Idhlāq', 'إِذْلَاق', 'ismat', 'فرمنلب',
      'Articulated at the tip of the tongue or the lips — fluent, easy letters. Mnemonic: فرّ من لب (every 4+ letter Arabic root has at least one of these).', [('ف', 'ٱلۡفَلَقِ', '113:1', 'فَ'), ('ر', 'رَبِّ', '1:2', 'رَ'), ('م', 'مَٰلِكِ', '1:4', 'مَٰ'), ('ن', 'نَعۡبُدُ', '1:5', 'نَ'), ('ل', 'لَهَبٖ', '111:1', 'لَ')]),
  Sifah('ismat', 'Iṣmāt', 'إِصْمَات', 'idhlaq', 'ءاتثجحخدذزسشصضطظعغقكهوي',
      'Held back — heavier on the tongue, rarer to find all four+ root letters from this set alone.', [('ء', 'سَوَآءٌ', '2:6', 'ءٌ'), ('ا', 'إِيَّاكَ', '1:5', 'ا'), ('ت', 'تَبَّتۡ', '111:1', 'تَ'), ('ث', 'ثُمَّ', '78:5', 'ثُ'), ('ج', 'جَآءَ', '110:1', 'جَ')]),
  Sifah('safir', 'Ṣafīr', 'صَفِير', '', 'صزس',
      'A sharp whistling hiss alongside the letter: ص ز س.', [('ص', 'ٱلصَّمَدُ', '112:2', 'صَّ'), ('ز', 'زُلۡزِلَتِ', '99:1', 'زُ'), ('س', 'سَلَٰمٌ', '97:5', 'سَ')]),
  Sifah('qalqalah_sifah', 'Qalqalah', 'قَلْقَلَة', '', 'قطبجد',
      'An echoing bounce when the letter is sākin — strongest when stopping on it. The same five letters as the Qalqalah rule: قُطْبُ جَدٍّ.', [('ق', 'قُلۡ', '112:1', 'قُ'), ('ط', 'طه', '20:1', 'ط'), ('ب', 'بِسۡمِ', '1:1', 'بِ'), ('ج', 'جَآءَ', '110:1', 'جَ'), ('د', 'دِينِ', '109:6', 'دِ')]),
  Sifah('lin', 'Līn', 'لِين', '', 'وي',
      'A soft, effortless glide — و or ي sākinah preceded by a fatḥah.', [('و', 'وَٱلۡعَصۡرِ', '103:1', 'وَ'), ('ي', 'يَوۡمِ', '1:4', 'يَ')]),
  Sifah('inhiraf', 'Inḥirāf', 'انْحِرَاف', '', 'لر',
      'The sound leans toward an adjacent articulation point: ل toward the tongue tip, ر toward the back of the tongue.', [('ل', 'لَهَبٖ', '111:1', 'لَ'), ('ر', 'رَبِّ', '1:2', 'رَ')]),
  Sifah('takrir', 'Takrīr', 'تَكْرِير', '', 'ر',
      'A slight trill in the tip of the tongue — real, but a reciter must never exaggerate it into a rolled rrr.', [('ر', 'رَبِّ', '1:2', 'رَ')]),
  Sifah('tafashshi', 'Tafashshī', 'تَفَشِّي', '', 'ش',
      'The breath spreads out across the mouth as the letter is said.', [('ش', 'شَهۡرٖ', '97:3', 'شَ')]),
  Sifah('istitala', 'Istiṭālah', 'اسْتِطَالَة', '', 'ض',
      'The sound draws out along the full edge of the tongue — unique to ض, which is why it is singled out as the hardest letter of the alphabet.', [('ض', 'ٱلضَّآلِّينَ', '1:7', 'ضَّ')]),
];

List<Sifah> sifatOf(String letter) =>
    sifat.where((s) => s.letters.contains(letter)).toList();

Sifah sifahById(String id) => sifat.firstWhere((s) => s.id == id);

/// The 5 opposed-pair axes, grouped by classical teaching pair (shiddah's
/// axis is a genuine 3-way — shiddah / tawassuṭ / rakhāwah — not a clean
/// binary, so it can't be reconstructed from [Sifah.opposite] alone).
const sifatAxes = <List<String>>[
  ['hams', 'jahr'],
  ['shidda', 'tawassut', 'rakhawa'],
  ['istila', 'istifal'],
  ['itbaq', 'infitah'],
  ['idhlaq', 'ismat'],
];

/// The standalone qualities — every [Sifah] not part of an opposed axis.
List<Sifah> get sifatStandalone {
  final inAxis = {for (final axis in sifatAxes) ...axis};
  return sifat.where((s) => !inAxis.contains(s.id)).toList();
}
