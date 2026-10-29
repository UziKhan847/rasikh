import 'dart:async';
import 'dart:collection';
import 'dart:developer' show Timeline;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/fluency/fluency_store.dart' show FluencyVisual;
import '../../core/marks/marks_model.dart';
import '../../core/marks/qc_words.dart';
import '../../core/marks/word_ref.dart';
import '../../core/perf_log.dart';
import '../../core/tap_longpress.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../ui/ornaments/ayah_markers.dart';
import '../../ui/fluency_style.dart';
import '../../ui/mark_style.dart';
import 'mushaf_marks_layer.dart';

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
/// The muṣḥaf's two opening pages (al-Fātiḥah, the start of al-Baqarah):
/// a few short lines set close together in a rounded block in the middle of
/// the page, not spread over a full page's height.
bool mushafOpeningPage(int page, List<MushafLine> lines) =>
    page <= 2 && lines.length < 12;

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
  if (mushafOpeningPage(page, lines)) {
    // The text size of a regular page in this viewport (its full measure
    // and fifteen lines), the lines at the usual pitch; the page centres
    // the block.
    final byWidth = vw / MushafGeometry.refEmOf(script);
    final byHeight =
        (fitWidth ? vw * 1.5 : vh) / 15 / MushafGeometry.minPitch;
    final raw = (byWidth < byHeight ? byWidth : byHeight).clamp(8.0, 200.0);
    final fs = (raw * 2).floorToDouble() / 2;
    final slotH = fs * MushafGeometry.pitch;
    final r = (fs, slotH, fitWidth ? slotH * 15 : vh);
    return _geomCache[key] = r;
  }
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

  /// Whether the line may be justified (spaces widened to the measure).
  /// The opening pages' lines keep their natural width.
  final bool justify;

  /// Traced āyah markers: the circle is [markerArt]'s drawing ('madani' or
  /// 'indopak') in this colour, [markerScale] its size and [markerDy] its
  /// offset (a fraction of its height) — on the atlas path; the text
  /// fallback keeps the font's circle.
  final Color? ornament;
  final String markerArt;
  final double markerScale, markerDy;

  /// White-filled papers: the circle's hole is filled with this.
  final Color? ornamentFill;

  /// Memorize mode: tokens from this index of the token stream on are
  /// hidden — left out of the sprite lists entirely (no glyphs, colours,
  /// highlights or marks), their boxes kept so nothing moves. -1: none.
  final int hideFrom;

  /// Tajwīd rule colours (by rule index) when tajwīd colouring is on — drawn
  /// from the glyph atlas only; the text fallback ignores it.
  final List<Color>? tajwid;

  /// A search's match: tokens [matchFrom, matchTo) on the āyah's ground
  /// (as a recited āyah's). -1: none.
  final int matchFrom, matchTo;

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
    int hideFrom = -1,
    bool justify = true,
    Color? ornament,
    Color? ornamentFill,
    String markerArt = 'madani',
    double markerScale = 1,
    double markerDy = 0,
    int matchFrom = -1,
    int matchTo = -1,
  }) {
    final variant = StringBuffer();
    // Only how much of THIS line is hidden matters: lines wholly before the
    // cursor keep their key (and their cached look).
    final t0 = line.firstTok, n = line.words.length;
    final hide = hideFrom < 0 || t0 < 0 || hideFrom >= t0 + n
        ? -1
        : (hideFrom <= t0 ? 0 : hideFrom - t0);
    if (hide >= 0) variant.write('h$hide,');
    if (!justify) variant.write('nj,');
    for (var i = 0; i < line.words.length; i++) {
      final wd = line.words[i];
      var st = _tokenState(wd, playAyah, playWord, reciting);
      if (st == 0 && t0 + i >= matchFrom && t0 + i < matchTo) st = 2;
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
        '${ornament == null ? '' : '|o$markerArt${ornament.toARGB32()}/$markerScale/$markerDy'}'
        '${ornament == null || ornamentFill == null ? '' : '/${ornamentFill.toARGB32()}'}'
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
      hide < 0 ? -1 : t0 + hide,
      justify,
      ornament,
      markerArt,
      markerScale,
      markerDy,
      ornamentFill,
      key,
      plain,
      matchFrom,
      matchTo,
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
    this.hideFrom,
    this.justify,
    this.ornament,
    this.markerArt,
    this.markerScale,
    this.markerDy,
    this.ornamentFill,
    this.key,
    this.plain,
    this.matchFrom,
    this.matchTo,
  );

  /// The same line with [m] for its marks (a new key when they touch it).
  MushafLineSpec withMarks(Map<int, MarkVisual> m) => identical(m, marks)
      ? this
      : MushafLineSpec(
          script: script,
          page: page,
          index: index,
          line: line,
          fontSize: fontSize,
          slotH: slotH,
          targetW: targetW,
          ink: ink,
          accent: accent,
          strongBg: strongBg,
          verseBg: verseBg,
          playAyah: playAyah,
          playWord: playWord,
          reciting: reciting,
          marks: m,
          markPal: markPal,
          tajwid: tajwid,
          focus: focus,
          rewrap: rewrap,
          hideFrom: hideFrom,
          justify: justify,
          ornament: ornament,
          ornamentFill: ornamentFill,
          markerArt: markerArt,
          markerScale: markerScale,
          markerDy: markerDy,
          matchFrom: matchFrom,
          matchTo: matchTo,
        );

  /// Token [i]'s state: 0 plain, 1 the word being recited/played, 2 inside
  /// the recited āyah or a search's match.
  int stateAt(int i) {
    final st = _tokenState(line.words[i], playAyah, playWord, reciting);
    final t = line.firstTok + i;
    return st == 0 && t >= matchFrom && t < matchTo ? 2 : st;
  }

  /// Whether the line's token [i] is hidden (memorize mode).
  bool isHidden(int i) => hideFrom >= 0 && line.firstTok + i >= hideFrom;

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

  /// The line's words as read out (hidden ones left out).
  String get text => [
        for (var i = 0; i < line.words.length; i++)
          if (!isHidden(i)) line.words[i].text,
      ].join(' ');
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

/// A line's sprites, laid out once and kept: every glyph's place in font
/// units (from the line's left edge and its baseline) and its source in the
/// sheet — the line at any size is this, scaled. Built at most once per
/// line, sheet size and measure, and shared by every page that shows it
/// (see [_geometryOf]); what a line looks like (colours, hidden words,
/// marks) is laid over it per paint, never by redoing it.
class AtlasGeometry {
  final int tier;

  /// Font units: the line's width and the extra in each space.
  final double width, gapExtra;

  /// Each token's left and right edge, font units.
  final Float32List left, right;

  /// Per sheet: transforms, source rects, and each sprite's token and glyph
  /// (within its word: tajwīd colours it).
  final List<(int sheet, Float32List xforms, Float32List rects, Int32List token, Int32List glyph)>
      batches;

  /// The traced āyah circles (their own sprite) and the discs filling their
  /// holes, each with its token.
  final (ui.Image, Float32List, Float32List, Int32List)? circles;
  final List<(Offset, double, int)> discs;

  const AtlasGeometry(this.tier, this.width, this.gapExtra, this.left,
      this.right, this.batches, this.circles, this.discs);
}

/// Lines' geometry, most recently used last: a page swiped back, a resized
/// window or a tool turned on finds its lines here.
final LinkedHashMap<String, AtlasGeometry> _geometry = LinkedHashMap();
const _geometryCap = 900;

/// Builds (or finds) [s]'s geometry at [tier].
AtlasGeometry _geometryOf(MushafLineSpec s, MushafAtlas atlas, int tier) {
  final l = s.line;
  final n = l.words.length;
  final t0 = l.firstTok;
  final tokenWord = atlas.tokenWord, tokenGap = atlas.tokenGap;
  final wordAdvance = atlas.wordAdvance;
  int gapAfter(int tok) {
    final g = tokenGap[tok];
    return g == 0 && s.rewrap ? atlas.space : g;
  }

  var natural = 0.0;
  for (var i = 0; i < n; i++) {
    natural += wordAdvance[tokenWord[t0 + i]];
    if (i < n - 1) natural += gapAfter(t0 + i);
  }
  final k = s.fontSize / atlas.upem;
  final spaces = n - 1;
  final justified = s.justify &&
      natural * k >= s.targetW * (atlas.justified ? 0.97 : 0.45) &&
      spaces > 0;
  // The measure in font units (to the unit: a pixel's fraction).
  final measure = justified ? (s.targetW / k).round() : -1;
  final key = '${identityHashCode(atlas)}|$t0|$n|$tier|${s.rewrap}|$measure|'
      '${s.ornament == null ? '' : '${s.markerArt}/${s.markerScale}/${s.markerDy}'}';
  final hit = _geometry.remove(key);
  if (hit != null) return _geometry[key] = hit;

  final gapExtra = justified ? ((measure - natural) / spaces).clamp(0.0, 1e9) : 0.0;
  final width = natural + gapExtra * (spaces < 0 ? 0 : spaces);
  final t = atlas.tiers[tier];
  final wordStart = atlas.wordGlyphStart;
  final glyphId = atlas.glyphId, sheetOf = t.sheet;
  final ornament = s.ornament;
  int circleOf(int i) => ornament != null && l.words[i].isMarker
      ? wordStart[tokenWord[t0 + i]]
      : -1;
  final perSheet = List<int>.filled(t.sheetCount, 0);
  for (var i = 0; i < n; i++) {
    final w = tokenWord[t0 + i];
    final circle = circleOf(i);
    for (var g = wordStart[w]; g < wordStart[w + 1]; g++) {
      if (g == circle) continue;
      final sh = sheetOf[glyphId[g]];
      if (sh != 255) perSheet[sh]++;
    }
  }
  final xforms = [for (final c in perSheet) Float32List(c * 4)];
  final rects = [for (final c in perSheet) Float32List(c * 4)];
  final tokens = [for (final c in perSheet) Int32List(c)];
  final glyphs = [for (final c in perSheet) Int32List(c)];
  final fill = List<int>.filled(t.sheetCount, 0);
  // A sheet's pixels in font units.
  final scale = atlas.upem / t.em;
  final gx = atlas.glyphX, gy = atlas.glyphY;
  final sx = t.x, sy = t.y, sw = t.w, shh = t.h, bl = t.left, bt = t.top;
  final lefts = Float32List(n), rights = Float32List(n);
  ui.Image? circleImg;
  final circleXf = <double>[], circleRc = <double>[], circleTok = <int>[];
  final discs = <(Offset, double, int)>[];
  final cc = ClassicCircle.of(s.markerArt);
  var x = width;
  for (var i = 0; i < n; i++) {
    final tok = t0 + i;
    final w = tokenWord[tok];
    final left = x - wordAdvance[w];
    lefts[i] = left;
    rights[i] = x;
    final g0 = wordStart[w], g1 = wordStart[w + 1];
    final circle = circleOf(i);
    if (circle >= 0) {
      // The traced circle, its ring over the font circle's (the number
      // sits in both alike).
      final a = glyphId[circle];
      final img = circleImg ??= cc.sprite(
          (shh[a] * s.markerScale / cc.ringDiameter).round().clamp(4, 1024));
      final dh = (img.height - 2) * scale, dw = (img.width - 2) * scale;
      final cx = left + gx[circle] + bl[a] * scale + sw[a] * scale / 2;
      final cy = -gy[circle] - bt[a] * scale + shh[a] * scale / 2;
      final x0 = cx - dw * cc.holeCentre.dx,
          y0 = cy - dh * (cc.ringCentreY - s.markerDy);
      circleXf.addAll([scale, 0, x0 - scale, y0 - scale]);
      discs.add((
        Offset(x0 + dw * cc.holeCentre.dx, y0 + dh * cc.holeCentre.dy),
        dh * cc.holeDiameter / 2,
        i,
      ));
      circleRc.addAll([0, 0, img.width.toDouble(), img.height.toDouble()]);
      circleTok.add(i);
    }
    for (var g = g0; g < g1; g++) {
      if (g == circle) continue;
      final a = glyphId[g];
      final sheet = sheetOf[a];
      if (sheet == 255) continue;
      final f = fill[sheet]++;
      final xf = xforms[sheet], rc = rects[sheet];
      xf[f * 4] = scale;
      xf[f * 4 + 1] = 0;
      xf[f * 4 + 2] = left + gx[g] + bl[a] * scale;
      xf[f * 4 + 3] = -gy[g] - bt[a] * scale;
      final ax = sx[a].toDouble(), ay = sy[a].toDouble();
      rc[f * 4] = ax;
      rc[f * 4 + 1] = ay;
      rc[f * 4 + 2] = ax + sw[a];
      rc[f * 4 + 3] = ay + shh[a];
      tokens[sheet][f] = i;
      glyphs[sheet][f] = g - g0;
    }
    x = left - (i < n - 1 ? gapAfter(tok) + gapExtra : 0);
  }
  final geo = AtlasGeometry(
    tier,
    width,
    gapExtra,
    lefts,
    rights,
    [
      for (var sh = 0; sh < perSheet.length; sh++)
        if (perSheet[sh] > 0) (sh, xforms[sh], rects[sh], tokens[sh], glyphs[sh]),
    ],
    circleImg == null
        ? null
        : (
            circleImg,
            Float32List.fromList(circleXf),
            Float32List.fromList(circleRc),
            Int32List.fromList(circleTok),
          ),
    discs,
  );
  while (_geometry.length >= _geometryCap) {
    _geometry.remove(_geometry.keys.first);
  }
  return _geometry[key] = geo;
}

/// A line drawn from the glyph atlas: its [geometry] (shared, font units)
/// at this size, and its look — each sprite's colour, the highlights behind
/// the words, the marks under them.
class AtlasLine implements MushafLineLayout {
  final AtlasGeometry geometry;

  /// Font units → pixels.
  final double k;
  @override
  final double width, height, baseline, gapExtra;
  @override
  final List<(double, double)> boxes;
  @override
  final List<(double, double, MarkVisual)> markLines;
  @override
  final List<(double, double)> focusBoxes;
  final List<(double left, double right, Color c)> backgrounds;

  /// Each sprite's colour, per batch of [geometry]; the circles' too.
  final List<Int32List> colors;
  final Int32List? circleColors;

  /// Which tokens are hidden (memorize): their circles' discs aren't drawn.
  final List<bool> hidden;

  /// Each token's colour as drawn (tests).
  @visibleForTesting
  final List<Color> tokenColors;

  /// Each glyph's colour, per token (tests: tajwīd colours letters; debug
  /// builds only).
  @visibleForTesting
  final List<List<Color>> glyphColors;

  const AtlasLine(
    this.geometry,
    this.k,
    this.width,
    this.height,
    this.baseline,
    this.gapExtra,
    this.boxes,
    this.markLines,
    this.backgrounds,
    this.colors,
    this.circleColors,
    this.hidden,
    this.tokenColors,
    this.glyphColors, [
    this.focusBoxes = const [],
  ]);

  int get tier => geometry.tier;

  /// Per sheet: transforms (font units), rects, colours (tests count them).
  List<(int, Float32List, Float32List, Int32List)> get batches => [
        for (final (i, b) in geometry.batches.indexed) (b.$1, b.$2, b.$3, colors[i]),
      ];
}

/// [s] from [atlas] at [tier]: its geometry (built once, shared — see
/// [AtlasGeometry]), and the look [s] asks for — colours, highlights and
/// marks — which is all that changes from one tick, mark or setting to the
/// next. Justified as the text path is (spaces widen once a line reaches
/// 45% of the measure; a pre-justified atlas, 97%).
AtlasLine buildAtlasLine(MushafLineSpec s, MushafAtlas atlas, int tier) {
  final geo = _geometryOf(s, atlas, tier);
  final l = s.line;
  final n = l.words.length;
  final t0 = l.firstTok;
  final k = s.fontSize / atlas.upem;
  final asc = atlas.ascender * k, desc = -atlas.descender * k;
  // As a TextPainter with height slotH/fs and even leading would place it.
  final baseline = (s.slotH - (asc + desc)) / 2 + asc;
  final pairs = atlas.tajwidPairs, tjStart = atlas.tajwidStart;
  final tj = s.tajwid;
  final mp = s.markPal;
  final boxes = <(double, double)>[];
  final backgrounds = <(double, double, Color)>[];
  final marked = <(double, double, MarkVisual)>[];
  final focused = <(double, double)>[];
  final tokenColors = <Color>[];
  final hidden = List<bool>.filled(n, false);
  // Each token's ink, and whether tajwīd colours its letters.
  final base = Int32List(n);
  final tajwid = List<bool>.filled(n, false);
  for (var i = 0; i < n; i++) {
    final wd = l.words[i];
    final left = geo.left[i] * k, right = geo.right[i] * k;
    boxes.add((left, right));
    if (s.isHidden(i)) {
      hidden[i] = true;
      tokenColors.add(const Color(0x00000000));
      continue;
    }
    final st = s.stateAt(i);
    final mv = s.marks.isEmpty || mp == null
        ? null
        : s.marks[WordRef.fromGlobal(wd.ayah, wd.isMarker ? -1 : wd.wordIdx).key];
    final f = s.isFocus(wd);
    if (f) focused.add((left, right));
    final over = st == 1 || f ? s.strongBg : (st == 2 ? s.verseBg : null);
    final tint = mv == null || mv.open == null ? null : mp!.tintOf(mv.open!);
    final bg = over ?? tint;
    if (bg != null) backgrounds.add((left, right, bg));
    if (mv != null && right > left) marked.add((left, right, mv));
    final c = st == 1 ? s.accent : s.ink;
    base[i] = c.toARGB32();
    tokenColors.add(c);
    // Tajwīd rules colour single glyphs (not the word being recited).
    tajwid[i] = tj != null && st != 1;
  }
  // Each sprite's colour: its token's ink, a tajwīd rule's on its letters,
  // nothing (transparent) for a hidden word.
  int colourOf(int i, int glyph) {
    if (hidden[i]) return 0;
    var argb = base[i];
    if (tajwid[i]) {
      final tok = t0 + i;
      for (var p = tjStart[tok]; p < tjStart[tok + 1]; p++) {
        if (pairs[p * 2] == glyph) {
          final r = pairs[p * 2 + 1];
          if (r < tj!.length) argb = tj[r].toARGB32();
          break;
        }
        if (pairs[p * 2] > glyph) break;
      }
    }
    return argb;
  }

  final colors = <Int32List>[];
  for (final (_, _, _, tokens, glyphs) in geo.batches) {
    final c = Int32List(tokens.length);
    for (var f = 0; f < tokens.length; f++) {
      c[f] = colourOf(tokens[f], glyphs[f]);
    }
    colors.add(c);
  }
  final circleTok = geo.circles?.$4;
  final circleColors = circleTok == null
      ? null
      : Int32List.fromList([
          for (final i in circleTok)
            hidden[i] ? 0 : (s.stateAt(i) == 1 ? s.accent : s.ornament!).toARGB32(),
        ]);
  // Each glyph's colour, per token, in the word's order (tests).
  final glyphColors = <List<Color>>[];
  if (kDebugMode) {
    final wordStart = atlas.wordGlyphStart, tokenWord = atlas.tokenWord;
    for (var i = 0; i < n; i++) {
      final w = tokenWord[t0 + i];
      glyphColors.add(hidden[i]
          ? const []
          : [
              for (var g = 0; g < wordStart[w + 1] - wordStart[w]; g++)
                Color(colourOf(i, g)),
            ]);
    }
  }
  return AtlasLine(
    geo,
    k,
    geo.width * k,
    s.slotH,
    baseline,
    geo.gapExtra * k,
    boxes,
    marked,
    backgrounds,
    colors,
    circleColors,
    hidden,
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
  final justified = s.justify && natural >= s.targetW * 0.45 && spaces > 0;
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
    final st = s.stateAt(i);
    final mp = s.markPal;
    final mv = s.marks.isEmpty || mp == null
        ? null
        : s.marks[WordRef.fromGlobal(
            wd.ayah,
            wd.isMarker ? -1 : wd.wordIdx,
          ).key];
    final hidden = s.isHidden(i);
    final f = !hidden && s.isFocus(wd);
    if (f) focusAt = i;
    final over = hidden
        ? null
        : (st == 1 || f ? s.strongBg : (st == 2 ? s.verseBg : null));
    final color = hidden
        ? const Color(0x00000000)
        : (st == 1 ? s.accent : s.ink);
    final style = hidden
        ? base.copyWith(color: color)
        : mv == null
        ? (st == 0 && !f
            ? base
            : base.copyWith(color: color, backgroundColor: over))
        : markSpanStyle(base.copyWith(color: color), mv, mp!, overBg: over);
    ranges.add((chars, chars + wd.text.length));
    if (mv != null && !hidden) marked.add((i, mv));
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

  /// Holding an āyah's ۝ (the whole āyah: its marks sheet); unset, a hold
  /// is a tap.
  void Function(MushafWord marker)? onLongPressVerse;
}

/// A muṣḥaf text line, painted from its cached shape.
class MushafLineView extends LeafRenderObjectWidget {
  final MushafLineSpec spec;
  final MushafTapHandlers handlers;

  /// Where the line's marks come from as they change (the muṣḥaf's pages):
  /// the line repaints itself from it, without a rebuild. Null: [spec]'s.
  final MushafMarksSource? marks;
  const MushafLineView(
      {super.key, required this.spec, required this.handlers, this.marks});

  @override
  RenderMushafLine createRenderObject(BuildContext context) =>
      RenderMushafLine(spec, handlers)
        ..marksSource = marks
        ..devicePixelRatio = View.maybeOf(context)?.devicePixelRatio ?? 1;

  @override
  void updateRenderObject(BuildContext context, RenderMushafLine renderObject) {
    renderObject
      ..marksSource = marks
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

  /// Paints made, for the tests' budgets.
  @visibleForTesting
  static int debugPaints = 0;

  // ── marks that change under the line ──

  MushafMarksSource? _marks;
  Listenable? _marksSignal;
  set marksSource(MushafMarksSource? v) {
    if (identical(v, _marks)) return;
    _unlisten();
    _marks = v;
    if (attached) _listen();
  }

  void _listen() {
    final m = _marks;
    if (m == null) return;
    _marksSignal = m.pageSignal(_spec.page)..addListener(_marksChanged);
  }

  void _unlisten() {
    _marksSignal?.removeListener(_marksChanged);
    _marksSignal = null;
  }

  void _marksChanged() {
    final m = _marks;
    if (m == null) return;
    spec = _spec.withMarks(m.visuals);
    // Fluency marks are painted over the line, not part of its spec.
    if (m.fluency.isNotEmpty || _hadFluency) markNeedsPaint();
  }

  bool _hadFluency = false;

  /// The Reader's fluency marks on this line's words (see fluency_style).
  void _paintFluency(Canvas canvas, Offset offset) {
    final f = _marks?.fluency ?? const <int, FluencyVisual>{};
    _hadFluency = false;
    if (f.isEmpty) return;
    final words = _spec.line.words;
    final colour = fluencyColor(dark: _spec.ink.computeLuminance() > .5);
    // A pair's second word on this line: one bridge, drawn by the first.
    final endDrawn = <int>{};
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isMarker) continue;
      final v = f[WordRef.fromGlobal(w.ayah, w.wordIdx).key];
      if (v == null) continue;
      final r = wordRect(i);
      if (r == null) continue;
      _hadFluency = true;
      Rect? to;
      if (v.pairStart) {
        var j = i + 1;
        while (j < words.length && words[j].isMarker) {
          j++;
        }
        if (j < words.length) {
          to = wordRect(j)?.shift(offset);
          if (to != null) endDrawn.add(j);
        }
      }
      paintFluency(canvas, r.shift(offset), v,
          fs: _spec.fontSize, color: colour, pairTo: to, endDrawn: endDrawn.contains(i));
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  MushafLineSpec get spec => _spec;
  set spec(MushafLineSpec v) {
    // The marks always as they are now (the widget's may be older).
    if (_marks != null) v = v.withMarks(_marks!.visuals);
    if (v.page != _spec.page && _marksSignal != null) {
      _unlisten();
      _marksSignal = _marks!.pageSignal(v.page)..addListener(_marksChanged);
    }
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

  /// Where word [i] of the line is drawn, in this line's coordinates (the
  /// page export leads its notes from it); null before it's laid out.
  Rect? wordRect(int i) {
    final l = laidLine;
    if (l == null || i < 0 || i >= l.boxes.length) return null;
    final o = textOffset;
    final (left, right) = l.boxes[i];
    return Rect.fromLTWH(o.dx + left, o.dy, right - left, l.height);
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
    paintAtlasLine(canvas, offset + textOffset, l, atlas, _spec);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (kDebugMode) debugPaints++;
    final atlas = _atlas;
    if (atlas != null) {
      _paintAtlas(context.canvas, offset, atlas);
      _paintFluency(context.canvas, offset);
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
    paintLineMarks(context.canvas, o, l, _spec);
    paintLineFocus(context.canvas, o, l, _spec);
    _paintFluency(context.canvas, offset);
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
      final hold = handlers.onLongPressVerse;
      long && hold != null ? hold(wd) : handlers.onTapVerse?.call(wd.ayah);
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

/// Draws an atlas line at [o]: its highlights, its glyphs (one
/// `drawRawAtlas` per sheet), its mark lines and focus outline. Shared by
/// the muṣḥaf's lines and anything that paints them elsewhere (the PDF
/// report's verse images).
void paintAtlasLine(Canvas canvas, Offset o, AtlasLine l, MushafAtlas atlas,
    MushafLineSpec spec) {
  for (final (left, right, c) in l.backgrounds) {
    canvas.drawRect(
      Rect.fromLTWH(o.dx + left, o.dy, right - left, l.height),
      Paint()..color = c,
    );
  }
  final geo = l.geometry;
  final images = atlas.tiers[l.tier].images;
  // The sprites in font units, from the baseline: scaled to this size.
  canvas.save();
  canvas.translate(o.dx, o.dy + l.baseline);
  canvas.scale(l.k);
  if (geo.discs.isNotEmpty && spec.ornamentFill != null) {
    final fill = Paint()..color = spec.ornamentFill!;
    for (final (c, r, i) in geo.discs) {
      if (!l.hidden[i]) canvas.drawCircle(c, r + .5 / l.k, fill);
    }
  }
  if (images != null) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final (b, (sheet, xf, rects, _, _)) in geo.batches.indexed) {
      // Each sprite is a white glyph; modulate takes its colour.
      canvas.drawRawAtlas(
          images[sheet], xf, rects, l.colors[b], BlendMode.modulate, null, paint);
    }
    if (geo.circles case (final img, final xf, final rects, _)) {
      canvas.drawRawAtlas(
          img, xf, rects, l.circleColors, BlendMode.modulate, null, paint);
    }
  }
  canvas.restore();
  paintLineMarks(canvas, o, l, spec);
  paintLineFocus(canvas, o, l, spec);
}

/// The focused word's outline: a rounded box in the accent colour.
void paintLineFocus(
    Canvas canvas, Offset o, MushafLineLayout l, MushafLineSpec spec) {
  if (l.focusBoxes.isEmpty) return;
  final w = (spec.fontSize * .07).clamp(1.5, 3.0);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = spec.accent;
  for (final (left, right) in l.focusBoxes) {
    if (right <= left) continue;
    final r = Rect.fromLTRB(o.dx + left - w, o.dy + w / 2, o.dx + right + w,
        o.dy + l.height - w / 2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(spec.fontSize * .25)),
        paint);
  }
}

/// The marked words' pattern lines, under the words.
void paintLineMarks(
    Canvas canvas, Offset o, MushafLineLayout l, MushafLineSpec spec) {
  final pal = spec.markPal;
  if (l.markLines.isEmpty || pal == null) return;
  final fs = spec.fontSize;
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
