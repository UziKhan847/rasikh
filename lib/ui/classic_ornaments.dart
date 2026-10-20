import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import 'classic_ornament_paths.dart';

/// The Classic ornament style (design handoff, Update 8): hand-drawn traced
/// artwork — the sūrah border, the āyah circle and the juzʼ lantern — as
/// single-colour paths, tinted where they're drawn. Each path is parsed once.
class ClassicArt {
  final double width, height;
  final Path path;
  const ClassicArt._(this.width, this.height, this.path);

  static ClassicArt _of(
    ({double width, double height, double dx, double dy, String d}) a,
  ) {
    final p = Path();
    writeSvgPathDataToPath(a.d, _Proxy(p));
    return ClassicArt._(a.width, a.height, p.shift(Offset(a.dx, a.dy)));
  }

  static final verseCircle = _of(verseCircleSvg);
  static final surahBorder = _of(surahBorderSvg);
  static final lantern = _of(lanternSvg);

  /// The āyah circle's hole: its centre and diameter as fractions of the
  /// drawing's height (the number sits there), and the outer ring's
  /// diameter — what matches the font's own plain circle.
  static const holeCentre = Offset(.5, .513);
  static const holeDiameter = .74;
  static const ringCentreY = .535;
  static const ringDiameter = .93;

  /// The lantern's window (where جزء and the number go), as fractions of
  /// its box.
  static const lanternWindow = Rect.fromLTRB(.12, .35, .88, .65);

  /// Draws this artwork into [dst] (stretched to it) in [color].
  void paint(Canvas canvas, Rect dst, Color color) {
    canvas.save();
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / width, dst.height / height);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  static final Map<int, ui.Image> _sprites = {};

  /// The āyah circle as a white sprite [h] px tall, for the muṣḥaf's glyph
  /// atlas (tinted by `drawRawAtlas` like the glyphs). Made once per size.
  static ui.Image circleSprite(int h) => _sprites[h] ??= () {
    final c = verseCircle;
    final w = (h * c.width / c.height).ceil();
    final rec = ui.PictureRecorder();
    c.paint(
      Canvas(rec),
      Rect.fromLTWH(1, 1, w.toDouble(), h.toDouble()),
      const Color(0xFFFFFFFF),
    );
    final pic = rec.endRecording();
    final img = pic.toImageSync(w + 2, h + 2);
    pic.dispose();
    return img;
  }();
}

class _Proxy extends PathProxy {
  final Path p;
  _Proxy(this.p);
  @override
  void moveTo(double x, double y) => p.moveTo(x, y);
  @override
  void lineTo(double x, double y) => p.lineTo(x, y);
  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => p.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => p.close();
}

/// The sūrah border, its ends kept to their drawn proportions and the
/// plain middle stretched to the width, with [child] (the title) centred
/// over the middle cartouche.
class ClassicSurahBorder extends StatelessWidget {
  final double height;
  final Color color;
  final Widget child;
  const ClassicSurahBorder({
    super.key,
    required this.height,
    required this.color,
    required this.child,
  });

  /// Where the ends stop (fractions of the drawing's width): the side
  /// panels and the cartouche's rounded ends.
  static const _endFrac = .31;

  @override
  Widget build(BuildContext context) {
    final art = ClassicArt.surahBorder;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BorderPainter(color),
        child: LayoutBuilder(
          builder: (context, c) {
            final s = height / art.height;
            final end = (art.width * _endFrac * s).clamp(
              0.0,
              c.maxWidth * _endFrac,
            );
            return Padding(
              // The cartouche's inside: clear of its rounded ends, rules
              // above and below.
              padding: EdgeInsets.fromLTRB(
                end * .85,
                height * .2,
                end * .85,
                height * .2,
              ),
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: child),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BorderPainter extends CustomPainter {
  final Color color;
  _BorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final art = ClassicArt.surahBorder;
    final paint = Paint()..color = color;
    final sy = size.height / art.height;
    final srcEnd = art.width * ClassicSurahBorder._endFrac;
    final end = srcEnd * sy;
    if (2 * end >= size.width) {
      // Too narrow to keep the ends: stretch the whole drawing.
      art.paint(canvas, Offset.zero & size, color);
      return;
    }
    void part(Rect clip, double dx, double sx) {
      canvas.save();
      canvas.clipRect(clip);
      canvas.translate(dx, 0);
      canvas.scale(sx, sy);
      canvas.drawPath(art.path, paint);
      canvas.restore();
    }

    // Ends at the drawing's own proportions; the clips overlap a little so
    // no seam shows.
    part(Rect.fromLTWH(0, 0, end + .5, size.height), 0, sy);
    part(
      Rect.fromLTWH(size.width - end - .5, 0, end + .5, size.height),
      size.width - art.width * sy,
      sy,
    );
    final midSrc = art.width - 2 * srcEnd;
    final sx = (size.width - 2 * end) / midSrc;
    part(
      Rect.fromLTWH(end, 0, size.width - 2 * end, size.height),
      end - srcEnd * sx,
      sx,
    );
  }

  @override
  bool shouldRepaint(_BorderPainter o) => o.color != color;
}

/// The juzʼ lantern for a page's outer margin: the drawing with جزء and
/// the number in its window.
class ClassicLantern extends StatelessWidget {
  final double width;
  final String number;
  final Color color, textColor;
  const ClassicLantern({
    super.key,
    required this.width,
    required this.number,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final art = ClassicArt.lantern;
    final h = width * art.height / art.width;
    final win = ClassicArt.lanternWindow;
    return SizedBox(
      width: width,
      height: h,
      child: CustomPaint(
        painter: _ArtPainter(art, color),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            win.left * width,
            win.top * h,
            (1 - win.right) * width,
            (1 - win.bottom) * h,
          ),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
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
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  final ClassicArt art;
  final Color color;
  _ArtPainter(this.art, this.color);

  @override
  void paint(Canvas canvas, Size size) =>
      art.paint(canvas, Offset.zero & size, color);

  @override
  bool shouldRepaint(_ArtPainter o) => o.color != color || o.art != art;
}

/// The Classic āyah circle as a widget (the reader): [fill] inside its
/// hole, the number centred there.
class ClassicAyahMarker extends StatelessWidget {
  final String numeralAr;
  final double size;
  final Color stroke, fill, textColor;
  const ClassicAyahMarker({
    super.key,
    required this.numeralAr,
    required this.size,
    required this.stroke,
    required this.fill,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final art = ClassicArt.verseCircle;
    // [size] is the ring's diameter, as the plain marker's.
    final h = size / ClassicArt.ringDiameter;
    final w = h * art.width / art.height;
    final hole = ClassicArt.holeDiameter * h;
    return SizedBox.square(
      dimension: size,
      child: OverflowBox(
        maxWidth: w,
        maxHeight: h,
        child: Transform.translate(
          offset: Offset(0, (.5 - ClassicArt.ringCentreY) * h),
          child: SizedBox(
            width: w,
            height: h,
            child: CustomPaint(
              painter: _MarkerPainter(stroke, fill),
              child: Align(
                alignment: Alignment(0, ClassicArt.holeCentre.dy * 2 - 1),
                child: SizedBox.square(
                  dimension: hole,
                  child: Center(
                    child: Text(
                      numeralAr,
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: hole * .52,
                        height: 1,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final Color stroke, fill;
  _MarkerPainter(this.stroke, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(
      size.width * ClassicArt.holeCentre.dx,
      size.height * ClassicArt.holeCentre.dy,
    );
    canvas.drawCircle(
      c,
      size.height * ClassicArt.holeDiameter / 2,
      Paint()..color = fill,
    );
    ClassicArt.verseCircle.paint(canvas, Offset.zero & size, stroke);
  }

  @override
  bool shouldRepaint(_MarkerPainter o) => o.stroke != stroke || o.fill != fill;
}
