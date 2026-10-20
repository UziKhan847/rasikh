import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import 'classic_ornament_paths.dart';

/// The Classic ornament style (design handoff, Updates 8 and 9): hand-drawn
/// traced artwork — sūrah borders, āyah circles, page borders and the juzʼ
/// lantern — as single-colour paths, tinted where they're drawn. Each path
/// is parsed once.
class ClassicArt {
  final double width, height;

  /// Filled one by one, as the SVG draws its elements.
  final List<Path> paths;
  const ClassicArt._(this.width, this.height, this.paths);

  static ClassicArt _of(
    ({double width, double height, double dx, double dy, List<String> d}) a,
  ) => ClassicArt._(a.width, a.height, [
    for (final d in a.d) _parse(d).shift(Offset(a.dx, a.dy)),
  ]);

  static final verseCircle = _of(verseCircleSvg);
  static final surahBorder = _of(surahBorderSvg);
  static final lantern = _of(lanternSvg);
  static final indopakVerseCircle = _of(indopakVerseCircleSvg);
  static final indopakSurahBorder = _of(indopakSurahBorderSvg);

  /// The Indo-Pak border's top tier alone, for a sūrah heading with no
  /// basmala under it (at-Tawbah).
  static final indopakSurahBorderTawbah = _of(indopakSurahBorderTawbahSvg);
  static final indopakPageBorder = _of(indopakPageBorderSvg);

  /// The lantern's window (where جزء and the number go) and its body (what
  /// a white-filled lantern fills), as fractions of its box.
  static const lanternWindow = Rect.fromLTRB(.12, .35, .88, .65);
  static const lanternBody = Rect.fromLTRB(.25, .19, .75, .81);

  /// Draws this artwork into [dst] (stretched to it) in [color].
  void paint(Canvas canvas, Rect dst, Color color) {
    canvas.save();
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / width, dst.height / height);
    final paint = Paint()..color = color;
    for (final p in paths) {
      canvas.drawPath(p, paint);
    }
    canvas.restore();
  }
}

Path _parse(String d) {
  final p = Path();
  writeSvgPathDataToPath(d, _Proxy(p));
  return p;
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

/// A script's āyah circle and where its parts are, as fractions of the
/// drawing's height: the hole (the number sits there; a white-filled circle
/// fills it), and the ring — what's matched to the font's own plain circle.
class ClassicCircle {
  final String script;
  final ClassicArt art;
  final Offset holeCentre;
  final double holeDiameter, ringCentreY, ringDiameter;
  const ClassicCircle._(
    this.script,
    this.art,
    this.holeCentre,
    this.holeDiameter,
    this.ringCentreY,
    this.ringDiameter,
  );

  static final madani = ClassicCircle._(
    'uthmani',
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

  static ClassicCircle of(String script) =>
      script == 'indopak' ? indopak : madani;

  static final Map<String, ui.Image> _sprites = {};

  /// This circle as a white sprite [h] px tall, for the muṣḥaf's glyph
  /// atlas (tinted by `drawRawAtlas` like the glyphs). Made once per size.
  ui.Image sprite(int h) => _sprites['$script/$h'] ??= () {
    final w = (h * art.width / art.height).ceil();
    final rec = ui.PictureRecorder();
    art.paint(
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

/// The Madani sūrah border, its ends kept to their drawn proportions and
/// the plain middle stretched to the width, with [child] (the title)
/// centred over the middle cartouche. With [fill], the cartouche and
/// rosettes are filled with it (white-filled papers).
class ClassicSurahBorder extends StatelessWidget {
  final double height;
  final Color color;
  final Color? fill;
  final Widget child;
  const ClassicSurahBorder({
    super.key,
    required this.height,
    required this.color,
    this.fill,
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
        painter: _BorderPainter(color, fill),
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
  final Color? fill;
  _BorderPainter(this.color, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final art = ClassicArt.surahBorder;
    if (fill != null) {
      canvas.drawRect(
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width * .86,
          height: size.height * .62,
        ),
        Paint()..color = fill!,
      );
    }
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
      for (final p in art.paths) {
        canvas.drawPath(p, paint);
      }
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
  bool shouldRepaint(_BorderPainter o) => o.color != color || o.fill != fill;
}

/// The Indo-Pak sūrah border: two tiers, stretched to its box — the sūrah's
/// name in the top tier's middle cartouche, the basmala (when the sūrah
/// has it there) in the lower band.
class IndopakSurahBorder extends StatelessWidget {
  final Color color;
  final Color? fill;
  final Widget title;
  final Widget? basmala;

  /// Only the top tier (a sūrah heading with no basmala under it, as
  /// at-Tawbah's): its own drawing.
  final bool topOnly;
  const IndopakSurahBorder({
    super.key,
    required this.color,
    this.fill,
    required this.title,
    this.basmala,
    this.topOnly = false,
  });


  /// The cartouche and band insides, as fractions of the box.
  static const titleBox = Rect.fromLTRB(.3, .14, .7, .5);
  static const basmalaBox = Rect.fromLTRB(.22, .63, .78, .95);
  static const tawbahTitleBox = Rect.fromLTRB(.3, .25, .7, .88);

  @override
  Widget build(BuildContext context) {
    Widget place(Rect r, Widget child) => Positioned.fill(
      child: FractionallySizedBox(
        alignment: Alignment(
          r.left / (1 - r.width) * 2 - 1,
          r.top / (1 - r.height) * 2 - 1,
        ),
        widthFactor: r.width,
        heightFactor: r.height,
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
    if (topOnly) {
      return CustomPaint(
        painter: _FillPainter(
          ClassicArt.indopakSurahBorderTawbah,
          color,
          fill,
          const [Rect.fromLTRB(.26, .18, .74, .94)],
        ),
        child: Stack(children: [place(tawbahTitleBox, title)]),
      );
    }
    return CustomPaint(
      painter: _FillPainter(ClassicArt.indopakSurahBorder, color, fill, const [
        Rect.fromLTRB(.26, .1, .74, .53),
        Rect.fromLTRB(.12, .57, .88, .98),
      ]),
      child: Stack(
        children: [
          place(titleBox, title),
          if (basmala != null) place(basmalaBox, basmala!),
        ],
      ),
    );
  }
}

/// Stretches [art] to its box in [color], with [fill] behind it over
/// [fillBoxes] (fractions of the box).
class _FillPainter extends CustomPainter {
  final ClassicArt art;
  final Color color;
  final Color? fill;
  final List<Rect> fillBoxes;
  _FillPainter(this.art, this.color, this.fill, this.fillBoxes);

  @override
  void paint(Canvas canvas, Size size) {
    if (fill != null) {
      final paint = Paint()..color = fill!;
      for (final r in fillBoxes) {
        canvas.drawRect(
          Rect.fromLTRB(
            r.left * size.width,
            r.top * size.height,
            r.right * size.width,
            r.bottom * size.height,
          ),
          paint,
        );
      }
    }
    art.paint(canvas, Offset.zero & size, color);
  }

  @override
  bool shouldRepaint(_FillPainter o) =>
      o.art != art || o.color != color || o.fill != fill;
}

/// A Classic page border around its child: the Madani nine-slice of tiles
/// (corners kept, the edge tile repeated in whole tiles) or the Indo-Pak
/// frame stretched to the box. [inner] fills inside it.
class ClassicPageBorder extends StatelessWidget {
  final String script;

  /// The Madani border's thickness (the Indo-Pak frame's follows the box).
  final double thickness;
  final Color band, cut, hairline;
  final Color? inner;
  final EdgeInsets padding;
  final Widget child;
  const ClassicPageBorder({
    super.key,
    required this.script,
    required this.thickness,
    required this.band,
    required this.cut,
    required this.hairline,
    this.inner,
    required this.padding,
    required this.child,
  });

  /// The Indo-Pak frame's thickness, as fractions of its box.
  static const indopakInset = Size(.0227, .0158);

  @override
  Widget build(BuildContext context) {
    final indopak = script == 'indopak';
    return CustomPaint(
      painter: indopak
          ? _IndopakFramePainter(band, inner)
          : _MadaniBorderPainter(thickness, band, cut, hairline, inner),
      child: LayoutBuilder(
        builder: (context, c) {
          final inset = indopak
              ? EdgeInsets.symmetric(
                  horizontal: indopakInset.width * c.maxWidth,
                  vertical: indopakInset.height *
                      (c.maxHeight.isFinite ? c.maxHeight : c.maxWidth * 1.4),
                )
              : EdgeInsets.all(thickness);
          return Padding(padding: inset + padding, child: child);
        },
      ),
    );
  }
}

class _IndopakFramePainter extends CustomPainter {
  final Color color;
  final Color? inner;
  _IndopakFramePainter(this.color, this.inner);

  @override
  void paint(Canvas canvas, Size size) {
    if (inner != null) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * ClassicPageBorder.indopakInset.width,
          size.height * ClassicPageBorder.indopakInset.height,
          size.width * (1 - 2 * ClassicPageBorder.indopakInset.width),
          size.height * (1 - 2 * ClassicPageBorder.indopakInset.height),
        ),
        Paint()..color = inner!,
      );
    }
    ClassicArt.indopakPageBorder.paint(canvas, Offset.zero & size, color);
  }

  @override
  bool shouldRepaint(_IndopakFramePainter o) =>
      o.color != color || o.inner != inner;
}

/// The Madani page border's two 30-unit tiles (from madani_page_border.svg):
/// each part's colour key — 0 the band, 1 the motifs, 2 the hairlines — and
/// its outline.
final List<(int, Path)> _edgeTile = _tile([
  (0, 'M0 0h30v28.6H0z'),
  (2, 'M0 2.9h30v.5H0zM0 25.4h30v.5H0z'),
  (
    1,
    'M4.6 15C7.4 10.6 10 7.9 15 6.4 20 7.9 22.6 10.6 25.4 15 22.6 19.4 20 22.1 '
        '15 23.6 10 22.1 7.4 19.4 4.6 15Z',
  ),
  (
    0,
    'M15 9.8C16.6 11.2 16.8 12.6 15 14.1 13.2 12.6 13.4 11.2 15 9.8ZM15 20.2C'
        '16.6 18.8 16.8 17.4 15 15.9 13.2 17.4 13.4 18.8 15 20.2ZM9.6 15C11.4 '
        '13.6 12.8 13.5 14 15 12.8 16.5 11.4 16.4 9.6 15ZM20.4 15C18.6 13.6 17.2 '
        '13.5 16 15 17.2 16.5 18.6 16.4 20.4 15Z',
  ),
  (1, _circle(15, 15, .8)),
  (1, 'M0 11.2 3 15 0 18.8-3 15ZM30 11.2 33 15 30 18.8 27 15Z'),
  (1, 'M2.4 14.6h2.4v.8H2.4zM25.2 14.6h2.4v.8h-2.4z'),
  (1, _circle(0, 7.4, 1.1)),
  (1, _circle(30, 7.4, 1.1)),
  (1, _circle(0, 22.6, 1.1)),
  (1, _circle(30, 22.6, 1.1)),
]);

final List<(int, Path)> _cornerTile = _tile([
  (0, 'M0 0h30v28.6H28.6V30H0z'),
  (2, 'M2.9 2.9h27.1v.5H3.4V30h-.5zM25.4 25.4h4.6v.5h-4.1V30h-.5z'),
  (1, 'M15 5.8 17.8 11.2 24.2 15 17.8 18.8 15 24.2 12.2 18.8 5.8 15 12.2 11.2Z'),
  (
    1,
    'M8.6 8.6 13.4 10.4 15 11.8 16.6 10.4 21.4 8.6 19.6 13.4 18.2 15 19.6 16.6 '
        '21.4 21.4 16.6 19.6 15 18.2 13.4 19.6 8.6 21.4 10.4 16.6 11.8 15 10.4 '
        '13.4Z',
  ),
  (0, 'M15 10.4 16.2 13.8 19.6 15 16.2 16.2 15 19.6 13.8 16.2 10.4 15 13.8 13.8Z'),
  (1, _circle(15, 15, 1.4)),
  (1, _circle(7, 7, 1.1)),
  (1, _circle(23.2, 23.2, 1.1)),
]);

String _circle(double cx, double cy, double r) =>
    'M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0Z';

List<(int, Path)> _tile(List<(int, String)> parts) => [
  for (final (k, d) in parts) (k, _parse(d)),
];

class _MadaniBorderPainter extends CustomPainter {
  final double t;
  final Color band, cut, hairline;
  final Color? inner;
  _MadaniBorderPainter(this.t, this.band, this.cut, this.hairline, this.inner);

  @override
  void paint(Canvas canvas, Size size) {
    if (inner != null) {
      canvas.drawRect(
        Rect.fromLTWH(t, t, size.width - 2 * t, size.height - 2 * t),
        Paint()..color = inner!,
      );
    }
    final paints = [
      Paint()..color = band,
      Paint()..color = cut,
      Paint()..color = hairline,
    ];
    final k = t / 30;
    final w = size.width, h = size.height;
    // The band as one ring (each tile's first part), so no seams show where
    // tiles meet; the tiles' motifs and hairlines go over it.
    final b = 28.6 * k;
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(Rect.fromLTWH(b, b, w - 2 * b, h - 2 * b)),
      paints[0],
    );
    // Draws [tile] through the SVG transform (a b c d e f) in tile units,
    // [along] stretching it lengthwise, clipped to its 30-unit square.
    void draw(
      List<(int, Path)> tile,
      Matrix4 m, {
      double along = 1,
    }) {
      canvas.save();
      canvas.transform(m.storage);
      canvas.scale(along, 1);
      canvas.clipRect(const Rect.fromLTWH(0, 0, 30, 30), doAntiAlias: false);
      for (final (key, p) in tile.skip(1)) {
        canvas.drawPath(p, paints[key]);
      }
      canvas.restore();
    }

    Matrix4 at(double a, double b, double c, double d, double e, double f) =>
        Matrix4(a * k, b * k, 0, 0, c * k, d * k, 0, 0, 0, 0, 1, 0, e, f, 0, 1);

    // Corners, mirrored into place.
    draw(_cornerTile, at(1, 0, 0, 1, 0, 0));
    draw(_cornerTile, at(-1, 0, 0, 1, w, 0));
    draw(_cornerTile, at(1, 0, 0, -1, 0, h));
    draw(_cornerTile, at(-1, 0, 0, -1, w, h));
    // Edges: whole tiles, each stretched a little to fill the run.
    void edge(double len, Matrix4 Function(double offset) place) {
      if (len <= 0) return;
      final n = (len / t).round().clamp(1, 1000);
      final step = len / n;
      for (var i = 0; i < n; i++) {
        draw(_edgeTile, place(t + i * step), along: step / t);
      }
    }

    edge(w - 2 * t, (o) => at(1, 0, 0, 1, o, 0));
    edge(w - 2 * t, (o) => at(1, 0, 0, -1, o, h));
    edge(h - 2 * t, (o) => at(0, 1, 1, 0, 0, o));
    edge(h - 2 * t, (o) => at(0, 1, -1, 0, w, o));
  }

  @override
  bool shouldRepaint(_MadaniBorderPainter o) =>
      o.t != t ||
      o.band != band ||
      o.cut != cut ||
      o.hairline != hairline ||
      o.inner != inner;
}

/// The juzʼ marker for a page's outer margin: on Madani pages the lantern
/// with جزء and the number in its window; on Indo-Pak pages just the text,
/// as those muṣḥafs print it.
class ClassicLantern extends StatelessWidget {
  final double width;
  final String number;
  final Color color, textColor;
  final Color? fill;

  /// Indo-Pak: the text alone.
  final bool plain;
  const ClassicLantern({
    super.key,
    required this.width,
    required this.number,
    required this.color,
    required this.textColor,
    this.fill,
    this.plain = false,
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
    if (plain) {
      return SizedBox(
        width: width,
        child: FittedBox(fit: BoxFit.scaleDown, child: text),
      );
    }
    final art = ClassicArt.lantern;
    final h = width * art.height / art.width;
    final win = ClassicArt.lanternWindow;
    return SizedBox(
      width: width,
      height: h,
      child: CustomPaint(
        painter: _FillPainter(art, color, fill, const [ClassicArt.lanternBody]),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            win.left * width,
            win.top * h,
            (1 - win.right) * width,
            (1 - win.bottom) * h,
          ),
          child: FittedBox(fit: BoxFit.contain, child: text),
        ),
      ),
    );
  }
}

/// The Classic āyah circle as a widget (the reader): [fill] inside its
/// hole, the number centred there.
class ClassicAyahMarker extends StatelessWidget {
  final String numeralAr;
  final double size;
  final Color stroke, fill, textColor;
  final String script;
  const ClassicAyahMarker({
    super.key,
    required this.numeralAr,
    required this.size,
    required this.stroke,
    required this.fill,
    required this.textColor,
    this.script = 'uthmani',
  });

  @override
  Widget build(BuildContext context) {
    final c = ClassicCircle.of(script);
    // [size] is the ring's diameter, as the plain marker's.
    final h = size / c.ringDiameter;
    final w = h * c.art.width / c.art.height;
    final hole = c.holeDiameter * h;
    return SizedBox.square(
      dimension: size,
      child: OverflowBox(
        maxWidth: w,
        maxHeight: h,
        child: Transform.translate(
          offset: Offset(0, (.5 - c.ringCentreY) * h),
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
    circle.art.paint(canvas, Offset.zero & size, stroke);
  }

  @override
  bool shouldRepaint(_MarkerPainter o) =>
      o.circle != circle || o.stroke != stroke || o.fill != fill;
}
