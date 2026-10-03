// Parallax backdrop (port of drawLayers + applyParallax in source/Kids Backdrops.dc.html).
//
// Each layer is painted ONCE into its own RepaintBoundary, sized larger than the screen so it
// can slide without showing an edge. Scrolling/swiping only changes a Transform — no repaint —
// so this is as cheap as a static backdrop. Depth blur is an ImageFiltered on the far/mid layers.
// (APP ADAPTATION: in the app the layers are pre-drawn images instead — see layer() below.)
//
//   final camX = ValueNotifier<double>(0);   // tab index * screen width (see KbSwipeTabs)
//   final scrollY = ValueNotifier<double>(0); // current page's scroll offset
//   final scrollExtent = ValueNotifier<double>(0); // current page's position.maxScrollExtent
//   KbParallaxBackdrop(theme:…, mode:…, style:…, cameraX: camX, scrollY: scrollY, scrollExtent: scrollExtent, child: page)
//
// Vertical travel is progress-based: the layers move across the WHOLE scroll, and reach their
// full travel (kbPlxMaxScrollY) exactly at the bottom of the page. Short pages move 1:1.

import 'dart:math' as math;
import 'dart:ui' as ui;
// APP ADAPTATION: not re-exported by widgets.dart/material.dart in this Flutter.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'kb_hifi.dart';
import 'kb_raster.dart';
import 'kb_scene.dart';
import 'kb_themes.dart';

class KbParallaxBackdrop extends StatefulWidget {
  final KbTheme theme;
  final KbMode mode;
  final KbStyle style;
  final ValueListenable<double> cameraX, scrollY;
  /// maxScrollExtent of the current page. Null = legacy behaviour (stops after kbPlxMaxScrollY).
  final ValueListenable<double>? scrollExtent;
  final int tabCount;
  /// 0 = off, .6 subtle, 1 normal (default), 1.6 strong.
  final double strength;
  final bool depthBlur, motion;
  /// Sun bloom: Off 0 · Soft .6 · Medium 1 · Strong 1.5 (default). Light modes, sun themes.
  final double bloom;
  /// Backdrop saturation (1 = none); the design's choice is 1.3.
  final double saturation;
  /// Standard (v2 look) · High (grain, per-theme specks, mist, tilt) · Ultra (High + light & life effects).
  final KbFidelity fidelity;
  /// UI tilt (High/Ultra only): 0 off, 1 subtle (default), 1.6 strong. Turns the `child` slightly to
  /// face the tilt (max 2.5° × k) and floats it (max 5 px × k).
  final double uiTilt;
  final Widget? child;
  const KbParallaxBackdrop({super.key, required this.theme, required this.mode, this.style = KbStyle.vivid, required this.cameraX, required this.scrollY, this.scrollExtent, this.tabCount = 5, this.strength = 1, this.depthBlur = true, this.motion = true, this.bloom = 1.5, this.saturation = 1.3, this.fidelity = KbFidelity.high, this.uiTilt = 1, this.child});
  @override
  State<KbParallaxBackdrop> createState() => _KbParallaxBackdropState();
}

class _KbParallaxBackdropState extends State<KbParallaxBackdrop> with TickerProviderStateMixin {
  late final AnimationController _motes = AnimationController(vsync: this, duration: const Duration(seconds: 24));
  late final AnimationController _bokeh = AnimationController(vsync: this, duration: const Duration(seconds: 60));
  final _moteOx = ValueNotifier<double>(0);
  double _on = 1, _camMax = 0;
  // High / Ultra
  final KbFxSystem _fx = KbFxSystem();
  final KbTilt _tilt = KbTilt();
  final _ptr = ValueNotifier<Offset?>(null);
  Ticker? _fxTicker;
  Duration _fxLast = Duration.zero;
  double _lw = kbDesignWidth, _lh = 844, _cyNow = 0;
  bool _reduce = false;
  // APP ADAPTATION: the Ultra scroll blur cross-fades each soft layer into a more
  // blurred, pre-drawn copy by scroll progress — not a live ImageFiltered.
  late final _scrollK = _Derived(() {
    final y = widget.scrollY.value, ext = widget.scrollExtent?.value ?? 0;
    final cy = ext <= 0 ? y.clamp(0.0, kbPlxMaxScrollY) : (y / ext).clamp(0.0, 1.0) * math.min(kbPlxMaxScrollY, ext);
    return (cy / kbPlxMaxScrollY).clamp(0.0, 1.0) * _on.clamp(0.0, 1.0);
  });
  // APP ADAPTATION: the layer painters' shouldRepaint compares palettes by identity
  // (KbPalette has no ==), so a fresh one each build repainted every layer on any
  // rebuild — a tab change, for one. Reuse it while theme, mode and style hold.
  KbPalette? _p;
  Object? _pKey;
  KbPalette _palette() {
    final key = (widget.theme.id, widget.mode, widget.style);
    if (_p == null || key != _pKey) {
      _p = kbPalette(widget.theme, widget.mode, widget.style);
      _pKey = key;
    }
    return _p!;
  }

  bool get _hf => widget.fidelity != KbFidelity.standard && widget.style == KbStyle.vivid && !_reduce;

  void _updateOx() {
    if (mounted) _moteOx.value = widget.cameraX.value.clamp(0.0, _camMax) * kbParallax['motes']!.x * _on;
  }

  @override
  void initState() {
    super.initState();
    widget.cameraX.addListener(_updateOx);
    _scrollK.listen([widget.scrollY, if (widget.scrollExtent != null) widget.scrollExtent!]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(KbParallaxBackdrop old) {
    super.didUpdateWidget(old);
    if (old.cameraX != widget.cameraX) {
      old.cameraX.removeListener(_updateOx);
      widget.cameraX.addListener(_updateOx);
    }
    if (old.scrollY != widget.scrollY || old.scrollExtent != widget.scrollExtent) {
      _scrollK.listen([widget.scrollY, if (widget.scrollExtent != null) widget.scrollExtent!]);
    }
    _sync();
  }

  void _sync() {
    for (final c in [_motes, _bokeh]) {
      // Under reduce-motion the motes and bokeh are not drawn at all; their
      // clocks must not keep asking for frames either.
      if (!widget.motion || _reduce) {
        c.stop();
      } else if (!c.isAnimating) {
        c.repeat();
      }
    }
    // APP ADAPTATION: the effects' clock and the tilt run only while something can
    // move — not with motion off or under reduce-motion (the handoff's kept ticking).
    final run = _hf && widget.motion;
    if (run && _fxTicker == null) {
      _fxLast = Duration.zero;
      _fxTicker = createTicker(_fxTick)..start();
      _tilt.start(this);
    } else if (!run && _fxTicker != null) {
      _fxTicker!.dispose();
      _fxTicker = null;
      _tilt.stop();
    }
  }

  void _fxTick(Duration now) {
    final dt = _fxLast == Duration.zero ? 0.0 : (now - _fxLast).inMicroseconds / 1e6;
    _fxLast = now;
    final th = widget.theme, P = _palette(), on = _on;
    _fx
      ..ultra = widget.fidelity == KbFidelity.ultra
      ..tilt = _tilt.value.value
      ..cam = Offset(widget.cameraX.value.clamp(0.0, _camMax) * on, _cyNow * on);
    final o = th.orn;
    if (!P.dark && o != null && o.kind == 'sun') {
      final f = kbParallax['orn']!, tk = kbTiltPx['orn']!;
      _fx.sun = Offset((o.hasLight ? o.lx! : o.x) * _lw - _fx.cam.dx * f.x - _fx.tilt.dx * tk, (o.hasLight ? o.ly! : o.y) * _lh - _fx.cam.dy * f.y - _fx.tilt.dy * tk);
    } else {
      _fx.sun = null;
    }
    _fx.ensure(th, widget.mode, P, _lw, _lh);
    _fx.step(math.min(dt, .05), _lw, _lh, pointer: _ptr.value);
  }

  @override
  void dispose() {
    widget.cameraX.removeListener(_updateOx);
    _fxTicker?.dispose();
    _tilt.stop();
    _fx.dispose();
    _ptr.dispose();
    _scrollK.dispose();
    _motes.dispose();
    _bokeh.dispose();
    _moteOx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduce;
    final on = (widget.style == KbStyle.vivid && !reduce) ? widget.strength : 0.0;
    final blur = widget.depthBlur && widget.style == KbStyle.vivid;
    final th = widget.theme, P = _palette();
    // APP ADAPTATION: the scene keeps the height it has without the keyboard. A
    // resizing Scaffold shrinks its body a little every frame the keyboard
    // slides; adding the inset back keeps every layer's size (and so its
    // pre-drawn image) unchanged, instead of re-drawing all of them per frame.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    return LayoutBuilder(builder: (context, box) {
      final W = box.maxWidth, s = W / kbDesignWidth;
      final H = inset > 0 && box.maxHeight + inset <= screenH + .5 ? box.maxHeight + inset : box.maxHeight;
      // APP ADAPTATION: nothing to paint in an empty (or unbounded) box — and the
      // scene's maths divides by W.
      if (!(W > 0 && H > 0 && W.isFinite && H.isFinite)) return widget.child ?? const SizedBox.shrink();
      final camMax = (widget.tabCount - 1) * W, maxY = kbPlxMaxScrollY;
      final pad = 24.0 * s;
      final hf = _hf;
      final ultra = hf && widget.fidelity == KbFidelity.ultra;
      _lw = W;
      _lh = H;
      // APP ADAPTATION: the saturation is baked into each pre-drawn layer (and the
      // motes' colour) rather than a ColorFiltered over the scene, which would be a
      // full-screen offscreen pass every frame. Vivid only: Medium stays soft.
      final sat = !P.orig && widget.saturation != 1 ? ColorFilter.matrix(kbSaturation(widget.saturation)) : null;
      final cam = Listenable.merge([widget.cameraX, widget.scrollY, if (widget.scrollExtent != null) widget.scrollExtent!, if (hf) _tilt.value, if (hf) _fx]);
      double cyNow() {
        final y = widget.scrollY.value, ext = widget.scrollExtent?.value ?? 0;
        if (ext <= 0) return y.clamp(0.0, maxY);
        return (y / ext).clamp(0.0, 1.0) * math.min(maxY, ext);
      }
      _on = on;
      _camMax = camMax;
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateOx());

      Offset shift(String role) {
        final f = kbParallax[role]!;
        final cx = widget.cameraX.value.clamp(0.0, camMax), cy = cyNow();
        _cyNow = cy;
        var o = Offset(-cx * f.x * on, -cy * f.y * on);
        if (hf) {
          o -= _tilt.value.value * ((kbTiltPx[role] ?? 0) * s);
          final d = kbMistDrift[role];
          if (d != null) o -= Offset((_fx.t * d * s) % W, 0);
        }
        return o;
      }

      // APP ADAPTATION: every layer but the sky is drawn into an image ONCE
      // (kb_raster.dart), blur baked in, instead of being replayed by the GPU
      // every frame the motes move — an ImageFiltered blur, a sun's full-screen
      // gradients, or the near ridge's ~150 separate shapes. Stored at:
      //  - 1 px per logical px where the layer is soft anyway (depth-blurred far
      //    ridge, mist, clouds, aurora, an over-exposed sun) — identical once scaled up;
      //  - 1.5 for the lightly blurred mid ridge;
      //  - full density for anything with a crisp edge (near ridge, moon, a sun disc).
      // A ridge is stored from just above its crest down: the clear sky above it
      // is not stored or drawn.
      Widget layer(String role, CustomPainter painter, {double padX = 0, Rect? content, double maxScale = double.infinity, Object? extraKey}) {
        final f = kbParallax[role]!;
        final ew = W + (camMax * f.x * math.max(1, on)).ceilToDouble() + 4, eh = H + (maxY * f.y * math.max(1, on)).ceilToDouble() + 4;
        final lw = role.startsWith('mist') ? ew + W : ew; // mist is 2W wide so it can drift
        final size = Size(lw + padX * 2, eh + padX);
        final sigma = blur ? (kbDepthBlur[role] ?? 0) * s : 0.0;
        final scrollBlur = ultra && blur ? (kbScrollBlur[role] ?? 0) * s : 0.0;
        Widget raster(double sg, {ValueListenable<double>? opacity}) => KbRaster(
              size: size,
              cacheKey: (th.id, widget.mode, widget.style, role, W, H, sg, extraKey),
              maxScale: maxScale,
              content: content,
              colorFilter: sat,
              opacity: opacity,
              paint: (c, sz) {
                if (sg > 0) c.saveLayer(Offset.zero & sz, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sg, sigmaY: sg, tileMode: TileMode.decal));
                painter.paint(c, sz);
                if (sg > 0) c.restore();
              },
            );
        final Widget w;
        if (P.orig) {
          // The soft original style is a few flat shapes: cheap as it is.
          w = RepaintBoundary(child: CustomPaint(size: size, painter: painter));
        } else if (scrollBlur > 0) {
          // Ultra: the further down the page, the softer the far layers — the
          // more-blurred copy fades in over the base one by scroll progress.
          w = RepaintBoundary(child: Stack(children: [raster(sigma), raster(sigma + scrollBlur, opacity: _scrollK)]));
        } else {
          w = RepaintBoundary(child: raster(sigma));
        }
        return Positioned(
          // APP ADAPTATION: keyed by role. Themes have two ridges or three, and
          // unkeyed slots would slide the page into a different slot on a theme
          // change, rebuilding every tab from scratch.
          key: ValueKey('kb.$role'),
          left: -padX, top: 0, width: size.width, height: size.height,
          child: AnimatedBuilder(animation: cam, child: w, builder: (context, child) => Transform.translate(offset: shift(role), child: child)),
        );
      }

      Rect ridgeContent(KbRidge r, Size size, String role) {
        // Above the crest: the rim stroke, grass tufts (≤ 10 px), and the blur's reach.
        final margin = (30 + 3 * (blur ? (kbDepthBlur[role] ?? 0) + (kbScrollBlur[role] ?? 0) : 0)) * s;
        final top = ((r.base - r.amp) * H - margin).clamp(0.0, size.height);
        return Rect.fromLTRB(0, top, size.width, size.height);
      }

      final o = th.orn;
      final overExposed = o != null && o.kind == 'sun' && ((!P.dark && !th.softSun) || (P.dark && th.dusk));
      final softOrn = o != null && (o.kind == 'clouds' || o.kind == 'aurora' || overExposed);
      final rim = ultra ? (P.dark ? 0xBED2FF : 0xFFF0D6) : null;

      final roles = kbRidgeRoles(th);
      final scene = Stack(clipBehavior: Clip.hardEdge, children: [
        Positioned(
          key: const ValueKey('kb.sky'), left: 0, top: 0, width: W, height: H,
          child: RepaintBoundary(
            child: P.orig
                ? CustomPaint(painter: _SkyPainter(th, P))
                // Pre-drawn too, so the saturation can be baked into it.
                : KbRaster(size: Size(W, H), cacheKey: (th.id, widget.mode, widget.style, 'sky', W, H), colorFilter: sat, paint: (c, sz) => kbPaintSky(c, sz, th, P)),
          ),
        ),
        layer('orn', _OrnPainter(th, P, W, H), maxScale: softOrn ? 1 : double.infinity),
        for (var i = 0; i < th.ridges.length; i++) ...[
          // High/Ultra mist: in front of the far ridge (behind mid) and of mid (behind near).
          if (hf && i >= th.ridges.length - 2)
            () {
              final j = i - (th.ridges.length - 2), role = 'mist$j';
              final r = th.ridges[th.ridges.length - 2 + j];
              // The bands sit around the ridge's base: stored only there.
              final yc = r.base * H - H * .012, reach = H * .03 + W * .09 + 12 * s;
              final f = kbParallax[role]!;
              final eh = H + (maxY * f.y * math.max(1, on)).ceilToDouble() + 4;
              return layer(role, KbMistPainter(th, P, j, W, H, 20 * s),
                  padX: 20 * s, maxScale: 1,
                  content: Rect.fromLTRB(0, (yc - reach).clamp(0.0, eh), double.infinity, (yc + reach).clamp(0.0, eh + 20 * s)));
            }(),
          () {
            final role = roles[i];
            final f = kbParallax[role]!;
            final size = Size(W + (camMax * f.x * math.max(1, on)).ceilToDouble() + 4 + pad * 2, H + (maxY * f.y * math.max(1, on)).ceilToDouble() + 4 + pad);
            return layer(role, _RidgePainter(th, P, i, role, W, H, pad, rim: rim, rimA: P.dark ? .45 : .9),
                padX: pad, content: ridgeContent(th.ridges[i], size, role),
                maxScale: role == 'far' ? 1 : role == 'mid' ? 1.5 : double.infinity,
                extraKey: rim);
          }(),
        ],
        // Sun bloom: light bleeding over the ridges in front of the sun, screen-
        // blended above them and moving at the sun's parallax speed. Pre-drawn
        // (soft, so 1 px per logical px) and drawn with `screen` each frame; NOT
        // inside a RepaintBoundary of its own, or it would blend with nothing.
        if (!P.orig && widget.bloom > 0 && kbHasBloom(th, P))
          () {
            final f = kbParallax['orn']!;
            final size = Size(W + (camMax * f.x * math.max(1, on)).ceilToDouble() + 4, H + (maxY * f.y * math.max(1, on)).ceilToDouble() + 4);
            return Positioned(
              key: const ValueKey('kb.bloom'),
              left: 0, top: 0, width: size.width, height: size.height,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: cam,
                  builder: (context, child) => Transform.translate(offset: shift('orn'), child: child),
                  child: KbRaster(
                    size: size,
                    cacheKey: (th.id, widget.mode, widget.style, 'bloom', W, H, widget.bloom),
                    maxScale: 1,
                    colorFilter: sat,
                    blendMode: BlendMode.screen,
                    paint: (c, sz) => kbPaintBloom(c, sz, th, W, H, widget.bloom),
                  ),
                ),
              ),
            );
          }(),
        // High/Ultra replace the motes with the per-theme effects.
        if (!reduce && !hf)
          Positioned.fill(
            key: const ValueKey('kb.motes'),
            child: AnimatedBuilder(
              animation: cam,
              child: RepaintBoundary(child: CustomPaint(painter: KbMotesPainter(th, widget.mode, widget.style, _motes, ox: _moteOx, saturation: P.orig ? 1 : widget.saturation))),
              builder: (context, child) => Transform.translate(offset: Offset(0, -cyNow() * kbParallax['motes']!.y * on), child: child),
            ),
          ),
        // APP ADAPTATION: the bokeh is drawn already soft (see _paintSoftBokeh), not
        // blurred as a full-screen layer every frame.
        if (blur && !reduce)
          Positioned.fill(
            key: const ValueKey('kb.bokeh'),
            child: IgnorePointer(
              child: RepaintBoundary(child: CustomPaint(painter: _BokehPainter(th, P, _bokeh, _moteOx, kbDepthBlur['bokeh']! * s))),
            ),
          ),
        if (hf) ...[
          // No RepaintBoundary on these: the light layer screen-blends with the scene below.
          Positioned.fill(key: const ValueKey('kb.fx'), child: IgnorePointer(child: CustomPaint(painter: KbFxPainter(_fx, th, P)))),
          if (ultra) Positioned.fill(key: const ValueKey('kb.fxLight'), child: IgnorePointer(child: CustomPaint(painter: KbFxLightPainter(_fx, th)))),
        ],
      ]);
      // Ultra: the slow sky shimmer (±4° hue, ±2.5% brightness) — the one filter
      // that has to stay live, since it moves.
      final backdrop = !ultra
          ? scene
          : AnimatedBuilder(
              animation: _fx,
              child: scene,
              builder: (context, child) {
                final ss = _fx.t;
                return ColorFiltered(colorFilter: ColorFilter.matrix(kbHueBright(math.sin(ss * math.pi * 2 / 9) * 4, 1 + math.sin(ss * math.pi * 2 / 7) * .025)), child: child);
              },
            );
      Widget? page = widget.child;
      if (page != null && hf && widget.uiTilt > 0) {
        // APP ADAPTATION: one Transform, always present (identity at rest). The
        // handoff returned the bare page when the tilt was ~0, which swapped the
        // page between two trees each time the phone passed level — losing its
        // scroll and cancelling a drag.
        page = AnimatedBuilder(
          animation: _tilt.value,
          child: page,
          builder: (context, child) {
            final t = _tilt.value.value * widget.uiTilt;
            const deg = 2.5 * math.pi / 180, px = 5.0;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 1 / 1100) // perspective, matches CSS perspective(1100px)
                ..rotateY(t.dx * deg)
                ..rotateX(-t.dy * deg)
                ..translateByDouble(t.dx * px * s, t.dy * px * s, 0, 1),
              child: child,
            );
          },
        );
      }
      return MouseRegion(
        opaque: false,
        onExit: (_) {
          _ptr.value = null;
          _tilt.pointerExit();
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _ptr.value = e.localPosition,
          onPointerMove: (e) => _ptr.value = e.localPosition,
          onPointerUp: (_) => _ptr.value = null,
          onPointerCancel: (_) => _ptr.value = null,
          // Desktop / web mouse: hover drives tilt + the Ultra finger-swirl (no click needed).
          onPointerHover: (e) {
            _ptr.value = e.localPosition;
            if (hf) _tilt.pointer(e.localPosition, Size(W, H));
          },
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned.fill(key: const ValueKey('kb.scene'), child: backdrop),
            if (hf) Positioned.fill(key: const ValueKey('kb.grain'), child: KbGrain(opacity: P.dark ? .22 : .16, animate: widget.motion)),
            if (ultra) const Positioned.fill(key: ValueKey('kb.vignette'), child: KbVignette()),
            if (page != null) Positioned.fill(key: const ValueKey('kb.page'), child: page),
          ]),
        ),
      );
    });
  }
}

/// A value worked out from other listenables, notifying when any of them does.
class _Derived extends ChangeNotifier implements ValueListenable<double> {
  final double Function() compute;
  _Derived(this.compute);
  List<Listenable> _src = const [];
  void listen(List<Listenable> src) {
    for (final l in _src) {
      l.removeListener(notifyListeners);
    }
    _src = src;
    for (final l in _src) {
      l.addListener(notifyListeners);
    }
  }

  @override
  double get value => compute();

  @override
  void dispose() {
    listen(const []);
    super.dispose();
  }
}

class _SkyPainter extends CustomPainter {
  final KbTheme th;
  final KbPalette P;
  _SkyPainter(this.th, this.P);
  @override
  void paint(Canvas c, Size size) => kbPaintSky(c, size, th, P);
  @override
  bool shouldRepaint(_SkyPainter o) => o.th.id != th.id || o.P != P;
}

class _OrnPainter extends CustomPainter {
  final KbTheme th;
  final KbPalette P;
  final double W, H;
  _OrnPainter(this.th, this.P, this.W, this.H);
  @override
  void paint(Canvas c, Size size) {
    c.clipRect(Offset.zero & size);
    kbPaintOrn(c, W, H, th, P);
  }
  @override
  bool shouldRepaint(_OrnPainter o) => o.th.id != th.id || o.P != P || o.W != W || o.H != H;
}

class _RidgePainter extends CustomPainter {
  final KbTheme th;
  final KbPalette P;
  final int i;
  final String role;
  final double W, H, pad;
  /// Ultra rim light: a blurred, tinted copy of the ridge 1.5 px higher, under the ridge (CSS drop-shadow(0 -1.5px 1.2px)).
  final int? rim;
  final double rimA;
  _RidgePainter(this.th, this.P, this.i, this.role, this.W, this.H, this.pad, {this.rim, this.rimA = .9});
  @override
  void paint(Canvas c, Size size) {
    c.clipRect(Offset.zero & size);
    c.translate(pad, 0); // pad keeps the blurred edge off-screen
    if (rim != null) {
      c.saveLayer(null, Paint()
        ..colorFilter = ColorFilter.mode(kbC(rim!, rimA), BlendMode.srcIn)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2));
      c.translate(0, -1.5 * W / kbDesignWidth);
      kbPaintRidge(c, W, H, th, th.ridges[i], i, role, P, xFrom: -pad, xTo: size.width - pad, hE: size.height);
      c.restore();
    }
    kbPaintRidge(c, W, H, th, th.ridges[i], i, role, P, xFrom: -pad, xTo: size.width - pad, hE: size.height);
  }
  @override
  bool shouldRepaint(_RidgePainter o) => o.th.id != th.id || o.P != P || o.W != W || o.H != H || o.rim != rim;
}

class _BokehPainter extends CustomPainter {
  final KbTheme th;
  final KbPalette P;
  final Animation<double> t;
  final ValueListenable<double> ox;
  final double sigma;
  _BokehPainter(this.th, this.P, this.t, this.ox, this.sigma) : super(repaint: Listenable.merge([t, ox]));
  @override
  void paint(Canvas c, Size size) => _paintSoftBokeh(c, size, th, P, t.value, sigma, ox: ox.value);
  @override
  bool shouldRepaint(_BokehPainter o) => o.th.id != th.id || o.P != P || o.sigma != sigma;
}

/// APP ADAPTATION: kbPaintBokeh's specks (same positions, sizes, colours and
/// timing, line for line) drawn as they look after a Gaussian blur of [sigma],
/// instead of blurring the whole layer every frame. A blurred disc is a radial
/// profile, so each speck is one radial gradient through that profile.
void _paintSoftBokeh(Canvas c, Size size, KbTheme th, KbPalette P, double t, double sigma, {double ox = 0}) {
  if (P.orig || sigma <= 0 || size.isEmpty) return;
  final W = size.width, H = size.height, s = W / kbDesignWidth;
  final col = P.dark ? kbMix(th.bright, kWhite, .35) : kbMix(th.reward, kWhite, .55);
  for (var i = 0; i < 6; i++) {
    final h1 = kbHash(i * 17 + 5), h2 = kbHash(i * 17 + 6), h3 = kbHash(i * 17 + 7);
    final span = W * 1.3;
    final x = ((h1 * span - ox * 1.1 + math.sin(tau * (t + h2)) * 30 * s) % span + span) % span - W * .15;
    final y = H * (.52 + h2 * .44) + math.sin(tau * (t * 2 + h3)) * 18 * s, r = (18 + h3 * 22) * s;
    final a = (P.dark ? .22 : .3) * (.55 + .45 * math.sin(tau * (t * 3 + h1)));
    if (a <= 0) continue;
    final prof = _blurredDisc(r / sigma);
    final reach = r + 3 * sigma;
    c.drawCircle(Offset(x, y), reach, Paint()
      ..shader = ui.Gradient.radial(Offset(x, y), reach,
          [for (final (_, v) in prof) kbC(col, a * v)], [for (final (d, _) in prof) d * sigma / reach]));
  }
}

final _discProfiles = <int, List<(double, double)>>{};

/// The radial profile of a unit disc of radius [k] (in sigmas) after a Gaussian
/// blur of sigma 1: (distance from centre in sigmas, coverage 0–1), sampled from
/// the centre to k + 3. Integrated numerically once per size and cached.
List<(double, double)> _blurredDisc(double k) {
  final key = (k * 20).round();
  return _discProfiles[key] ??= () {
    final kk = key / 20;
    const nr = 48, na = 64;
    double at(double d) {
      // coverage at distance d = integral over the disc of the unit Gaussian
      var sum = 0.0;
      for (var i = 0; i < nr; i++) {
        final rho = (i + .5) / nr * kk;
        for (var j = 0; j < na; j++) {
          final th = (j + .5) / na * math.pi;
          final dx = rho * math.cos(th) - d, dy = rho * math.sin(th);
          sum += math.exp(-(dx * dx + dy * dy) / 2) * rho;
        }
      }
      // polar area element (rho drho dth), both half-planes, / (2 pi)
      return sum * (kk / nr) * (math.pi / na) * 2 / (2 * math.pi);
    }
    final end = kk + 3;
    return [for (var n = 0; n <= 14; n++) (end * n / 14, at(end * n / 14).clamp(0.0, 1.0))];
  }();
}

/// Horizontal swipe between the 5 tabs. The backdrop follows the finger (via [camera]);
/// the page content does NOT slide — on release the new tab fades in (220 ms).
/// Rubber-bands at the first/last tab (x0.3). Threshold 70 px. Camera eases to the tab in ~450 ms.
class KbSwipeTabs extends StatefulWidget {
  final int index, count;
  final ValueChanged<int> onChanged;
  final ValueNotifier<double> camera;
  final Widget child; // current tab page; give it a Key per tab so AnimatedSwitcher fades
  /// APP ADAPTATION: false turns the drag off — tabs change only from the nav bar,
  /// which still eases the camera across.
  final bool swipe;
  const KbSwipeTabs({super.key, required this.index, this.count = 5, required this.onChanged, required this.camera, required this.child, this.swipe = true});
  @override
  State<KbSwipeTabs> createState() => _KbSwipeTabsState();
}

class _KbSwipeTabsState extends State<KbSwipeTabs> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  double _dx = 0, _from = 0, _to = 0, _w = 390;

  @override
  void initState() {
    super.initState();
    _a.addListener(() => widget.camera.value = _from + (_to - _from) * Curves.easeOutCubic.transform(_a.value));
  }

  @override
  void didUpdateWidget(KbSwipeTabs old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _animateTo(widget.index); // nav-bar taps animate too
  }

  void _animateTo(int i) {
    _from = widget.camera.value;
    _to = i * _w;
    _a.forward(from: 0);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        // APP ADAPTATION: after a rotation or a resize the camera would still be
        // aimed at index × the OLD width — re-aim it (after this frame: this runs
        // during layout, and moving the camera rebuilds the layers).
        if (box.maxWidth != _w && !_a.isAnimating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_a.isAnimating) widget.camera.value = widget.index * _w;
          });
        }
        _w = box.maxWidth;
        final fade = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          child: widget.child,
        );
        if (!widget.swipe) return fade;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) {
            _a.stop();
            _dx = 0;
          },
          onHorizontalDragUpdate: (d) {
            _dx += d.delta.dx;
            final atEdge = (widget.index == 0 && _dx > 0) || (widget.index == widget.count - 1 && _dx < 0);
            widget.camera.value = widget.index * _w - (atEdge ? _dx * .3 : _dx);
          },
          onHorizontalDragEnd: (_) {
            final n = _dx < -70 ? widget.index + 1 : _dx > 70 ? widget.index - 1 : widget.index;
            if (n != widget.index && n >= 0 && n < widget.count) {
              widget.onChanged(n);
            } else {
              _animateTo(widget.index);
            }
          },
          child: fade,
        );
      });
}
