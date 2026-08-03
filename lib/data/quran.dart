import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// 📖 Qur'an data layer.
///
/// Text ships OFFLINE in assets for the whole Qur'an in two scripts:
///   assets/quran/u/{n}.json — Madani (Tanzil Uthmani text)
///   assets/quran/i/{n}.json — IndoPak script
///   assets/quran/meta.json  — 114 surah metadata entries
/// (Both are QUL-compatible datasets; swap the assets with QUL exports at
/// any time — the loader only expects a JSON array of ayah strings.)
///
/// Word-by-word segmentation: ayahs are tokenized on whitespace with
/// Qur'anic annotation signs (waqf marks, rubʿ el-ḥizb…) merged into their
/// neighboring word, which keeps word numbering aligned with the
/// word-by-word recordings at audio.qurancdn.com (verified against
/// quran.com word counts).
class SurahMeta {
  final int n;
  final String name; // Arabic name
  final String tname; // transliteration
  final String type; // meccan / medinan
  final int ayahs;

  const SurahMeta(this.n, this.name, this.tname, this.type, this.ayahs);

  factory SurahMeta.fromJson(Map<String, dynamic> j) => SurahMeta(
      j['n'], j['name'], j['tname'], j['type'], j['ayahs']);
}

/// Strip ḥarakāt + Qur'anic annotation marks for "clear letters" mode.
final _marks = RegExp(
    r'[\u064B-\u065F\u0670\u06D6-\u06ED\u08F0-\u08FF\u0640]');
String stripTashkil(String t) => t.replaceAll(_marks, '');

class TajwidAyah {
  final List<List<int>> spans; // [start, end, ruleIdx]
  final List<int> wordRule; // dominant ruleIdx per word, -1 = none
  const TajwidAyah(this.spans, this.wordRule);
}

class QuranRepo {
  static List<SurahMeta>? _meta;
  static final Map<String, List<String>> _ayahCache = {};
  static final Map<String, List<List<String>>> _wordCache = {};

  static Future<List<SurahMeta>> meta() async {
    if (_meta != null) return _meta!;
    final raw = await rootBundle.loadString('assets/quran/meta.json');
    _meta = [
      for (final j in jsonDecode(raw) as List)
        SurahMeta.fromJson(j as Map<String, dynamic>)
    ];
    return _meta!;
  }

  /// Ayah strings for a surah. [script] is 'uthmani' or 'indopak'.
  static Future<List<String>> ayahs(int surah, String script) async {
    final key = '$script:$surah';
    if (_ayahCache.containsKey(key)) return _ayahCache[key]!;
    final dir = script == 'indopak' ? 'i' : 'u';
    final raw = await rootBundle.loadString('assets/quran/$dir/$surah.json');
    // decode off the UI thread — large sūrahs were freezing the first frame
    final list =
        await compute(dir == 'i' ? _decodeIndopakList : _decodeStringList, raw);
    _ayahCache[key] = list;
    return list;
  }

  /// Word tokens per ayah, aligned with wbw audio numbering (1-based).
  static Future<List<List<String>>> words(int surah, String script) async {
    final key = '$script:$surah';
    if (_wordCache.containsKey(key)) return _wordCache[key]!;
    final ay = await ayahs(surah, script);
    // tokenizing a 6000-word sūrah also blocks — run it in a background isolate
    final list = await compute(_tokenizeAll, ay);
    _wordCache[key] = list;
    return list;
  }

  static final _annotation =
      RegExp(r'^[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u08D3-\u08FF\u200D-\u200F]+$');

  static List<String> tokenize(String ayah) {
    final out = <String>[];
    var prefix = '';
    for (final t in ayah.split(RegExp(r'\s+'))) {
      if (t.isEmpty) continue;
      if (_annotation.hasMatch(t)) {
        if (out.isNotEmpty) {
          out[out.length - 1] = '${out.last}$t';
        } else {
          prefix = t;
        }
      } else {
        out.add('$prefix$t');
        prefix = '';
      }
    }
    return out;
  }

  static final Map<String, List<TajwidAyah>> _tajwidCache = {};

  static Future<List<TajwidAyah>> tajwid(int surah,
      [String script = 'uthmani']) async {
    final key = '$script/$surah';
    if (_tajwidCache.containsKey(key)) return _tajwidCache[key]!;
    final dir = script == 'indopak' ? 't_indopak' : 't';
    final raw = await rootBundle.loadString('assets/quran/$dir/$surah.json');
    final list = await compute(_decodeTajwid, raw);
    _tajwidCache[key] = list;
    return list;
  }

  static final Map<String, List<(int, int)>> _wordRangesCache = {};

  /// Char range (start,end) of each WORD inside the raw ayah string, using
  /// the same annotation-merge logic as [tokenize] — so tajwīd char spans
  /// can be sliced per word.
  ///
  /// Memoized: called once per word during tajwīd rendering (see
  /// `_tajwidWordSpan` in quran_screen.dart), so an unmemoized scan would
  /// redo this same O(ayah length) work for every word in the ayah, on every
  /// rebuild triggered by word-highlight updates during playback.
  static List<(int, int)> wordRanges(String ayah) {
    final cached = _wordRangesCache[ayah];
    if (cached != null) return cached;
    final ranges = <(int, int)>[];
    var p = 0;
    final raw = <(int, int)>[];
    for (final tok in ayah.split(' ')) {
      if (tok.isNotEmpty) raw.add((p, p + tok.length));
      p += tok.length + 1;
    }
    (int, int)? pending;
    for (final (a, b) in raw) {
      if (_annotation.hasMatch(ayah.substring(a, b))) {
        if (ranges.isNotEmpty) {
          ranges[ranges.length - 1] = (ranges.last.$1, b);
        } else {
          pending = (a, b);
        }
      } else {
        if (pending != null) {
          ranges.add((pending.$1, b));
          pending = null;
        } else {
          ranges.add((a, b));
        }
      }
    }
    _wordRangesCache[ayah] = ranges;
    return ranges;
  }

}

List<String> _decodeStringList(String raw) =>
    [for (final a in jsonDecode(raw) as List) a as String];

/// The reader's Indo-Pak text (`assets/quran/i/`) and DigitalKhattIndoPak.otf
/// (built for the 15-line muṣḥaf's own Indo-Pak corpus) disagree on which
/// codepoint represents which mark — e.g. this corpus's sukūn is U+06E1,
/// where the muṣḥaf's is U+0652, which is the one the font actually has a
/// glyph for. This is a 1:1, length-preserving substitution, not a
/// re-encoding: it changes which codepoint sits at a position, never how
/// many characters there are or where word boundaries fall. Verified against
/// all 6,236 Indo-Pak āyāt — [QuranRepo.tokenize] word counts and
/// [QuranRepo.wordRanges] char offsets are byte-identical before and after,
/// so tajwīd spans (`assets/quran/t_indopak/`, character offsets) and the
/// word-by-word audio's word numbering both stay valid untouched.
const _indopakGlyphMap = {
  'ۡ': 'ْ', // SMALL HIGH DOTLESS HEAD OF KHAH -> ARABIC SUKUN
  '۠': '۟', // SMALL HIGH UPRIGHT RECT. ZERO -> SMALL HIGH ROUNDED ZERO
};

String _transcodeIndopak(String s) {
  var out = s;
  for (final e in _indopakGlyphMap.entries) {
    out = out.replaceAll(e.key, e.value);
  }
  return out;
}

List<String> _decodeIndopakList(String raw) => [
      for (final a in jsonDecode(raw) as List) _transcodeIndopak(a as String)
    ];

List<List<String>> _tokenizeAll(List<String> ayahs) =>
    [for (final a in ayahs) QuranRepo.tokenize(a)];

List<TajwidAyah> _decodeTajwid(String raw) => [
      for (final a in jsonDecode(raw) as List)
        TajwidAyah(
          [for (final t in a['s'] as List) [t[0] as int, t[1] as int, t[2] as int]],
          [for (final w in (a['w'] as List? ?? const [])) w as int],
        )
    ];
