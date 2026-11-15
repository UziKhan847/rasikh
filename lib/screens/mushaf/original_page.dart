import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart' show MouseCursor, MouseTrackerAnnotation, PointerEnterEventListener, PointerExitEventListener, SystemMouseCursors;
import 'package:flutter/widgets.dart';

import '../../core/fluency/fluency_store.dart' show FluencyVisual;
import '../../core/marks/marks_model.dart';
import '../../core/marks/word_ref.dart';
import '../../core/perf_log.dart';
import '../../core/tap_longpress.dart';
import '../../data/mushaf.dart';
import '../../data/original/original_atlas.dart';
import '../../ui/fluency_style.dart';
import '../../ui/mark_style.dart';
import 'mushaf_line.dart' show MushafLineSpec, MushafTapHandlers, RenderMushafLine;
import 'mushaf_marks_layer.dart';

/// What a printed page looks like now.
@immutable
class OriginalPageSpec {
  final OriginalAtlas atlas;
  final int page;
  final Color ink, ornament, accent, strongBg, verseBg;
  final int playAyah, playWord;
  final bool reciting;
  final MarkPalette? markPal;
  final int focus, hideFrom;

  /// Laid out to the full width: as tall as that makes it (the page scrolls).
  final bool fitWidth;

  /// The classic āyah circle, not the print's own.
  final bool classicCircle;
  const OriginalPageSpec({
    required this.atlas,
    required this.page,
    required this.ink,
    required this.ornament,
    required this.accent,
    required this.strongBg,
    required this.verseBg,
    this.playAyah = -1,
    this.playWord = -1,
    this.reciting = false,
    this.markPal,
    this.focus = -1,
    this.hideFrom = -1,
    this.fitWidth = false,
    this.classicCircle = false,
  });

  @override
  bool operator ==(Object other) =>
      other is OriginalPageSpec &&
      identical(other.atlas, atlas) &&
      other.page == page &&
      other.ink == ink &&
      other.ornament == ornament &&
      other.accent == accent &&
      other.strongBg == strongBg &&
      other.verseBg == verseBg &&
      other.playAyah == playAyah &&
      other.playWord == playWord &&
      other.reciting == reciting &&
      other.markPal == markPal &&
      other.focus == focus &&
      other.hideFrom == hideFrom &&
      other.fitWidth == fitWidth &&
      other.classicCircle == classicCircle;

  @override
  int get hashCode => Object.hash(atlas, page, ink, ornament, accent, strongBg,
      verseBg, playAyah, playWord, reciting, markPal, focus, hideFrom, fitWidth, classicCircle);
}

/// A muṣḥaf page drawn from the print's own atlases: two `drawRawAtlas` calls,
/// the page's sprites and the shapes shared across the book. Every page shares
/// one scale and one grid of lines, as a printed book does; spare height
/// spreads the lines. It asks for its image at paint time and never keeps it:
/// the window may dispose it at any swipe (see [PageImageWindow]).
class OriginalPageView extends LeafRenderObjectWidget {
  final OriginalPageSpec spec;
  final MushafTapHandlers handlers;
  final MushafMarksSource? marks;
  const OriginalPageView(
      {super.key, required this.spec, required this.handlers, this.marks});

  @override
  RenderOriginalPage createRenderObject(BuildContext context) =>
      RenderOriginalPage(spec, handlers)
        ..marksSource = marks
        ..devicePixelRatio = View.maybeOf(context)?.devicePixelRatio ?? 1;

  @override
  void updateRenderObject(BuildContext context, RenderOriginalPage renderObject) {
    renderObject
      ..marksSource = marks
      ..spec = spec
      ..handlers = handlers
      ..devicePixelRatio = View.maybeOf(context)?.devicePixelRatio ?? 1;
  }
}

class RenderOriginalPage extends RenderBox implements MouseTrackerAnnotation {
  RenderOriginalPage(this._spec, this.handlers);

  // ── the mouse: the word under it is lit, and shows it can be clicked ──

  int? _hover;

  void _setHover(int? t) {
    if (t == _hover) return;
    _hover = t;
    markNeedsPaint();
  }

  @override
  MouseCursor get cursor => SystemMouseCursors.click;
  @override
  PointerEnterEventListener? get onEnter => null;
  @override
  PointerExitEventListener? get onExit => (_) => _setHover(null);
  @override
  bool get validForMouseTracker => attached;

  /// How far lines may spread to fill the height, of their pitch.
  static const _maxSpread = .25;

  OriginalPageSpec _spec;
  MushafTapHandlers handlers;
  double devicePixelRatio = 1;

  OriginalPageSpec get spec => _spec;
  set spec(OriginalPageSpec v) {
    if (v == _spec) return;
    final old = _spec;
    if (attached && (v.page != old.page || !identical(v.atlas, old.atlas))) {
      _unlistenPage();
      _spec = v;
      _listenPage();
    } else {
      _spec = v;
    }
    _pageColors = _sharedColors = null;
    if (v.page != old.page ||
        !identical(v.atlas, old.atlas) ||
        v.fitWidth != old.fitWidth ||
        v.classicCircle != old.classicCircle) {
      _xforms = null;
      markNeedsLayout();
      markNeedsSemanticsUpdate();
    } else {
      markNeedsPaint();
    }
  }

  OriginalPageData get _data =>
      _spec.atlas.dataOf(_spec.page, classic: _spec.classicCircle);

  // ── what it listens to ──

  Listenable? _imageSignal, _marksSignal;
  MushafMarksSource? _marks;

  set marksSource(MushafMarksSource? v) {
    if (identical(v, _marks)) return;
    _unlistenPage();
    _marks = v;
    if (attached) _listenPage();
    markNeedsPaint();
  }

  void _listenPage() {
    _imageSignal = _spec.atlas.window.signal(_spec.page)..addListener(markNeedsPaint);
    _marksSignal = _marks?.pageSignal(_spec.page)?..addListener(markNeedsPaint);
  }

  void _unlistenPage() {
    _imageSignal?.removeListener(markNeedsPaint);
    _marksSignal?.removeListener(markNeedsPaint);
    _imageSignal = _marksSignal = null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listenPage();
  }

  @override
  void detach() {
    _unlistenPage();
    super.detach();
  }

  // ── layout ──

  /// Page pixels → this box: the scale, the block's top-left, and how much
  /// each line adds in page pixels.
  double _s = 1, _ox = 0, _oy = 0, _extra = 0;
  Float32List? _xforms, _sharedXforms;

  @override
  void performLayout() {
    final d = _data;
    final w = constraints.maxWidth;
    final full = 15 * d.pitch;
    final double h;
    if (_spec.fitWidth || !constraints.hasBoundedHeight) {
      _s = w / d.blockW;
      h = full * _s;
    } else {
      h = constraints.maxHeight;
      final byW = w / d.blockW, byH = h / full;
      _s = byW < byH ? byW : byH;
    }
    size = constraints.constrain(Size(w, h));
    final spare = size.height / _s - full;
    _extra = d.opening || spare <= 0
        ? 0
        : (spare / 15).clamp(0.0, d.pitch * _maxSpread);
    _ox = (size.width - d.blockW * _s) / 2;
    _oy = (size.height - (full + 15 * _extra) * _s) / 2;
    _buildXforms(d);
  }

  double _lineShift(int row) => (row + .5) * _extra;

  void _buildXforms(OriginalPageData d) {
    final n = d.pageX.length, m = d.sharedX.length;
    final a = _xforms = Float32List(n * 4);
    for (var i = 0; i < n; i++) {
      a
        ..[i * 4] = 1
        ..[i * 4 + 2] = d.pageX[i]
        ..[i * 4 + 3] = d.pageY[i] + _lineShift(d.pageRow[i]);
    }
    final b = _sharedXforms = Float32List(m * 4);
    for (var i = 0; i < m; i++) {
      b
        ..[i * 4] = d.sharedScale[i]
        ..[i * 4 + 2] = d.sharedX[i]
        ..[i * 4 + 3] = d.sharedY[i] + _lineShift(d.sharedRow[i]);
    }
  }

  // ── where things are ──

  double _rowH(OriginalPageData d) => d.opening
      ? (d.rowCentres.length > 1 ? d.rowCentres[1] - d.rowCentres[0] : d.pitch)
      : d.pitch + _extra;

  /// Token [t]'s box here: its width, its line's height.
  Rect? tokenRect(int t) {
    final d = _data;
    final b = d.tokens[t];
    if (b == null) return null;
    final rowH = _rowH(d);
    final cy = d.rowCentres[b.row] + _lineShift(b.row);
    return Rect.fromLTRB(_ox + b.left * _s, _oy + (cy - rowH / 2) * _s,
        _ox + b.right * _s, _oy + (cy + rowH / 2) * _s);
  }

  /// Where each word on the page is drawn (the page export leads its notes
  /// from it): (global āyah, word index; -1 for the ۝) → its box here.
  Map<(int, int), Rect> get wordRects => {
        for (final t in _data.order)
          if (_wordAt(t) case final w?) (w.ayah, w.wordIdx): ?tokenRect(t),
      };

  /// The script's word for token [t].
  MushafWord? _wordAt(int t) => MushafRepo.wordAtToken(_spec.atlas.script, t);

  /// The token under [p], if any: an āyah marker's target reaches into the
  /// gaps around it; a word's covers its own box.
  /// The word at [local] (a point on this page), if any.
  MushafWord? wordAtLocal(Offset local) {
    final t = tokenAt(local);
    return t == null ? null : _wordAt(t);
  }

  int? tokenAt(Offset p) {
    final d = _data;
    final y = (p.dy - _oy) / _s;
    var row = 0;
    var best = double.infinity;
    for (var i = 0; i < d.rowCentres.length; i++) {
      final e = (d.rowCentres[i] + _lineShift(i) - y).abs();
      if (e < best) {
        best = e;
        row = i;
      }
    }
    final inLine = d.rowTokens[row];
    if (inLine == null) return null;
    final x = (p.dx - _ox) / _s;
    final pad = 8 / _s;
    for (final t in inLine) {
      if (_wordAt(t)?.isMarker != true) continue;
      final b = d.tokens[t]!;
      if (x >= b.left - pad && x <= b.right + pad) return t;
    }
    for (final t in inLine) {
      final b = d.tokens[t]!;
      if (x >= b.left && x <= b.right) return t;
    }
    return null;
  }

  // ── paint ──

  Int32List? _pageColors, _sharedColors;

  int _colourOf(int token, int base) {
    final s = _spec;
    if (token >= 0) {
      if (s.hideFrom >= 0 && token >= s.hideFrom) return 0;
      final w = _wordAt(token);
      if (w != null &&
          MushafLineSpec.tokenState(w, s.playAyah, s.playWord, s.reciting) == 1) {
        return s.accent.toARGB32();
      }
    }
    return base;
  }

  void _buildColours(OriginalPageData d) {
    final ink = _spec.ink.toARGB32(), ornament = _spec.ornament.toARGB32();
    _pageColors = Int32List.fromList(
        [for (final t in d.pageToken) _colourOf(t, ink)]);
    _sharedColors = Int32List.fromList([
      for (var i = 0; i < d.sharedToken.length; i++)
        _colourOf(d.sharedToken[i], d.sharedOrnament[i] == 1 ? ornament : ink),
    ]);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final d = _data;
    final s = _spec;
    final marks = _marks?.visuals ?? const <int, MarkVisual>{};
    final mp = s.markPal;

    if (_hover case final h?) {
      final r = tokenRect(h);
      if (r != null) {
        canvas.drawRRect(RRect.fromRectAndRadius(r.shift(offset), const Radius.circular(4)),
            Paint()..color = s.ink.withValues(alpha: .07));
      }
    }
    // Behind the words: the recited āyah, the word, the marks' tints.
    for (final t in d.order) {
      final w = _wordAt(t);
      if (w == null) continue;
      if (s.hideFrom >= 0 && t >= s.hideFrom) continue;
      final key = WordRef.fromGlobal(w.ayah, w.isMarker ? -1 : w.wordIdx).key;
      final st = MushafLineSpec.tokenState(w, s.playAyah, s.playWord, s.reciting);
      final mv = marks[key];
      final over = st == 1 || key == s.focus ? s.strongBg : (st == 2 ? s.verseBg : null);
      final bg = over ?? (mv?.open == null || mp == null ? null : mp.tintOf(mv!.open!));
      if (bg != null) {
        canvas.drawRect(tokenRect(t)!.shift(offset), Paint()..color = bg);
      }
    }

    if (_pageColors == null) _buildColours(d);
    final page = s.atlas.window.imageOf(s.page);
    final shared = s.atlas.shared;
    canvas.save();
    canvas.translate(offset.dx + _ox, offset.dy + _oy);
    canvas.scale(_s);
    // Bilinear holds down to about half size; past that, the mipmaps.
    final paint = Paint()
      ..filterQuality = _s * devicePixelRatio < .6 ? FilterQuality.medium : FilterQuality.low;
    if (page == null) {
      // On screen with no image (the window was behind): next in line. Should
      // be rare: the profile log counts them.
      if (kMushafPerf) PerfLog.log('old madani p.${s.page} painted without its image');
      final atlas = s.atlas, n = s.page;
      SchedulerBinding.instance.addPostFrameCallback((_) => atlas.window.ask(n));
    }
    if (page != null) {
      canvas.drawRawAtlas(page, _xforms!, d.pageRects, _pageColors, OriginalAtlas.atlasBlend, null, paint);
    }
    if (shared != null) {
      canvas.drawRawAtlas(shared, _sharedXforms!, d.sharedRects, _sharedColors, OriginalAtlas.atlasBlend, null, paint);
    }
    canvas.restore();

    final fs = d.pitch * _s / 1.8;
    _paintMarks(canvas, offset, d, marks, fs);
    _paintFocus(canvas, offset, fs);
    _paintFluency(canvas, offset, d, fs);
  }

  void _paintMarks(Canvas canvas, Offset o, OriginalPageData d,
      Map<int, MarkVisual> marks, double fs) {
    final mp = _spec.markPal;
    if (marks.isEmpty || mp == null) return;
    final t = (fs * .065).clamp(1.2, 3.0);
    for (final token in d.order) {
      final w = _wordAt(token);
      if (w == null) continue;
      if (_spec.hideFrom >= 0 && token >= _spec.hideFrom) continue;
      final v = marks[WordRef.fromGlobal(w.ayah, w.isMarker ? -1 : w.wordIdx).key];
      if (v == null) continue;
      final r = tokenRect(token)!.shift(o);
      final inset = (r.width * .06).clamp(1.0, 4.0);
      // Under the kasrahs, above the next line's tallest marks.
      paintMarkLine(canvas, Offset(r.left + inset, r.center.dy + d.pitch * _s * .43),
          r.width - inset * 2, v, mp, thickness: t);
      paintBreathSigns(canvas, v, mp,
          left: r.left,
          right: r.right,
          top: r.center.dy - d.pitch * _s * .5,
          size: (fs * .42).clamp(8.0, 26.0));
    }
  }

  void _paintFocus(Canvas canvas, Offset o, double fs) {
    final f = _spec.focus;
    if (f < 0) return;
    final ref = WordRef.fromKey(f);
    final t = MushafRepo.tokenOf(_spec.atlas.script, ref.globalAyah, ref.word0);
    final r = tokenRect(t);
    if (r == null) return;
    final w = (fs * .07).clamp(1.5, 3.0);
    canvas.drawRRect(
        RRect.fromRectAndRadius(r.shift(o).inflate(w), Radius.circular(fs * .25)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = _spec.accent);
  }

  void _paintFluency(Canvas canvas, Offset o, OriginalPageData d, double fs) {
    final f = _marks?.fluency ?? const <int, FluencyVisual>{};
    if (f.isEmpty) return;
    final colour = fluencyColor(dark: _spec.ink.computeLuminance() > .5);
    final endDrawn = <int>{};
    for (final (i, t) in d.order.indexed) {
      final w = _wordAt(t);
      if (w == null || w.isMarker) continue;
      final v = f[WordRef.fromGlobal(w.ayah, w.wordIdx).key];
      if (v == null) continue;
      final r = tokenRect(t);
      if (r == null) continue;
      Rect? to;
      if (v.pairStart) {
        var j = i + 1;
        while (j < d.order.length && _wordAt(d.order[j])?.isMarker == true) {
          j++;
        }
        if (j < d.order.length) {
          final next = tokenRect(d.order[j]);
          // The pair's join only along one line.
          if (next != null && (next.center.dy - r.center.dy).abs() < r.height / 2) {
            to = next.shift(o);
            endDrawn.add(d.order[j]);
          }
        }
      }
      paintFluency(canvas, r.shift(o), v,
          fs: fs, color: colour, pairTo: to, endDrawn: endDrawn.contains(t));
    }
  }

  // ── taps ──

  TapAndLongPressGestureRecognizer? _recognizer;
  int? _down;

  @override
  bool hitTestSelf(Offset position) => tokenAt(position) != null;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerHoverEvent) return _setHover(tokenAt(event.localPosition));
    if (event is! PointerDownEvent) return;
    _down = tokenAt(event.localPosition);
    if (_down == null) return;
    final mouseWd = event.kind == PointerDeviceKind.mouse ? _wordAt(_down!) : null;
    if (mouseWd != null &&
        (handlers.onMouseWord?.call(mouseWd, event.buttons, event.position) ?? false)) {
      return;
    }
    (_recognizer ??= TapAndLongPressGestureRecognizer(
      onTap: () => _fire(long: false),
      onLongPress: () => _fire(long: true),
    )).addPointer(event);
  }

  void _fire({required bool long}) {
    final t = _down;
    if (t == null) return;
    final wd = _wordAt(t);
    if (wd == null) return;
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

  // ── accessibility: the page reads as its text ──

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final words = [
      for (final t in _data.order)
        if (_wordAt(t) case final w? when !w.isMarker) w.text,
    ];
    config
      ..label = words.join(' ')
      ..textDirection = TextDirection.rtl;
  }
}

/// The muṣḥaf word under [global] (a point on the screen), on a typeset
/// line or a printed page; null if none.
MushafWord? mushafWordAtGlobal(Offset global) {
  final binding = WidgetsBinding.instance;
  final view = binding.platformDispatcher.implicitView ?? binding.platformDispatcher.views.first;
  final result = HitTestResult();
  binding.hitTestInView(result, global, view.viewId);
  for (final e in result.path) {
    final t = e.target;
    if (t is RenderMushafLine) return t.wordAtLocal(t.globalToLocal(global));
    if (t is RenderOriginalPage) return t.wordAtLocal(t.globalToLocal(global));
  }
  return null;
}
