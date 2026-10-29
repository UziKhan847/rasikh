import '../core/fluency/joins.dart' show clustersOf, isMark;
import '../core/fluency/words.dart' show cleanForm;
import 'mushaf.dart';

/// The fluency plan's high-frequency words, in three tiers (particles and
/// anchors; common nouns and verbs; divine names and frequent phrases) —
/// each matched to the muṣḥaf's own spelling, since the Uthmani spelling
/// differs from the standard one (السَّمَاوَات, ٱلسَّمَٰوَٰتِ): the card
/// shows the word as the reader's muṣḥaf prints it.
const fluencyTierLists = <List<String>>[
  [
    'اللَّه', 'مِنْ', 'فِي', 'مَا', 'لَا', 'إِنَّ', 'أَنْ', 'إِنْ', 'عَلَى', 'إِلَى',
    'إِلَّا', 'الَّذِينَ', 'الَّذِي', 'مَنْ', 'هُوَ', 'هُمْ', 'لَهُمْ', 'قَالَ', 'قُلْ',
    'كَانَ', 'لَمْ', 'قَدْ', 'ثُمَّ', 'أَوْ', 'ذَٰلِكَ', 'هَٰذَا', 'إِذْ', 'إِذَا',
    'يَا أَيُّهَا', 'رَبِّ',
  ],
  [
    'الْأَرْض', 'السَّمَاء', 'يَوْم', 'قَوْم', 'كُلّ', 'شَيْء', 'النَّاس', 'الْكِتَاب',
    'رَسُول', 'آيَات', 'عَذَاب', 'النَّار', 'الْحَقّ', 'خَيْر', 'آمَنُوا', 'كَفَرُوا',
    'عَمِلُوا', 'الصَّالِحَات', 'جَاءَ', 'أَنْزَلَ', 'يَعْلَمُونَ', 'تَعْمَلُونَ', 'عِنْدَ',
    'بَلْ', 'أَمْ', 'لَعَلَّ', 'الْآخِرَة', 'الدُّنْيَا', 'جَنَّات', 'أَكْثَر',
  ],
  [
    'عَلِيم', 'حَكِيم', 'غَفُور', 'رَحِيم', 'عَزِيز', 'سَمِيع', 'بَصِير', 'قَدِير',
    'خَبِير', 'مُؤْمِنِين', 'الْمُتَّقِين', 'الظَّالِمِين', 'تَجْرِي مِنْ تَحْتِهَا الْأَنْهَار',
    'خَالِدِينَ فِيهَا', 'بِإِذْنِ اللَّه', 'فِي سَبِيلِ اللَّه',
  ],
];

/// One tier word, as the muṣḥaf prints it.
class TierWord {
  final int tier; // 1..3
  final String label; // the list's spelling
  final String form; // the muṣḥaf's (a phrase: its words, a space between)
  final int firstTok; // where it's first printed (its audio and place)
  final int words; // how many words it is
  const TierWord(this.tier, this.label, this.form, this.firstTok, this.words);

  /// Its card (shared with the same word marked not fluent).
  String get cardId => 'f:$form';
}

/// The letters that set spellings apart: alif and its seats, hamzah, the
/// dagger alif and the final yāʼ forms fold away; the rest of the
/// skeleton is compared.
String _loose(String w) {
  final b = StringBuffer();
  for (final c in w.runes) {
    if (isMark(c)) continue;
    final ch = String.fromCharCode(c);
    if (ch == 'ـ') continue; // tatweel
    if ('اٱأإآءؤئى'.contains(ch)) {
      if (ch == 'ؤ') b.write('و');
      if (ch == 'ئ' || ch == 'ى') b.write('ي');
      continue;
    }
    b.write(ch);
  }
  return b.toString();
}

/// The vowels and signs of [w], letter by letter (to tell مِنْ from مَنْ,
/// إِلَّا from لَا): each letter's sorted (shaddah and fatḥah come in either
/// order); letters without any left out (the spellings' alifs differ).
String _vowels(String w) => [
      for (final c in clustersOf(w))
        String.fromCharCodes(
            (c.marks.runes.where((r) => r >= 0x064B && r <= 0x0652).toList()..sort())),
    ].where((v) => v.isNotEmpty).join('|');

final Map<String, List<TierWord>> _cache = {};

/// The tiers' words in [script] (its text loaded), each its most frequent
/// printing whose vowels agree with the list's (else the most frequent).
List<TierWord> tierWords(String script) => _cache.putIfAbsent(script, () {
      final toks = MushafRepo.tokensSync(script);
      if (toks.isEmpty) return const [];
      // The real words' token indices, by loose skeleton.
      final by = <String, List<int>>{};
      final words = <int>[]; // token indices of words (no ۝), in order
      for (var t = 0; t < toks.length; t++) {
        if (MushafRepo.tokenAt(script, t).$2 < 0) continue;
        words.add(t);
        (by[_loose(toks[t])] ??= []).add(words.length - 1);
      }
      final out = <TierWord>[];
      for (final (ti, list) in fluencyTierLists.indexed) {
        for (final label in list) {
          // A phrase may be one word in the muṣḥaf (يَٰٓأَيُّهَا).
          final split = label.split(' ');
          final parts = split.length > 1 && by[_loose(split.join())] != null
              ? [split.join()]
              : split;
          final loose = parts.map(_loose).toList();
          final want = parts.map(_vowels).join(' ');
          final counts = <String, int>{};
          final first = <String, int>{};
          for (final i in by[loose.first] ?? const <int>[]) {
            if (i + parts.length > words.length) continue;
            var ok = true;
            for (var k = 1; k < parts.length && ok; k++) {
              ok = _loose(toks[words[i + k]]) == loose[k];
            }
            if (!ok) continue;
            final form = [
              for (var k = 0; k < parts.length; k++) cleanForm(toks[words[i + k]])
            ].join(' ');
            counts[form] = (counts[form] ?? 0) + 1;
            first.putIfAbsent(form, () => words[i]);
          }
          if (counts.isEmpty) continue;
          String? best;
          var score = -1;
          counts.forEach((form, n) {
            final vowelsAgree = form.split(' ').map(_vowels).join(' ') == want;
            final s = (vowelsAgree ? 1 << 20 : 0) + n;
            if (s > score) {
              score = s;
              best = form;
            }
          });
          out.add(TierWord(ti + 1, label, best!, first[best]!, parts.length));
        }
      }
      return out;
    });
