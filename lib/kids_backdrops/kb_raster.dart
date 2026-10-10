// APP ADAPTATION (not in the handoff): paint once into an image, then show the image.
//
// A RepaintBoundary keeps a layer from being RE-RECORDED, but Flutter's
// renderer (Impeller) still replays the recorded drawing on the GPU every frame
// the screen changes, and the motes change it every frame. For flat shapes that
// is cheap; for a blur filter, a path of hundreds of segments or a full-screen
// gradient it is not. Drawing the finished layer into an image once makes the
// per-frame cost a single textured quad.
//
// A layer that is blurred anyway loses nothing when stored at fewer pixels than
// the screen has, which keeps the wide parallax layers' memory small: pass a
// lower [KbRaster.maxScale] for those.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

/// Paints [paint] once, at [size], into an image and shows that image.
///
/// Re-paints only when [cacheKey], the size or the device pixel ratio changes.
/// With a finite [size] it is that big; with null it fills its constraints.
///
/// Identical images are shared: every KbRaster with the same key, size, scale
/// and [content] holds the one image (the tab shell's scene, a stage screen and
/// the lesson above it are the same picture).
class KbRaster extends StatefulWidget {
  final Size? size;
  final Object cacheKey;
  final void Function(Canvas canvas, Size size) paint;

  /// Image pixels per logical pixel, at most (the device pixel ratio caps it).
  final double maxScale;

  /// The part of the layer that has anything in it, in logical pixels. Only
  /// that part is stored and drawn, so a layer that is mostly clear sky costs
  /// what its hills cover rather than a whole screen of transparent pixels.
  /// Null = all of it.
  final Rect? content;

  /// Applied to the whole layer as it is pre-drawn (the backdrop's saturation)
  /// — once, not every frame.
  final ColorFilter? colorFilter;

  /// How the finished image is drawn onto what is beneath it — `screen` for
  /// the sun's bloom. A layer with a blend mode must not have a repaint
  /// boundary of its own, or it would blend with nothing.
  ///
  /// `screen` is not drawn as one `screen` draw: see [KbLight]. The image is
  /// stored opaque (its premultiplied colour on black) for that.
  final BlendMode blendMode;

  /// How opaque the image is drawn, live: changing it repaints only this
  /// image's quad (used to cross-fade a layer into a more blurred copy as the
  /// page scrolls). Null = fully opaque.
  final ValueListenable<double>? opacity;

  /// A colour matrix (as for [ColorFilter.matrix], with no offset column)
  /// applied live as the image is drawn — Ultra's slow sky shimmer. Changing
  /// it repaints only this image's quad: no offscreen pass. A `screen` layer
  /// cannot carry a colour filter on its draws (see [KbLight]), so it bakes
  /// the matrix into its light instead, again each time it has moved by more
  /// than a shade.
  final ValueListenable<List<double>?>? liveMatrix;
  const KbRaster({
    super.key,
    this.size,
    required this.cacheKey,
    required this.paint,
    this.maxScale = double.infinity,
    this.content,
    this.colorFilter,
    this.blendMode = BlendMode.srcOver,
    this.opacity,
    this.liveMatrix,
  });

  /// No image side goes past this: larger textures fail to upload on many
  /// GPUs. A layer that would need more is stored at a lower scale.
  static const maxTexture = 4096.0;

  /// A size change (a window being dragged) waits this long before the image
  /// is painted again at the new size; until then the last one is stretched.
  static const settle = Duration(milliseconds: 150);

  @override
  State<KbRaster> createState() => _KbRasterState();
}

class _Entry {
  final ui.Image image;
  final double scale;
  final Rect content;
  int refs = 0;
  _Entry(this.image, this.scale, this.content);

  // A screen layer's light: as stored, and with the last live matrix baked in.
  KbLight? _plain, _tinted;
  List<double>? _tint;

  KbLight light(List<double>? m) {
    if (m == null) return _plain ??= KbLight.of(image);
    final t = _tint;
    if (_tinted == null || t == null || !_close(t, m)) {
      _tinted?.dispose();
      _tinted = KbLight.of(image, m);
      _tint = m;
    }
    return _tinted!;
  }

  /// Whether colour matrices [a] and [b] differ by under a shade on any
  /// channel — the shimmer moves its matrix by about this every tenth of a
  /// second at its fastest.
  static bool _close(List<double> a, List<double> b) {
    for (final i in const [0, 1, 2, 5, 6, 7, 10, 11, 12]) {
      if ((a[i] - b[i]).abs() > .006) return false;
    }
    return true;
  }

  void dispose() {
    image.dispose();
    _plain?.dispose();
    _tinted?.dispose();
  }
}

final _shared = <Object, _Entry>{};

class _KbRasterState extends State<KbRaster> {
  Object? _key;
  _Entry? _entry;

  /// Logical size the held image was painted for.
  Size? _paintedFor;
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    _release();
    super.dispose();
  }

  void _release() {
    final e = _entry, k = _key;
    if (e == null) return;
    if (--e.refs == 0) {
      e.dispose();
      if (identical(_shared[k], e)) _shared.remove(k);
    }
    _entry = null;
    _key = null;
  }

  _Entry _acquire(Size size, double dpr) {
    final content =
        (widget.content ?? Offset.zero & size).intersect(Offset.zero & size);
    final area = content.isEmpty ? const Rect.fromLTWH(0, 0, 1, 1) : content;
    final scale = [
      dpr,
      widget.maxScale,
      KbRaster.maxTexture / area.width,
      KbRaster.maxTexture / area.height,
    ].reduce(math.min);
    final opaque = widget.blendMode == BlendMode.screen;
    final key = (widget.cacheKey, size, scale, area, widget.colorFilter, opaque);
    if (_entry != null && key == _key) return _entry!;
    _release();
    final e = _shared[key] ??= () {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)
        ..scale(scale)
        ..translate(-area.left, -area.top);
      // A screen layer is stored on black: see [KbRaster.blendMode].
      if (opaque) c.drawRect(area, Paint()..color = const Color(0xFF000000));
      final cf = widget.colorFilter;
      if (cf != null) c.saveLayer(area, Paint()..colorFilter = cf);
      widget.paint(c, size);
      if (cf != null) c.restore();
      final pic = rec.endRecording();
      final img = pic.toImageSync(
        math.max(1, (area.width * scale).ceil()),
        math.max(1, (area.height * scale).ceil()),
      );
      pic.dispose();
      return _Entry(img, scale, area);
    }();
    e.refs++;
    _entry = e;
    _key = key;
    _paintedFor = size;
    return e;
  }

  Widget _show(Size size) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final held = _paintedFor;
    // A new size while an image is already up (a window being resized, a
    // rotation): stretch the old one until the size holds still, rather than
    // painting a fresh image every frame of the drag.
    if (_entry != null && held != null && held != size) {
      _settle?.cancel();
      _settle = Timer(KbRaster.settle, () {
        if (mounted) setState(() => _paintedFor = null);
      });
      final e = _entry!;
      return CustomPaint(
        size: size,
        painter: _ImagePainter(e, Size(size.width / held.width, size.height / held.height), widget.blendMode, widget.opacity, widget.liveMatrix),
      );
    }
    final e = _acquire(size, dpr);
    return CustomPaint(size: size, painter: _ImagePainter(e, const Size(1, 1), widget.blendMode, widget.opacity, widget.liveMatrix));
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (size != null) return _show(size);
    return LayoutBuilder(builder: (context, c) => _show(c.biggest));
  }
}

class _ImagePainter extends CustomPainter {
  final _Entry e;

  /// Extra stretch while a resize settles; (1, 1) otherwise.
  final Size stretch;
  final BlendMode blendMode;
  final ValueListenable<double>? opacity;
  final ValueListenable<List<double>?>? liveMatrix;
  _ImagePainter(this.e, this.stretch, this.blendMode, this.opacity, this.liveMatrix)
      : super(repaint: Listenable.merge([opacity, liveMatrix]));

  @override
  void paint(Canvas canvas, Size size) {
    final a = (opacity?.value ?? 1).clamp(0.0, 1.0);
    if (a <= 0) return;
    final img = e.image, s = e.scale, r = e.content;
    final w = img.width.toDouble(), h = img.height.toDouble();
    final src = Rect.fromLTWH(0, 0, w, h),
        dst = Rect.fromLTWH(r.left * stretch.width, r.top * stretch.height,
            w / s * stretch.width, h / s * stretch.height);
    final m = liveMatrix?.value;
    if (blendMode == BlendMode.screen) {
      e.light(m).screen(canvas, dst, a);
      return;
    }
    canvas.drawImageRect(
        img,
        src,
        dst,
        // Bilinear: only ever scaling a soft layer up, or showing 1:1.
        Paint()
          ..filterQuality = FilterQuality.low
          ..blendMode = blendMode
          ..color = Color.fromRGBO(255, 255, 255, a)
          ..colorFilter = m == null ? null : ColorFilter.matrix(m));
  }

  @override
  bool shouldRepaint(_ImagePainter o) =>
      o.e != e || o.stretch != stretch || o.blendMode != blendMode || o.opacity != opacity || o.liveMatrix != liveMatrix;
}

/// APP ADAPTATION: a light screened onto the scene — the sun's bloom, the god
/// rays, the water glints, the glow halos — without a `screen` draw.
///
/// `screen` is an "advanced" blend: each draw has to read what is already on
/// screen, which on many phones means a copy of the frame per draw. Screen is
/// `s + d·(1 − s)`, so it is two cheap blends instead: `modulate` by
/// `1 − s` ([inverse]), then `plus` `s` ([light]). Same pixels, give or take
/// rounding, over an opaque scene (which a backdrop always is).
///
/// Neither draw may carry a colour filter: Impeller draws an image with a
/// colour matrix through a fast path that ignores the paint's blend mode, so
/// the inverse is baked into its own image, and an alpha below 1 goes through
/// the paint (for `plus`) or a `drawAtlas` colour (for `modulate`), both of
/// which keep their blend.
class KbLight {
  /// The light's premultiplied colour, opaque on black; and `1 − light`.
  final ui.Image light, inverse;
  KbLight._(this.light, this.inverse);

  /// From [onBlack] (the light's colour on black, opaque), with colour matrix
  /// [m] baked in when given. [onBlack] stays the caller's.
  factory KbLight.of(ui.Image onBlack, [List<double>? m]) => KbLight._(
        m == null ? onBlack.clone() : _bake(onBlack, kbScreenMatrix(m, 1, 0)),
        _bake(onBlack, kbScreenMatrix(m, -1, 255)),
      );

  static ui.Image _bake(ui.Image src, List<double> matrix) {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImage(src, Offset.zero, Paint()..colorFilter = ColorFilter.matrix(matrix));
    final pic = rec.endRecording();
    final img = pic.toImageSync(src.width, src.height);
    pic.dispose();
    return img;
  }

  /// Screens the light onto [c] at [dst], at alpha [a]. With [a] below 1,
  /// [dst] must have the image's proportions.
  void screen(Canvas c, Rect dst, [double a = 1]) {
    final src = Rect.fromLTWH(0, 0, light.width.toDouble(), light.height.toDouble());
    // Bilinear: only ever scaling a soft light up, or showing it 1:1.
    final mod = Paint()
      ..filterQuality = FilterQuality.low
      ..blendMode = BlendMode.modulate;
    if (a >= 1) {
      c.drawImageRect(inverse, src, dst, mod);
    } else {
      // 1 − a·x = screen(1 − a, 1 − x): the colour blend is worked out
      // between the colour and the texture, in the shader.
      final g = 1 - a, k = dst.width / src.width;
      c.drawAtlas(inverse, [RSTransform(k, 0, dst.left, dst.top)], [src],
          [Color.from(alpha: 1, red: g, green: g, blue: g)], BlendMode.screen, null, mod);
    }
    c.drawImageRect(
        light,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.low
          ..blendMode = BlendMode.plus
          ..color = Color.fromRGBO(255, 255, 255, a));
  }

  void dispose() {
    light.dispose();
    inverse.dispose();
  }
}

/// The colour matrix that draws an opaque image's colour `x` as
/// `offset + k·M·x` in each colour channel, alpha 1 — [M] a 3×3 colour matrix
/// in [ColorFilter.matrix] form with no offsets (null = identity), [offset] in
/// 0…255. Used only to bake [KbLight]s, never on a draw with a blend mode.
List<double> kbScreenMatrix(List<double>? m, double k, double offset) => [
      for (var row = 0; row < 3; row++) ...[
        for (var col = 0; col < 3; col++)
          k * (m == null ? (row == col ? 1.0 : 0.0) : m[row * 5 + col]),
        0,
        offset,
      ],
      0, 0, 0, 0, 255,
    ];
