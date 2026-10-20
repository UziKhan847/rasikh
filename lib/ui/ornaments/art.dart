import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_parsing/path_parsing.dart';

import 'paths.dart';

/// The muṣḥaf's traced artwork (design handoff, Updates 8–10): sūrah
/// headers, āyah circles, page borders and the juzʼ lantern, as
/// single-colour paths tinted where they're drawn. Each is parsed once.
class ClassicArt {
  final double width, height;

  /// Filled one by one, as the SVG draws its elements.
  final List<Path> paths;
  const ClassicArt._(this.width, this.height, this.paths);

  static ClassicArt _of(
    ({double width, double height, double dx, double dy, List<String> d}) a,
  ) => ClassicArt._(a.width, a.height, [
    for (final d in a.d) parseSvgPath(d).shift(Offset(a.dx, a.dy)),
  ]);

  static final verseCircle = _of(verseCircleSvg);
  static final surahBorder = _of(surahBorderSvg);
  static final lantern = _of(lanternSvg);
  static final indopakVerseCircle = _of(indopakVerseCircleSvg);

  /// The Indo-Pak header in two tiers (the name over the basmala) …
  static final indopakSurahBorder = _of(indopakSurahBorderSvg);

  /// … and in one (a heading with no basmala under it: al-Fātiḥah,
  /// at-Tawbah).
  static final indopakSurahHeader = _of(indopakSurahHeaderSvg);
  static final indopakPageBorder = _of(indopakPageBorderSvg);

  double get ratio => width / height;

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

/// The full-colour artwork (Update 10's tiled frames and their sūrah
/// headers), decoded once from `assets/ornaments/`. Painters read
/// [image] and repaint on [loaded] when one arrives.
class OrnamentImages {
  OrnamentImages._();

  static final Map<String, ui.Image> _images = {};
  static final Map<String, Future<void>> _loading = {};

  /// Bumps when an image finishes loading.
  static final loaded = ValueNotifier<int>(0);

  /// Tiled frame [n] (1–3): a nine-slice, 263×286.
  static String frame(int n) => 'tile_frame_$n';

  /// Tiled sūrah header [n] (1–3), 8.2 : 1.
  static String header(int n) => 'tile_surah_border_$n';

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

  /// Tiled frame [n] and its header, ready before they're drawn.
  static Future<void> preloadTile(int n) =>
      Future.wait([load(frame(n)), load(header(n))]);
}
