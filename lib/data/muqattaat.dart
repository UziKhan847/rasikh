/// Ḥurūf Muqaṭṭaʿāt — the "disjointed letters" opening 29 sūrahs, always
/// read by naming each letter individually (never as a word). Qaidah
/// Nooraniyyah devotes its third lesson to them; this app previously had no
/// equivalent — confirmed absent from lib/ entirely.
///
/// There are exactly 14 distinct sets across those 29 sūrahs, built from 14
/// of the 28 letters — the classical mnemonic نص حكيم قاطع له سر ("naṣṣun
/// ḥakīmun qāṭiʿun lahu sirrun"). Surah 42 uniquely spans two consecutive
/// āyāt (حمٓ · عٓسٓقٓ), so it is its own set rather than folded into the
/// plain حمٓ group shared by the other six ḥā-mīm sūrahs.
///
/// [example] is verbatim from assets/quran/u/, including any trailing waqf
/// mark (e.g. Ṣad's ۚ) — kept for the substring test; strip it for display
/// with [displayText].
class MuqattaatSet {
  final String id;
  final String letters; // bare letters, e.g. 'الم'
  final String display; // as written, with maddah marks, e.g. 'الٓمٓ'
  final String example; // verbatim Uthmani (surah 42: both āyāt, '|'-joined)
  final String ref; // surah:ayah, or 'surah:1-2' for the one two-āyah set
  final List<int> surahs; // every sūrah that opens with this set
  // Every OTHER sūrah's real opening āyah beyond `example`/`ref` — several
  // examples, not just one, straight from the `surahs` list above.
  final List<(String, String)> moreExamples;

  const MuqattaatSet(this.id, this.letters, this.display, this.example,
      this.ref, this.surahs, [this.moreExamples = const []]);

  /// [display] with trailing waqf/stop signs removed — those are recitation
  /// marks, not part of the letters being named.
  String get displayText =>
      display.replaceAll(RegExp('[\u06D6-\u06DB\u06DE]'), '').trim();
}

const muqattaatSets = <MuqattaatSet>[
  MuqattaatSet('alif_lam_mim', 'الم', 'الٓمٓ', 'الٓمٓ', '2:1', [2, 3, 29, 30, 31, 32], [('الٓمٓ', '3:1'), ('الٓمٓ', '29:1'), ('الٓمٓ', '30:1'), ('الٓمٓ', '31:1'), ('الٓمٓ', '32:1')]),
  MuqattaatSet('alif_lam_mim_sad', 'المص', 'الٓمٓصٓ', 'الٓمٓصٓ', '7:1', [7], []),
  MuqattaatSet('alif_lam_ra', 'الر', 'الٓرۚ', 'الٓرۚ', '10:1', [10, 11, 12, 14, 15], [('الٓرۚ كِتَٰبٌ أُحۡكِمَتۡ ءَايَٰتُهُۥ ثُمَّ فُصِّلَتۡ مِن لَّدُنۡ حَكِيمٍ خَبِيرٍ', '11:1'), ('الٓرۚ تِلۡكَ ءَايَٰتُ ٱلۡكِتَٰبِ ٱلۡمُبِينِ', '12:1'), ('الٓرۚ كِتَٰبٌ أَنزَلۡنَٰهُ إِلَيۡكَ لِتُخۡرِجَ ٱلنَّاسَ مِنَ ٱلظُّلُمَٰتِ إِلَى ٱلنُّورِ بِإِذۡنِ رَبِّهِمۡ إِلَىٰ صِرَٰطِ ٱلۡعَزِيزِ ٱلۡحَمِيدِ', '14:1'), ('الٓرۚ تِلۡكَ ءَايَٰتُ ٱلۡكِتَٰبِ وَقُرۡءَانٖ مُّبِينٖ', '15:1')]),
  MuqattaatSet('alif_lam_mim_ra', 'المر', 'الٓمٓرۚ', 'الٓمٓرۚ', '13:1', [13], []),
  MuqattaatSet('kaf_ha2_ya_ain_sad', 'كهيعص', 'كٓهيعٓصٓ', 'كٓهيعٓصٓ', '19:1', [19], []),
  MuqattaatSet('ta_ha2', 'طه', 'طه', 'طه', '20:1', [20], []),
  MuqattaatSet('ta_sin_mim', 'طسم', 'طسٓمٓ', 'طسٓمٓ', '26:1', [26, 28], [('طسٓمٓ', '28:1')]),
  MuqattaatSet('ta_sin', 'طس', 'طسٓۚ', 'طسٓۚ', '27:1', [27], []),
  MuqattaatSet('ya_sin', 'يس', 'يسٓ', 'يسٓ', '36:1', [36], []),
  MuqattaatSet('sad', 'ص', 'صٓۚ', 'صٓۚ', '38:1', [38], []),
  MuqattaatSet('ha_mim', 'حم', 'حمٓ', 'حمٓ', '40:1', [40, 41, 43, 44, 45, 46], [('حمٓ', '41:1'), ('حمٓ', '43:1'), ('حمٓ', '44:1'), ('حمٓ', '45:1'), ('حمٓ', '46:1')]),
  MuqattaatSet('ha_mim_ain_sin_qaf', 'حمعسق', 'حمٓ', 'حمٓ | عٓسٓقٓ', '42:1-2', [42], []),
  MuqattaatSet('qaf', 'ق', 'قٓۚ', 'قٓۚ', '50:1', [50], []),
  MuqattaatSet('nun', 'ن', 'نٓۚ', 'نٓۚ', '68:1', [68], []),
];

/// Madd duration (in ḥarakāt) when each muqaṭṭaʿah letter is read alone as
/// its own name — the whole point of Qaidah lesson 3. '—' means the letter
/// has no madd letter in its own name (only alif has none). 'ʿayn' is the
/// one exception: books differ, so it is taught as 4-or-6 rather than a
/// fixed count like the rest of the six-count group.
const Map<String, String> muqattaatCounts = {
  'ا': '—',
  'ح': '2', 'ي': '2', 'ط': '2', 'ه': '2', 'ر': '2',
  'ن': '6', 'ق': '6', 'ص': '6', 'س': '6', 'ل': '6', 'ك': '6', 'م': '6',
  'ع': '4 or 6',
};
