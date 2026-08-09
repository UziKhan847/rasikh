/// Tanwīn is written in two different shapes in the muṣḥaf, and which one
/// appears tells you which tajwīd rule applies to it — the shape isn't
/// decorative. The classic parallel dots/dashes (ً ٌ ٍ) mark iẓhār (clear
/// pronunciation); the alternate stacked marks (ٗ ٞ ٖ) mark idghām or ikhfāʾ;
/// and a small mīm above or below (ۢ ۭ) replaces tanwīn entirely before a
/// bāʾ, marking iqlāb.
///
/// Correlated against the whole bundled corpus (assets/quran/u/): the
/// parallel forms precede an iẓhār letter 96-98% of the time; the alternate
/// forms precede an iẓhār letter 0.0% of the time. [ruleId] links to the
/// matching rule in tajweed.dart, which already has the colour and the full
/// trigger/how explanation — this file only teaches the shape ↔ rule link,
/// it doesn't restate the rule.
///
/// `letters.dart`'s `tanwin` list and `tashkeel.dart`'s three tanwīn entries
/// both show the plain parallel shape when just naming the mark — this file
/// is where the shape distinction itself is taught.
class TanwinAllograph {
  final String id;
  final String tanwinId; // 'fathatan' | 'dammatan' | 'kasratan' — matches TashkilItem.id
  final String form; // 'parallel' | 'alternate' | 'iqlab'
  final String ruleId; // tajweed.dart TajwidRule.id this shape signals
  final String example; // verbatim Uthmani word
  final String ref; // surah:ayah
  final String highlight; // substring of example carrying the mark
  final List<(String, String, String)> moreExamples; // several, not just one

  const TanwinAllograph(this.id, this.tanwinId, this.form, this.ruleId,
      this.example, this.ref, this.highlight, [this.moreExamples = const []]);
}

const tanwinAllographs = <TanwinAllograph>[
  TanwinAllograph('fathatan.parallel', 'fathatan', 'parallel', 'izhar', 'رَغَدًا', '2:35', 'دًا', [('قِرَدَةً', '2:65', 'ةً'), ('شَهَٰدَةً', '2:140', 'ةً'), ('لَكَبِيرَةً', '2:143', 'ةً')]),
  TanwinAllograph('fathatan.alternate', 'fathatan', 'alternate', 'idgham_g', 'هُدٗى', '2:5', 'دٗى', [('بِنَآءٗ', '2:22', 'ءٗ'), ('مَآءٗ', '2:22', 'ءٗ'), ('بَعُوضَةٗ', '2:26', 'ةٗ')]),
  TanwinAllograph('fathatan.iqlab', 'fathatan', 'iqlab', 'iqlab', 'قَآئِمَۢا', '3:18', 'مَۢ', [('أَبَدَۢا', '2:95', 'َۢا'), ('بَغۡيَۢا', '2:213', 'َۢا'), ('مَتَٰعَۢا', '2:236', 'َۢا')]),
  TanwinAllograph('dammatan.parallel', 'dammatan', 'parallel', 'izhar', 'سَوَآءٌ', '2:6', 'ءٌ', [('عَذَابٌ', '2:7', 'بٌ'), ('بُكۡمٌ', '2:18', 'مٌ'), ('وَمَتَٰعٌ', '2:36', 'عٌ')]),
  TanwinAllograph('dammatan.alternate', 'dammatan', 'alternate', 'idgham_g', 'ظُلُمَٰتٞ', '2:19', 'تٞ', [('عَظِيمٞ', '2:7', 'مٞ'), ('مَّرَضٞ', '2:10', 'ضٞ'), ('عُمۡيٞ', '2:18', 'يٞ')]),
  TanwinAllograph('dammatan.iqlab', 'dammatan', 'iqlab', 'iqlab', 'أَلِيمُۢ', '2:10', 'مُۢ', [('صُمُّۢ', '2:18', 'ُۢ'), ('مُحِيطُۢ', '2:19', 'ُۢ'), ('مِنۢ', '2:27', 'نۢ')]),
  TanwinAllograph('kasratan.parallel', 'kasratan', 'parallel', 'izhar', 'شَيۡءٍ', '2:29', 'ءٍ', [('لِبَعۡضٍ', '2:36', 'ضٍ'), ('بِغَٰفِلٍ', '2:74', 'لٍ'), ('بِغَضَبٍ', '2:90', 'بٍ')]),
  TanwinAllograph('kasratan.alternate', 'kasratan', 'alternate', 'idgham_g', 'كَصَيِّبٖ', '2:19', 'بٖ', [('ظُلُمَٰتٖ', '2:17', 'تٖ'), ('شَيۡءٖ', '2:20', 'ءٖ'), ('رَيۡبٖ', '2:23', 'بٖ')]),
  TanwinAllograph('kasratan.iqlab', 'kasratan', 'iqlab', 'iqlab', 'قَوۡمِۭ', '4:90', 'مِۭ', [('كَافِرِۭ', '2:41', 'ِۭ'), ('ءَايَٰتِۭ', '2:99', 'ِۭ'), ('شِقَاقِۭ', '2:176', 'ِۭ')]),
];
