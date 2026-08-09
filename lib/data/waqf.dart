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
  // Several real examples beyond `example`/`ref`, not just one.
  final List<(String, String, String)> moreExamples;

  const WaqfMark(this.id, this.name, this.arabicName, this.action, this.note,
      this.example, this.ref, this.scripts, [this.moreExamples = const []]);
}

const waqfMarks = <WaqfMark>[
  WaqfMark('lazim', 'Lāzim', 'م — الوقف اللازم', 'must_stop',
      'A required stop — continuing without pausing changes the meaning.', 'مَثَلٗاۘ', '2:26', 'both', [('قَوۡلِهِمۡۘ', '2:118', 'ۡۘ'), ('ءَامَنُواْۘ', '2:212', 'ْۘ'), ('بَعۡضٖۘ', '2:253', 'ٖۘ')]),
  WaqfMark('mamnu', 'Mamnū‘', 'لا — الوقف الممنوع', 'must_not_stop',
      'Stopping here is forbidden — it would break the sentence apart. Absent from the Madani muṣḥaf bundled in this app; common in Indo-Pak muṣḥafs.', 'الۡعٰلَمِيۡنَۙ‏', '1:2', 'indopak', [('الرَّحِيۡمِۙ‏', '1:3', 'ِۙ'), ('الۡمُسۡتَقِيۡمَۙ‏', '1:6', 'َۙ'), ('عَلَيۡهِمۡۙ', '1:7', 'ۡۙ')]),
  WaqfMark('jaiz', 'Jā’iz', 'ج — الوقف الجائز', 'either',
      'A permissible stop — fine to pause or to continue, no preference either way.', 'ٱلۡمَوۡتِۚ', '2:19', 'both', [('قَامُواْۚ', '2:20', 'ْۚ'), ('وَأَبۡصَٰرِهِمۡۚ', '2:20', 'ۡۚ'), ('فَوۡقَهَاۚ', '2:26', 'اۚ')]),
  WaqfMark('wasl_awla', 'Al-Waṣl Awlā', 'صلى — الوصل أولى', 'preferred_continue',
      'Continuing is preferable, though stopping is allowed.', 'رَّبِّهِمۡۖ', '2:5', 'both', [('سَمۡعِهِمۡۖ', '2:7', 'ۡۖ'), ('غِشَٰوَةٞۖ', '2:7', 'ٞۖ'), ('مَرَضٗاۖ', '2:10', 'اۖ')]),
  WaqfMark('waqf_awla', 'Al-Waqf Awlā', 'قلى — الوقف أولى', 'preferred_stop',
      'Stopping is preferable, though continuing is allowed. Absent from the bundled Indo-Pak text.', 'ٱلسُّفَهَآءُۗ', '2:13', 'madani', [('سَأَلۡتُمۡۗ', '2:61', 'ۡۗ'), ('ٱللَّهِۗ', '2:74', 'ِۗ'), ('ٱلۡعَذَابِۗ', '2:85', 'ِۗ')]),
  WaqfMark('muanaqah', 'Mu‘ānaqah', 'ۛ ۛ — علامة التعانق', 'either_not_both',
      'Two stop marks close together, linked — stop at exactly one of the two, never at both and never at neither.', 'ذَٰلِكَ ٱلۡكِتَٰبُ لَا رَيۡبَۛ فِيهِۛ هُدٗى لِّلۡمُتَّقِينَ', '2:2', 'both', [('قَالَ فَإِنَّهَا مُحَرَّمَةٌ عَلَيۡهِمۡۛ أَرۡبَعِينَ سَنَةٗۛ يَتِيهُونَ فِي ٱلۡأَرۡضِۚ فَلَا تَأۡسَ عَلَى ٱلۡقَوۡمِ ٱلۡفَٰسِقِينَ', '5:26', 'ۡۛ'), ('۞يَـٰٓأَيُّهَا ٱلرَّسُولُ لَا يَحۡزُنكَ ٱلَّذِينَ يُسَٰرِعُونَ فِي ٱلۡكُفۡرِ مِنَ ٱلَّذِينَ قَالُوٓاْ ءَامَنَّا بِأَفۡوَٰهِهِمۡ وَلَمۡ تُؤۡمِن قُلُوبُهُمۡۛ وَمِنَ ٱلَّذِينَ هَادُواْۛ سَمَّـٰعُونَ لِلۡكَذِبِ سَمَّـٰعُونَ لِقَوۡمٍ ءَاخَرِينَ لَمۡ يَأۡتُوكَۖ يُحَرِّفُونَ ٱلۡكَلِمَ مِنۢ بَعۡدِ مَوَاضِعِهِۦۖ يَقُولُونَ إِنۡ أُوتِيتُمۡ هَٰذَا فَخُذُوهُ وَإِن لَّمۡ تُؤۡتَوۡهُ فَٱحۡذَرُواْۚ وَمَن يُرِدِ ٱللَّهُ فِتۡنَتَهُۥ فَلَن تَمۡلِكَ لَهُۥ مِنَ ٱللَّهِ شَيۡـًٔاۚ أُوْلَـٰٓئِكَ ٱلَّذِينَ لَمۡ يُرِدِ ٱللَّهُ أَن يُطَهِّرَ قُلُوبَهُمۡۚ لَهُمۡ فِي ٱلدُّنۡيَا خِزۡيٞۖ وَلَهُمۡ فِي ٱلۡأٓخِرَةِ عَذَابٌ عَظِيمٞ', '5:41', 'ۡۛ')]),
  WaqfMark('sajdah', 'Sajdah', '۩ — سجدة التلاوة', 'page',
      'Marks a verse of prostration — a physical sajdah is recommended on recitation or hearing it. 15 places in this muṣḥaf; absent from the bundled Indo-Pak text.', 'يَسۡجُدُونَۤ۩', '7:206', 'madani', [('وَٱلۡأٓصَالِ۩', '13:15', 'ِ۩'), ('يُؤۡمَرُونَ۩', '16:50', 'َ۩'), ('خُشُوعٗا۩', '17:109', 'ا۩')]),
  WaqfMark('rub', 'Rubʿ al-Ḥizb', '۞ — بداية الربع', 'page',
      'Marks the start of a quarter-ḥizb — a navigation aid for reciters working through a set portion, not a stopping instruction.', '۞إِنَّ', '2:26', 'madani', [('۞أَتَأۡمُرُونَ', '2:44', '۞'), ('۞وَإِذِ', '2:60', '۞'), ('۞أَفَتَطۡمَعُونَ', '2:75', '۞')]),
];

WaqfMark waqfMarkById(String id) => waqfMarks.firstWhere((m) => m.id == id);
