import 'dart:math' as math;

import 'tashkeel.dart';
import 'wasl.dart';

/// Real Qurʼānic words drawn from the marks' and waṣl's own examples — every
/// one already checked verbatim against the muṣḥaf text by the data tests, so
/// a quiz that needs "some real words" can take them without authoring any.
List<String> quranicExampleWords() => {
      for (final t in tashkil) ...[
        ...t.example.split(' '),
        for (final e in t.moreExamples) ...e.$1.split(' '),
      ],
      for (final w in waslItems) ...[
        ...w.example.split(' '),
        for (final e in w.moreExamples) ...e.$1.split(' '),
      ],
    }.where((w) => w.trim().isNotEmpty && !w.contains('ـ')).toList();

bool _isMark(int r) =>
    (r >= 0x064B && r <= 0x065F) ||
    r == 0x0670 ||
    (r >= 0x06D6 && r <= 0x06ED);

/// [word]'s last letter with everything written on it — 'ةٌ' from 'جَنَّةٌ' —
/// or null for a word with no letter in it.
String? wordEnding(String word) {
  final runes = word.runes.toList();
  for (var i = runes.length - 1; i >= 0; i--) {
    if (!_isMark(runes[i])) return String.fromCharCodes(runes.sublist(i));
  }
  return null;
}

/// The code points that write [markId] — the same five a word-level check can
/// honestly be asked about (`kidsWordHasMark` in `kids_stage_quizzes.dart`
/// mirrors this set; tanwīn is deliberately absent, since the muṣḥaf writes
/// each one in more than one shape — see `tanwin_allographs.dart`).
const _markCodepoints = {
  'fatha': {0x064E},
  'kasra': {0x0650},
  'damma': {0x064F},
  'sukun': {0x06E1, 0x0652},
  'shadda': {0x0651},
};

/// The smallest legible substring of [word] carrying [markId] — the marked
/// letter itself, plus any other mark riding the same letter (a mushaddad
/// letter's own vowel, say) — or '' if [word] does not carry it. For
/// [highlightSpans]: a bare combining mark highlighted on its own has nothing
/// to sit on, so the highlight always includes the base letter.
String kidsMarkHighlightIn(String markId, String word) {
  final marks = _markCodepoints[markId];
  if (marks == null) return '';
  final runes = word.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    if (!marks.contains(runes[i])) continue;
    var start = i;
    while (start > 0 && _isMark(runes[start - 1])) {
      start--;
    }
    if (start > 0) start--; // the base letter the mark(s) ride on
    var end = i + 1;
    while (end < runes.length && _isMark(runes[end])) {
      end++;
    }
    return String.fromCharCodes(runes.sublist(start, end));
  }
  return '';
}

/// One real muṣḥaf word carrying a mark being practised, with the coordinates
/// its own per-word recording needs (`WbwAudio.instance.playWord`) — unlike
/// [quranicExampleWords]'s 164-word pool, which carries no such coordinates
/// at all.
class KidsMarkWord {
  final int surah;
  final int ayah; // 1-based
  final int index; // 1-based position in the āyah — playWord's own numbering
  final String word;
  final String highlight;
  const KidsMarkWord({
    required this.surah,
    required this.ayah,
    required this.index,
    required this.word,
    required this.highlight,
  });
}

/// Up to [count] real words from [corpus] (surah → āyahs → words) carrying
/// ANY of [markIds] — the tamrīn every Qāʿidah runs after its own table: real
/// words with the mark just learned, not just the isolated syllable. [corpus]
/// is typically every word of `kidsFindSurahs`
/// (`QuranRepo.words(s, 'uthmani')` per sūrah) — the same real, already
/// verbatim-tested corpus Find-it and Build-the-word draw from, rather than
/// the much smaller [quranicExampleWords] pool, which has too few sukūn/
/// shaddah examples to draw a fresh round from every time.
List<KidsMarkWord> kidsWordsWithMark(
  Map<int, List<List<String>>> corpus,
  List<String> markIds,
  math.Random rng, {
  int count = 8,
}) {
  final out = <KidsMarkWord>[];
  final seen = <String>{};
  for (final entry in corpus.entries) {
    for (var a = 0; a < entry.value.length; a++) {
      for (var w = 0; w < entry.value[a].length; w++) {
        final word = entry.value[a][w];
        if (!seen.add(word)) continue;
        for (final id in markIds) {
          final hl = kidsMarkHighlightIn(id, word);
          if (hl.isEmpty) continue;
          out.add(
            KidsMarkWord(
              surah: entry.key,
              ayah: a + 1,
              index: w + 1,
              word: word,
              highlight: hl,
            ),
          );
          break; // one entry per word, even if it carries more than one mark
        }
      }
    }
  }
  out.shuffle(rng);
  return out.take(count).toList();
}
