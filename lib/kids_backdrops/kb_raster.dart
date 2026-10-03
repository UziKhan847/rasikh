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
  final BlendMode blendMode;

  /// How opaque the image is drawn, live: changing it repaints only this
  /// image's quad (used to cross-fade a layer into a more blurred copy as the
  /// page scrolls). Null = fully opaque.
  final ValueListenable<double>? opacity;
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
      e.image.dispose();
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
    final key = (widget.cacheKey, size, scale, area, widget.colorFilter);
    if (_entry != null && key == _key) return _entry!;
    _release();
    final e = _shared[key] ??= () {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)
        ..scale(scale)
        ..translate(-area.left, -area.top);
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
        painter: _ImagePainter(e, Size(size.width / held.width, size.height / held.height), widget.blendMode, widget.opacity),
      );
    }
    final e = _acquire(size, dpr);
    return CustomPaint(size: size, painter: _ImagePainter(e, const Size(1, 1), widget.blendMode, widget.opacity));
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
  _ImagePainter(this.e, this.stretch, this.blendMode, this.opacity) : super(repaint: opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final a = (opacity?.value ?? 1).clamp(0.0, 1.0);
    if (a <= 0) return;
    final img = e.image, s = e.scale, r = e.content;
    final w = img.width.toDouble(), h = img.height.toDouble();
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, w, h),
      Rect.fromLTWH(r.left * stretch.width, r.top * stretch.height,
          w / s * stretch.width, h / s * stretch.height),
      // Bilinear: only ever scaling a soft layer up, or showing 1:1.
      Paint()
        ..filterQuality = FilterQuality.low
        ..blendMode = blendMode
        ..color = Color.fromRGBO(255, 255, 255, a),
    );
  }

  @override
  bool shouldRepaint(_ImagePainter o) =>
      o.e != e || o.stretch != stretch || o.blendMode != blendMode || o.opacity != opacity;
}
