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

  const TanwinAllograph(this.id, this.tanwinId, this.form, this.ruleId,
      this.example, this.ref, this.highlight);
}

const tanwinAllographs = <TanwinAllograph>[
  TanwinAllograph('fathatan.parallel', 'fathatan', 'parallel', 'izhar', 'رَغَدًا', '2:35', 'دًا'),
  TanwinAllograph('fathatan.alternate', 'fathatan', 'alternate', 'idgham_g', 'هُدٗى', '2:5', 'دٗى'),
  TanwinAllograph('fathatan.iqlab', 'fathatan', 'iqlab', 'iqlab', 'قَآئِمَۢا', '3:18', 'مَۢ'),
  TanwinAllograph('dammatan.parallel', 'dammatan', 'parallel', 'izhar', 'سَوَآءٌ', '2:6', 'ءٌ'),
  TanwinAllograph('dammatan.alternate', 'dammatan', 'alternate', 'idgham_g', 'ظُلُمَٰتٞ', '2:19', 'تٞ'),
  TanwinAllograph('dammatan.iqlab', 'dammatan', 'iqlab', 'iqlab', 'أَلِيمُۢ', '2:10', 'مُۢ'),
  TanwinAllograph('kasratan.parallel', 'kasratan', 'parallel', 'izhar', 'شَيۡءٍ', '2:29', 'ءٍ'),
  TanwinAllograph('kasratan.alternate', 'kasratan', 'alternate', 'idgham_g', 'كَصَيِّبٖ', '2:19', 'بٖ'),
  TanwinAllograph('kasratan.iqlab', 'kasratan', 'iqlab', 'iqlab', 'قَوۡمِۭ', '4:90', 'مِۭ'),
];
