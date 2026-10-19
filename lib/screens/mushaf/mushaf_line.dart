import 'dart:async';
import 'dart:collection';
import 'dart:developer' show Timeline;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/marks/marks_model.dart';
import '../../core/marks/qc_words.dart';
import '../../core/marks/word_ref.dart';
import '../../core/perf_log.dart';
import '../../core/tap_longpress.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../ui/mark_style.dart';

/// One text line of the 15-line muṣḥaf, shaped once.
///
/// DigitalKhatt is by far the costliest face in the app to shape (its
/// positioning tables run 5–7× larger than the others), and a page used to
/// shape every line three or four times — to size the page, to paint it
/// (`Text.rich`, again on every relayout), and once more to find word
/// positions — much of it in the middle of a swipe. Here a line is shaped
/// exactly once per look: [MushafLineCache] keeps the laid-out painter, and
/// [RenderMushafLine] paints it, finds tapped words from its boxes and draws
/// the marks' pattern lines from them. Lines for pages not yet on screen are
/// prepared in small background steps by [MushafLineScheduler], never while
/// a finger is down.

/// Font size, line slot and content height of a page for a viewport — a
/// pure function of (script, page, viewport, layout mode), shared by the page
/// and by background preparation so both build the same lines.
(double fs, double slotH, double contentH) mushafPageGeometry(
  String script,
  int page,
  List<MushafLine> lines,
  double vw,
  double vh, {
  required bool fitWidth,
}) {
  final key = '$script/$page/${_round4(vw)}/${_round4(vh)}/$fitWidth';
  final cached = _geomCache[key];
  if (cached != null) return cached;
  final n = lines.isEmpty ? 1 : lines.length;
  // The page's widest line fills the width; lines sit about
  // MushafGeometry.pitch apart (never tighter than minPitch, which caps the
  // font on pages with short lines).
  final widest = MushafGeometry.widestEm(script, page, lines);
  final byWidth = vw / widest;
  final ratio = MushafGeometry.pageRatio(script, page);
  final double fs, slotH;
  if (fitWidth && ratio != null) {
    // Full width, and as tall as the printed page is for that width.
    slotH = vw / ratio / n;
    final byHeight = slotH / MushafGeometry.minPitch;
    final raw = (byWidth < byHeight ? byWidth : byHeight).clamp(8.0, 200.0);
    fs = (raw * 2).floorToDouble() / 2;
  } else if (fitWidth) {
    fs = byWidth.clamp(8.0, 200.0);
    slotH = fs * MushafGeometry.pitch;
  } else {
    slotH = vh / n;
    final byHeight = slotH / MushafGeometry.minPitch;
    // Rounded DOWN to 0.5 px: neighbouring pages then share font sizes, and
    // the renderer's glyph cache (kept per size) is reused instead of
    // rasterising every glyph anew on each page. Rounding down keeps the
    // text inside the line; justification absorbs the difference.
    final raw = (byWidth < byHeight ? byWidth : byHeight).clamp(8.0, 200.0);
    fs = (raw * 2).floorToDouble() / 2;
  }
  final r = (fs, slotH, fitWidth ? slotH * n : vh);
  if (_geomCache.length > 256) _geomCache.clear();
  return _geomCache[key] = r;
}

final Map<String, (double, double, double)> _geomCache = {};

// Rounds a viewport dimension to the nearest 4px before it goes into a key:
// an interactive window resize would otherwise mint one entry per pixel.
double _round4(double x) => (x / 4).round() * 4.0;

/// Everything that decides how one line looks.
class MushafLineSpec {
  final String script;
  final int page;
  final int index; // line index on the page
  final MushafLine line;
  final double fontSize;
  final double slotH;
  final double targetW;
  final Color ink, accent, strongBg, verseBg;
  final int playAyah, playWord;
  final bool reciting;
  final Map<int, MarkVisual> marks;
  final MarkPalette? markPal;

  /// The word in focus (review: the mark being looked at), as a
  /// [WordRef.key] (word 0 = the āyah's ۝); -1 for none. It's drawn on its
  /// strong background with an outline — rectangles beside the glyphs, which
  /// stay atlas sprites like any other word.
  final int focus;

  /// The words were re-wrapped from their muṣḥaf lines (a verse card): a
  /// word that ended a muṣḥaf line has no stored gap to the next, so it
  /// takes a plain space.
  final bool rewrap;

  /// Tajwīd rule colours (by rule index) when tajwīd colouring is on — drawn
  /// from the glyph atlas only; the text fallback ignores it.
  final List<Color>? tajwid;

  /// The cache key: the line, its size, and only the styling that actually
  /// touches its words — so a recitation tick changes the key of the one or
  /// two lines it highlights, and every other line is reused.
  final String key;

  /// True when nothing on the line is highlighted or marked (the look that
  /// is prepared ahead of time).
  final bool plain;

  factory MushafLineSpec({
    required String script,
    required int page,
    required int index,
    required MushafLine line,
    required double fontSize,
    required double slotH,
    required double targetW,
    required Color ink,
    required Color accent,
    required Color strongBg,
    required Color verseBg,
    int playAyah = -1,
    int playWord = -1,
    bool reciting = false,
    Map<int, MarkVisual> marks = const {},
    MarkPalette? markPal,
    List<Color>? tajwid,
    int focus = -1,
    bool rewrap = false,
  }) {
    final variant = StringBuffer();
    for (var i = 0; i < line.words.length; i++) {
      final wd = line.words[i];
      final st = _tokenState(wd, playAyah, playWord, reciting);
      final key = (marks.isEmpty || markPal == null) && focus < 0
          ? -1
          : _wordKey(wd);
      final mv = marks.isEmpty || markPal == null ? null : marks[key];
      final f = focus >= 0 && key == focus;
      if (st == 0 && mv == null && !f) continue;
      variant.write('$i:$st');
      if (mv != null) variant.write(':${mv.hashCode}');
      if (f) variant.write(':f');
      variant.write(',');
    }
    final plain = variant.isEmpty;
    final key =
        '$script|$page|$index|${fontSize.toStringAsFixed(2)}|'
        '${_round4(targetW)}|${slotH.toStringAsFixed(1)}|${ink.toARGB32()}|'
        '${plain ? 'p' : '${accent.toARGB32()}|${strongBg.toARGB32()}|'
                  '${verseBg.toARGB32()}|${identityHashCode(markPal)}|$variant'}'
        '${tajwid == null ? '' : '|tj${identityHashCode(tajwid)}'}'
        // Atlas or text: the line redraws when the atlas arrives.
        '|${MushafAtlas.of(script) == null ? 't' : 'a'}';
    return MushafLineSpec._(
      script,
      page,
      index,
      line,
      fontSize,
      slotH,
      targetW,
      ink,
      accent,
      strongBg,
      verseBg,
      playAyah,
      playWord,
      reciting,
      marks,
      markPal,
      tajwid,
      focus,
      rewrap,
      key,
      plain,
    );
  }

  const MushafLineSpec._(
    this.script,
    this.page,
    this.index,
    this.line,
    this.fontSize,
    this.slotH,
    this.targetW,
    this.ink,
    this.accent,
    this.strongBg,
    this.verseBg,
    this.playAyah,
    this.playWord,
    this.reciting,
    this.marks,
    this.markPal,
    this.tajwid,
    this.focus,
    this.rewrap,
    this.key,
    this.plain,
  );

  /// [wd]'s [WordRef.key] (the ۝ is word 0).
  static int _wordKey(MushafWord wd) =>
      WordRef.fromGlobal(wd.ayah, wd.isMarker ? -1 : wd.wordIdx).key;

  /// Whether [wd] is the word in focus.
  bool isFocus(MushafWord wd) => focus >= 0 && _wordKey(wd) == focus;

  /// 0 plain, 1 the word being recited/played, 2 inside the recited āyah.
  static int _tokenState(
    MushafWord wd,
    int playAyah,
    int playWord,
    bool reciting,
  ) {
    if (wd.ayah != playAyah) return 0;
    if (!wd.isMarker &&
        playWord >= 0 &&
        qcWordOf(wd.ayah, wd.wordIdx) == qcWordOf(wd.ayah, playWord)) {
      return 1;
    }
    return reciting ? 2 : 0;
  }

  String get text => line.words.map((w) => w.text).join(' ');
}

/// A line ready to paint: its size, each token's horizontal extent within
/// it, and what's needed to hit-test and mark it — drawn either from the
/// glyph atlas ([AtlasLine]) or, without one, from shaped text ([LaidLine]).
abstract interface class MushafLineLayout {
  double get width;
  double get height;
  double get baseline;
  double get gapExtra;
  List<(double left, double right)> get boxes;
  List<(double left, double right, MarkVisual v)> get markLines;

  /// The word in focus, outlined (at most one).
  List<(double left, double right)> get focusBoxes;
}

/// A shaped line: its painter, each token's horizontal extent within it, and
/// what's needed to justify, hit-test and mark it.
class LaidLine implements MushafLineLayout {
  final TextPainter painter;
  @override
  final List<(double left, double right)> boxes;
  @override
  final double baseline;
  @override
  final double gapExtra;
  @override
  final List<(double left, double right, MarkVisual v)> markLines;
  @override
  final List<(double left, double right)> focusBoxes;
  const LaidLine(
    this.painter,
    this.boxes,
    this.baseline,
    this.gapExtra,
    this.markLines, [
    this.focusBoxes = const [],
  ]);

  @override
  double get width => painter.width;
  @override
  double get height => painter.height;
}

/// A line drawn from the glyph atlas: per atlas sheet, one sprite per glyph
/// (transform, source rect, colour) for `Canvas.drawRawAtlas`, plus the
/// highlight rects behind the words.
class AtlasLine implements MushafLineLayout {
  @override
  final double width, height, baseline, gapExtra;
  @override
  final List<(double, double)> boxes;
  @override
  final List<(double, double, MarkVisual)> markLines;
  @override
  final List<(double, double)> focusBoxes;
  final List<(double left, double right, Color c)> backgrounds;
  final int tier;
  final List<(int sheet, Float32List xforms, Float32List rects, Int32List colors)>
      batches;

  /// Each token's colour as drawn (tests).
  @visibleForTesting
  final List<Color> tokenColors;

  /// Each glyph's colour, per token (tests: tajwīd colours letters; debug
  /// builds only).
  @visibleForTesting
  final List<List<Color>> glyphColors;

  const AtlasLine(
    this.width,
    this.height,
    this.baseline,
    this.gapExtra,
    this.boxes,
    this.markLines,
    this.backgrounds,
    this.tier,
    this.batches,
    this.tokenColors,
    this.glyphColors, [
    this.focusBoxes = const [],
  ]);
}

/// Lays [s] out from [atlas] at [tier]: the same justification as the text
/// path (spaces widen once a line's natural width reaches 45% of the
/// measure), words placed right to left from their premade shapes.
AtlasLine buildAtlasLine(MushafLineSpec s, MushafAtlas atlas, int tier) {
  // Runs for every line of every page as it comes on screen, so it allocates
  // as little as it can: one pass to count each sheet's glyphs, then the
  // sprite arrays are filled in place (on a Pixel 7 Pro, growable lists of
  // boxed doubles made this ~1–2 ms a line).
  final l = s.line;
  final fs = s.fontSize;
  final k = fs / atlas.upem; // font units → px
  final n = l.words.length;
  final t0 = l.firstTok;
  final t = atlas.tiers[tier];
  final tokenWord = atlas.tokenWord, tokenGap = atlas.tokenGap;
  final wordAdvance = atlas.wordAdvance, wordStart = atlas.wordGlyphStart;
  final glyphId = atlas.glyphId, sheetOf = t.sheet;

  int gapAfter(int tok) {
    final g = tokenGap[tok];
    return g == 0 && s.rewrap ? atlas.space : g;
  }

  var natural = 0.0;
  final perSheet = List<int>.filled(t.sheetCount, 0);
  for (var i = 0; i < n; i++) {
    final w = tokenWord[t0 + i];
    natural += wordAdvance[w];
    if (i < n - 1) natural += gapAfter(t0 + i);
    for (var g = wordStart[w]; g < wordStart[w + 1]; g++) {
      final sh = sheetOf[glyphId[g]];
      if (sh != 255) perSheet[sh]++;
    }
  }
  natural *= k;
  final spaces = n - 1;
  final justified = natural >= s.targetW * 0.45 && spaces > 0;
  final gapExtra = justified
      ? ((s.targetW - natural) / spaces).clamp(0.0, 1e6)
      : 0.0;
  final width = natural + gapExtra * (spaces < 0 ? 0 : spaces);
  // As a TextPainter with height slotH/fs and even leading would place it.
  final asc = atlas.ascender * k, desc = -atlas.descender * k;
  final baseline = (s.slotH - (asc + desc)) / 2 + asc;

  final xforms = [for (final c in perSheet) Float32List(c * 4)];
  final rects = [for (final c in perSheet) Float32List(c * 4)];
  final colors = [for (final c in perSheet) Int32List(c)];
  final fill = List<int>.filled(t.sheetCount, 0);
  final scale = fs / t.em;
  final gx = atlas.glyphX, gy = atlas.glyphY;
  final sx = t.x, sy = t.y, sw = t.w, shh = t.h, bl = t.left, bt = t.top;
  final pairs = atlas.tajwidPairs, tjStart = atlas.tajwidStart;
  final tj = s.tajwid;
  final mp = s.markPal;
  final boxes = <(double, double)>[];
  final backgrounds = <(double, double, Color)>[];
  final marked = <(double, double, MarkVisual)>[];
  final focused = <(double, double)>[];
  final tokenColors = <Color>[];
  final glyphColors = <List<Color>>[];
  var x = width;
  for (var i = 0; i < n; i++) {
    final wd = l.words[i];
    final tok = t0 + i;
    final w = tokenWord[tok];
    final left = x - wordAdvance[w] * k;
    boxes.add((left, x));
    final st = MushafLineSpec._tokenState(wd, s.playAyah, s.playWord, s.reciting);
    final mv = s.marks.isEmpty || mp == null
        ? null
        : s.marks[WordRef.fromGlobal(wd.ayah, wd.isMarker ? -1 : wd.wordIdx).key];
    final f = s.isFocus(wd);
    if (f) focused.add((left, x));
    final over = st == 1 || f ? s.strongBg : (st == 2 ? s.verseBg : null);
    final tint = mv == null || mv.open == null ? null : mp!.tintOf(mv.open!);
    final bg = over ?? tint;
    if (bg != null) backgrounds.add((left, x, bg));
    if (mv != null && x > left) marked.add((left, x, mv));
    final base = st == 1 ? s.accent : s.ink;
    final baseArgb = base.toARGB32();
    tokenColors.add(base);
    // Tajwīd rules colour single glyphs (not the word being recited); the
    // pairs are sorted by glyph.
    var p = tj != null && st != 1 ? tjStart[tok] : 0;
    final pEnd = tj != null && st != 1 ? tjStart[tok + 1] : 0;
    final g0 = wordStart[w], g1 = wordStart[w + 1];
    final debugColors = kDebugMode ? <Color>[] : null;
    for (var g = g0; g < g1; g++) {
      var argb = baseArgb;
      while (p < pEnd && pairs[p * 2] < g - g0) {
        p++;
      }
      if (p < pEnd && pairs[p * 2] == g - g0) {
        final r = pairs[p * 2 + 1];
        if (r < tj!.length) argb = tj[r].toARGB32();
      }
      debugColors?.add(Color(argb));
      final a = glyphId[g];
      final sheet = sheetOf[a];
      if (sheet == 255) continue;
      final f = fill[sheet]++;
      final xf = xforms[sheet], rc = rects[sheet];
      xf[f * 4] = scale;
      xf[f * 4 + 1] = 0;
      xf[f * 4 + 2] = left + gx[g] * k + bl[a] * scale;
      xf[f * 4 + 3] = baseline - gy[g] * k - bt[a] * scale;
      final ax = sx[a].toDouble(), ay = sy[a].toDouble();
      rc[f * 4] = ax;
      rc[f * 4 + 1] = ay;
      rc[f * 4 + 2] = ax + sw[a];
      rc[f * 4 + 3] = ay + shh[a];
      colors[sheet][f] = argb;
    }
    glyphColors.add(debugColors ?? const []);
    x = left - (i < n - 1 ? gapAfter(tok) * k + gapExtra : 0);
  }
  return AtlasLine(
    width,
    s.slotH,
    baseline,
    gapExtra,
    boxes,
    marked,
    backgrounds,
    tier,
    [
      for (var sh = 0; sh < perSheet.length; sh++)
        if (perSheet[sh] > 0) (sh, xforms[sh], rects[sh], colors[sh]),
    ],
    tokenColors,
    glyphColors,
    focused,
  );
}

/// Whether [token] holds characters that bidi treats as numbers — the āyah
/// marker ۝ and its digits, or the disputed-end sign U+08E2 some Indo-Pak
/// words carry — and so splits off a run of its own.
bool _numberRun(String token) {
  for (final c in token.codeUnits) {
    if (c == 0x06DD ||
        c == 0x08E2 ||
        (c >= 0x0660 && c <= 0x0669) ||
        (c >= 0x06F0 && c <= 0x06F9)) {
      return true;
    }
  }
  return false;
}

LaidLine _shape(MushafLineSpec s) {
  final l = s.line;
  final fs = s.fontSize;
  final base = TextStyle(
    fontFamily: MushafRepo.fontFamily(s.script),
    fontSize: fs,
    color: s.ink,
    height: s.slotH / fs,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Natural width with plain spaces, from the page's sizing data (colours
  // and marks don't change it).
  final em =
      MushafGeometry.lineEm(l) ?? MushafGeometry.measureLineEm(s.script, l);
  final natural = em * fs;

  // Justify by widening each space (the paragraph's wordSpacing; Skia
  // ignores letterSpacing on these runs, and wordSpacing on a child span).
  final spaces = l.words.length - 1;
  final justified = natural >= s.targetW * 0.45 && spaces > 0;
  var gapExtra = justified
      ? ((s.targetW - natural) / spaces).clamp(0.0, 1e6)
      : 0.0;
  final rootStyle = gapExtra > 0 ? base.copyWith(wordSpacing: gapExtra) : base;

  final spans = <InlineSpan>[];
  final ranges = <(int, int)>[];
  final marked = <(int, MarkVisual)>[];
  var focusAt = -1;
  var chars = 0;
  for (var i = 0; i < l.words.length; i++) {
    final wd = l.words[i];
    final st = MushafLineSpec._tokenState(
      wd,
      s.playAyah,
      s.playWord,
      s.reciting,
    );
    final mp = s.markPal;
    final mv = s.marks.isEmpty || mp == null
        ? null
        : s.marks[WordRef.fromGlobal(
            wd.ayah,
            wd.isMarker ? -1 : wd.wordIdx,
          ).key];
    final f = s.isFocus(wd);
    if (f) focusAt = i;
    final over = st == 1 || f ? s.strongBg : (st == 2 ? s.verseBg : null);
    final color = st == 1 ? s.accent : s.ink;
    final style = mv == null
        ? (st == 0 && !f
            ? base
            : base.copyWith(color: color, backgroundColor: over))
        : markSpanStyle(base.copyWith(color: color), mv, mp!, overBg: over);
    ranges.add((chars, chars + wd.text.length));
    if (mv != null) marked.add((i, mv));
    spans.add(TextSpan(text: wd.text, style: style));
    chars += wd.text.length;
    if (i != spaces) {
      // An āyah marker (۝ + digits) is a run of its own, and Skia never
      // widens the spaces at the edges of the runs around it — those lines
      // came out short, the circle touching its neighbours. A right-to-left
      // mark between the space and the marker keeps the space inside the
      // word's run, where it widens like any other.
      final gap = _numberRun(wd.text)
          ? (_numberRun(l.words[i + 1].text) ? '‏ ‏' : '‏ ')
          : (_numberRun(l.words[i + 1].text) ? ' ‏' : ' ');
      spans.add(TextSpan(text: gap, style: base));
      chars += gap.length;
    }
  }

  var tp = TextPainter(
    text: TextSpan(children: spans, style: rootStyle),
    textDirection: TextDirection.rtl,
    maxLines: 1,
  )..layout();
  // The natural width came from the precomputed table. Should the face that
  // actually draws the text differ from the one measured (a font update, a
  // fallback face), the line misses its width: measure what was drawn and
  // lay it out once more with the right spacing.
  if (justified && (tp.width - s.targetW).abs() > 1.0) {
    final drawn = tp.width - gapExtra * spaces;
    gapExtra = drawn >= s.targetW * 0.45
        ? ((s.targetW - drawn) / spaces).clamp(0.0, 1e6)
        : 0.0;
    tp.dispose();
    tp = TextPainter(
      text: TextSpan(
        children: spans,
        style: gapExtra > 0 ? base.copyWith(wordSpacing: gapExtra) : base,
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
  }
  final boxes = <(double, double)>[];
  for (final r in ranges) {
    final bs = tp.getBoxesForSelection(
      TextSelection(baseOffset: r.$1, extentOffset: r.$2),
    );
    if (bs.isEmpty) {
      boxes.add((0, 0));
      continue;
    }
    var left = bs.first.left, right = bs.first.right;
    for (final b in bs) {
      if (b.left < left) left = b.left;
      if (b.right > right) right = b.right;
    }
    boxes.add((left, right));
  }
  return LaidLine(
    tp,
    boxes,
    tp.computeDistanceToActualBaseline(TextBaseline.alphabetic),
    gapExtra,
    [
      for (final (i, v) in marked)
        if (boxes[i].$2 > boxes[i].$1) (boxes[i].$1, boxes[i].$2, v),
    ],
    [if (focusAt >= 0) boxes[focusAt]],
  );
}

/// The shaped lines, most recently used last. Bounded: a session that reads
/// through hundreds of pages keeps only the lines around where it is.
abstract final class MushafLineCache {
  static const _capacity = 420;
  static final LinkedHashMap<String, LaidLine> _lines = LinkedHashMap();

  /// Lines shaped since start (for tests and the perf log).
  @visibleForTesting
  static int debugShaped = 0;

  /// How many times each line key was shaped (tests: never twice while it
  /// stays cached).
  @visibleForTesting
  static final Map<String, int> debugShapesPerKey = {};

  static LaidLine? peek(String key) => _lines[key];

  /// A running average of what shaping one line costs on this device.
  static int avgShapeUs = 4000;

  static bool has(String key) => _lines.containsKey(key);

  /// The line for [spec], shaping it now if it isn't cached.
  static LaidLine get(MushafLineSpec spec, {String why = 'line'}) {
    final hit = _lines.remove(spec.key);
    if (hit != null) return _lines[spec.key] = hit;
    final sw = Stopwatch()..start();
    final laid = _shape(spec);
    final us = sw.elapsedMicroseconds;
    _frameSpent(us);
    avgShapeUs = (avgShapeUs * 3 + us) ~/ 4;
    debugShaped++;
    if (kDebugMode) {
      debugShapesPerKey[spec.key] = (debugShapesPerKey[spec.key] ?? 0) + 1;
    }
    PerfLog.shaped(spec.plain ? why : 'highlight', sw.elapsedMicroseconds);
    _lines[spec.key] = laid;
    // Evicted painters aren't disposed: a line render may still hold one
    // until its next paint; the garbage collector frees it after that.
    while (_lines.length > _capacity) {
      _lines.remove(_lines.keys.first);
    }
    return laid;
  }

  @visibleForTesting
  static void clear() => _lines.clear();

  // ── shaping time spent in the current frame ──
  static Duration? _stamp;
  static int _spentUs = 0;

  static void _frameSpent(int us) {
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    if (now != _stamp) {
      _stamp = now;
      _spentUs = 0;
    }
    _spentUs += us;
  }

  /// Microseconds of shaping already done in the frame being drawn.
  static int get spentThisFrameUs =>
      SchedulerBinding.instance.currentSystemFrameTimeStamp == _stamp
          ? _spentUs
          : 0;
}

/// Prepares lines in the background, one small step per scheduler task, so
/// no single task holds up a frame — and not at all while a finger is on the
/// screen or the pages are moving (a drag is not an animation, so idle tasks
/// would otherwise run between its frames).
abstract final class MushafLineScheduler {
  static final List<Iterator<void>> _jobs = [];
  // Lines already on screen, waiting: these come before everything else.
  static final List<Iterator<void>> _urgent = [];
  static final Set<String> _queued = {};
  static int _pointers = 0;
  static bool _scrolling = false;

  static bool get busy => _pointers > 0 || _scrolling;

  static void pointerDown() {
    _pointers++;
    PerfLog.phase = 'dragging';
  }

  static void pointerUp() {
    if (_pointers > 0) _pointers--;
    if (_pointers == 0) PerfLog.phase = _scrolling ? 'settling' : 'idle';
    _kick();
  }

  static set scrolling(bool v) {
    if (_scrolling == v) return;
    _scrolling = v;
    PerfLog.phase = _pointers > 0 ? 'dragging' : (v ? 'settling' : 'idle');
    _kick();
  }

  /// Runs [steps] in the background, one step per task. Steps queued later
  /// run first: the newest request is about where the reader is now.
  static void addJob(Iterable<void> steps) {
    _jobs.insert(0, steps.iterator);
    _kick();
  }

  /// Shapes [spec] in the background if it isn't cached or queued already.
  /// Queued after the reader's own neighbour pages (see [addJob]); with
  /// [urgent] — a line on screen still waiting — ahead of everything, and
  /// [then] runs once it's ready (to repaint it).
  static void want(MushafLineSpec spec,
      {bool urgent = false, VoidCallback? then}) {
    if (MushafLineCache.has(spec.key)) return;
    if (!_queued.add(spec.key)) {
      if (then != null) (_waiting[spec.key] ??= []).add(then);
      return;
    }
    if (then != null) (_waiting[spec.key] ??= []).add(then);
    (urgent ? _urgent : _jobs).add(_one(spec).iterator);
    _kick();
  }

  static final Map<String, List<VoidCallback>> _waiting = {};

  static Iterable<void> _one(MushafLineSpec spec) sync* {
    MushafLineCache.get(spec, why: 'line');
    _queued.remove(spec.key);
    for (final cb in _waiting.remove(spec.key) ?? const <VoidCallback>[]) {
      cb();
    }
    yield null;
  }

  /// Drops pending work (the reader closed the muṣḥaf or switched script).
  static void cancelAll() {
    _jobs.clear();
    _urgent.clear();
    _queued.clear();
    _waiting.clear();
    _timer?.cancel();
    _timer = null;
  }

  /// Drops pending work and forgets pointers (the muṣḥaf screen closed —
  /// possibly with a finger still down).
  static void reset() {
    cancelAll();
    _pointers = 0;
    _scrolling = false;
  }

  static Timer? _timer;
  static bool _perFrame = false;

  // A plain timer, not SchedulerBinding.scheduleTask: an idle-priority task
  // may only run while no animation is ticking, and until then the binding
  // re-checks on every event-loop turn — a busy loop for as long as any
  // animation runs, which also hung the widget tests.
  //
  // While the pages are still: steps run back to back on timers. While a
  // finger drags them or they settle: at most one step after each frame, and
  // only in a frame with time to spare — most drag frames are ~1 ms of work,
  // but the one that builds the next page isn't, and a line takes 3–13 ms on
  // a Pixel 7 Pro. Lines already on screen go regardless.
  static void _kick({Duration delay = Duration.zero}) {
    if (_jobs.isEmpty && _urgent.isEmpty) return;
    if (busy) {
      if (_perFrame) return;
      _perFrame = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _perFrame = false;
        if (busy && (_urgent.isNotEmpty || _frameHasRoom())) {
          PerfLog.afterFrame(_step);
        }
        _kick();
      });
      return;
    }
    if (_timer != null) return;
    _timer = Timer(delay, _run);
  }

  static void _run() {
    _timer = null;
    if (busy) {
      _kick();
      return;
    }
    if (SchedulerBinding.instance.transientCallbackCount > 0) {
      // Something is animating: one step per frame instead.
      _step();
      _kick(delay: const Duration(milliseconds: 16));
      return;
    }
    _step();
    _kick();
  }

  static void _step() {
    final sw = Stopwatch()..start();
    final q = _urgent.isNotEmpty ? _urgent : _jobs;
    while (q.isNotEmpty) {
      final job = q.first;
      if (job.moveNext()) break;
      q.removeAt(0);
    }
    PerfLog.task(sw.elapsedMicroseconds);
  }

  /// Whether one more line still fits in the frame just drawn: the time
  /// since its vsync plus an average line, against ¾ of the frame budget.
  /// True when that can't be told (a test's fake clock).
  static bool _frameHasRoom() {
    final b = SchedulerBinding.instance;
    final elapsed =
        Timeline.now - b.currentSystemFrameTimeStamp.inMicroseconds;
    if (elapsed < 0 || elapsed > 1000000) return true;
    final displays = b.platformDispatcher.displays;
    final hz = displays.isEmpty ? 60.0 : displays.first.refreshRate;
    final budgetUs = 1e6 / (hz < 30 ? 60 : hz);
    return elapsed + MushafLineCache.avgShapeUs < budgetUs * .75;
  }

  /// Whether there's background work left (tests).
  @visibleForTesting
  static bool get idle => _jobs.isEmpty && _urgent.isEmpty;
}

/// The size of the text area of the last page laid out, and whether it was
/// the scrolling full-width layout — every page of a view shares it, so
/// background preparation sizes the next pages' lines from it.
(Size, bool)? mushafLastViewport;

/// The current view's page box for a page (pages take their scanned shape,
/// so each has its own), and what the page's chrome — padding, frame, header
/// — takes out of a box, measured from the last page laid out. Together they
/// give the text area of a page not on screen yet; see [mushafTextAreaFor].
Size Function(int page)? mushafPageBoxOf;
Size? mushafChrome;

/// The text area [page]'s lines will be laid out in, in the current view.
Size? mushafTextAreaFor(int page) {
  final vp = mushafLastViewport;
  if (vp == null) return null;
  final (size, fitWidth) = vp;
  final box = mushafPageBoxOf?.call(page);
  final chrome = mushafChrome;
  if (fitWidth || box == null || chrome == null) return size;
  return Size(box.width - chrome.width, box.height - chrome.height);
}

/// Where taps on the page's words go. One object per muṣḥaf screen, its
/// handlers swapped as the screen's mode changes (marking or listening), so
/// the lines themselves never need rebuilding for it.
class MushafTapHandlers {
  void Function(MushafWord)? onTapWord;
  void Function(MushafWord)? onLongPressWord;
  void Function(int globalAyah)? onTapVerse;
}

/// A muṣḥaf text line, painted from its cached shape.
class MushafLineView extends LeafRenderObjectWidget {
  final MushafLineSpec spec;
  final MushafTapHandlers handlers;
  const MushafLineView({super.key, required this.spec, required this.handlers});

  @override
  RenderMushafLine createRenderObject(BuildContext context) =>
      RenderMushafLine(spec, handlers)
        ..devicePixelRatio = View.maybeOf(context)?.devicePixelRatio ?? 1;

  @override
  void updateRenderObject(BuildContext context, RenderMushafLine renderObject) {
    renderObject
      ..spec = spec
      ..handlers = handlers
      ..devicePixelRatio = View.maybeOf(context)?.devicePixelRatio ?? 1;
  }
}

/// Shaping allowed per frame while the pages move, before further lines
/// wait for the next frames.
const _frameShapeBudgetUs = 4000;

class RenderMushafLine extends RenderBox {
  RenderMushafLine(this._spec, this.handlers);

  MushafLineSpec _spec;
  MushafTapHandlers handlers;
  LaidLine? _line;
  AtlasLine? _atlasLine;

  int _capVersion = MushafAtlas.capVersion;
  double _dpr = 1;
  set devicePixelRatio(double v) {
    if (v == _dpr) return;
    _dpr = v;
    _atlasLine = null;
    markNeedsPaint();
  }

  MushafLineSpec get spec => _spec;
  set spec(MushafLineSpec v) {
    if (_capVersion != MushafAtlas.capVersion) {
      // Lite mode changed which sheets to draw from.
      _capVersion = MushafAtlas.capVersion;
      _atlasLine = null;
      markNeedsPaint();
    }
    if (v.key == _spec.key) {
      _spec = v;
      return;
    }
    final resize = v.targetW != _spec.targetW || v.slotH != _spec.slotH;
    _spec = v;
    _line = null;
    _atlasLine = null;
    if (resize) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
    markNeedsSemanticsUpdate();
  }

  /// The glyph atlas this line draws from, if its script has one loaded.
  MushafAtlas? get _atlas =>
      _spec.line.firstTok < 0 ? null : MushafAtlas.of(_spec.script);

  /// The line as drawn, once painted (tests read token positions from it).
  @visibleForTesting
  MushafLineLayout? get laidLine {
    final atlas = _atlas;
    if (atlas != null) return _atlasLine ??= _buildAtlas(atlas);
    return _line ?? MushafLineCache.peek(_spec.key);
  }

  /// The atlas line at the resolution this line's size calls for. Until the
  /// larger sheets have loaded, the standard ones stand in (and the line
  /// repaints once they're ready).
  AtlasLine _buildAtlas(MushafAtlas atlas) {
    var tier = atlas.tierFor(_spec.fontSize * _dpr);
    if (atlas.tiers[tier].images == null) {
      atlas.tiers[tier].load().then((_) {
        if (attached) {
          _atlasLine = null;
          markNeedsPaint();
        }
      });
      tier = 0;
    }
    return buildAtlasLine(_spec, atlas, tier);
  }

  @visibleForTesting
  Offset get textOffset {
    final l = laidLine;
    if (l == null) return Offset.zero;
    return Offset((size.width - l.width) / 2, (size.height - l.height) / 2);
  }

  @override
  bool get sizedByParent => false;

  @override
  void performLayout() {
    size = constraints.constrain(Size(_spec.targetW, _spec.slotH));
    // Without the atlas, a page laid out before it's on screen (the pager
    // builds the next one early) gets its lines shaped in the background.
    if (_atlas == null && !MushafLineCache.has(_spec.key)) {
      MushafLineScheduler.want(_spec);
    }
  }

  void _paintAtlas(Canvas canvas, Offset offset, MushafAtlas atlas) {
    final sw = kMushafPerf ? (Stopwatch()..start()) : null;
    final built = _atlasLine == null;
    final l = laidLine! as AtlasLine;
    if (built && sw != null) PerfLog.atlasLine(sw.elapsedMicroseconds);
    final o = offset + textOffset;
    for (final (left, right, c) in l.backgrounds) {
      canvas.drawRect(
        Rect.fromLTWH(o.dx + left, o.dy, right - left, l.height),
        Paint()..color = c,
      );
    }
    final images = atlas.tiers[l.tier].images;
    if (images != null) {
      final paint = Paint()..filterQuality = FilterQuality.medium;
      canvas.save();
      canvas.translate(o.dx, o.dy);
      for (final (sheet, xf, rects, colors) in l.batches) {
        // Each sprite is a white glyph; modulate takes its colour.
        canvas.drawRawAtlas(
          images[sheet],
          xf,
          rects,
          colors,
          BlendMode.modulate,
          null,
          paint,
        );
      }
      canvas.restore();
    }
    _paintMarks(canvas, o, l);
    _paintFocus(canvas, o, l);
  }

  /// The focused word's outline: a rounded box in the accent colour.
  void _paintFocus(Canvas canvas, Offset o, MushafLineLayout l) {
    if (l.focusBoxes.isEmpty) return;
    final w = (_spec.fontSize * .07).clamp(1.5, 3.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = _spec.accent;
    for (final (left, right) in l.focusBoxes) {
      if (right <= left) continue;
      final r = Rect.fromLTRB(o.dx + left - w, o.dy + w / 2,
          o.dx + right + w, o.dy + l.height - w / 2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(_spec.fontSize * .25)),
          paint);
    }
  }

  void _paintMarks(Canvas canvas, Offset o, MushafLineLayout l) {
    final pal = _spec.markPal;
    if (l.markLines.isEmpty || pal == null) return;
    final fs = _spec.fontSize;
    final t = (fs * .065).clamp(1.2, 3.0);
    // Under the kasrahs (~0.35 em below the baseline), above the next line's
    // tallest marks.
    final y = o.dy + l.baseline + fs * .42;
    for (final (left, right, v) in l.markLines) {
      // Inset a little so neighbouring marked words read as separate.
      final inset = ((right - left) * .06).clamp(1.0, 4.0);
      paintMarkLine(
        canvas,
        Offset(o.dx + left + inset, y),
        right - left - inset * 2,
        v,
        pal,
        thickness: t,
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final atlas = _atlas;
    if (atlas != null) {
      _paintAtlas(context.canvas, offset, atlas);
      return;
    }
    // Painting only happens on screen; a line still unshaped by then is
    // shaped now — unless the pages are moving and this frame has already
    // spent its share on shaping: then it comes in a frame or two later
    // (fast flicks), instead of one long frame shaping a whole page.
    if (!MushafLineCache.has(_spec.key) &&
        MushafLineScheduler.busy &&
        MushafLineCache.spentThisFrameUs > _frameShapeBudgetUs) {
      _line = null;
      MushafLineScheduler.want(_spec, urgent: true, then: () {
        if (attached) markNeedsPaint();
      });
      return;
    }
    final l = _line = MushafLineCache.get(_spec);
    final o = offset + textOffset;
    l.painter.paint(context.canvas, o);
    _paintMarks(context.canvas, o, l);
    _paintFocus(context.canvas, o, l);
  }

  // ── taps ──

  TapAndLongPressGestureRecognizer? _recognizer;
  int? _down;

  /// The token under [p], if any: an āyah marker's target reaches into the
  /// gaps around it (it's a small glyph in wide justified gaps); a word's
  /// covers its own box.
  int? _tokenAt(Offset p) {
    final l = laidLine;
    if (l == null) return null;
    final o = textOffset;
    final x = p.dx - o.dx;
    final words = _spec.line.words;
    final hPad = (8.0 + l.gapExtra / 2).clamp(8.0, 26.0);
    for (var i = 0; i < words.length; i++) {
      if (!words[i].isMarker) continue;
      final (left, right) = l.boxes[i];
      if (right > left && x >= left - hPad && x <= right + hPad) return i;
    }
    for (var i = 0; i < words.length; i++) {
      final (left, right) = l.boxes[i];
      if (right > left && x >= left && x <= right) return i;
    }
    return null;
  }

  @override
  bool hitTestSelf(Offset position) => _tokenAt(position) != null;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is! PointerDownEvent) return;
    _down = _tokenAt(event.localPosition);
    if (_down == null) return;
    // Fires straight from the pointer-up instead of waiting to win the
    // gesture arena (a plain TapGestureRecognizer's wait swallowed mouse
    // clicks on the āyah circles).
    (_recognizer ??= TapAndLongPressGestureRecognizer(
      onTap: () => _fire(long: false),
      onLongPress: () => _fire(long: true),
    )).addPointer(event);
  }

  void _fire({required bool long}) {
    final i = _down;
    if (i == null) return;
    final words = _spec.line.words;
    if (i >= words.length) return;
    final wd = words[i];
    if (wd.isMarker) {
      handlers.onTapVerse?.call(wd.ayah);
    } else if (long) {
      handlers.onLongPressWord?.call(wd);
    } else {
      handlers.onTapWord?.call(wd);
    }
  }

  @override
  void dispose() {
    _recognizer?.dispose();
    super.dispose();
  }

  // ── accessibility: the line reads as its text ──

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _spec.text
      ..textDirection = TextDirection.rtl;
  }
}
