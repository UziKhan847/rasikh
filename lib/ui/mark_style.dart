import 'package:flutter/material.dart';

import '../core/marks/marks_model.dart';
import '../core/theme.dart';

/// Colours and underline patterns for word marks.
///
/// Every type has its own underline pattern as well as its own colour, so the
/// types stay distinguishable for colour-blind readers and on the mono paper
/// (where the colours are greys). The colours were contrast-checked against
/// the cream, night and OLED papers.
class MarkPalette {
  final Map<MarkType, Color> solid;
  final Color fixed;

  /// Alpha of the highlighter tint behind a marked word.
  final double tintAlpha;
  final bool mono;
  const MarkPalette(
      {required this.solid,
      required this.fixed,
      required this.tintAlpha,
      this.mono = false});

  Color colorOf(MarkType t) => solid[t]!;

  /// Solid colour for a word's visual state (open mark first, else fixed).
  Color colorFor(MarkVisual v) => v.open != null ? colorOf(v.open!) : fixed;

  Color? tintOf(MarkType t) => t == MarkType.note
      ? null
      : colorOf(t).withValues(alpha: tintAlpha);

  static TextDecorationStyle patternOf(MarkType? t) => switch (t) {
        MarkType.mistake => TextDecorationStyle.solid,
        MarkType.tajwid => TextDecorationStyle.dashed,
        MarkType.hesitation => TextDecorationStyle.dotted,
        MarkType.doubt => TextDecorationStyle.wavy,
        MarkType.note => TextDecorationStyle.dotted,
        MarkType.mutashabih => TextDecorationStyle.dashed,
        null => TextDecorationStyle.double, // fixed
      };
}

const _light = MarkPalette(
  solid: {
    MarkType.mistake: Color(0xFFC8402F),
    MarkType.tajwid: Color(0xFF2A78D6),
    MarkType.hesitation: Color(0xFFB87A00),
    MarkType.doubt: Color(0xFF7A4FD0),
    MarkType.note: Color(0xFF6F6656),
    MarkType.mutashabih: Color(0xFF0B8A8F),
  },
  fixed: Color(0xFF16875A),
  tintAlpha: .16,
);

const _dark = MarkPalette(
  solid: {
    MarkType.mistake: Color(0xFFE0604C),
    MarkType.tajwid: Color(0xFF4F93E6),
    MarkType.hesitation: Color(0xFFBF861A),
    MarkType.doubt: Color(0xFF9580EA),
    MarkType.note: Color(0xFF929B96),
    MarkType.mutashabih: Color(0xFF3FB6BA),
  },
  fixed: Color(0xFF2FA77A),
  tintAlpha: .24,
);

const _mono = MarkPalette(
  solid: {
    MarkType.mistake: Color(0xFF111111),
    MarkType.tajwid: Color(0xFF3A3A3A),
    MarkType.hesitation: Color(0xFF555555),
    MarkType.doubt: Color(0xFF222222),
    MarkType.note: Color(0xFF6E6E6E),
    MarkType.mutashabih: Color(0xFF4A4A4A),
  },
  fixed: Color(0xFF777777),
  tintAlpha: .10,
  mono: true,
);

/// The mark palette for a muṣḥaf paper.
MarkPalette markPaletteForPaper(MushafPaper paper) => paper.id == 'mono'
    ? _mono
    : paper.dark
        ? _dark
        : _light;

/// The mark palette for an app palette (reader, lists, charts).
MarkPalette markPaletteFor(Palette p, {bool mono = false}) => mono
    ? _mono
    : p.isDark
        ? _dark
        : _light;

/// [base] dressed for a word with marks [v]: a translucent highlighter in the
/// mark's colour. Neither changes layout, so justified muṣḥaf lines keep their
/// measured geometry. [overBg] (the recitation highlight) wins over the tint.
///
/// The type's pattern line is NOT a text decoration: Flutter draws those near
/// the baseline, straight through the kasrahs. Hosts draw it with
/// [paintMarkLine] at the bottom of the word's box instead. Pass
/// [underline] = true only where that isn't possible.
TextStyle markSpanStyle(TextStyle base, MarkVisual? v, MarkPalette pal,
    {Color? overBg, bool underline = false}) {
  if (v == null || (v.open == null && !v.fixed)) {
    return overBg == null ? base : base.copyWith(backgroundColor: overBg);
  }
  final open = v.open;
  final tint = open == null ? null : pal.tintOf(open);
  final styled = base.copyWith(backgroundColor: overBg ?? tint);
  if (!underline) return styled;
  return styled.copyWith(
    decoration: TextDecoration.underline,
    decorationColor: pal.colorFor(v),
    decorationStyle: MarkPalette.patternOf(open),
    decorationThickness: open == null ? 1.2 : 2.0,
  );
}

/// Draws a mark's pattern line (solid, dashed, dotted, wavy or the fixed
/// double rule) from [start] rightwards over [width] — under a word's box.
void paintMarkLine(Canvas canvas, Offset start, double width, MarkVisual v,
    MarkPalette pal, {double thickness = 1.8}) {
  _paintPattern(canvas, start, width, pal.colorFor(v),
      MarkPalette.patternOf(v.open), thickness);
}

void _paintPattern(Canvas canvas, Offset start, double width, Color c,
    TextDecorationStyle style, double t) {
  final x0 = start.dx, y = start.dy, x1 = start.dx + width;
  final p = Paint()
    ..color = c
    ..strokeWidth = t
    ..strokeCap = StrokeCap.round;
  switch (style) {
    case TextDecorationStyle.solid:
      canvas.drawLine(Offset(x0, y), Offset(x1, y), p);
    case TextDecorationStyle.dashed:
      final dash = t * 3, gap = t * 2;
      for (var x = x0; x < x1; x += dash + gap) {
        canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(x0, x1), y), p);
      }
    case TextDecorationStyle.dotted:
      for (var x = x0 + t; x < x1; x += t * 2.6) {
        canvas.drawCircle(Offset(x, y), t * .6, p);
      }
    case TextDecorationStyle.wavy:
      final a = t * 1.3, step = t * 2.2;
      final path = Path()..moveTo(x0, y);
      for (var x = x0; x < x1; x += step * 2) {
        path.quadraticBezierTo(x + step / 2, y - a, x + step, y);
        path.quadraticBezierTo(x + step * 1.5, y + a, x + step * 2, y);
      }
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(x0, y - a - t, x1, y + a + t));
      canvas.drawPath(
          path,
          p
            ..style = PaintingStyle.stroke
            ..strokeWidth = t * .85);
      canvas.restore();
    case TextDecorationStyle.double:
      p.strokeWidth = t * .7;
      canvas.drawLine(Offset(x0, y), Offset(x1, y), p);
      canvas.drawLine(Offset(x0, y - t * 1.8), Offset(x1, y - t * 1.8), p);
  }
}

/// A small coloured swatch with the type's pattern, for legends and chips.
class MarkSwatch extends StatelessWidget {
  final MarkType? type; // null = fixed
  final MarkPalette pal;
  final double size;
  const MarkSwatch(
      {super.key, required this.type, required this.pal, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final c = type == null ? pal.fixed : pal.colorOf(type!);
    return CustomPaint(
      size: Size(size, size),
      painter: _SwatchPainter(c, type, pal.tintAlpha),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  final Color c;
  final MarkType? type;
  final double alpha;
  _SwatchPainter(this.c, this.type, this.alpha);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.width * .25));
    if (type != MarkType.note && type != null) {
      canvas.drawRRect(r, Paint()..color = c.withValues(alpha: alpha + .1));
    }
    _paintPattern(canvas, Offset(0, size.height - 2.5), size.width, c,
        MarkPalette.patternOf(type), 1.8);
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.c != c || old.type != type || old.alpha != alpha;
}
