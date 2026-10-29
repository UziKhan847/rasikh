import '../../data/mushaf.dart';
import '../marks/word_ref.dart';

/// The muṣḥaf's words, for fluency marks: a word's text as printed, and
/// the word read after it (across an āyah's end: its ۝ is skipped).

/// [r]'s text in [script] ('' if unknown), without the pause signs
/// printed over it (ٱللَّهِۚ is ٱللَّهِ to read).
String formOf(String script, WordRef r) =>
    cleanForm(MushafRepo.wordText(script, r.globalAyah, r.word0));

/// [w] without pause signs, the ḥizb and sajdah signs.
String cleanForm(String w) => String.fromCharCodes(w.runes.where((c) =>
    !(c >= 0x06D6 && c <= 0x06DC) && c != 0x06DE && c != 0x06E9 && c != 0x200C));

/// The word after [r] (null at the muṣḥaf's end).
WordRef? nextWordOf(String script, WordRef r) {
  var t = MushafRepo.tokenOf(script, r.globalAyah, r.word0);
  if (t < 0) return null;
  final n = MushafRepo.tokenCount(script);
  while (++t < n) {
    final (g, w) = MushafRepo.tokenAt(script, t);
    if (w >= 0) return WordRef.fromGlobal(g, w);
  }
  return null;
}
