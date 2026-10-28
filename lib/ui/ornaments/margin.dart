import 'package:flutter/material.dart';

import 'art.dart';
import 'surah_headers.dart' show fillBoxes;

/// Each lantern's window (where its text goes), as fractions of its box;
/// a white-filled paper fills it.
const _windows = {
  'lantern1': Rect.fromLTRB(.146, .601, .841, .944),
  'lantern2': Rect.fromLTRB(.164, .386, .848, .612),
  'lantern3': Rect.fromLTRB(.058, .336, .946, .664),
};

/// A lantern in the Madani muṣḥaf's margin (where a ḥizb quarter starts):
/// [kind] 'lantern1' (a lantern over a box) or 'lantern2' (a box between
/// two knots), [width] wide, its [text] (one line or more) in its window.
/// It's drawn in [ink] — black on a light page, as printed, never in a
/// colour — and [fill] fills its window on white-filled papers.
class MarginLantern extends StatelessWidget {
  final String kind;
  final double width;
  final String text;
  final Color ink;
  final Color? fill;

  /// The text's colour, when not the lantern's own [ink].
  final Color? textColor;

  /// The text's own style (its colour aside), set at its size — shrunk
  /// only to fit — rather than filling the window in Naskh.
  final TextStyle? textStyle;
  const MarginLantern({
    super.key,
    required this.kind,
    required this.width,
    required this.text,
    required this.ink,
    this.fill,
    this.textColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final art = switch (kind) {
      'lantern2' => ClassicArt.lantern2,
      'lantern3' => ClassicArt.lantern3,
      _ => ClassicArt.lantern1,
    };
    final win = _windows[kind] ?? _windows['lantern1']!;
    final h = width / art.ratio;
    // A little inside the window's rule.
    final pad = width * .06;
    return SizedBox(
      width: width,
      height: h,
      child: CustomPaint(
        painter: _LanternPainter(art, win, ink, fill),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            win.left * width + pad,
            win.top * h + pad,
            (1 - win.right) * width + pad,
            (1 - win.bottom) * h + pad,
          ),
          child: FittedBox(
            fit: textStyle == null ? BoxFit.contain : BoxFit.scaleDown,
            child: Text(
              text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: (textStyle ??
                      const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ))
                  .copyWith(color: textColor ?? ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanternPainter extends CustomPainter {
  final ClassicArt art;
  final Rect window;
  final Color ink;
  final Color? fill;
  _LanternPainter(this.art, this.window, this.ink, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (fill != null) fillBoxes(canvas, r, [window], fill!);
    art.paint(canvas, r, ink);
  }

  @override
  bool shouldRepaint(_LanternPainter o) =>
      o.art != art || o.ink != ink || o.fill != fill;
}

/// A line of the page's details outside its frame, running along it:
/// upright above and below the frame, turned on its side beside it
/// ([quarterTurns] 1 or 3, so it reads from the frame's top or bottom).
class EdgeLabel extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final int quarterTurns;
  final String? fontFamily;
  const EdgeLabel({
    super.key,
    required this.text,
    required this.size,
    required this.color,
    this.quarterTurns = 0,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final t = Text(
      text,
      maxLines: 1,
      softWrap: false,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: fontFamily ?? 'NotoNaskhArabic',
        fontSize: size,
        height: 1.3,
        color: color,
      ),
    );
    return quarterTurns == 0 ? t : RotatedBox(quarterTurns: quarterTurns, child: t);
  }
}
