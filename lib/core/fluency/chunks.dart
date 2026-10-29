/// A word as stem and attachments, for the fluency plan's chunk practice
/// ("see the familiar word inside"): the prefixes وَ فَ بِ لِ سَ and the
/// article, the pronoun suffixes ـهُ ـهَا ـهُمْ ـكُمْ ـنَا … A suggestion from
/// the text alone (there's no morphology here): the reader confirms or
/// moves the split.
library;

import 'joins.dart';

/// Where [word] splits: how many letters (clusters) are its prefix and its
/// suffix. (0, 0): nothing to split off.
(int, int) suggestSplit(String word) {
  final c = clustersOf(word);
  final n = c.length;
  bool vowel(int i, String v) => i < n && c[i].marks.contains(v);
  const fatha = 'َ', kasra = 'ِ';
  var p = 0;
  // وَ / فَ (and, so), then بِ / لِ (with, for) or سَ (will) before a
  // present-tense letter.
  if (p < n && 'وف'.contains(c[p].base) && vowel(p, fatha) && !_rootInitial(word)) {
    p++;
  }
  if (p < n && 'بل'.contains(c[p].base) && vowel(p, kasra)) {
    p++;
  } else if (p + 1 < n && c[p].base == 'س' && vowel(p, fatha) && 'يتنأ'.contains(c[p + 1].base)) {
    p++;
  }
  // The article: ٱل / ال (a lām with no vowel of its own, or a sun
  // letter's shaddah after it) — not in the Name, which stays whole.
  final rest = skeletonOf(c.skip(p).map((x) => '${x.base}${x.marks}').join());
  final name = rest == 'ٱلله' || rest == 'الله' || rest == 'لله';
  if (name) {
    // nothing more comes off
  } else if (p + 1 < n && 'ٱا'.contains(c[p].base) && c[p + 1].base == 'ل' &&
      !c[p + 1].marks.contains(fatha) && !c[p + 1].marks.contains(kasra)) {
    p += 2;
  } else if (!name && p > 0 && p + 1 < n && c[p].base == 'ل' && !c[p].marks.contains(fatha) &&
      !c[p].marks.contains(kasra) && c[p - 1].base == 'ل') {
    // لِلْ: lām of the article after لِ (its alif dropped).
    p++;
  }
  final skel = skeletonOf(word);
  var s = 0;
  for (final suf in name ? const <String>[] : _suffixes) {
    final need = suf.length == 1 ? 3 : 2; // a one-letter suffix needs more stem
    if (skel.endsWith(suf) && n - p - suf.length >= need) {
      s = suf.length;
      break;
    }
  }
  // The stem keeps two letters at least, else no prefix either.
  if (n - p - s < 2) return (0, 0);
  if (_whole.contains(skel)) return (0, 0);
  return (p, s);
}

/// The pronoun suffixes' letters, longest first.
const _suffixes = ['هما', 'كما', 'هم', 'هن', 'كم', 'كن', 'نا', 'ها', 'ني', 'ه', 'ك'];

/// Words to leave whole, by skeleton (the attachment-like letters are their
/// own).
const _whole = {'الله', 'ٱلله', 'لله', 'ملك', 'فيه', 'فيها', 'هذه', 'إله', 'اله', 'وجه'};

/// Initial و / ف that are the word's own (وَجَدَ, وَعَدَ, فَتَحَ …).
bool _rootInitial(String word) {
  final s = skeletonOf(word);
  for (final r in const ['وجد', 'وعد', 'ولد', 'ولي', 'وقع', 'وضع', 'ورث', 'وهب', 'وسع', 'وصي', 'وزر', 'وكل', 'فتح', 'فعل', 'فرق', 'فضل', 'فسد', 'فرح', 'فوق', 'فرعون']) {
    if (s.startsWith(r)) return true;
  }
  return false;
}

/// [word] cut at its split: (prefix, stem, suffix), as text with marks.
(String, String, String) splitText(String word, int prefix, int suffix) {
  final c = clustersOf(word);
  String join(Iterable<Cluster> cs) => cs.map((x) => '${x.base}${x.marks}').join();
  final p = prefix.clamp(0, c.length);
  final s = suffix.clamp(0, c.length - p);
  return (
    join(c.take(p)),
    join(c.skip(p).take(c.length - p - s)),
    join(c.skip(c.length - s)),
  );
}
