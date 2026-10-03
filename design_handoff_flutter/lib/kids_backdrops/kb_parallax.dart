// Parallax backdrop (port of drawLayers + applyParallax in source/Kids Backdrops.dc.html).
//
// Each layer is painted ONCE into its own RepaintBoundary, sized larger than the screen so it
// can slide without showing an edge. Scrolling/swiping only changes a Transform — no repaint —
// so this is as cheap as a static backdrop. Depth blur is an ImageFiltered on the far/mid layers.
//
//   final camX = ValueNotifier<double>(0);   // tab index * screen width (see KbSwipeTabs)
//   final scrollY = ValueNotifier<double>(0);      // current page's scroll offset
//   final scrollExtent = ValueNotifier<double>(0); // current page's position.maxScrollExtent
//   KbParallaxBackdrop(theme:…, mode:…, style:…, cameraX: camX, scrollY: scrollY, scrollExtent: scrollExtent, child: page)
//
// Vertical travel is progress-based: the layers move across the WHOLE scroll, and reach their
// full travel (kbPlxMaxScrollY) exactly at the bottom of the page. Short pages move 1:1.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'kb_hifi.dart';
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
  /// Sun bloom over the hills (light modes): 0 off, .6 soft, 1 medium, 1.5 strong (default, chosen).
  final double bloom;
  /// Backdrop saturation: 1 = as designed, 1.3 default (chosen), up to 1.5.
  final double saturation;
  /// Standard (v2 look) · High (grain, per-theme specks, mist, tilt) · Ultra (High + light & life effects).
  /// Prototype default: High. Suggest Ultra on newer phones, Standard in battery saver.
  final KbFidelity fidelity;
  /// UI tilt (High/Ultra only): 0 off, 1 subtle (default), 1.6 strong. Turns the whole `child` UI plane
  /// slightly to face the tilt (max 2.5° × k) and floats it (max 5 px × k). Same input as backdrop tilt.
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
  double _W = kbDesignWidth, _H = 844, _cyNow = 0;

  void _updateOx() {
    if (mounted) _moteOx.value = widget.cameraX.value.clamp(0.0, _camMax) * kbParallax['motes']!.x * _on;
  }

  @override
  void initState() {
    super.initState();
    widget.cameraX.addListener(_updateOx);
    _sync();
  }

  @override
  void didUpdateWidget(KbParallaxBackdrop old) {
    super.didUpdateWidget(old);
    if (old.cameraX != widget.cameraX) {
      old.cameraX.removeListener(_updateOx);
      widget.cameraX.addListener(_updateOx);
    }
    _sync();
  }

  void _sync() {
    for (final c in [_motes, _bokeh]) {
      if (!widget.motion) {
        c.stop();
      } else if (!c.isAnimating) {
        c.repeat();
      }
    }
    final hf = widget.fidelity != KbFidelity.standard && widget.style == KbStyle.vivid;
    if (hf && _fxTicker == null) {
      _fxLast = Duration.zero;
      _fxTicker = createTicker(_fxTick)..start();
      _tilt.start(this);
    } else if (!hf && _fxTicker != null) {
      _fxTicker!.dispose();
      _fxTicker = null;
      _tilt.stop();
    }
  }

  void _fxTick(Duration now) {
    final dt = _fxLast == Duration.zero ? 0.0 : (now - _fxLast).inMicroseconds / 1e6;
    _fxLast = now;
    final th = widget.theme, P = kbPalette(th, widget.mode, widget.style), on = _on;
    _fx
      ..ultra = widget.fidelity == KbFidelity.ultra
      ..tilt = _tilt.value.value
      ..cam = Offset(widget.cameraX.value.clamp(0.0, _camMax) * on, _cyNow * on);
    final o = th.orn;
    if (!P.dark && o != null && o.kind == 'sun') {
      final f = kbParallax['orn']!, tk = kbTiltPx['orn']!;
      _fx.sun = Offset((o.hasLight ? o.lx! : o.x) * _W - _fx.cam.dx * f.x - _fx.tilt.dx * tk, (o.hasLight ? o.ly! : o.y) * _H - _fx.cam.dy * f.y - _fx.tilt.dy * tk);
    } else {
      _fx.sun = null;
    }
    _fx.ensure(th, widget.mode, P, _W, _H);
    _fx.step(widget.motion ? math.min(dt, .05) : 0, _W, _H, pointer: _ptr.value);
  }

  @override
  void dispose() {
    widget.cameraX.removeListener(_updateOx);
    _fxTicker?.dispose();
    _tilt.stop();
    _fx.dispose();
    _ptr.dispose();
    _motes.dispose();
    _bokeh.dispose();
    _moteOx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final on = (widget.style == KbStyle.vivid && !reduce) ? widget.strength : 0.0;
    final blur = widget.depthBlur && widget.style == KbStyle.vivid;
    final th = widget.theme, P = kbPalette(th, widget.mode, widget.style);
    return LayoutBuilder(builder: (context, box) {
      final W = box.maxWidth, H = box.maxHeight, s = W / kbDesignWidth;
      final camMax = (widget.tabCount - 1) * W, maxY = kbPlxMaxScrollY;
      final pad = 24.0 * s;
      final hf = widget.fidelity != KbFidelity.standard && widget.style == KbStyle.vivid && !reduce;
      final ultra = hf && widget.fidelity == KbFidelity.ultra;
      _W = W;
      _H = H;
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

      Widget layer(String role, CustomPainter painter, {double padX = 0}) {
        final f = kbParallax[role]!;
        final ew = W + (camMax * f.x * math.max(1, on)).ceilToDouble() + 4, eh = H + (maxY * f.y * math.max(1, on)).ceilToDouble() + 4;
        final lw = role.startsWith('mist') ? ew + W : ew; // mist is 2W wide so it can drift
        Widget w = RepaintBoundary(child: CustomPaint(size: Size(lw + padX * 2, eh + padX), painter: painter));
        final sigma = blur ? (kbDepthBlur[role] ?? 0) * s : 0.0;
        final scrollBlur = ultra && blur ? (kbScrollBlur[role] ?? 0) * s : 0.0;
        Widget blurred(Widget child) {
          final sg = sigma + scrollBlur * (_cyNow / maxY).clamp(0.0, 1.0);
          return sg > 0 ? ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: sg, sigmaY: sg, tileMode: TileMode.decal), child: child) : child;
        }
        if (scrollBlur == 0) w = blurred(w);
        return Positioned(
          left: -padX, top: 0, width: lw + padX * 2, height: eh + padX,
          child: AnimatedBuilder(animation: cam, child: w, builder: (context, child) => Transform.translate(offset: shift(role), child: scrollBlur > 0 ? blurred(child!) : child)),
        );
      }

      final roles = kbRidgeRoles(th);
      final scene = Stack(clipBehavior: Clip.hardEdge, children: [
        Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _SkyPainter(th, P)))),
        layer('orn', _OrnPainter(th, P, W, H)),
        for (var i = 0; i < th.ridges.length; i++) ...[
          if (hf && i >= th.ridges.length - 2) layer('mist${i - (th.ridges.length - 2)}', KbMistPainter(th, P, i - (th.ridges.length - 2), W, H, 20 * s), padX: 20 * s),
          layer(roles[i], _RidgePainter(th, P, i, roles[i], W, H, pad, rim: ultra ? (P.dark ? 0xBED2FF : 0xFFF0D6) : null, rimA: P.dark ? .45 : .9), padX: pad),
        ],
        if (widget.bloom > 0 && widget.style == KbStyle.vivid && kbHasBloom(th, P))
          // No RepaintBoundary here: the screen blend must composite against the ridges below.
          Positioned(
            left: 0, top: 0, width: W + (camMax * kbParallax['orn']!.x).ceilToDouble() + 4, height: H + (maxY * kbParallax['orn']!.y).ceilToDouble() + 4,
            child: AnimatedBuilder(animation: cam, builder: (context, _) => Transform.translate(offset: shift('orn'),
              child: CustomPaint(painter: _BloomPainter(th, W, H, widget.bloom)))),
          ),
        if (!reduce && !hf)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: cam,
              child: RepaintBoundary(child: CustomPaint(painter: KbMotesPainter(th, widget.mode, widget.style, _motes, ox: _moteOx))),
              builder: (context, child) => Transform.translate(offset: Offset(0, -cyNow() * kbParallax['motes']!.y * on), child: child),
            ),
          ),
        if (blur && !reduce)
          Positioned.fill(
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: kbDepthBlur['bokeh']! * s, sigmaY: kbDepthBlur['bokeh']! * s),
                child: RepaintBoundary(child: CustomPaint(painter: _BokehPainter(th, P, _bokeh, _moteOx))),
              ),
            ),
          ),
        if (hf) ...[
          // No RepaintBoundary on these: the light layer screen-blends with the scene below.
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: KbFxPainter(_fx, th, P)))),
          if (ultra) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: KbFxLightPainter(_fx, th)))),
        ],
      ]);
      final sat = widget.saturation;
      Widget backdrop = sat == 1 ? scene : ColorFiltered(colorFilter: ColorFilter.matrix(kbSaturation(sat)), child: scene);
      if (ultra) {
        // slow sky shimmer: ±4° hue, ±2.5% brightness
        backdrop = AnimatedBuilder(animation: _fx, child: backdrop, builder: (context, child) {
          final ss = _fx.t;
          return ColorFiltered(colorFilter: ColorFilter.matrix(kbHueBright(math.sin(ss * math.pi * 2 / 9) * 4, 1 + math.sin(ss * math.pi * 2 / 7) * .025)), child: child);
        });
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
          Positioned.fill(child: backdrop),
          if (hf) Positioned.fill(child: KbGrain(opacity: P.dark ? .22 : .16, animate: widget.motion)),
          if (ultra) const Positioned.fill(child: KbVignette()),
          if (widget.child != null)
            Positioned.fill(
              child: hf && widget.uiTilt > 0
                  ? AnimatedBuilder(
                      animation: _tilt.value,
                      child: widget.child,
                      builder: (context, child) {
                        final t = _tilt.value.value * widget.uiTilt;
                        if (t.distanceSquared < 1e-6) return child!;
                        const deg = 2.5 * math.pi / 180, px = 5.0;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 1 / 1100) // perspective, matches CSS perspective(1100px)
                            ..rotateY(t.dx * deg)
                            ..rotateX(-t.dy * deg)
                            ..translate(t.dx * px * s, t.dy * px * s),
                          child: child,
                        );
                      },
                    )
                  : widget.child!,
            ),
        ]),
      ),
      );
    });
  }
}

class _BloomPainter extends CustomPainter {
  final KbTheme th;
  final double W, H, k;
  _BloomPainter(this.th, this.W, this.H, this.k);
  @override
  void paint(Canvas c, Size size) => kbPaintBloom(c, size, th, W, H, k);
  @override
  bool shouldRepaint(_BloomPainter o) => o.th.id != th.id || o.k != k || o.W != W;
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
  _BokehPainter(this.th, this.P, this.t, this.ox) : super(repaint: Listenable.merge([t, ox]));
  @override
  void paint(Canvas c, Size size) => kbPaintBokeh(c, size, th, P, t.value, ox: ox.value);
  @override
  bool shouldRepaint(_BokehPainter o) => o.th.id != th.id || o.P != P;
}

/// Horizontal swipe between the 5 tabs. The backdrop follows the finger (via [camera]);
/// the page content does NOT slide — on release the new tab fades in (220 ms).
/// Rubber-bands at the first/last tab (x0.3). Threshold 70 px. Camera eases to the tab in ~450 ms.
class KbSwipeTabs extends StatefulWidget {
  final int index, count;
  final ValueChanged<int> onChanged;
  final ValueNotifier<double> camera;
  final Widget child; // current tab page; give it a Key per tab so AnimatedSwitcher fades
  const KbSwipeTabs({super.key, required this.index, this.count = 5, required this.onChanged, required this.camera, required this.child});
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
        _w = box.maxWidth;
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: widget.child,
          ),
        );
      });
}
