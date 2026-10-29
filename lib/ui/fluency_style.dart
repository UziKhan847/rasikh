import 'dart:ui';

import '../core/fluency/fluency_store.dart';

/// How fluency marks are drawn, on the verse cards and the muṣḥaf's lines
/// alike: not fluent, a dotted line under the word; a pair, a bridge under
/// the gap between its words (each word draws its half); a word split into
/// stem and attachments, a dot above it.

/// The marks' colour: amber, a little lighter on a dark page.
Color fluencyColor({required bool dark}) =>
    dark ? const Color(0xFFE6A84A) : const Color(0xFFC27C12);

/// [v] around [word] (its box, the text running right to left), at font
/// size [fs]. A pair whose second word is on the same line ([pairTo]) is
/// one bridge between their middles, drawn by its first word; [endDrawn]:
/// this word's end of a pair was drawn so.
void paintFluency(Canvas canvas, Rect word, FluencyVisual v,
    {required double fs, required Color color, Rect? pairTo, bool endDrawn = false}) {
  final y = word.bottom - fs * .02;
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = (fs * .05).clamp(1.2, 2.6);
  if (v.slow) {
    final dot = Paint()..color = color;
    final r = (fs * .035).clamp(1.0, 2.2);
    final step = r * 3.2;
    final left = word.left + r * 2, right = word.right - r * 2;
    for (var x = right; x >= left; x -= step) {
      canvas.drawCircle(Offset(x, y), r, dot);
    }
  }
  // The bridge: down from the word's middle to the gap's, where the next
  // word (on its left) takes it up again.
  final depth = fs * .22, half = fs * .12;
  if (v.pairStart && pairTo != null) {
    final a = Offset(word.center.dx, y - fs * .02);
    final b = Offset(pairTo.center.dx, y - fs * .02);
    canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(a.dx, a.dy + depth * 1.4, b.dx, b.dy + depth * 1.4, b.dx, b.dy),
        stroke);
  } else if (v.pairStart) {
    final from = Offset(word.center.dx, y - fs * .02);
    final to = Offset(word.left - half, y + depth);
    canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(from.dx, to.dy, to.dx + (from.dx - to.dx) * .4, to.dy, to.dx, to.dy),
        stroke);
  }
  if (v.pairEnd && !endDrawn) {
    final from = Offset(word.right + half, y + depth);
    final to = Offset(word.center.dx, y - fs * .02);
    canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(from.dx - (from.dx - to.dx) * .4, from.dy, to.dx, from.dy, to.dx, to.dy),
        stroke);
  }
  if (v.chunk) {
    canvas.drawCircle(Offset(word.center.dx, word.top + fs * .06),
        (fs * .06).clamp(1.6, 3.4), Paint()..color = color);
  }
}
