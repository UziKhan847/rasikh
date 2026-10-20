import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'art.dart';

/// An āyah circle's artwork and where its parts are, as fractions of the
/// drawing's height: the hole (the number sits there; white-filled papers
/// fill it), and the ring — what's matched to the font's own plain circle.
/// Either drawing goes with either script's text.
class ClassicCircle {
  /// 'madani' or 'indopak'.
  final String art;
  final ClassicArt drawing;
  final Offset holeCentre;
  final double holeDiameter, ringCentreY, ringDiameter;
  const ClassicCircle._(
    this.art,
    this.drawing,
    this.holeCentre,
    this.holeDiameter,
    this.ringCentreY,
    this.ringDiameter,
  );

  static final madani = ClassicCircle._(
    'madani',
    ClassicArt.verseCircle,
    const Offset(.5, .513),
    .74,
    .535,
    .93,
  );
  static final indopak = ClassicCircle._(
    'indopak',
    ClassicArt.indopakVerseCircle,
    const Offset(.496, .5),
    .69,
    .5,
    .86,
  );

  static ClassicCircle of(String art) => art == 'indopak' ? indopak : madani;

  /// The tuning keys for this circle's size and vertical offset.
  String get scaleKey =>
      art == 'indopak' ? 'markerIndopakScale' : 'markerMadaniScale';
  String get dyKey => art == 'indopak' ? 'markerIndopakDy' : 'markerMadaniDy';

  static final Map<String, ui.Image> _sprites = {};

  /// This circle as a white sprite [h] px tall, for the muṣḥaf's glyph
  /// atlas (tinted by `drawRawAtlas` like the glyphs). Made once per size.
  ui.Image sprite(int h) => _sprites['$art/$h'] ??= () {
    final w = (h * drawing.width / drawing.height).ceil();
    final rec = ui.PictureRecorder();
    drawing.paint(
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

/// The āyah marker as a widget (the reader, the style screen's swatches):
/// the traced circle of [art] with [fill] inside its hole and the number
/// centred there.
class ClassicAyahMarker extends StatelessWidget {
  final String numeralAr;

  /// The ring's diameter, as the plain marker's size.
  final double size;
  final Color stroke, fill, textColor;
  final String art;
  final double scale, dy;
  const ClassicAyahMarker({
    super.key,
    required this.numeralAr,
    required this.size,
    required this.stroke,
    required this.fill,
    required this.textColor,
    this.art = 'madani',
    this.scale = 1,
    this.dy = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = ClassicCircle.of(art);
    final h = size * scale / c.ringDiameter;
    final w = h * c.drawing.width / c.drawing.height;
    final hole = c.holeDiameter * h;
    return SizedBox.square(
      dimension: size,
      child: OverflowBox(
        maxWidth: w,
        maxHeight: h,
        child: Transform.translate(
          offset: Offset(0, (.5 - c.ringCentreY + dy) * h),
          child: SizedBox(
            width: w,
            height: h,
            child: CustomPaint(
              painter: _MarkerPainter(c, stroke, fill),
              child: Align(
                alignment: Alignment(
                  c.holeCentre.dx * 2 - 1,
                  c.holeCentre.dy * 2 - 1,
                ),
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
  final ClassicCircle circle;
  final Color stroke, fill;
  _MarkerPainter(this.circle, this.stroke, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(
      size.width * circle.holeCentre.dx,
      size.height * circle.holeCentre.dy,
    );
    canvas.drawCircle(
      c,
      size.height * circle.holeDiameter / 2,
      Paint()..color = fill,
    );
    circle.drawing.paint(canvas, Offset.zero & size, stroke);
  }

  @override
  bool shouldRepaint(_MarkerPainter o) =>
      o.circle != circle || o.stroke != stroke || o.fill != fill;
}
