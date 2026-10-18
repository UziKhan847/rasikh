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
  ///
  /// [font] is the family the returned text will be *rendered with*, because
  /// which extra codepoints have to be transcoded is a property of the face,
  /// not of the script — see [_uthmaniKhattGlyphMap]. It defaults to the face
  /// every caller except the card reader uses (`downloads.dart`), so they need not care. Regardless of [font], the
  /// Uthmani corpus always gets one correction — see [_fixSilentLetterMark] —
  /// since that one is a data error, not a font-compatibility question.
  static Future<List<String>> ayahs(int surah, String script,
      {String font = 'UthmanicHafs'}) async {
    final key = '$script:$font:$surah';
    if (_ayahCache.containsKey(key)) return _ayahCache[key]!;
    final dir = script == 'indopak' ? 'i' : 'u';
    final raw = await rootBundle.loadString('assets/quran/$dir/$surah.json');
    // decode off the UI thread — large sūrahs were freezing the first frame
    final list = await compute(_decoderFor(dir, font), raw);
    _ayahCache[key] = list;
    return list;
  }

  /// Which load-time transcode this (corpus, face) pair needs. Top-level
  /// functions, not closures: they are handed to [compute].
  static List<String> Function(String) _decoderFor(String dir, String font) {
    if (dir == 'i') return _decodeIndopakList;
    return font == 'DigitalKhattV2' ? _decodeUthmaniKhattList : _decodeStringList;
  }

  /// Word tokens per ayah, aligned with wbw audio numbering (1-based).
  static Future<List<List<String>>> words(int surah, String script,
      {String font = 'UthmanicHafs'}) async {
    final key = '$script:$font:$surah';
    if (_wordCache.containsKey(key)) return _wordCache[key]!;
    final ay = await ayahs(surah, script, font: font);
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

/// Corrects a data error in the Uthmani corpus (`assets/quran/u/`): the three
/// weak letters ا و ي, whenever they are written but never pronounced —
/// the "farqa" alif after a plural وا (وَٱدْعُوا۟), the silent wāw of a word
/// like أُو۟لَـٰٓئِكَ, the historical extra alif of مِا۟ئَة, the tanwīn-naṣb
/// alif — carry **U+0652 ARABIC SUKUN** in this corpus. That is the wrong
/// mark: sukūn means "no vowel on an otherwise pronounced consonant", and
/// these letters are not pronounced at all. Unicode's own mark for exactly
/// this — "used in the Qurʼān to indicate a letter that is not pronounced" —
/// is **U+06DF ARABIC SMALL HIGH ROUNDED ZERO**, which is what the 15-line
/// muṣḥaf's own corpus (`mushaf_u_text.json`) correctly uses in the same
/// positions. The two views of the same muṣḥaf were disagreeing about which
/// mark a silent letter carries — this is not a font/rendering difference,
/// every bundled Arabic face has real glyphs for both marks.
///
/// Safe to apply unconditionally: checked across the whole corpus, U+0652
/// appears on ا, و or ي and nowhere else — a genuine sukūn on any other
/// letter is already written with the corpus's own regular-sukūn mark,
/// U+06E1, entirely disjoint from these 3,988 occurrences. So this can never
/// misfire on a real jazm sukūn. Pinned by
/// `test/uthmani_silent_letter_test.dart` against exactly that base-letter
/// set, over all 6,236 āyāt.
String _fixSilentLetterMark(String s) => s.replaceAll('ْ', '۟');

List<String> _decodeStringList(String raw) => [
      for (final a in jsonDecode(raw) as List)
        _fixSilentLetterMark(a as String)
    ];

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

/// The same problem as [_indopakGlyphMap], one corpus over: the reader's
/// Uthmani text (`assets/quran/u/`, Tanzil) and DigitalKhattV2.otf (built for
/// the 15-line muṣḥaf's own Uthmani corpus) encode three marks differently,
/// so the reader's Madani text needs this before DigitalKhattV2 — its one
/// typeface — can render it. Applied on top of [_fixSilentLetterMark]'s
/// correction, not instead of it: that one is a genuine data error and
/// belongs to every caller, this one is font compatibility and belongs only
/// to whichever caller renders with this specific face. Keyed off [font] in
/// [QuranRepo._decoderFor] rather than folded permanently into the default
/// decode path, since UthmanicHafs — still the muṣḥaf-less callers'
/// face — has no glyph for U+08F0/U+08F1/U+08F2 at all, and
/// transcoding unconditionally would break rendering there in 6,643 places.
///
/// The first three rows are exact re-encodings — the same mark, two Unicode
/// conventions. Derived by aligning the two corpora mark-cluster by
/// mark-cluster: every āyah whose cluster streams line up agrees on these
/// pairings, with no conflicting mapping anywhere, and the grammar confirms
/// them (`هُدٗى` *hudan* is a fatḥatān; `مَّرَضٞ` *maraḍun* a ḍammatān). The
/// Unicode *names* on the Tanzil side describe glyph shapes rather than
/// functions, so they read as mismatched and are not the thing to trust.
///
/// The fourth row is **an approximation, not an equivalence**: U+06E4 SMALL
/// HIGH MADDA has no glyph in DigitalKhattV2 and no counterpart in the muṣḥaf
/// corpus, which simply omits it. U+0653 is the same maddah sign at full size
/// rather than the small high variant. It affects 26 characters in 15 āyāt —
/// the sajdah verses, every one of them: 7:206, 13:15, 16:49, 17:107, 19:58,
/// 22:18, 22:77, 25:60, 27:25, 32:15, 38:24, 41:37, 53:62, 84:21, 96:19.
/// Dropping it instead would match the muṣḥaf corpus but is not
/// length-preserving, and that is not negotiable — see below.
///
/// Like [_transcodeIndopak] this is 1:1 and length-preserving: it changes
/// which codepoint sits at a position, never how many there are or where word
/// boundaries fall, so tajwīd spans (`assets/quran/t/`, character offsets) and
/// the word-by-word audio's word numbering stay valid untouched. Pinned by
/// `test/uthmani_khatt_transcode_test.dart` over all 6,236 āyāt.
const _uthmaniKhattGlyphMap = {
  'ٗ': 'ࣰ', // U+0657 INVERTED DAMMA       -> U+08F0 OPEN FATHATAN
  'ٞ': 'ࣱ', // U+065E FATHA WITH TWO DOTS  -> U+08F1 OPEN DAMMATAN
  'ٖ': 'ࣲ', // U+0656 SUBSCRIPT ALEF       -> U+08F2 OPEN KASRATAN
  'ۤ': 'ٓ', // U+06E4 SMALL HIGH MADDA     -> U+0653 MADDAH ABOVE (approx.)
};

String _transcodeUthmaniKhatt(String s) {
  var out = s;
  for (final e in _uthmaniKhattGlyphMap.entries) {
    out = out.replaceAll(e.key, e.value);
  }
  return out;
}

List<String> _decodeUthmaniKhattList(String raw) => [
      for (final a in jsonDecode(raw) as List)
        _transcodeUthmaniKhatt(_fixSilentLetterMark(a as String))
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
