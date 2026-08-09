/// Makhraj — where a letter's sound originates. The 17 classical points
/// (Ibn al-Jazarī's scheme), grouped into 5 zones. [makhrajOfLetter] maps
/// every core letter, plus hamzah, to exactly one point — its consonant
/// articulation. و and ي's second role as madd letters (from the jawf) is a
/// different function, not a second point, so it is only noted on the jawf
/// entry, not modelled as a second mapping.
class Makhraj {
  final String id;
  final String zone; // 'jawf' | 'halq' | 'lisan' | 'shafatan' | 'khayshum'
  final String group; // lisan only: 'back' | 'middle' | 'edge' | 'tip'; '' elsewhere
  final String name;
  final String arabicName;
  final String letters; // teaching list; may include a letter noted elsewhere too
  final String note; // where it is
  final String how; // how the sound is actually produced
  // One real corpus word per member letter (letter, word, ref, highlight) —
  // several examples, not just a bare letter list.
  final List<(String, String, String, String)> examples;

  const Makhraj(this.id, this.zone, this.group, this.name, this.arabicName,
      this.letters, this.note, this.how,
      [this.examples = const []]);
}

const makharij = <Makhraj>[
  Makhraj('jawf', 'jawf', '', 'The Oral Cavity', 'الجوف', 'اوي',
      'No contact point at all — the three madd letters (ا و ي, each preceded by its matching short vowel) ring out through the open cavity.',
      'The sound rings freely through the open mouth and throat with no contact anywhere — alif after a fatḥah, wāw after a ḍammah, yāʼ after a kasrah. This is why madd letters can be held for several counts: nothing is stopping the airflow.',
      [('ا', 'إِيَّاكَ', '1:5', 'ا'), ('و', 'وَٱلۡعَصۡرِ', '103:1', 'وَ'), ('ي', 'يَوۡمِ', '1:4', 'يَ')]),
  Makhraj('halq_aqsa', 'halq', '', 'Farthest Throat', 'أقصى الحلق', 'ءه',
      'Deepest in the throat, closest to the chest.',
      'ء is a full, momentary closure of the throat at its very base, releasing the breath in a light burst; ه is the same spot left open, so the breath passes through as a soft, breathy hiss with no closure at all.',
      [('ء', 'سَوَآءٌ', '2:6', 'ء'), ('ه', 'هُوَ', '112:1', 'هُ')]),
  Makhraj('halq_wasat', 'halq', '', 'Middle Throat', 'وسط الحلق', 'عح',
      'The middle of the throat.',
      'ع narrows the middle of the throat until the airflow buzzes through it; ح is the same spot left open a little wider, so the air passes as a rough, unvoiced friction instead.',
      [('ع', 'ٱلۡعَٰلَمِينَ', '1:2', 'عَٰ'), ('ح', 'ٱلۡحَمۡدُ', '1:2', 'حَ')]),
  Makhraj('halq_adna', 'halq', '', 'Nearest Throat', 'أدنى الحلق', 'غخ',
      'Closest to the mouth, where the throat meets the tongue.',
      'The very back of the tongue rises toward the soft palate at the throat’s entrance, narrowing the passage — غ voices it into a soft gargle, خ leaves it unvoiced as a harsher rasp.',
      [('غ', 'غَيۡرِ', '1:7', 'غَ'), ('خ', 'خَلَقَ', '96:1', 'خَ')]),
  Makhraj('lisan_aqsa_qaf', 'lisan', 'back', 'Tongue Base — Qāf', 'أقصى اللسان (قاف)', 'ق',
      'The very back of the tongue against the soft palate.',
      'The back of the tongue presses fully up against the soft palate (the fleshy back roof of the mouth), sealing the passage completely before releasing in a hard, heavy pop.',
      [('ق', 'قُلۡ', '112:1', 'قُ')]),
  Makhraj('lisan_aqsa_kaf', 'lisan', 'back', 'Tongue Base — Kāf', 'أقصى اللسان (كاف)', 'ك',
      'Just in front of qāf’s point, still at the back of the tongue.',
      'The back of the tongue presses against the hard palate, a little further forward and higher than qāf’s spot — the seal is lighter, giving a thinner, drier pop.',
      [('ك', 'ٱلۡكَوۡثَرَ', '108:1', 'كَ')]),
  Makhraj('lisan_wasat', 'lisan', 'middle', 'Tongue Middle', 'وسط اللسان', 'جشي',
      'The middle of the tongue against the middle of the hard palate.',
      'The middle of the tongue rises to meet the middle of the hard palate — ج seals it fully for an instant before releasing with friction; ش and ي leave a narrow gap for the air to pass through continuously.',
      [('ج', 'جَآءَ', '110:1', 'ج'), ('ش', 'شَهۡرٖ', '97:3', 'شَ'), ('ي', 'يَوۡمِ', '1:4', 'يَ')]),
  Makhraj('lisan_hafah_dad', 'lisan', 'edge', 'Tongue Edge — Ḍād', 'حافة اللسان (ضاد)', 'ض',
      'One edge of the tongue (either side) against the upper molars — the hardest letter for most learners.',
      'One full side edge of the tongue (whichever comes naturally — left, right, or both) presses along the upper molars, sealing that whole side before the sound releases with a heavy, drawn-out pressure.',
      [('ض', 'ٱلۡمَغۡضُوبِ', '1:7', 'ض')]),
  Makhraj('lisan_hafah_lam', 'lisan', 'edge', 'Tongue Edge — Lām', 'حافة اللسان (لام)', 'ل',
      'The edge of the tongue, further forward than ḍād, against the gum ridge.',
      'The edge of the tongue — further forward and lighter than ḍād’s contact — presses against the gum ridge just behind the upper front teeth, letting the air flow around both sides.',
      [('ل', 'لَهَبٖ', '111:1', 'لَ')]),
  Makhraj('lisan_tarf_nun', 'lisan', 'tip', 'Tongue Tip — Nūn', 'طرف اللسان (نون)', 'ن',
      'The tip of the tongue, just below lām’s point.',
      'The very tip of the tongue touches the gum ridge just below lām’s spot, sealing the mouth completely while the sound is released as a hum through the nose instead — the source of every ghunnah.',
      [('ن', 'نَعۡبُدُ', '1:5', 'نَ')]),
  Makhraj('lisan_tarf_raa', 'lisan', 'tip', 'Tongue Tip — Rā’', 'طرف اللسان (راء)', 'ر',
      'The tip of the tongue, slightly further back than nūn, with a light flick.',
      'The tip of the tongue flicks lightly against the gum ridge, a touch further back than nūn’s point — a single quick tap, not a rolled or repeated trill.',
      [('ر', 'رَبِّ', '1:2', 'ر')]),
  Makhraj('lisan_tarf_tdt', 'lisan', 'tip', 'Tongue Tip & Front Teeth', 'طرف اللسان مع الثنايا', 'طدت',
      'The tip of the tongue against the base of the upper front teeth: ط د ت.',
      'The tip of the tongue presses against the base (root) of the upper front teeth, sealing the mouth completely before releasing — ط heavy and forceful, د and ت lighter, voiced and unvoiced respectively.',
      [('ط', 'طه', '20:1', 'ط'), ('د', 'دِينِ', '109:6', 'دِ'), ('ت', 'تَبَّتۡ', '111:1', 'ت')]),
  Makhraj('lisan_tarf_sibilants', 'lisan', 'tip', 'Tongue Tip Between the Incisors', 'طرف اللسان بين الثنايا', 'صزس',
      'The tip of the tongue near the edge of the lower incisors, whistling letters: ص ز س.',
      'The tip of the tongue hovers just above the edge of the lower front teeth, leaving a narrow channel the air whistles through — ص heavy, ز voiced, س light and unvoiced.',
      [('ص', 'ٱلصَّمَدُ', '112:2', 'ص'), ('ز', 'زُلۡزِلَتِ', '99:1', 'زُ'), ('س', 'سَلَٰمٌ', '97:5', 'سَ')]),
  Makhraj('lisan_tarf_interdental', 'lisan', 'tip', 'Tongue Tip & Upper Incisor Edges', 'طرف اللسان مع أطراف الثنايا', 'ظذث',
      'The tip of the tongue just touching the edges of the upper front teeth: ظ ذ ث.',
      'The tip of the tongue lightly touches the very edges of the upper front teeth, letting a continuous stream of air pass — ظ heavy, ذ voiced, ث light and unvoiced.',
      [('ظ', 'عَظِيمٞ', '2:7', 'ظِ'), ('ذ', 'ذَٰلِكَ', '2:2', 'ذَٰ'), ('ث', 'ثُمَّ', '78:5', 'ث')]),
  Makhraj('shafatan_fa', 'shafatan', '', 'Lip & Teeth — Fā’', 'بطن الشفة (فاء)', 'ف',
      'The inside of the lower lip against the edges of the upper front teeth.',
      'The inner edge of the lower lip touches the tips of the upper front teeth, leaving a narrow gap for a continuous, unvoiced stream of air.',
      [('ف', 'ٱلۡفَلَقِ', '113:1', 'فَ')]),
  Makhraj('shafatan_bmw', 'shafatan', '', 'The Two Lips', 'الشفتان', 'بمو',
      'Both lips together — closed for ب م, rounded for و.',
      'The two lips meet fully for ب and م, sealing the mouth before releasing (م through the nose); for و the lips only round and narrow, without ever fully closing.',
      [('ب', 'بِسۡمِ', '1:1', 'بِ'), ('م', 'مَٰلِكِ', '1:4', 'مَٰ'), ('و', 'وَٱلۡعَصۡرِ', '103:1', 'وَ')]),
  Makhraj('khayshum', 'khayshum', '', 'The Nasal Cavity', 'الخيشوم', '',
      'Not a letter’s own point — the ghunnah (nasal hum) riding on nūn/mīm in ghunnah, iqlāb, ikhfā’, and idghām with ghunnah comes from here.',
      'No letter is fully articulated here on its own — instead, whenever nūn or mīm carries a ghunnah, the soft palate drops and lets part of the airflow escape through the nose, producing the nasal hum that rides alongside (or in place of) the mouth articulation.',
      []),
];

/// The 5 zones, in classical order (nearest the chest to the lips), plus
/// their tap targets on the Makhārij index — Oral Cavity · Throat · Tongue ·
/// Lips · Nasal Cavity.
class MakhrajZone {
  final String id;
  final String name;
  final String arabicName;
  final String note;
  const MakhrajZone(this.id, this.name, this.arabicName, this.note);
}

const makhrajZones = <MakhrajZone>[
  MakhrajZone('jawf', 'The Oral Cavity', 'الجوف',
      'Not really a point of contact at all — the open mouth and throat themselves, where the three madd letters ring out freely.'),
  MakhrajZone('halq', 'The Throat', 'الحلق',
      'Three points, from deepest to nearest the mouth: ء ه (farthest), ع ح (middle), غ خ (nearest).'),
  MakhrajZone('lisan', 'The Tongue', 'اللسان',
      'Ten points — more than any other zone — from the back of the tongue to its very tip.'),
  MakhrajZone('shafatan', 'The Lips', 'الشفتان',
      'Two points: the lower lip against the teeth, and the two lips together.'),
  MakhrajZone('khayshum', 'The Nasal Cavity', 'الخيشوم',
      'Not a letter’s own point — where the ghunnah (nasal hum) comes from.'),
];

List<Makhraj> makharijOfZone(String zone) =>
    makharij.where((m) => m.zone == zone).toList();

/// Every core letter (+ hamzah) mapped to exactly one makhraj id.
const Map<String, String> makhrajOfLetter = {
  'ء': 'halq_aqsa',
  'ا': 'jawf',
  'ب': 'shafatan_bmw',
  'ت': 'lisan_tarf_tdt',
  'ث': 'lisan_tarf_interdental',
  'ج': 'lisan_wasat',
  'ح': 'halq_wasat',
  'خ': 'halq_adna',
  'د': 'lisan_tarf_tdt',
  'ذ': 'lisan_tarf_interdental',
  'ر': 'lisan_tarf_raa',
  'ز': 'lisan_tarf_sibilants',
  'س': 'lisan_tarf_sibilants',
  'ش': 'lisan_wasat',
  'ص': 'lisan_tarf_sibilants',
  'ض': 'lisan_hafah_dad',
  'ط': 'lisan_tarf_tdt',
  'ظ': 'lisan_tarf_interdental',
  'ع': 'halq_wasat',
  'غ': 'halq_adna',
  'ف': 'shafatan_fa',
  'ق': 'lisan_aqsa_qaf',
  'ك': 'lisan_aqsa_kaf',
  'ل': 'lisan_hafah_lam',
  'م': 'shafatan_bmw',
  'ن': 'lisan_tarf_nun',
  'ه': 'halq_aqsa',
  'و': 'shafatan_bmw',
  'ي': 'lisan_wasat',
};

Makhraj makhrajById(String id) => makharij.firstWhere((m) => m.id == id);
