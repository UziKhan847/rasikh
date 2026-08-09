/// Hand-drawn muṣḥaf shapes for Joining Forms > Special Shapes.
///
/// [LetterVariant] (variants.dart) renders each shape by slicing a fragment
/// out of a verbatim Qur'anic word and letting UthmanicHafs's own GSUB
/// shape it. That works when the fragment sits in the same position it was
/// found in, but the lesson tile shows the fragment ALONE — pulled out of
/// its neighbors, UthmanicHafs falls back to the fragment's default/
/// isolated form, which is exactly the wrong shape for a page whose whole
/// point is the non-default contextual form. [SpecialShape] fixes this by
/// showing a hand-traced SVG of the real contextual shape instead of text.
///
/// [variants.dart] is NOT replaced — [LetterVariant] still backs the quiz
/// question generators in qaidah_screen.dart and its own corpus-verified
/// tests, and every [SpecialShape.examples] entry below is a verbatim word
/// copied from an already-tested [LetterVariant], not hand-typed.
///
/// Several shapes have more than one hand-drawn positional form (a beginning
/// and a middle rendering, say), and a few single drawings cover what used
/// to be several separate [LetterVariant] tiles (one mīm-over-jīm/ḥāʾ/khāʾ
/// drawing replaces three). [SpecialShape.variantIds] records which old
/// entries a tile supersedes, so nothing is silently dropped.
library;

/// Where a hand-drawn form sits in a word. Captioned via the SAME
/// formAlone/formStart/formMiddle/formEnd strings a plain letter's joining
/// forms already use — nothing new is localized for this axis.
enum ShapePosition { isolated, beginning, middle, ending }

/// One hand-drawn rendering of a shape — the (shape, position) key. A tile
/// owning several of these shows them side by side in its build strip,
/// replacing the old "apart -> joined" text pair.
class ShapeForm {
  final String asset; // 'assets/special_cases/middle_ha.svg'

  /// Caption via [ShapePosition] when the forms differ by WHERE they sit in
  /// a word; via [label] when they differ by something else (lām + hamzah's
  /// forms differ by which mark the hamzah carries, not by word position).
  /// Exactly one of the two is set.
  final ShapePosition? position;
  final String label;

  const ShapeForm(this.asset, {this.position, this.label = ''})
      : assert((position == null) != (label == ''),
            'ShapeForm needs exactly one of position/label');
}

/// One real muṣḥaf example. [asset] is '' for every entry right now — the
/// hand-drawn example SVGs exist but carry no word/ref metadata yet, so
/// every example below renders as UthmanicHafs text (still correct: a whole
/// word shapes properly, it's only an isolated FRAGMENT that doesn't).
/// [word] stays populated even when [asset] is empty, since it doubles as
/// the accessibility label once art is wired in.
class ShapeExample {
  final String asset;
  final String word; // verbatim Uthmani
  final String ref; // 'surah:ayah'
  final String highlight; // substring of [word]; '' = whole word
  const ShapeExample({this.asset = '', this.word = '', this.ref = '', this.highlight = ''});
}

class SpecialShape {
  final String id;
  final String group; // 'ligature' | 'kaf' | 'stacking' | 'tails'
  final String title; // hardcoded English, matching variants.dart's own notes
  final String note; // -> LessonDetail.intro
  final String tellApart; // disambiguation note -> its own facts row
  final List<ShapeForm> forms; // 1..3
  final List<ShapeExample> examples; // may be empty for a brand-new shape
  final List<String> variantIds; // LetterVariant ids this tile supersedes

  const SpecialShape({
    required this.id,
    required this.group,
    required this.title,
    required this.note,
    required this.tellApart,
    required this.forms,
    this.examples = const [],
    this.variantIds = const [],
  });
}

SpecialShape shapeById(String id) => specialShapes.firstWhere((s) => s.id == id);

/// Intrinsic size of each drawn asset, in millimetres, taken verbatim from
/// its own `<svg width="..mm" height="..mm">`. All 20 were traced from the
/// QCF2004 muṣḥaf font at one consistent scale
/// (`matrix(0.26458333,...)`, the 96dpi px->mm factor), so these sizes are
/// directly comparable ACROSS files — a lām-alif is genuinely tall, a
/// tooth-over-mīm is genuinely small, and the widget layer scales every
/// shape off ONE shared px-per-mm factor so that stays true on screen.
const shapeSvgMm = <String, (double, double)>{
  'assets/special_cases/beginning_ayn_and_middle_jim_7a_kha.svg': (13.367203, 12.202789),
  'assets/special_cases/beginning_ba_ta_tha_nun_ya_and_ending_mim.svg': (10.068356, 13.869211),
  'assets/special_cases/beginning_ba_ta_tha_nun_ya_and_middle_jim_7a_kha.svg': (12.382201, 8.8135105),
  'assets/special_cases/beginning_ba_ta_tha_nun_ya_and_middle_meem.svg': (8.3938934, 8.2777601),
  'assets/special_cases/beginning_elongated_kaf.svg': (20.620522, 9.4318091),
  'assets/special_cases/beginning_fa_qaf_and_jim_7a_kha.svg': (12.110886, 11.354689),
  'assets/special_cases/beginning_kaf_with_lam_or_alif.svg': (14.475571, 16.167361),
  'assets/special_cases/beginning_meem_and_middle_mim.svg': (8.4600479, 8.4062105),
  'assets/special_cases/beginning_mim_and_middle_jim_7a_kha.svg': (12.044911, 10.08927),
  'assets/special_cases/elongated_ending_ra_za.svg': (14.677548, 12.432471),
  'assets/special_cases/ending_lam_alif.svg': (12.152016, 14.642927),
  'assets/special_cases/isolated_lam_alif.svg': (10.92591, 17.728202),
  'assets/special_cases/lam_and_jim_7a_kha.svg': (11.207512, 13.492733),
  'assets/special_cases/lam_hamza_alif.svg': (11.120774, 17.710668),
  'assets/special_cases/lam_hamza_with_fathah_or_dhammah.svg': (11.607881, 17.946908),
  'assets/special_cases/lam_hamza_with_kasrah.svg': (10.693322, 20.827932),
  'assets/special_cases/middle_ba_ta_tha_nun_ya_and_middle_mim.svg': (9.3835966, 8.0845991),
  'assets/special_cases/middle_elongated_kaf.svg': (21.213156, 10.340147),
  'assets/special_cases/middle_ha.svg': (9.1988404, 11.115761),
  'assets/special_cases/middle_kaf_with_lam_or_alif.svg': (14.14297, 14.883462),
};

/// The [LetterVariant] ids with no hand-drawn shape yet. Still listed in
/// their group, dimmed, locked — tapping shows "coming soon" instead of
/// navigating. Every one of these renders its shape WRONG today (a lone
/// dotless yāʾ picks its dots right back up in isolation, etc.) except
/// `taa_marbuta.word_final`, which has no distinct medial/initial form and
/// so still renders correctly as plain text; it's locked here for
/// consistency with its Heights & Tails siblings, not because it's broken.
const pendingVariantIds = <String>[
  'tooth.elevated',
  'tooth.before_ain_tah',
  'tooth.after_descender',
  'haa.word_final',
  'taa_marbuta.word_final',
  'yeh.dotless_final',
  'lam.tucks_mim',
];

const specialShapes = <SpecialShape>[
  // ── Ligatures ────────────────────────────────────────────────────────
  SpecialShape(
    id: 'lam_alif',
    group: 'ligature',
    title: 'Lām + Alif',
    note: 'Lām followed by a plain alif fuses into one shape — the alif’s '
        'stroke rises through lām’s loop instead of standing beside it.',
    tellApart: 'No dot and no hamzah mark anywhere on the stroke — that’s '
        'what makes this the plain lām-alif. A mark riding above or below '
        'the rising stroke means one of the lām + hamzah ligatures instead.',
    forms: [
      ShapeForm('assets/special_cases/isolated_lam_alif.svg', position: ShapePosition.isolated),
      ShapeForm('assets/special_cases/ending_lam_alif.svg', position: ShapePosition.ending),
    ],
    examples: [
          ShapeExample(word: 'وَلَا', ref: '1:7', highlight: 'لَا'),
          ShapeExample(word: 'لَا', ref: '2:2', highlight: 'لَا'),
          ShapeExample(word: 'إِلَّآ', ref: '2:9', highlight: 'لَّآ'),
        ],
    variantIds: ['lam_alif.ligature'],
  ),
  SpecialShape(
    id: 'lam_hamza',
    group: 'ligature',
    title: 'Lām + Hamzah',
    note: 'The same lām-alif fusion, but carrying a hamzah — above the '
        'alif, below it, or riding a standalone alif maddah. The ligature '
        'shape barely changes; only the mark on top shifts.',
    tellApart: 'Read the mark on the rising stroke: a hamzah sitting above '
        'it (with a fatḥah or ḍammah) is أ; a hamzah tucked below it (with '
        'a kasrah) is إ; a wavy maddah with no separate hamzah mark is the '
        'alif maddah form.',
    forms: [
      ShapeForm('assets/special_cases/lam_hamza_with_fathah_or_dhammah.svg',
          label: 'Hamzah Above'),
      ShapeForm('assets/special_cases/lam_hamza_with_kasrah.svg', label: 'Hamzah Below'),
      ShapeForm('assets/special_cases/lam_hamza_alif.svg', label: 'With Alif Maddah'),
    ],
    examples: [
          ShapeExample(word: 'وَبِٱلۡأٓخِرَةِ', ref: '2:4', highlight: 'لۡأٓ'),
          ShapeExample(word: 'بِٱلۡإِثۡمِ', ref: '2:85', highlight: 'لۡإِ'),
        ],
    variantIds: ['lam_alif.hamza_above', 'lam_alif.hamza_below'],
  ),

  // ── Kāf's Wrap ───────────────────────────────────────────────────────
  SpecialShape(
    id: 'kaf_wraps',
    group: 'kaf',
    title: 'Kāf Wrapping Lām or Alif',
    note: 'Kāf’s tail curls up and over a following alif or lām instead of '
        'sitting beside it — the letter tucks into the curve.',
    tellApart: 'Look at what’s nested inside the curl: a single plain '
        'stroke with nothing else attached is alif; a stroke that itself '
        'has a small hook or loop at its foot is lām.',
    forms: [
      ShapeForm('assets/special_cases/beginning_kaf_with_lam_or_alif.svg',
          position: ShapePosition.beginning),
      ShapeForm('assets/special_cases/middle_kaf_with_lam_or_alif.svg',
          position: ShapePosition.middle),
    ],
    examples: [
          ShapeExample(word: 'كَانُواْ', ref: '2:10', highlight: 'كَا'),
          ShapeExample(word: 'كُلَّمَآ', ref: '2:20', highlight: 'كُلَّ'),
        ],
    variantIds: ['kaf.wraps_alif', 'kaf.wraps_lam'],
  ),
  SpecialShape(
    id: 'kaf_elongated',
    group: 'kaf',
    title: 'Elongated Kāf',
    note: 'Kāf’s flat stroke along the baseline stretches out much further '
        'than usual — a stylistic lengthening used to fill out a line, not '
        'a different letter.',
    tellApart: 'Kāf keeps its usual hooked head here — only the straight '
        'stroke beneath it runs unusually long. Same head as an ordinary '
        'kāf, just a longer tail.',
    forms: [
      ShapeForm('assets/special_cases/beginning_elongated_kaf.svg',
          position: ShapePosition.beginning),
      ShapeForm('assets/special_cases/middle_elongated_kaf.svg', position: ShapePosition.middle),
    ],
  ),

  // ── Stacking ─────────────────────────────────────────────────────────
  SpecialShape(
    id: 'mim_over_jim',
    group: 'stacking',
    title: 'Mīm over Jīm, Ḥāʾ, or Khāʾ',
    note: 'Mīm’s loop drops down and nests inside the open bowl of a '
        'following jīm, ḥāʾ, or khāʾ instead of sitting beside it — mīm '
        'comes first in reading order, but its loop tucks under the letter '
        'that follows.',
    tellApart: 'The bowl underneath is the same open curve for all three '
        'letters. Check the dot: none below the bowl is ḥāʾ, one dot below '
        'is jīm, one dot above is khāʾ.',
    forms: [
      ShapeForm('assets/special_cases/beginning_mim_and_middle_jim_7a_kha.svg',
          position: ShapePosition.beginning),
    ],
    examples: [
          ShapeExample(word: 'مُجۡرِمِينَ', ref: '9:66', highlight: 'مُجۡ'),
          ShapeExample(word: 'مُحِيطُۢ', ref: '2:19', highlight: 'مُحِ'),
          ShapeExample(word: 'مُخۡرِجٞ', ref: '2:72', highlight: 'مُخۡ'),
        ],
    variantIds: ['mim.stacks_jeem', 'mim.stacks_hah', 'mim.stacks_khah'],
  ),
  SpecialShape(
    id: 'lam_over_jim',
    group: 'stacking',
    title: 'Lām over Jīm, Ḥāʾ, or Khāʾ',
    note: 'Lām’s upright stroke leans back and its foot tucks under the '
        'bowl of a following jīm, ḥāʾ, or khāʾ rather than continuing '
        'along the baseline.',
    tellApart: 'Same bowl, same dot rule as mīm’s stack: no dot is ḥāʾ, a '
        'dot below is jīm, a dot above is khāʾ.',
    forms: [
      ShapeForm('assets/special_cases/lam_and_jim_7a_kha.svg', position: ShapePosition.beginning),
    ],
    examples: [
          ShapeExample(word: 'ٱلۡحَمۡدُ', ref: '1:2', highlight: 'لۡحَ'),
          ShapeExample(word: 'ٱلۡخَوۡفِ', ref: '2:155', highlight: 'لۡخَ'),
          ShapeExample(word: 'ٱلۡجَنَّةَ', ref: '2:35', highlight: 'لۡجَ'),
        ],
    variantIds: ['lam.stacks_hah', 'lam.stacks_khah', 'lam.stacks_jeem'],
  ),
  SpecialShape(
    id: 'tooth_over_jim',
    group: 'stacking',
    title: 'A Tooth Letter over Jīm, Ḥāʾ, or Khāʾ',
    note: 'A tooth letter (ب ت ث ن ي) riding just before jīm, ḥāʾ, or khāʾ '
        'tucks its head down into the bowl the same way mīm and lām do.',
    tellApart: 'One dot below serves either letter, so read its horizontal '
        'position: further right it belongs to the tooth letter (bāʾ, tāʾ, '
        'nūn) underneath; further left it belongs to the jīm on top. '
        '(Thāʾ and yāʾ carry their own extra dots above, unaffected either '
        'way; ḥāʾ has no dot at all, khāʾ has one above.)',
    forms: [
      ShapeForm('assets/special_cases/beginning_ba_ta_tha_nun_ya_and_middle_jim_7a_kha.svg',
          position: ShapePosition.beginning),
    ],
  ),
  SpecialShape(
    id: 'tooth_over_mim',
    group: 'stacking',
    title: 'A Tooth Letter over Mīm',
    note: 'A tooth letter’s connecting stroke drops and mīm’s loop nests '
        'beneath it — the same nesting pattern as tooth-over-jīm, but with '
        'mīm’s round loop instead of an open bowl.',
    tellApart: 'Mīm’s loop is fully closed and round, unlike jīm/ḥāʾ/khāʾ’s '
        'open bowl — that alone tells the two families of stacking apart, '
        'before checking any dots.',
    forms: [
      ShapeForm('assets/special_cases/beginning_ba_ta_tha_nun_ya_and_middle_meem.svg',
          position: ShapePosition.beginning),
      ShapeForm('assets/special_cases/middle_ba_ta_tha_nun_ya_and_middle_mim.svg',
          position: ShapePosition.middle),
    ],
  ),
  SpecialShape(
    id: 'ayn_over_jim',
    group: 'stacking',
    title: 'ʿAyn over Jīm, Ḥāʾ, or Khāʾ',
    note: 'ʿAyn’s looped head sits above and a following jīm, ḥāʾ, or '
        'khāʾ’s bowl tucks underneath it — the same stacking pattern as '
        'mīm and lām, with ʿayn on top instead.',
    tellApart: 'ʿAyn’s own loop stays open at the top — don’t mistake it '
        'for mīm’s closed loop riding in a similar position. Below it the '
        'usual rule applies: no dot is ḥāʾ, a dot below is jīm, a dot '
        'above is khāʾ.',
    forms: [
      ShapeForm('assets/special_cases/beginning_ayn_and_middle_jim_7a_kha.svg',
          position: ShapePosition.beginning),
    ],
  ),
  SpecialShape(
    id: 'faqaf_over_jim',
    group: 'stacking',
    title: 'Fāʾ or Qāf over Jīm, Ḥāʾ, or Khāʾ',
    note: 'Fāʾ or qāf’s round head sits above a following jīm, ḥāʾ, or '
        'khāʾ’s bowl — the same stacking family again, this time with '
        'fāʾ/qāf on top.',
    tellApart: 'One dot above the head is fāʾ; two dots above is qāf. '
        'Below the head, the usual rule: no dot is ḥāʾ, a dot below is '
        'jīm, a dot above is khāʾ.',
    forms: [
      ShapeForm('assets/special_cases/beginning_fa_qaf_and_jim_7a_kha.svg',
          position: ShapePosition.beginning),
    ],
  ),
  SpecialShape(
    id: 'mim_over_mim',
    group: 'stacking',
    title: 'Mīm over Mīm',
    note: 'Two mīms in a row: the first mīm’s loop rides above and the '
        'second nests directly beneath it, rather than the two sitting '
        'side by side.',
    tellApart: 'Both loops look identical — mīm never carries a dot to '
        'distinguish them. Reading order runs the top loop first, then '
        'the nested loop underneath.',
    forms: [
      ShapeForm('assets/special_cases/beginning_meem_and_middle_mim.svg',
          position: ShapePosition.beginning),
    ],
  ),

  // ── Heights & Tails ──────────────────────────────────────────────────
  SpecialShape(
    id: 'mim_final_after_tooth',
    group: 'tails',
    title: 'Final Mīm After a Tooth Letter',
    note: 'Mīm’s final loop tucks in close under a preceding tooth letter '
        'rather than trailing level with it.',
    tellApart: 'This only shows up at the very end of a word, with mīm as '
        'the last letter — the loop itself is mīm’s ordinary final shape, '
        'just nudged in closer to its neighbor. Check position, not shape.',
    forms: [
      ShapeForm('assets/special_cases/beginning_ba_ta_tha_nun_ya_and_ending_mim.svg',
          position: ShapePosition.ending),
    ],
    examples: [
          ShapeExample(word: 'ٱلرَّحِيمِ', ref: '1:1', highlight: 'يمِ'),
          ShapeExample(word: 'ٱلۡمُسۡتَقِيمَ', ref: '1:6', highlight: 'يمَ'),
        ],
    variantIds: ['mim.final_after_tooth'],
  ),
  SpecialShape(
    id: 'haa_medial',
    group: 'tails',
    title: 'Medial Hāʾ',
    note: 'A medial hāʾ narrows into its small double-loop shape, nested '
        'closely against the letters on either side of it.',
    tellApart: 'Hāʾ’s medial form is a tight figure-eight, not a single '
        'open loop — that shape is what marks it as hāʾ rather than a '
        'medial mīm sitting in a similar spot.',
    forms: [
      ShapeForm('assets/special_cases/middle_ha.svg', position: ShapePosition.middle),
    ],
    examples: [
          ShapeExample(word: 'ٱللَّهِ', ref: '1:1', highlight: 'لَّهِ'),
          ShapeExample(word: 'وَلَهُمۡ', ref: '2:7', highlight: 'لَهُ'),
        ],
    variantIds: ['haa.medial_after_lam'],
  ),
  SpecialShape(
    id: 'ra_za_elongated_final',
    group: 'tails',
    title: 'Elongated Final Rāʾ or Zāy',
    note: 'A final rāʾ or zāy’s downward tail stretches out along the '
        'baseline instead of the usual short curl — the same stylistic '
        'lengthening kāf gets, applied to a different letter.',
    tellApart: 'Rāʾ carries no dot; zāy carries one dot above. The '
        'elongated tail itself doesn’t tell them apart — check for the dot.',
    forms: [
      ShapeForm('assets/special_cases/elongated_ending_ra_za.svg', position: ShapePosition.ending),
    ],
  ),
];
