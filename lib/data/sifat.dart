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

  const Sifah(this.id, this.name, this.arabicName, this.opposite, this.letters, this.note);
}

const sifat = <Sifah>[
  Sifah('hams', 'Hams', 'هَمْس', 'jahr', 'فحثهشخصسكت',
      'The breath flows freely through — the vocal cords stay relaxed. Mnemonic: فحثه شخص سكت.'),
  Sifah('jahr', 'Jahr', 'جَهْر', 'hams', 'ءابجدذرزضطظعغقلمنوي',
      'The breath is held back — the vocal cords vibrate and the sound rings.'),
  Sifah('shidda', 'Shiddah', 'شِدَّة', 'rakhawa', 'ءجدقطبكت',
      'The sound stops completely for an instant — a full plosive. Mnemonic: أجد قطب كت.'),
  Sifah('tawassut', 'Tawassuṭ', 'تَوَسُّط', '', 'لنعمر',
      'Neither a full stop nor a free flow — partway between shiddah and rakhāwah. Mnemonic: لن عمر.'),
  Sifah('rakhawa', 'Rakhāwah', 'رَخَاوَة', 'shidda', 'اثحخذزسشصضظغفهوي',
      'The sound flows freely the whole time the letter is held — a fricative.'),
  Sifah('istila', 'Isti‘lā’', 'اسْتِعْلَاء', 'istifal', 'خصضغطقظ',
      'The back of the tongue rises toward the soft palate — a heavy, full sound. Mnemonic: خص ضغط قظ. The same seven letters as the Tafkhīm rule.'),
  Sifah('istifal', 'Istifāl', 'اسْتِفَال', 'istila', 'ءابتثجحدذرزسشعفكلمنهوي',
      'The tongue stays low in the mouth — a light sound, the default state.'),
  Sifah('itbaq', 'Iṭbāq', 'إِطْبَاق', 'infitah', 'صضطظ',
      'The tongue presses along its whole length against the palate, sealing the sound in — the heaviest four letters.'),
  Sifah('infitah', 'Infitāḥ', 'انْفِتَاح', 'itbaq', 'ءابتثجحخدذرزسشعغفقكلمنهوي',
      'The tongue leaves a gap against the palate — most letters, including the other three isti‘lā’ letters.'),
  Sifah('idhlaq', 'Idhlāq', 'إِذْلَاق', 'ismat', 'فرمنلب',
      'Articulated at the tip of the tongue or the lips — fluent, easy letters. Mnemonic: فرّ من لب (every 4+ letter Arabic root has at least one of these).'),
  Sifah('ismat', 'Iṣmāt', 'إِصْمَات', 'idhlaq', 'ءاتثجحخدذزسشصضطظعغقكهوي',
      'Held back — heavier on the tongue, rarer to find all four+ root letters from this set alone.'),
  Sifah('safir', 'Ṣafīr', 'صَفِير', '', 'صزس',
      'A sharp whistling hiss alongside the letter: ص ز س.'),
  Sifah('qalqalah_sifah', 'Qalqalah', 'قَلْقَلَة', '', 'قطبجد',
      'An echoing bounce when the letter is sākin — strongest when stopping on it. The same five letters as the Qalqalah rule: قُطْبُ جَدٍّ.'),
  Sifah('lin', 'Līn', 'لِين', '', 'وي',
      'A soft, effortless glide — و or ي sākinah preceded by a fatḥah.'),
  Sifah('inhiraf', 'Inḥirāf', 'انْحِرَاف', '', 'لر',
      'The sound leans toward an adjacent articulation point: ل toward the tongue tip, ر toward the back of the tongue.'),
  Sifah('takrir', 'Takrīr', 'تَكْرِير', '', 'ر',
      'A slight trill in the tip of the tongue — real, but a reciter must never exaggerate it into a rolled rrr.'),
  Sifah('tafashshi', 'Tafashshī', 'تَفَشِّي', '', 'ش',
      'The breath spreads out across the mouth as the letter is said.'),
  Sifah('istitala', 'Istiṭālah', 'اسْتِطَالَة', '', 'ض',
      'The sound draws out along the full edge of the tongue — unique to ض, which is why it is singled out as the hardest letter of the alphabet.'),
];

List<Sifah> sifatOf(String letter) =>
    sifat.where((s) => s.letters.contains(letter)).toList();

Sifah sifahById(String id) => sifat.firstWhere((s) => s.id == id);
