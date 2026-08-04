/// Makhraj — where a letter's sound originates. The 17 classical points
/// (Ibn al-Jazarī's scheme), grouped into 5 zones. [makhrajOfLetter] maps
/// every core letter, plus hamzah, to exactly one point — its consonant
/// articulation. و and ي's second role as madd letters (from the jawf) is a
/// different function, not a second point, so it is only noted on the jawf
/// entry, not modelled as a second mapping.
class Makhraj {
  final String id;
  final String zone; // 'jawf' | 'halq' | 'lisan' | 'shafatan' | 'khayshum'
  final String name;
  final String arabicName;
  final String letters; // teaching list; may include a letter noted elsewhere too
  final String note;

  const Makhraj(this.id, this.zone, this.name, this.arabicName, this.letters, this.note);
}

const makharij = <Makhraj>[
  Makhraj('jawf', 'jawf', 'The Oral Cavity', 'الجوف', 'اوي',
      'No contact point at all — the three madd letters (ا و ي, each preceded by its matching short vowel) ring out through the open cavity.'),
  Makhraj('halq_aqsa', 'halq', 'Farthest Throat', 'أقصى الحلق', 'ءه',
      'Deepest in the throat, closest to the chest.'),
  Makhraj('halq_wasat', 'halq', 'Middle Throat', 'وسط الحلق', 'عح',
      'The middle of the throat.'),
  Makhraj('halq_adna', 'halq', 'Nearest Throat', 'أدنى الحلق', 'غخ',
      'Closest to the mouth, where the throat meets the tongue.'),
  Makhraj('lisan_aqsa_qaf', 'lisan', 'Tongue Base — Qāf', 'أقصى اللسان (قاف)', 'ق',
      'The very back of the tongue against the soft palate.'),
  Makhraj('lisan_aqsa_kaf', 'lisan', 'Tongue Base — Kāf', 'أقصى اللسان (كاف)', 'ك',
      'Just in front of qāf’s point, still at the back of the tongue.'),
  Makhraj('lisan_wasat', 'lisan', 'Tongue Middle', 'وسط اللسان', 'جشي',
      'The middle of the tongue against the middle of the hard palate.'),
  Makhraj('lisan_hafah_dad', 'lisan', 'Tongue Edge — Ḍād', 'حافة اللسان (ضاد)', 'ض',
      'One edge of the tongue (either side) against the upper molars — the hardest letter for most learners.'),
  Makhraj('lisan_hafah_lam', 'lisan', 'Tongue Edge — Lām', 'حافة اللسان (لام)', 'ل',
      'The edge of the tongue, further forward than ḍād, against the gum ridge.'),
  Makhraj('lisan_tarf_nun', 'lisan', 'Tongue Tip — Nūn', 'طرف اللسان (نون)', 'ن',
      'The tip of the tongue, just below lām’s point.'),
  Makhraj('lisan_tarf_raa', 'lisan', 'Tongue Tip — Rā’', 'طرف اللسان (راء)', 'ر',
      'The tip of the tongue, slightly further back than nūn, with a light flick.'),
  Makhraj('lisan_tarf_tdt', 'lisan', 'Tongue Tip & Front Teeth', 'طرف اللسان مع الثنايا', 'طدت',
      'The tip of the tongue against the base of the upper front teeth: ط د ت.'),
  Makhraj('lisan_tarf_sibilants', 'lisan', 'Tongue Tip Between the Incisors', 'طرف اللسان بين الثنايا', 'صزس',
      'The tip of the tongue near the edge of the lower incisors, whistling letters: ص ز س.'),
  Makhraj('lisan_tarf_interdental', 'lisan', 'Tongue Tip & Upper Incisor Edges', 'طرف اللسان مع أطراف الثنايا', 'ظذث',
      'The tip of the tongue just touching the edges of the upper front teeth: ظ ذ ث.'),
  Makhraj('shafatan_fa', 'shafatan', 'Lip & Teeth — Fā’', 'بطن الشفة (فاء)', 'ف',
      'The inside of the lower lip against the edges of the upper front teeth.'),
  Makhraj('shafatan_bmw', 'shafatan', 'The Two Lips', 'الشفتان', 'بمو',
      'Both lips together — closed for ب م, rounded for و.'),
  Makhraj('khayshum', 'khayshum', 'The Nasal Cavity', 'الخيشوم', '',
      'Not a letter’s own point — the ghunnah (nasal hum) riding on nūn/mīm in ghunnah, iqlāb, ikhfā’, and idghām with ghunnah comes from here.'),
];

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
