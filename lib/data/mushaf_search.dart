import 'mushaf.dart';

/// Searching the muṣḥaf's text: an Arabic query matches the āyāt whose
/// letters contain it, whatever its vowels and marks — so «الرحمن» finds
/// ٱلرَّحْمَٰنِ. Letters are compared bare: no ḥarakāt, Qurʾānic marks or
/// tatweel; the alif forms as alif, hamza seats as their letter, alif
/// maqṣūrah as yāʾ.

/// [s] as bare letters (see the library comment).
String bareArabic(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    if ((r >= 0x0610 && r <= 0x061A) ||
        (r >= 0x064B && r <= 0x065F) ||
        r == 0x0670 ||
        (r >= 0x06D6 && r <= 0x06ED) ||
        (r >= 0x08D3 && r <= 0x08FF) ||
        r == 0x0640 ||
        r == 0x034F ||
        r == 0x200C ||
        r == 0x200F) {
      continue;
    }
    out.writeCharCode(switch (r) {
      0x0671 || 0x0623 || 0x0625 || 0x0622 => 0x0627, // waṣlah, hamzah, maddah alifs → alif
      0x0649 || 0x0626 => 0x064A, // alif maqṣūrah, yāʾ seat → yāʾ
      0x0624 => 0x0648, // wāw seat → wāw
      _ => r,
    });
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// One āyah that matched: global āyah index, (sūrah, āyah), its text.
typedef MushafHit = ({int ayah, int surah, int ayahInSurah, String text});

final Map<String, List<(String bare, String text)>> _ayat = {};

/// Each āyah of [script]'s muṣḥaf text: its bare letters and its words.
List<(String, String)> _ayatOf(String script) => _ayat.putIfAbsent(script, () {
      final n = MushafRepo.tokenCount(script);
      final words = <int, List<String>>{};
      for (var t = 0; t < n; t++) {
        final (g, w) = MushafRepo.tokenAt(script, t);
        if (w < 0) continue; // the ۝
        (words[g] ??= []).add(MushafRepo.wordText(script, g, w));
      }
      final last = words.keys.fold(-1, (a, b) => a > b ? a : b);
      return [
        for (var g = 0; g <= last; g++)
          (bareArabic((words[g] ?? const []).join(' ')), (words[g] ?? const []).join(' ')),
      ];
    });

/// The āyāt of [script] containing [query] (two letters at least), in
/// order, at most [limit].
List<MushafHit> searchMushaf(String script, String query, {int limit = 80}) {
  final q = bareArabic(query);
  if (q.length < 2) return const [];
  final out = <MushafHit>[];
  final ayat = _ayatOf(script);
  for (var g = 0; g < ayat.length && out.length < limit; g++) {
    if (!ayat[g].$1.contains(q)) continue;
    final (s, a) = MushafRepo.surahAyahOf(g);
    out.add((ayah: g, surah: s, ayahInSurah: a, text: ayat[g].$2));
  }
  return out;
}
