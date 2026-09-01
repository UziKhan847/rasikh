import 'dart:ui' show Size, Offset;

/// Per-letter ink bounds for UthmanicHafs, read straight out of the font's
/// own `glyf` table by `tool/glyph_ink_bounds.py` — re-run that script and
/// paste its output here if the bundled font is ever replaced.
///
/// This exists because `FittedBox` centres a `Text` widget's LINE BOX, not
/// its ink, and the two are very different things for an isolated Arabic
/// letter. UthmanicHafs' natural line (ascent 1.172em + descent 0.586em, from
/// its own `hhea` table) leaves headroom sized for a full word's tashkīl —
/// headroom a bare letter never fills — and how much ink actually sits above
/// vs. below the baseline swings wildly by letter: kāf reaches +0.68em above
/// it, jīm/ḥā/khā/ʿayn/ghayn/mīm reach −0.44em below it. No single line box
/// centres all 28, which is why "This is Jīm" showed a wide gap above the
/// glyph and the glyph crowded against the bottom of its card. See
/// `_GlyphHero` in `screens/kids/kids_letter_flow.dart`, the only place this
/// is used — it only ever draws isolated letters.
///
/// Values are in em units relative to the font's own baseline (positive up).
const kUthmanicInk = <String, (double top, double bottom)>{
  'ا': (0.6328, -0.0034),
  'ب': (0.3462, -0.2051),
  'ت': (0.4424, -0.0034),
  'ث': (0.5386, -0.0034),
  'ج': (0.3442, -0.4434),
  'ح': (0.3442, -0.4434),
  'خ': (0.5479, -0.4434),
  'د': (0.3672, -0.0029),
  'ذ': (0.5742, -0.0029),
  'ر': (0.2173, -0.2603),
  'ز': (0.4180, -0.2603),
  'س': (0.2549, -0.2588),
  'ش': (0.5269, -0.2588),
  'ص': (0.3247, -0.2583),
  'ض': (0.4922, -0.2583),
  'ط': (0.6660, -0.0024),
  'ظ': (0.6660, -0.0024),
  'ع': (0.4961, -0.4424),
  'غ': (0.7021, -0.4424),
  'ف': (0.6143, -0.0024),
  'ق': (0.5176, -0.1401),
  'ك': (0.6831, -0.0024),
  'ل': (0.6709, -0.1348),
  'م': (0.3184, -0.4390),
  'ن': (0.4829, -0.1328),
  'ه': (0.2607, 0.0024),
  'و': (0.2480, -0.2622),
  'ي': (0.4204, -0.1416),
};

/// The font size at which a glyph with these ink bounds fills [boxHeight]
/// vertically, ink edge to ink edge. Pure arithmetic, kept separate from the
/// `TextPainter` calls that use it (see `_GlyphHero` in
/// `screens/kids/kids_letter_flow.dart`) so the centring math can be unit
/// tested without laying out real text.
double glyphInkFontSize(double boxHeight, double top, double bottom) =>
    boxHeight / (top - bottom);

/// Where to paint a glyph's `TextPainter` line box so its ink — not the line
/// box itself — lands centred in [size]. [fontSize] is whatever was used to
/// lay the text out; [lineWidth] and [baseline] are that `TextPainter`'s own
/// `.width` and `computeDistanceToActualBaseline(TextBaseline.alphabetic)`.
Offset glyphInkOffset({
  required Size size,
  required double fontSize,
  required double top,
  required double bottom,
  required double lineWidth,
  required double baseline,
}) {
  final dx = (size.width - lineWidth) / 2;
  final dy = size.height / 2 + (top + bottom) / 2 * fontSize - baseline;
  return Offset(dx, dy);
}
