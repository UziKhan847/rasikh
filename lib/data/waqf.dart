/// Waqf (stopping) signs and page marks. [scripts] records which of this
/// app's two bundled scripts actually carry the mark — several are
/// script-specific, which is itself real evidence for the Script Families
/// unit (see script_diff.dart). [example]/[ref] are drawn from whichever
/// script the mark actually appears in.
class WaqfMark {
  final String id;
  final String name;
  final String arabicName;
  final String action; // 'must_stop' | 'must_not_stop' | 'either' | 'either_not_both' | 'preferred_stop' | 'preferred_continue' | 'page'
  final String note;
  final String example;
  final String ref;
  final String scripts; // 'both' | 'madani' | 'indopak'

  const WaqfMark(this.id, this.name, this.arabicName, this.action, this.note,
      this.example, this.ref, this.scripts);
}

const waqfMarks = <WaqfMark>[
  WaqfMark('lazim', 'Lāzim', 'م — الوقف اللازم', 'must_stop',
      'A required stop — continuing without pausing changes the meaning.', 'مَثَلٗاۘ', '2:26', 'both'),
  WaqfMark('mamnu', 'Mamnū‘', 'لا — الوقف الممنوع', 'must_not_stop',
      'Stopping here is forbidden — it would break the sentence apart. Absent from the Madani muṣḥaf bundled in this app; common in Indo-Pak muṣḥafs.', 'الۡعٰلَمِيۡنَۙ‏', '1:2', 'indopak'),
  WaqfMark('jaiz', 'Jā’iz', 'ج — الوقف الجائز', 'either',
      'A permissible stop — fine to pause or to continue, no preference either way.', 'ٱلۡمَوۡتِۚ', '2:19', 'both'),
  WaqfMark('wasl_awla', 'Al-Waṣl Awlā', 'صلى — الوصل أولى', 'preferred_continue',
      'Continuing is preferable, though stopping is allowed.', 'رَّبِّهِمۡۖ', '2:5', 'both'),
  WaqfMark('waqf_awla', 'Al-Waqf Awlā', 'قلى — الوقف أولى', 'preferred_stop',
      'Stopping is preferable, though continuing is allowed. Absent from the bundled Indo-Pak text.', 'ٱلسُّفَهَآءُۗ', '2:13', 'madani'),
  WaqfMark('muanaqah', 'Mu‘ānaqah', 'ۛ ۛ — علامة التعانق', 'either_not_both',
      'Two stop marks close together, linked — stop at exactly one of the two, never at both and never at neither.', 'ذَٰلِكَ ٱلۡكِتَٰبُ لَا رَيۡبَۛ فِيهِۛ هُدٗى لِّلۡمُتَّقِينَ', '2:2', 'both'),
  WaqfMark('sajdah', 'Sajdah', '۩ — سجدة التلاوة', 'page',
      'Marks a verse of prostration — a physical sajdah is recommended on recitation or hearing it. 15 places in this muṣḥaf; absent from the bundled Indo-Pak text.', 'يَسۡجُدُونَۤ۩', '7:206', 'madani'),
  WaqfMark('rub', 'Rubʿ al-Ḥizb', '۞ — بداية الربع', 'page',
      'Marks the start of a quarter-ḥizb — a navigation aid for reciters working through a set portion, not a stopping instruction.', '۞إِنَّ', '2:26', 'madani'),
];

WaqfMark waqfMarkById(String id) => waqfMarks.firstWhere((m) => m.id == id);
