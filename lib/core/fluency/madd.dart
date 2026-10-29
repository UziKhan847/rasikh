/// Where a word's madd is and how long it's held — for the fluency plan's
/// "count and say" drill (D3). From the printed text: the maddah sign (ٓ)
/// marks a long madd — six counts before a shaddah or sukūn (lāzim), four
/// or five before a hamzah in the word (muttaṣil) or at the word's end
/// (munfaṣil); a vowel's own letter (ا after a fatḥah, و after a ḍammah,
/// ي after a kasrah, the small alif) is two (ṭabīʿī).
library;

import 'joins.dart';

/// A madd: its letter (cluster index), kind and counts ('2', '4–5', '6').
typedef Madd = ({int at, String kind, String counts});

const _maddah = 'ٓ', _dagger = 'ٰ';
const _fatha = 'َ', _damma = 'ُ', _kasra = 'ِ';
const _shadda = 'ّ', _sukun = 'ْ';
const _hamzas = 'ءأإؤئ';

bool _vowelless(String marks) =>
    !marks.contains(_fatha) && !marks.contains(_damma) && !marks.contains(_kasra) &&
    !marks.contains(_shadda);

/// [word]'s madds, in order.
List<Madd> maddsIn(String word) {
  final c = clustersOf(word);
  final out = <Madd>[];
  for (var i = 0; i < c.length; i++) {
    final m = c[i].marks;
    // آ is an alif with the maddah on it.
    if (m.contains(_maddah) || c[i].base == 'آ') {
      final next = i + 1 < c.length ? c[i + 1] : null;
      if (next != null && (next.marks.contains(_shadda) || next.marks.contains(_sukun))) {
        out.add((at: i, kind: 'lazim', counts: '6'));
      } else if (next != null && (_hamzas.contains(next.base) || next.marks.contains('ٔ'))) {
        out.add((at: i, kind: 'muttasil', counts: '4–5'));
      } else if (next == null) {
        out.add((at: i, kind: 'munfasil', counts: '4–5'));
      } else {
        out.add((at: i, kind: 'muttasil', counts: '4–5'));
      }
      continue;
    }
    if (i == 0) continue;
    final prev = c[i - 1].marks;
    final natural = m.contains(_dagger) ||
        (c[i].base == 'ا' && prev.contains(_fatha) && _vowelless(m)) ||
        (c[i].base == 'و' && prev.contains(_damma) && _vowelless(m)) ||
        (c[i].base == 'ي' && prev.contains(_kasra) && _vowelless(m));
    if (natural) out.add((at: m.contains(_dagger) ? i : i - 1, kind: 'natural', counts: '2'));
  }
  return out;
}
