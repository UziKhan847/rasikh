import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_parsing/path_parsing.dart';

import 'paths.dart';

/// The muṣḥaf's traced artwork (design handoff): sūrah headers, āyah
/// circles, page borders and the juzʼ lantern, as paths in their SVG
/// units — single-colour ones tinted where they're drawn, the coloured
/// header in its own colours (or a palette's). Each is parsed once.
class ClassicArt {
  final double width, height;

  /// Filled one by one, as the SVG draws its elements, each in [fills].
  final List<Path> paths;
  final List<Color> fills;
  const ClassicArt._(this.width, this.height, this.paths, this.fills);

  static ClassicArt _of(
    ({
      double width,
      double height,
      double dx,
      double dy,
      List<int> fills,
      List<String> d,
    })
    a,
  ) => ClassicArt._(
    a.width,
    a.height,
    [for (final d in a.d) parseSvgPath(d).shift(Offset(a.dx, a.dy))],
    [for (final f in a.fills) Color(f)],
  );

  /// The Madani sūrah header in line art, and in colour.
  static final surahBorder = _of(surahBorderSvg);
  static final surahBorderColoured = _of(surahBorderColouredSvg);
  static final lantern = _of(lanternSvg);
  static final indopakVerseCircle = _of(indopakVerseCircleSvg);

  /// The Indo-Pak header in two tiers (the name over the basmala; the
  /// basmala drawn separately, [indopakBasmala]) …
  static final indopakSurahBorder = _of(indopakSurahBorderSvg);
  static final indopakBasmala = _of(indopakBasmalaSvg);

  /// … and in one (a heading with no basmala under it: al-Fātiḥah,
  /// at-Tawbah, the reader's banner).
  static final indopakSurahHeader = _of(indopakSurahHeaderSvg);
  static final indopakPageBorder = _of(indopakPageBorderSvg);

  double get ratio => width / height;

  /// Draws this artwork into [dst] (stretched to it): every path in
  /// [color], or — without one — each in its own colour, through [palette]
  /// (its colours → replacements).
  void paint(
    Canvas canvas,
    Rect dst, [
    Color? color,
    Map<Color, Color> palette = const {},
  ]) {
    canvas.save();
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / width, dst.height / height);
    final paint = Paint();
    for (var i = 0; i < paths.length; i++) {
      final f = fills[i];
      paint.color = color ?? palette[f] ?? f;
      canvas.drawPath(paths[i], paint);
    }
    canvas.restore();
  }
}

/// [d] (SVG path data) as a Path.
Path parseSvgPath(String d) {
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

/// [box] of the given aspect [ratio] (width ÷ height), as large as fits in
/// [within] and centred there (`BoxFit.contain`), then scaled by [scale]
/// about its centre and moved down by [dy] × its height.
Rect containRect(Rect within, double ratio, {double scale = 1, double dy = 0}) {
  var w = within.width, h = w / ratio;
  if (h > within.height) {
    h = within.height;
    w = h * ratio;
  }
  w *= scale;
  h *= scale;
  return Rect.fromCenter(
    center: within.center + Offset(0, dy * h),
    width: w,
    height: h,
  );
}

/// An artwork drawn [height] tall and widened to a width without
/// distorting it: its ends kept to their proportions and its plain middle
/// lengthened — by stretching a zone of straight lines ([stretch], as
/// fractions of the art's width), or, where the middle has a repeating
/// pattern (the Indo-Pak beads), by repeating a strip of whole periods
/// ([repeat]: its start and width as fractions) as many times as fit.
///
/// [pieces] are what to draw — each a part of the art (fractions of it)
/// and where it goes — and [x] maps a point of the art across onto the
/// widened drawing (where its title boxes land).
class WideArt {
  final Rect bounds;
  final List<(Rect src, Rect dst)> pieces;
  final double Function(double fraction) x;
  const WideArt._(this.bounds, this.pieces, this.x);

  factory WideArt.layout(
    ClassicArt art, {
    required Rect box,
    required double height,
    (double, double)? stretch,
    (double, double)? repeat,
  }) {
    final natural = height * art.ratio;
    final top = box.top + (box.height - height) / 2;
    Rect src(double a, double b) => Rect.fromLTRB(a, 0, b, 1);
    Rect dst(double l, double r) => Rect.fromLTRB(l, top, r, top + height);
    final extra = box.width - natural;
    if (extra <= 0 || (stretch == null && repeat == null)) {
      // Narrower than the art: the whole art, contained.
      final r = containRect(box, art.ratio);
      return WideArt._(r, [(src(0, 1), r)], (f) => r.left + f * r.width);
    }
    if (stretch != null) {
      final (a, b) = stretch;
      final l = box.left, w = box.width;
      final midW = (b - a) * natural + extra;
      final x0 = l + a * natural, x1 = x0 + midW;
      return WideArt._(
        Rect.fromLTWH(l, top, w, height),
        [
          (src(0, a), dst(l, x0)),
          (src(a, b), dst(x0, x1)),
          (src(b, 1), dst(x1, l + w)),
        ],
        (f) => f <= a
            ? l + f * natural
            : f >= b
            ? x1 + (f - b) * natural
            : x0 + (f - a) / (b - a) * midW,
      );
    }
    final (a, p) = repeat!;
    final stripW = p * natural;
    final n = (extra / stripW).floor();
    final w = natural + n * stripW;
    final l = box.left + (box.width - w) / 2;
    final x0 = l + a * natural;
    return WideArt._(
      Rect.fromLTWH(l, top, w, height),
      [
        (src(0, a + p), dst(l, x0 + stripW)),
        for (var i = 1; i <= n; i++)
          (src(a, a + p), dst(x0 + i * stripW, x0 + (i + 1) * stripW)),
        (src(a + p, 1), dst(x0 + (n + 1) * stripW, l + w)),
      ],
      (f) => f <= a + p
          ? l + f * natural
          : l + f * natural + n * stripW,
    );
  }

  /// Draws [art]'s pieces with [paintArt] (which draws the whole art into
  /// the rectangle it's given; each piece clips it).
  void paint(
    Canvas canvas,
    ClassicArt art,
    void Function(Canvas canvas, Rect whole) paintArt,
  ) {
    for (final (s, d) in pieces) {
      // The whole art, scaled so that piece [s] lands on [d].
      final sx = d.width / s.width;
      final whole = Rect.fromLTWH(
        d.left - s.left * sx,
        d.top,
        sx,
        d.height,
      );
      canvas.save();
      // A hair of overlap, so no seam shows between pieces.
      canvas.clipRect(d.inflate(.3));
      paintArt(canvas, whole);
      canvas.restore();
    }
  }

  /// [b] (fractions of the art) on the widened drawing.
  Rect map(Rect b) => Rect.fromLTRB(
    x(b.left),
    bounds.top + b.top * bounds.height,
    x(b.right),
    bounds.top + b.bottom * bounds.height,
  );
}

/// Black and white, for the Mono papers: colour artwork turned to
/// high-contrast grey — white lines on black for the dark ones.
ColorFilter monoFilter({required bool dark}) {
  const k = 1.6;
  const r = .299 * k, g = .587 * k, b = .114 * k;
  const o = 128 * (1 - k);
  return dark
      ? const ColorFilter.matrix([
          -r, -g, -b, 0, 255 - o, //
          -r, -g, -b, 0, 255 - o,
          -r, -g, -b, 0, 255 - o,
          0, 0, 0, 1, 0,
        ])
      : const ColorFilter.matrix([
          r, g, b, 0, o, //
          r, g, b, 0, o,
          r, g, b, 0, o,
          0, 0, 0, 1, 0,
        ]);
}

/// The full-colour artwork (the tiled and thin page frames), decoded once
/// from `assets/ornaments/`. Painters read [image] and repaint on [loaded]
/// when one arrives.
class OrnamentImages {
  OrnamentImages._();

  static final Map<String, ui.Image> _images = {};
  static final Map<String, Future<void>> _loading = {};

  /// Bumps when an image finishes loading.
  static final loaded = ValueNotifier<int>(0);

  /// The image [name], once loaded (starting the load if not).
  static ui.Image? image(String name) {
    final img = _images[name];
    if (img == null) load(name);
    return img;
  }

  static Future<void> load(String name) => _loading[name] ??= () async {
    try {
      final data = await rootBundle.load('assets/ornaments/$name.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _images[name] = frame.image;
      loaded.value++;
    } catch (e) {
      debugPrint('ornament $name: $e');
    }
  }();
}
