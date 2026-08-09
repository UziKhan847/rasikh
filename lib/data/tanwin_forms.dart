/// Fatḥatān's three real spellings at a word's end — the only tanwīn that
/// changes its written ending depending on what the word ends in, which is
/// why it alone gets a "how it's written" breakdown; kasratān and ḍammatān
/// never take a trailing alif. All three examples are corpus-verified real
/// words (see test/tanwin_forms_data_test.dart).
class TanwinForm {
  final String id; // 'with_alif' | 'teh_marbuta' | 'hamzah_alif'
  final String name;
  final String note;
  final String waqfNote; // what happens when you stop on it
  final String example;
  final String ref;
  final String highlight;
  final List<(String, String, String)> moreExamples;

  const TanwinForm(this.id, this.name, this.note, this.waqfNote, this.example,
      this.ref, this.highlight, [this.moreExamples = const []]);
}

const tanwinForms = <TanwinForm>[
  TanwinForm('with_alif', 'With a Trailing Alif',
      'The default spelling: fatḥatān is followed by an extra ا that carries no sound of its own — it only marks where the "-an" ending is written. Most fatḥatān words are spelled this way.',
      'On stopping, the nasalization drops and the ending is read as a plain two-count fatḥah — "-ā", not "-an".',
      'رَغَدًا', '2:35', 'دًا', [('قَوۡلًا', '2:59', 'لًا'), ('بَغۡيًا', '2:90', 'يًا'), ('هُودًا', '2:111', 'دًا')]),
  TanwinForm('teh_marbuta', 'On Tāʼ Marbūṭah',
      'No extra alif is written when the word already ends in ة — the fatḥatān sits directly on the tāʼ marbūṭah instead.',
      'On stopping, the tāʼ marbūṭah becomes a silent هْ — the ending is "-ah", not "-an" or "-ā". This is the one case that does NOT become a two-count fatḥah.',
      'قِرَدَةً', '2:65', 'ةً', [('شَهَٰدَةً', '2:140', 'ةً'), ('لَكَبِيرَةً', '2:143', 'ةً'), ('تِجَٰرَةً', '2:282', 'ةً')]),
  TanwinForm('hamzah_alif', 'After a Hamzah Already Seated on an Alif',
      'No extra alif is written when the word already ends in a hamzah carried on an alif (آء) — a second alif would be redundant, since one is already there.',
      'On stopping, this behaves like the plain trailing-alif case: a two-count fatḥah, "-ā".',
      'مَآءً', '24:39', 'ٓءً', [('جَزَآءً', '18:88', 'ٓءً'), ('عَطَآءً', '11:108', 'ٓءً'), ('نِدَآءً', '19:3', 'ٓءً')]),
];

TanwinForm tanwinFormById(String id) => tanwinForms.firstWhere((f) => f.id == id);
