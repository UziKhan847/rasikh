import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/fluency/fluency_store.dart' show FluencyVisual;
import '../../core/marks/marks_model.dart';
import '../../core/tap_longpress.dart';
import '../../ui/fluency_style.dart';
import '../../ui/mark_style.dart';

/// An āyah's words as ONE paragraph, shaped once: the word being recited
/// and the words' marks are painted around the text (rectangles and pattern
/// lines), so a recitation tick or a new mark repaints it without shaping
/// it again — where a widget per word reshaped its word on every change.
/// Taps and holds find their word from where they land.
class AyahText extends LeafRenderObjectWidget {
  /// One span per word, in order (their styles: tajwīd colours and the
  /// like); a space is set between them.
  final List<InlineSpan> words;

  /// What [words] look like, as a key: when it changes, the paragraph is
  /// shaped anew; otherwise it's only repainted.
  final String textKey;

  /// The word being recited (-1: none), on [highlight].
  final int playWord;
  final Color highlight;

  /// Each word's marks (null: none), drawn with [markPal].
  final List<MarkVisual?> marks;
  final MarkPalette? markPal;

  /// Each word's fluency marks (the Reader's), in [fluencyColor].
  final List<FluencyVisual?> fluency;
  final Color fluencyColor;

  final void Function(int word) onTap;
  final void Function(int word) onLongPress;
  const AyahText({
    super.key,
    required this.words,
    required this.textKey,
    required this.playWord,
    required this.highlight,
    required this.marks,
    required this.markPal,
    this.fluency = const [],
    this.fluencyColor = const Color(0xFFC27C12),
    required this.onTap,
    required this.onLongPress,
  });

  @override
  RenderAyahText createRenderObject(BuildContext context) => RenderAyahText(this);

  @override
  void updateRenderObject(BuildContext context, RenderAyahText renderObject) =>
      renderObject.update(this);
}

class RenderAyahText extends RenderBox {
  RenderAyahText(AyahText w) : _w = w {
    _setText(w);
  }

  AyahText _w;
  final TextPainter _tp = TextPainter(textDirection: TextDirection.rtl);

  /// Each word's [start, end) in the paragraph's characters.
  final List<(int, int)> _ranges = [];

  /// Each word's boxes once laid out.
  List<List<Rect>> _boxes = const [];

  /// Paragraphs shaped, for the tests' budgets.
  @visibleForTesting
  static int debugLayouts = 0;

  void _setText(AyahText w) {
    final spans = <InlineSpan>[];
    _ranges.clear();
    var at = 0;
    for (var i = 0; i < w.words.length; i++) {
      if (i > 0) {
        spans.add(const TextSpan(text: ' '));
        at++;
      }
      final n = w.words[i].toPlainText(includeSemanticsLabels: false).length;
      spans.add(w.words[i]);
      _ranges.add((at, at + n));
      at += n;
    }
    _tp.text = TextSpan(children: spans);
  }

  void update(AyahText w) {
    final old = _w;
    _w = w;
    if (w.textKey != old.textKey) {
      _setText(w);
      markNeedsLayout();
      markNeedsSemanticsUpdate();
    } else if (w.playWord != old.playWord ||
        w.highlight != old.highlight ||
        !_sameMarks(w.marks, old.marks) ||
        !_sameMarks(w.fluency, old.fluency) ||
        w.fluencyColor != old.fluencyColor ||
        w.markPal != old.markPal) {
      markNeedsPaint();
    }
  }

  static bool _sameMarks(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void performLayout() {
    if (kDebugMode) debugLayouts++;
    _tp.layout(maxWidth: constraints.maxWidth);
    size = constraints.constrain(Size(constraints.maxWidth, _tp.height));
    _boxes = [
      for (final (a, b) in _ranges)
        [
          for (final box in _tp.getBoxesForSelection(TextSelection(baseOffset: a, extentOffset: b)))
            box.toRect(),
        ],
    ];
  }

  /// The text's offset in the box: right-aligned, as Arabic runs.
  Offset get _origin => Offset(size.width - _tp.width, 0);

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final o = offset + _origin;
    final mp = _w.markPal;
    for (var i = 0; i < _boxes.length; i++) {
      final v = i < _w.marks.length ? _w.marks[i] : null;
      final on = i == _w.playWord;
      if (!on && (v == null || mp == null)) continue;
      for (final r in _boxes[i]) {
        final box = r.shift(o).inflate(2);
        if (on) {
          canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(8)),
              Paint()..color = _w.highlight);
        }
        if (v != null && mp != null) {
          canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(6)),
              Paint()..color = mp.colorFor(v).withValues(alpha: mp.tintAlpha));
        }
      }
    }
    _tp.paint(canvas, o);
    // A word's box is a line of text tall; its font size, about half.
    var endDrawn = false;
    for (var i = 0; i < _boxes.length && i < _w.fluency.length; i++) {
      final v = _w.fluency[i];
      final drawn = endDrawn;
      endDrawn = false;
      if (v == null || _boxes[i].isEmpty) continue;
      final r = _boxes[i].first.shift(o);
      Rect? to;
      if (v.pairStart && i + 1 < _boxes.length && _boxes[i + 1].isNotEmpty) {
        final n = _boxes[i + 1].first.shift(o);
        if ((n.center.dy - r.center.dy).abs() < r.height / 2) {
          to = n;
          endDrawn = true;
        }
      }
      paintFluency(canvas, r, v,
          fs: r.height * .5, color: _w.fluencyColor, pairTo: to, endDrawn: drawn);
    }
    if (mp == null) return;
    for (var i = 0; i < _boxes.length && i < _w.marks.length; i++) {
      final v = _w.marks[i];
      if (v == null) continue;
      for (final r in _boxes[i]) {
        final box = r.shift(o);
        paintMarkLine(canvas, Offset(box.left + 2, box.bottom - 2), box.width - 4, v, mp);
      }
    }
  }

  /// Word [w]'s middle, in this box (tests tap it).
  @visibleForTesting
  Offset? wordCenter(int w) =>
      w < _boxes.length && _boxes[w].isNotEmpty ? _boxes[w].first.center + _origin : null;

  // ── taps ──

  TapAndLongPressGestureRecognizer? _recognizer;
  int? _down;

  /// The word under [p] (or the nearest on its line).
  int? _wordAt(Offset p) {
    final q = p - _origin;
    for (var i = 0; i < _boxes.length; i++) {
      for (final r in _boxes[i]) {
        if (r.inflate(3).contains(q)) return i;
      }
    }
    final c = _tp.getPositionForOffset(q).offset;
    for (var i = 0; i < _ranges.length; i++) {
      if (c >= _ranges[i].$1 && c <= _ranges[i].$2) return i;
    }
    return null;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is! PointerDownEvent) return;
    _down = _wordAt(event.localPosition);
    if (_down == null) return;
    (_recognizer ??= TapAndLongPressGestureRecognizer(
      onTap: () {
        final w = _down;
        if (w != null) _w.onTap(w);
      },
      onLongPress: () {
        final w = _down;
        if (w != null) _w.onLongPress(w);
      },
    ))
        .addPointer(event);
  }

  @override
  void detach() {
    _recognizer?.dispose();
    _recognizer = null;
    super.detach();
  }

  @override
  void dispose() {
    _tp.dispose();
    super.dispose();
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _tp.layout(maxWidth: width);
    return _tp.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _tp.plainText
      ..textDirection = TextDirection.rtl;
  }
}
