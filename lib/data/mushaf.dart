import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'quran.dart';

/// One rendered token on a mushaf line: a word (or the ayah-end marker).
class MushafWord {
  final String text;
  final int ayah; // global ayah index (0-based, 0..6235)
  final int wordIdx; // real-word index within the ayah; -1 for the ۝ marker
  const MushafWord(this.text, this.ayah, this.wordIdx);
  bool get isMarker => wordIdx < 0;
}

/// One physical line on a mushaf page.
class MushafLine {
  final int kind; // 0 = surah header, 1 = basmala, 2 = text
  final int surah; // 1-based surah number (header lines only)
  final List<MushafWord> words; // text lines only
  /// Index of the line's first token in the script's token stream (text
  /// lines; the glyph atlas is indexed by it).
  final int firstTok;
  const MushafLine.header(this.surah)
      : kind = 0,
        words = const [],
        firstTok = -1;
  const MushafLine.basmala()
      : kind = 1,
        surah = 0,
        words = const [],
        firstTok = -1;
  const MushafLine.text(this.words, {this.firstTok = -1})
      : kind = 2,
        surah = 0;
  bool get isHeader => kind == 0;
  bool get isBasmala => kind == 1;
  bool get isText => kind == 2;
}

/// Surah-name glyphs in the SurahNames (icomoon) font, indexed by 0-based
/// surah. Pair each with 0xE903 (the decorative frame) when rendering.
const surahGlyphCodes = <int>[
  0xe904, 0xe905, 0xe906, 0xe907, 0xe908, 0xe90b, 0xe90c, 0xe90d,
  0xe90e, 0xe90f, 0xe910, 0xe911, 0xe912, 0xe913, 0xe914, 0xe915,
  0xe916, 0xe917, 0xe918, 0xe919, 0xe91a, 0xe91b, 0xe91c, 0xe91d,
  0xe91e, 0xe91f, 0xe920, 0xe921, 0xe922, 0xe923, 0xe924, 0xe925,
  0xe926, 0xe92e, 0xe92f, 0xe930, 0xe931, 0xe909, 0xe90a, 0xe927,
  0xe928, 0xe929, 0xe92a, 0xe92b, 0xe92c, 0xe92d, 0xe932, 0xe902,
  0xe933, 0xe934, 0xe935, 0xe936, 0xe937, 0xe938, 0xe939, 0xe93a,
  0xe93b, 0xe93c, 0xe900, 0xe901, 0xe941, 0xe942, 0xe943, 0xe944,
  0xe945, 0xe946, 0xe947, 0xe948, 0xe949, 0xe94a, 0xe94b, 0xe94c,
  0xe94d, 0xe94e, 0xe94f, 0xe950, 0xe951, 0xe952, 0xe93d, 0xe93e,
  0xe93f, 0xe940, 0xe953, 0xe954, 0xe955, 0xe956, 0xe957, 0xe958,
  0xe959, 0xe95a, 0xe95b, 0xe95c, 0xe95d, 0xe95e, 0xe95f, 0xe960,
  0xe961, 0xe962, 0xe963, 0xe964, 0xe965, 0xe966, 0xe967, 0xe968,
  0xe969, 0xe96a, 0xe96b, 0xe96c, 0xe96d, 0xe96e, 0xe96f, 0xe970,
  0xe971, 0xe972,
];

class _ScriptData {
  final List<String> tok; // flat token stream
  final List<int> tokAyah; // global ayah per token
  final List<int> tokWord; // real-word index per token (-1 marker)
  final List<int> realWordCount; // per global ayah
  final List<int> ayahFirstTok; // first token of each global ayah (+ sentinel)
  final Uint16List tokPage; // 1-based page each token is printed on
  final List<List<MushafLine>> pages;
  final List<int> pageFirstGlobal; // first global ayah shown on each page
  final List<int> surahFirstPage; // 1-based page a surah's header/text first appears on, by surah
  _ScriptData(this.tok, this.tokAyah, this.tokWord, this.realWordCount,
      this.ayahFirstTok, this.tokPage, this.pages, this.pageFirstGlobal,
      this.surahFirstPage);
}

/// The 15-line Madani and Indo-Pak mushaf: text, page/line layout, and the
/// DigitalKhatt/SurahNames/Bismillah fonts are adapted, with attribution, from
/// Waqar Ahmed's open-source Quran Revision Companion
/// (github.com/Waqar144/quran_memorization_helper, MIT License — see
/// LICENSES/quran_memorization_helper-MIT.txt at the repo root). Underlying
/// parametric typesetting by the DigitalKhatt project (github.com/DigitalKhatt).
/// Text is delimited by U+200C ZWNJ; the DigitalKhatt fonts render the
/// presentation marks and ayah-end circles natively. Layout is a list of pages,
/// each a list of lines; a line is either a surah header, a basmala, or text
/// beginning at a given global ayah + word.
class MushafRepo {
  static const bismillahChar = '\uFDFD';

  static final Map<String, _ScriptData> _data = {};
  static List<int>? _surahCum; // cumulative ayah counts; _surahCum[s] before surah s+1
  static List<int> _juzStartAyah = const []; // 30 global ayah indices

  static String _norm(String s) => s == 'indopak' ? 'indopak' : 'uthmani';
  static String fontFamily(String script) =>
      _norm(script) == 'indopak' ? 'DigitalKhattIndoPak' : 'DigitalKhattV2';

  /// True for the two DigitalKhatt faces, whose vertical metrics differ enough
  /// from UthmanicHafs' that a line built for one clips the other. The card
  /// reader can now be handed either family for either script, so "which
  /// height does this text need" is a question about the FONT, not the script.
  static bool isKhatt(String family) => family.startsWith('DigitalKhatt');

  /// Line height multiplier for the DigitalKhatt faces.
  ///
  /// Both declare ascent 1500 + descent 700 on a 1000-unit em (confirmed via
  /// `ttx -t hhea`), so a line needs 2.2× the font size to contain the tallest
  /// ḥarakah stacks per the font's own metrics. A handful of combinations ink
  /// slightly past what the font declares, hence the ~5% margin.
  ///
  /// One constant rather than three: the 15-line muṣḥaf derives its line slot
  /// from this (`_lineHeightRatio`) and the card reader sets it as a `height`,
  /// and the two must not drift apart.
  static const khattLineHeight = 2.2 * 1.05;

  // Standard juz starts as (surah, ayah) pairs — script-independent.
  static const _juzStarts = <List<int>>[
    [1, 1], [2, 142], [2, 253], [3, 93], [4, 24], [4, 148], [5, 82],
    [6, 111], [7, 88], [8, 41], [9, 93], [11, 6], [12, 53], [15, 1],
    [17, 1], [18, 75], [21, 1], [23, 1], [25, 21], [27, 56], [29, 46],
    [33, 31], [36, 28], [39, 32], [41, 47], [46, 1], [51, 31], [58, 1],
    [67, 1], [78, 1],
  ];

  /// 1..30: the juzʼ [surah]:[ayah] is in. Needs no loaded data.
  static int juzOfAyah(int surah, int ayah) {
    var juz = 1;
    for (var i = 0; i < _juzStarts.length; i++) {
      final j = _juzStarts[i];
      if (surah > j[0] || (surah == j[0] && ayah >= j[1])) juz = i + 1;
    }
    return juz;
  }

  static Future<void> _ensureMeta() async {
    if (_surahCum != null) return;
    final metas = await QuranRepo.meta();
    final cum = List<int>.filled(metas.length + 1, 0);
    for (var i = 0; i < metas.length; i++) {
      cum[i + 1] = cum[i] + metas[i].ayahs;
    }
    _surahCum = cum;
    _juzStartAyah = [
      for (final j in _juzStarts) cum[j[0] - 1] + (j[1] - 1),
    ];
  }

  /// Load & build a script's mushaf (idempotent). Call before any *Sync method.
  static Future<void> ensure(String script) => _ensure(script);

  static Future<_ScriptData> _ensure(String script) async {
    await _ensureMeta();
    final s = _norm(script);
    final cached = _data[s];
    if (cached != null) return cached;
    final txtFile = s == 'indopak' ? 'mushaf_i_text.json' : 'mushaf_u_text.json';
    final layFile =
        s == 'indopak' ? 'mushaf_i_layout.json' : 'mushaf_u_layout.json';
    final txtRaw = await rootBundle.loadString('assets/quran/$txtFile');
    final layRaw = await rootBundle.loadString('assets/quran/$layFile');
    final built =
        await compute(_buildMushaf, <String, String>{'txt': txtRaw, 'lay': layRaw});

    final tok = (built['tok'] as List).cast<String>();
    final tokAyah = (built['tokAyah'] as List).cast<int>();
    final tokWord = (built['tokWord'] as List).cast<int>();
    final rwc = (built['rwc'] as List).cast<int>();
    final ayahFirstTok = (built['ayahFirstTok'] as List).cast<int>();
    final tokPage = Uint16List.fromList((built['tokPage'] as List).cast<int>());
    final rawPages = built['pages'] as List;
    final pages = <List<MushafLine>>[];
    for (final p in rawPages) {
      final lines = <MushafLine>[];
      for (final ln in (p as List)) {
        final e = (ln as List).cast<int>();
        if (e[0] == 0) {
          lines.add(MushafLine.header(e[1]));
        } else if (e[0] == 1) {
          lines.add(const MushafLine.basmala());
        } else {
          final ws = <MushafWord>[];
          for (var t = e[1]; t < e[2]; t++) {
            ws.add(MushafWord(tok[t], tokAyah[t], tokWord[t]));
          }
          lines.add(MushafLine.text(ws, firstTok: e[1]));
        }
      }
      pages.add(lines);
    }
    final pageFirst = <int>[];
    for (final pg in pages) {
      var fg = 1 << 30;
      for (final ln in pg) {
        if (ln.isText) {
          for (final wd in ln.words) {
            if (wd.ayah < fg) fg = wd.ayah;
          }
        }
      }
      pageFirst.add(fg == 1 << 30 ? (pageFirst.isEmpty ? 0 : pageFirst.last) : fg);
    }
    // First page each surah appears on — header line if there is one, else its
    // first text ayah — mirroring pageForSurah's old per-call search, computed
    // once here instead of on every jump-to-surah/script-switch.
    final surahCount = (_surahCum?.length ?? 1) - 1;
    final surahFirstPage = List<int>.filled(surahCount + 1, 0);
    for (var p = 0; p < pages.length; p++) {
      for (final ln in pages[p]) {
        if (ln.isHeader) {
          if (ln.surah >= 1 &&
              ln.surah <= surahCount &&
              surahFirstPage[ln.surah] == 0) {
            surahFirstPage[ln.surah] = p + 1;
          }
        } else if (ln.isText && ln.words.isNotEmpty) {
          final sa = surahAyahOf(ln.words.first.ayah);
          if (sa.$1 >= 1 &&
              sa.$1 <= surahCount &&
              surahFirstPage[sa.$1] == 0) {
            surahFirstPage[sa.$1] = p + 1;
          }
        }
      }
    }
    final data = _ScriptData(tok, tokAyah, tokWord, rwc, ayahFirstTok,
        tokPage, pages, pageFirst, surahFirstPage);
    await MushafGeometry._loadEmTable(s);
    await MushafGeometry._loadRatios(s);
    _data[s] = data;
    return data;
  }

  /// The script's token stream (after [ensure]); the glyph atlas is
  /// indexed by it.
  static List<String> tokensSync(String script) =>
      _data[_norm(script)]?.tok ?? const [];

  static Future<int> pageCount(String script) async =>
      (await _ensure(script)).pages.length;

  static int pageCountSync(String script) =>
      _data[_norm(script)]?.pages.length ?? 0;

  static Future<List<MushafLine>> page(String script, int page) async {
    final d = await _ensure(script);
    if (page < 1 || page > d.pages.length) return const [];
    return d.pages[page - 1];
  }

  static List<MushafLine>? pageSync(String script, int page) {
    final d = _data[_norm(script)];
    if (d == null) return null;
    if (page < 1 || page > d.pages.length) return const [];
    return d.pages[page - 1];
  }

  /// Real words (ayah-end marker excluded) in [globalAyah]; -1 if the script
  /// isn't loaded. Both scripts agree on every ayah (77,432 words in all), so
  /// a word index is a script-independent key — see test/mushaf_word_index_test.
  static int wordCount(String script, int globalAyah) {
    final d = _data[_norm(script)];
    if (d == null || globalAyah < 0 || globalAyah >= d.realWordCount.length) {
      return -1;
    }
    return d.realWordCount[globalAyah];
  }

  /// Token index of real word [word0] (0-based) of [globalAyah], or -1.
  static int _tokOf(_ScriptData d, int globalAyah, int word0) {
    if (globalAyah < 0 || globalAyah >= d.realWordCount.length) return -1;
    if (word0 < 0 || word0 >= d.realWordCount[globalAyah]) return -1;
    // Real words come first in each ayah; the ۝ marker is always its last
    // token, so word w is simply the w-th token of the ayah.
    return d.ayahFirstTok[globalAyah] + word0;
  }

  /// 1-based page (in [script]'s own numbering) that word [word0] of
  /// [globalAyah] is printed on. Falls back to the ayah's page.
  static int pageOfWord(String script, int globalAyah, int word0) {
    final d = _data[_norm(script)];
    if (d == null) return 1;
    final t = _tokOf(d, globalAyah, word0 < 0 ? 0 : word0);
    if (t < 0) return pageForGlobalAyah(script, globalAyah);
    return d.tokPage[t];
  }

  /// The page of [toScript] that shows what [page] of [fromScript] shows:
  /// the one printing the word in the middle of [page]. The two scripts
  /// break their pages at different words, so a page's first āyah (let
  /// alone its sūrah) can land a page or more away; the middle word is on
  /// the page that overlaps it most. Both scripts must be loaded.
  static int matchingPage(String fromScript, int page, String toScript) {
    final from = _data[_norm(fromScript)];
    final to = _data[_norm(toScript)];
    if (from == null || to == null) return page;
    if (_norm(fromScript) == _norm(toScript)) return page;
    if (page < 1 || page > from.pages.length) return 1;
    final words = [
      for (final ln in from.pages[page - 1])
        if (ln.isText) ...ln.words,
    ];
    if (words.isEmpty) {
      // A page of headers only: the sūrah it opens.
      for (final ln in from.pages[page - 1]) {
        if (ln.isHeader && ln.surah < to.surahFirstPage.length) {
          final p = to.surahFirstPage[ln.surah];
          if (p > 0) return p;
        }
      }
      return page.clamp(1, to.pages.length);
    }
    final w = words[words.length ~/ 2];
    if (w.ayah < 0 || w.ayah >= to.realWordCount.length) return 1;
    // The ۝ marker is the token after the āyah's last real word.
    final t = to.ayahFirstTok[w.ayah] +
        (w.wordIdx < 0 ? to.realWordCount[w.ayah] : w.wordIdx);
    return t < to.tokPage.length ? to.tokPage[t] : to.pages.length;
  }

  /// [globalAyah]'s tokens as [script] prints them (its words, then its ۝)
  /// and the first one's index in the token stream (which the glyph atlas
  /// is indexed by); (-1, []) if the script isn't loaded.
  static (int, List<MushafWord>) ayahTokens(String script, int globalAyah) {
    final d = _data[_norm(script)];
    if (d == null || globalAyah < 0 || globalAyah >= d.realWordCount.length) {
      return (-1, const []);
    }
    final a = d.ayahFirstTok[globalAyah], b = d.ayahFirstTok[globalAyah + 1];
    return (
      a,
      [for (var t = a; t < b; t++) MushafWord(d.tok[t], globalAyah, d.tokWord[t])],
    );
  }

  // ── the token stream (memorize mode walks it word by word) ──

  /// How many tokens [script]'s text has (words and ۝ markers); 0 if not
  /// loaded.
  static int tokenCount(String script) => _data[_norm(script)]?.tok.length ?? 0;

  /// Token [t]'s (global āyah, word index; -1 for the ۝).
  static (int, int) tokenAt(String script, int t) {
    final d = _data[_norm(script)];
    if (d == null || t < 0 || t >= d.tok.length) return (-1, -1);
    return (d.tokAyah[t], d.tokWord[t]);
  }

  /// The token of word [word0] of [globalAyah] (word -1: its ۝); -1 if
  /// unknown.
  static int tokenOf(String script, int globalAyah, int word0) {
    final d = _data[_norm(script)];
    if (d == null || globalAyah < 0 || globalAyah >= d.realWordCount.length) {
      return -1;
    }
    final w = word0 < 0 ? d.realWordCount[globalAyah] : word0;
    return d.ayahFirstTok[globalAyah] + w;
  }

  /// The 1-based page token [t] is printed on.
  static int pageOfToken(String script, int t) {
    final d = _data[_norm(script)];
    if (d == null || d.tok.isEmpty) return 1;
    return d.tokPage[t.clamp(0, d.tok.length - 1)];
  }

  /// The tokens printed on [page]: [first, end). Empty (first == end) for a
  /// page of headers only.
  static (int, int) pageTokens(String script, int page) {
    final d = _data[_norm(script)];
    if (d == null || page < 1 || page > d.pages.length) return (0, 0);
    var first = -1, end = -1;
    for (final ln in d.pages[page - 1]) {
      if (!ln.isText || ln.words.isEmpty || ln.firstTok < 0) continue;
      if (first < 0) first = ln.firstTok;
      end = ln.firstTok + ln.words.length;
    }
    if (first < 0) {
      // Headers only: an empty range where the next page's text begins.
      for (var p = page; p < d.pages.length; p++) {
        final (f, _) = pageTokens(script, p + 1);
        if (f > 0) return (f, f);
      }
      return (d.tok.length, d.tok.length);
    }
    return (first, end);
  }

  /// The word's text as printed in [script], or '' if unknown.
  static String wordText(String script, int globalAyah, int word0) {
    final d = _data[_norm(script)];
    if (d == null) return '';
    final t = _tokOf(d, globalAyah, word0);
    return t < 0 ? '' : d.tok[t];
  }

  /// global ayah index -> (surah 1-based, ayah-in-surah 1-based). Binary
  /// search over the sorted cumulative-ayah-count table.
  static (int, int) surahAyahOf(int globalAyah) {
    final cum = _surahCum;
    if (cum == null) return (1, 1);
    var lo = 0, hi = cum.length - 2, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (cum[mid] <= globalAyah) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return (ans + 1, globalAyah - cum[ans] + 1);
  }

  static Future<int> pageForSurah(String script, int surah) async {
    final d = await _ensure(script);
    if (surah < 1 || surah >= d.surahFirstPage.length) return 1;
    final p = d.surahFirstPage[surah];
    return p == 0 ? 1 : p;
  }

  /// [pageForSurah] once [script] is loaded (1 before).
  static int surahPageSync(String script, int surah) {
    final d = _data[_norm(script)];
    if (d == null || surah < 1 || surah >= d.surahFirstPage.length) return 1;
    final p = d.surahFirstPage[surah];
    return p == 0 ? 1 : p;
  }

  /// First (surah, ayah) that appears as text on [page]; falls back to a header.
  static (int, int) firstVerseOfPage(String script, int page) {
    final info = _pageInfo(script, page);
    return (info.$1, info.$2);
  }

  static (int, int) _firstVerseOfPageUncached(String script, int page) {
    final d = _data[_norm(script)];
    if (d == null || page < 1 || page > d.pages.length) return (1, 1);
    int? headerSurah;
    for (final ln in d.pages[page - 1]) {
      if (ln.isText && ln.words.isNotEmpty) {
        return surahAyahOf(ln.words.first.ayah);
      }
      headerSurah ??= ln.isHeader ? ln.surah : null;
    }
    if (headerSurah != null) return (headerSurah, 1);
    return (1, 1);
  }

  /// global (surah, ayah-in-surah) → global ayah index (0-based).
  static int globalAyahOf(int surah, int ayahInSurah) {
    final cum = _surahCum;
    if (cum == null || surah < 1 || surah > cum.length - 1) return 0;
    return cum[surah - 1] + (ayahInSurah - 1);
  }

  /// Highest valid global ayah index (6235 for the full muṣḥaf).
  static int get lastGlobalAyah => (_surahCum?.last ?? 6236) - 1;

  /// 1-based page that contains [globalAyah] (binary search).
  static int pageForGlobalAyah(String script, int globalAyah) {
    final d = _data[_norm(script)];
    if (d == null) return 1;
    final pf = d.pageFirstGlobal;
    var lo = 0, hi = pf.length - 1, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (pf[mid] <= globalAyah) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans + 1;
  }

  /// 1..30 for a global ayah index. Binary search over the sorted juz-start
  /// table.
  static int juzOf(int globalAyah) {
    final starts = _juzStartAyah;
    if (starts.isEmpty) return 1;
    var lo = 0, hi = starts.length - 1, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (starts[mid] <= globalAyah) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans + 1;
  }

  static int juzOfPage(String script, int page) =>
      _pageInfo(script, page).$3;

  // (surah, ayah-in-surah, juz) for a page — firstVerseOfPage and juzOfPage
  // both need this, and both get called multiple times per page render (page
  // header + bottom bar), so it's cached per (script, page) here instead of
  // rescanning the page's lines / rescanning _surahCum on every call.
  static final Map<String, (int, int, int)> _pageInfoCache = {};

  static (int, int, int) _pageInfo(String script, int page) {
    final key = '${_norm(script)}/$page';
    final cached = _pageInfoCache[key];
    if (cached != null) return cached;
    final fv = _firstVerseOfPageUncached(script, page);
    final cum = _surahCum;
    final juz =
        cum == null ? 1 : juzOf(cum[fv.$1 - 1] + (fv.$2 - 1));
    final result = (fv.$1, fv.$2, juz);
    _pageInfoCache[key] = result;
    return result;
  }
}

/// Runs in a background isolate. Builds the flat token stream and resolves every
/// page's lines to token ranges. Inputs/outputs are all primitives so they can
/// cross the isolate boundary.
Map<String, dynamic> _buildMushaf(Map<String, String> args) {
  final txt = (jsonDecode(args['txt']!) as List).cast<String>();
  final lay = jsonDecode(args['lay']!) as List; // List<List<[a,w]>>

  final tok = <String>[];
  final tokAyah = <int>[];
  final tokWord = <int>[];
  final ayahFirstTok = List<int>.filled(txt.length + 1, 0);
  final rwc = List<int>.filled(txt.length, 0);

  for (var a = 0; a < txt.length; a++) {
    ayahFirstTok[a] = tok.length;
    var real = 0;
    for (final t in txt[a].split('\u200c')) {
      if (t.isEmpty) continue;
      // Only ۝ (U+06DD) ends an ayah. The Uthmani text also prefixes ۞
      // (U+06DE, rub' al-hizb) onto the first word of 199 ayahs ('۞إِنَّ');
      // that token is a real word and must keep its index.
      final marker = t.startsWith('\u06dd');
      tok.add(t);
      tokAyah.add(a);
      tokWord.add(marker ? -1 : real);
      if (!marker) real++;
    }
    rwc[a] = real;
  }
  ayahFirstTok[txt.length] = tok.length;

  int pos(int a, int w) => ayahFirstTok[a] + w;

  // First pass: encode lines; collect text-line start positions in order.
  final starts = <int>[];
  final isText = <List<bool>>[];
  final encoded = <List<List<int>>>[];
  for (final p in lay) {
    final lb = <bool>[];
    final ld = <List<int>>[];
    for (final ln in (p as List)) {
      final a = (ln as List)[0] as int;
      final w = ln[1] as int;
      if (a < 0) {
        lb.add(false);
        if (w == -999) {
          ld.add(<int>[1]); // basmala
        } else {
          ld.add(<int>[0, 1 - w]); // header: surah = 1 - w
        }
      } else {
        lb.add(true);
        final st = pos(a, w);
        ld.add(<int>[2, st, -1]); // end filled in second pass
        starts.add(st);
      }
    }
    isText.add(lb);
    encoded.add(ld);
  }

  // Second pass: each text line ends where the next text line begins; record
  // the page every token lands on while we're at it.
  final tokPage = List<int>.filled(tok.length, 0);
  var k = 0;
  for (var pi = 0; pi < encoded.length; pi++) {
    for (var li = 0; li < encoded[pi].length; li++) {
      if (isText[pi][li]) {
        final end = (k + 1 < starts.length) ? starts[k + 1] : tok.length;
        encoded[pi][li][2] = end;
        for (var t = encoded[pi][li][1]; t < end; t++) {
          tokPage[t] = pi + 1;
        }
        k++;
      }
    }
  }

  return <String, dynamic>{
    'tok': tok,
    'tokAyah': tokAyah,
    'tokWord': tokWord,
    'rwc': rwc,
    'ayahFirstTok': ayahFirstTok,
    'tokPage': tokPage,
    'pages': encoded,
  };
}

/// How big a muṣḥaf page is drawn, and how big its text.
///
/// The 15-line data comes without the kashida a printed muṣḥaf uses to make
/// every line exactly full, so lines are justified by widening the gaps
/// between words. To keep those gaps print-like, the text is sized by the
/// page's WIDTH (its widest line fills the line) and lines sit [pitch] apart —
/// tall marks overlap into the gap between lines, as in print, instead of
/// every line reserving the font's full 2.3 em box.
///
/// [refEm] is the median page's widest line (in em), measured over every
/// line of both muṣḥafs with HarfBuzz and the bundled fonts. Every page in a
/// view shares one box sized for it, so turning a page never changes the
/// book's shape; each page then fits its own text into that box (±10% size
/// between pages; median extra gap 0.2 em, against 0.9 em when the font
/// was limited by height).
abstract final class MushafGeometry {
  static const refEm = {'uthmani': 17.3, 'indopak': 18.0};

  /// Line pitch the box is sized for, and the tightest a page may squeeze it
  /// to make room for a larger font (in em).
  static const pitch = 1.8;
  static const minPitch = 1.6;
  static const lines = 15;

  static double refEmOf(String script) =>
      refEm[script == 'indopak' ? 'indopak' : 'uthmani']!;

  // ── chrome of _MushafPageView (keep in step with it) ──

  /// Wider pages get roomier padding.
  static const roomyWidth = 520.0;

  /// [compact]: the phone's two-page spread — thinner padding, and the page
  /// number in the running head instead of a line of its own.
  ///
  /// The Classic page border and the juzʼ margin scale with the text: [fs]
  /// is the page's (estimated) font size.
  static double chromeW(
          {required bool roomy,
          required MushafDeco deco,
          bool compact = false,
          double fs = 0}) =>
      2 +
      (roomy ? 44 : (compact ? 8 : 12)) +
      switch (deco.frameRules) {
        2 => compact ? 22 : 26,
        1 => compact ? 14 : 18,
        _ => compact ? 12 : 16,
      } +
      (deco.classicBorder ? 2 * (classicBorder(fs) + classicGap(fs)) : 0) +
      (deco.lantern ? 2 * lanternBand(fs) : 0);

  static double chromeH(
          {required bool roomy,
          required MushafDeco deco,
          required bool header,
          bool compact = false,
          double fs = 0}) =>
      2 +
      (roomy ? 28 : (compact ? 7 : 10)) +
      switch (deco.frameRules) {
        2 => compact ? 14 : 18,
        1 => compact ? 6 : 10,
        _ => compact ? 4 : 8,
      } +
      (deco.classicBorder ? 2 * (classicBorder(fs) + classicGap(fs)) : 0) +
      (header ? (compact ? 30 : 30 + 19.5) : 0);

  /// The Classic page border's thickness (Update 9: ≈ 0.48 × the font,
  /// at least 9px), and the space between it and the text.
  static double classicBorder(double fs) => fs * .48 < 9 ? 9 : fs * .48;
  static double classicGap(double fs) => fs * .3 < 4 ? 4 : fs * .3;

  /// Classic: the band each side of the text that the juzʼ marker stands in
  /// (both sides, so the text stays centred) — ≈ 1.15 × the font + 10px.
  static double lanternBand(double fs) => 1.15 * fs + 10;

  /// The font size a page box [pageW] wide gives its text, chrome and all
  /// (the Classic chrome depends on it, so it's found by iterating).
  static double fontFor(double pageW, String script, MushafDeco deco,
      {bool compact = false}) {
    final roomy = pageW > roomyWidth;
    final em = refEmOf(script);
    var fs = 0.0;
    for (var i = 0; i < (deco.scalesChrome ? 4 : 1); i++) {
      fs = (pageW - chromeW(roomy: roomy, deco: deco, compact: compact, fs: fs)) /
          em;
    }
    return fs.clamp(4.0, 400.0);
  }

  /// The page box that fits in [avail]. With [page] and a scanned shape for
  /// it ([pageRatio]), its text block has exactly the printed page's
  /// proportions; otherwise its text is sized for the median page, and every
  /// page of a view shares the box. [heightBudget] replaces avail.height when
  /// the page may scroll (zoomed single page); with [byWidthOnly] the height
  /// follows the width.
  static Size pageBox(Size avail, String script,
      {required MushafDeco deco,
      required bool header,
      int? page,
      double? heightBudget,
      bool byWidthOnly = false,
      bool compact = false}) {
    final ratio = page == null ? null : pageRatio(script, page);
    final em = refEmOf(script);
    Size fit(bool roomy) {
      // The Classic chrome follows the font size, which follows the chrome:
      // a few rounds settle it.
      var fs = 0.0;
      var size = Size.zero;
      for (var i = 0; i < (deco.scalesChrome ? 4 : 1); i++) {
        final cw = chromeW(roomy: roomy, deco: deco, compact: compact, fs: fs);
        final ch = chromeH(
            roomy: roomy, deco: deco, header: header, compact: compact, fs: fs);
        final h = (heightBudget ?? avail.height) - ch;
        if (ratio != null) {
          final byH = h * ratio;
          final tw = (byWidthOnly || avail.width - cw < byH
                  ? avail.width - cw
                  : byH)
              .clamp(40.0, 1e5);
          fs = tw / em;
          size = Size(tw + cw, tw / ratio + ch);
        } else {
          final byW = (avail.width - cw) / em;
          final byH = h / (lines * pitch);
          fs = (byWidthOnly ? byW : (byW < byH ? byW : byH)).clamp(6.0, 400.0);
          size = Size(em * fs + cw, lines * pitch * fs + ch);
        }
      }
      return size;
    }

    final roomy = fit(true);
    return roomy.width > roomyWidth ? roomy : fit(false);
  }

  /// The text area inside a page box from [pageBox] (what the page's line
  /// grid gets) — for preparing a page's lines before it's on screen.
  static Size textArea(Size box,
      {required MushafDeco deco, required bool header}) {
    final roomy = box.width > roomyWidth;
    // Only a script's reference measure matters here, not which script.
    final fs = deco.scalesChrome ? fontFor(box.width, deco.script, deco) : 0.0;
    return Size(box.width - chromeW(roomy: roomy, deco: deco, fs: fs),
        box.height -
            chromeH(roomy: roomy, deco: deco, header: header, fs: fs));
  }

  /// Width ÷ height of [page]'s text block as printed, from the scanned
  /// Madani muṣḥaf (`tool/gen_mushaf_page_ratios.py`); null for scripts or
  /// pages without a scan.
  static double? pageRatio(String script, int page) =>
      _ratios[MushafRepo._norm(script)]?[page];

  static final Map<String, Map<int, double>> _ratios = {};

  static Future<void> _loadRatios(String script) async {
    if (_ratios.containsKey(script)) return;
    try {
      final raw = await rootBundle
          .loadString('assets/quran/mushaf_page_ratio_$script.json');
      final pages =
          (jsonDecode(raw) as Map<String, dynamic>)['pages'] as Map<String, dynamic>;
      _ratios[script] = {
        for (final e in pages.entries) int.parse(e.key): (e.value as num).toDouble(),
      };
    } catch (_) {
      _ratios[script] = const {}; // no scan for this script
    }
  }

  static final Map<String, double> _widestEm = {};
  static final Expando<double> _lineEm = Expando('lineEm');

  /// Every text line's natural width in em, per page (0 for header and
  /// basmala lines), precomputed by `tool/gen_mushaf_widths_test.dart` from
  /// the bundled fonts — so opening a page doesn't shape every line once just
  /// to measure it. Missing (or stale) pages fall back to measuring.
  static final Map<String, Map<int, List<double>>> _emTable = {};

  /// How many lines were shaped to be measured (not taken from the table).
  @visibleForTesting
  static int debugMeasuredLines = 0;

  static Future<void> _loadEmTable(String script) async {
    if (_emTable.containsKey(script)) return;
    try {
      final raw =
          await rootBundle.loadString('assets/quran/mushaf_line_em_$script.json');
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final pages = m['pages'] as Map<String, dynamic>;
      _emTable[script] = {
        for (final e in pages.entries)
          int.parse(e.key): [
            for (final v in e.value as List) (v as num).toDouble()
          ],
      };
    } catch (_) {
      _emTable[script] = const {};
    }
  }

  /// Shapes [line] at 44 px and returns its natural width in em.
  static double measureLineEm(String script, MushafLine line) {
    const ref = 44.0;
    debugMeasuredLines++;
    final tp = TextPainter(
        text: TextSpan(
            text: line.words.map((e) => e.text).join(' '),
            style: TextStyle(
                fontFamily: MushafRepo.fontFamily(script),
                fontSize: ref,
                height: 1.0)),
        textDirection: TextDirection.rtl,
        maxLines: 1)
      ..layout();
    final em = tp.width / ref;
    tp.dispose();
    return em;
  }

  /// The page's widest text line in em. Text width scales with font size, so
  /// the result holds for any viewport (and gives each line's width too —
  /// see [lineEm]). Read from the precomputed table when it covers the page;
  /// otherwise every line is shaped once.
  static double widestEm(String script, int page, List<MushafLine> lines) {
    final norm = MushafRepo._norm(script);
    final key = '$norm/$page';
    final cached = _widestEm[key];
    if (cached != null) return cached;
    final table = _emTable[norm]?[page];
    final useTable = table != null && table.length == lines.length;
    var widest = 1.0 / 44;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (!l.isText) continue;
      final em = _lineEm[l] ??
          (useTable && table[i] > 0 ? table[i] : measureLineEm(norm, l));
      _lineEm[l] = em;
      if (em > widest) widest = em;
    }
    return _widestEm[key] = widest;
  }

  /// Whether [page]'s widths are known without shaping (table or cache).
  static bool hasWidths(String script, int page, List<MushafLine> lines) {
    final norm = MushafRepo._norm(script);
    if (_widestEm.containsKey('$norm/$page')) return true;
    final table = _emTable[norm]?[page];
    return table != null && table.length == lines.length;
  }

  /// A text line's natural width (plain spaces) in em, from [widestEm]'s
  /// pass — so a line isn't shaped again just to be measured. Null until
  /// its page has been measured.
  static double? lineEm(MushafLine line) => _lineEm[line];
}

/// How a muṣḥaf page is dressed: its ornament style ('plain' | 'modern' |
/// 'classic'), whether it has its border, and (Classic) the juzʼ in its
/// margin. Classic draws each script's own artwork.
class MushafDeco {
  final String style;
  final bool border;
  final bool margin;
  final String script;

  /// The border's style: 'auto' (from the ornaments and script), 'line',
  /// 'double', 'madani' or 'indopak'.
  final String borderStyle;
  const MushafDeco(this.style, this.border,
      [this.margin = true, this.script = 'uthmani', this.borderStyle = 'auto']);

  /// The old "ornate borders" page: Modern, with its double frame.
  static const framed = MushafDeco('modern', true);

  factory MushafDeco.of(String script, String style, bool border,
          [bool margin = true, String borderStyle = 'auto']) =>
      MushafDeco(style, border, margin,
          script == 'indopak' ? 'indopak' : 'uthmani', borderStyle);

  bool get ornate => style != 'plain';
  bool get classic => style == 'classic';

  /// The border drawn: 'line', 'double', or the Classic artwork 'madani' /
  /// 'indopak' — by default the script's with Classic, two rules with
  /// Modern, one plain.
  String get borderArt => borderStyle != 'auto'
      ? borderStyle
      : classic
          ? (script == 'indopak' ? 'indopak' : 'madani')
          : (ornate ? 'double' : 'line');

  /// The page frame's rules: none, one, or two; the Classic artwork is
  /// drawn instead.
  int get frameRules => !border
      ? 0
      : switch (borderArt) {
          'double' => 2,
          'line' => 1,
          _ => 0,
        };

  /// A Classic page border (Madani's tiles or the Indo-Pak frame).
  bool get classicBorder =>
      border && (borderArt == 'madani' || borderArt == 'indopak');

  /// Classic pages carry the juzʼ in their outer margin: Madani's lantern,
  /// Indo-Pak's plain text.
  bool get lantern => classic && margin;

  /// Whether the chrome follows the font size.
  bool get scalesChrome => classicBorder || lantern;

  @override
  bool operator ==(Object other) =>
      other is MushafDeco &&
      other.style == style &&
      other.border == border &&
      other.margin == margin &&
      other.script == script &&
      other.borderStyle == borderStyle;
  @override
  int get hashCode => Object.hash(style, border, margin, script, borderStyle);
}
