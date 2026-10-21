import 'package:flutter/material.dart';

import 'art.dart';
import 'surah_headers.dart' show fillBoxes;

/// The lantern's window (where جزء and the number go) and its body (what
/// a white-filled paper fills), as fractions of its box.
const _lanternWindow = Rect.fromLTRB(.13, .63, .87, .94);
const _lanternBody = Rect.fromLTRB(.087, .599, .913, .968);

/// The juzʼ in a page's outer margin, as [kind] draws it: 'lantern' (the
/// lantern with جزء and the number in its window) or 'text' (the words
/// alone, as Indo-Pak muṣḥafs print them). [width] is the margin's band;
/// the lantern takes [scale] of it.
class MarginJuz extends StatelessWidget {
  final String kind;
  final double width;
  final String number;
  final Color color, textColor;
  final Color? fill;
  final double scale;
  const MarginJuz({
    super.key,
    required this.kind,
    required this.width,
    required this.number,
    required this.color,
    required this.textColor,
    this.fill,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      'جزء\n$number',
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: 'NotoNaskhArabic',
        fontSize: 12,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
    if (kind != 'lantern') {
      return SizedBox(
        width: width * .8,
        child: FittedBox(fit: BoxFit.scaleDown, child: text),
      );
    }
    final art = ClassicArt.lantern;
    final w = width * .9 * scale;
    final h = w * art.height / art.width;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _LanternPainter(color, fill),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _lanternWindow.left * w,
            _lanternWindow.top * h,
            (1 - _lanternWindow.right) * w,
            (1 - _lanternWindow.bottom) * h,
          ),
          child: FittedBox(fit: BoxFit.contain, child: text),
        ),
      ),
    );
  }
}

class _LanternPainter extends CustomPainter {
  final Color color;
  final Color? fill;
  _LanternPainter(this.color, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (fill != null) fillBoxes(canvas, r, const [_lanternBody], fill!);
    ClassicArt.lantern.paint(canvas, r, color);
  }

  @override
  bool shouldRepaint(_LanternPainter o) => o.color != color || o.fill != fill;
}
