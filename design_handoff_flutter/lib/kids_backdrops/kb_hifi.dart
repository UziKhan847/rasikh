// High / Ultra fidelity for KbParallaxBackdrop (port of the prototype's "Fidelity" switch).
//
// High : film grain, per-theme specks (mixed shapes, 3 depths), mist between the hills, phone tilt.
// Ultra: High + god rays, glow on bright specks, rim light on ridge tops, slow sky shimmer,
//        clouds + birds, water glints (wave themes), specks that brighten near the sun and swirl
//        away from the finger, extra blur on far layers while scrolling, soft vignette.
//
// Needs `sensors_plus` in pubspec.yaml (tilt). Everything else is plain Canvas.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'kb_scene.dart';
import 'kb_themes.dart';

enum KbFidelity { standard, high, ultra }

/// Tilt travel in logical px per unit of tilt (-1..1). Front layers move most.
const Map<String, double> kbTiltPx = {'orn': 2, 'far': 6, 'mist0': 8, 'mid': 10, 'mist1': 12, 'near': 15};
/// Mist drift speed, px per second.
const Map<String, double> kbMistDrift = {'mist0': 6, 'mist1': 10};

// ---------------------------------------------------------------- tilt
/// Smoothed tilt in -1..1 on both axes. Two sources:
///  • Phone / tablet: accelerometer (sensors_plus). If it feels backwards on a device, flip the sign of x.
///  • Desktop / web with a mouse: pointer position over the backdrop (centre = 0, edges = ±1), same as the prototype.
///    Fed by KbParallaxBackdrop's Listener.onPointerHover → [pointer]; leaving the window eases back to centre.
/// Once a real sensor reading arrives, mouse input is ignored. Touch drags never drive tilt (they scroll / swipe tabs).
class KbTilt {
  final ValueNotifier<Offset> value = ValueNotifier(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _sub;
  Ticker? _ticker;
  Offset _target = Offset.zero;
  Duration _last = Duration.zero;
  bool _sensor = false;

  bool get running => _ticker != null;

  /// Mouse hover over the backdrop. [local] in the backdrop's coordinates.
  void pointer(Offset local, Size size) {
    if (_sensor || size.isEmpty) return;
    _target = Offset(((local.dx / size.width) - .5) * 2, ((local.dy / size.height) - .5) * 2);
  }

  /// Mouse left the backdrop: ease back to centre.
  void pointerExit() {
    if (!_sensor) _target = Offset.zero;
  }

  void start(TickerProvider vsync) {
    if (running) return;
    final mobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (mobile || kIsWeb) {
      try {
        _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
          _sensor = true;
          // Upright-ish hold: y ≈ 6.9 at 45°. x = side roll.
          _target = Offset((-e.x / 4.5).clamp(-1.0, 1.0), ((e.y - 6.9) / 4.5).clamp(-1.0, 1.0));
        }, onError: (_) {}, cancelOnError: true);
      } catch (_) {/* no sensor (desktop / unsupported browser): mouse only */}
    }
    _last = Duration.zero;
    _ticker = vsync.createTicker((now) {
      final dt = _last == Duration.zero ? 16.0 : (now - _last).inMicroseconds / 1000.0;
      _last = now;
      final k = 1 - math.exp(-dt / 140), v = value.value;
      value.value = v + (_target - v) * k;
    })..start();
  }

  void stop() {
    _sub?.cancel();
    _ticker?.dispose();
    _sub = null;
    _ticker = null;
    _sensor = false;
    _target = Offset.zero;
    value.value = Offset.zero;
  }
}

// ---------------------------------------------------------------- grain
/// Fine moving film grain. Overlay blend: no effect on pure black (OLED stays black).
/// Do NOT wrap in a RepaintBoundary; the overlay must blend with the backdrop below.
class KbGrain extends StatefulWidget {
  final double opacity;
  final bool animate;
  const KbGrain({super.key, required this.opacity, this.animate = true});
  @override
  State<KbGrain> createState() => _KbGrainState();
}

class _KbGrainState extends State<KbGrain> with SingleTickerProviderStateMixin {
  static ui.Image? _img;
  final _off = ValueNotifier<Offset>(Offset.zero);
  late final Ticker _t;
  final _rnd = math.Random();
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    if (_img == null) {
      const n = 160;
      final px = Uint8List(n * n * 4);
      for (var i = 0; i < px.length; i += 4) {
        final v = (128 + (_rnd.nextDouble() - .5) * 110).round();
        px[i] = px[i + 1] = px[i + 2] = v;
        px[i + 3] = 255;
      }
      ui.decodeImageFromPixels(px, n, n, ui.PixelFormat.rgba8888, (img) {
        _img = img;
        if (mounted) setState(() {});
      });
    }
    _t = createTicker((_) {
      if (++_frame % 2 == 0) _off.value = Offset(_rnd.nextDouble() * 80 - 40, _rnd.nextDouble() * 80 - 40);
    });
    if (widget.animate) _t.start();
  }

  @override
  void didUpdateWidget(KbGrain old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_t.isActive) _t.start();
    if (!widget.animate && _t.isActive) _t.stop();
  }

  @override
  void dispose() {
    _t.dispose();
    _off.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _img == null ? const SizedBox.shrink() : IgnorePointer(child: CustomPaint(painter: _GrainPainter(_img!, _off, widget.opacity), size: Size.infinite));
}

class _GrainPainter extends CustomPainter {
  final ui.Image img;
  final ValueListenable<Offset> off;
  final double opacity;
  _GrainPainter(this.img, this.off, this.opacity) : super(repaint: off);
  @override
  void paint(Canvas c, Size size) {
    final o = off.value;
    c.drawRect(Offset.zero & size, Paint()
      ..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, Matrix4Storage.translate(o.dx, o.dy))
      ..color = Color.fromRGBO(255, 255, 255, opacity)
      ..blendMode = BlendMode.overlay);
  }
  @override
  bool shouldRepaint(_GrainPainter o) => o.opacity != opacity || o.img != img;
}

/// Tiny helper so we don't need vector_math imports.
class Matrix4Storage {
  static Float64List translate(double x, double y) => Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, 0, 1]);
}

// ---------------------------------------------------------------- mist
/// Soft mist bands. j = 0 sits in front of the far ridge (behind mid), j = 1 in front of mid (behind near).
/// Pattern repeats every W so the layer can drift forever: paint it 2W + parallax extent wide.
class KbMistPainter extends CustomPainter {
  final KbTheme th;
  final KbPalette P;
  final int j;
  final double W, H, padL;
  KbMistPainter(this.th, this.P, this.j, this.W, this.H, this.padL);
  @override
  void paint(Canvas c, Size size) {
    c.translate(padL, 0);
    final roles = kbRidgeRoles(th), role = roles[roles.length - 2 + j], r = th.ridges[roles.indexOf(role)];
    final yc = r.base * H - H * .012, col = P.dark ? kbMix(P.bot, th.bright, .3) : kbMix(P.bot, kWhite, .6), A = P.dark ? .28 : .5;
    for (var k = -1; k * W < size.width; k++) {
      for (var i = 0; i < 9; i++) {
        final h = i * 13 + j * 7, hx = kbHash(h + 1) * W + k * W, hy = yc + (kbHash(h + 2) - .5) * H * .05, rw = W * (.22 + .2 * kbHash(h + 3));
        c.save();
        c.translate(hx, hy);
        c.scale(1, .2);
        c.drawCircle(Offset.zero, rw, Paint()..shader = ui.Gradient.radial(Offset.zero, rw, [kbC(col, A), kbC(col, A * .45), kbC(col, 0)], [0, .6, 1]));
        c.restore();
      }
    }
  }
  @override
  bool shouldRepaint(KbMistPainter o) => o.th.id != th.id || o.P != P || o.W != W;
}

// ---------------------------------------------------------------- specks
class _Grp {
  final String shape; // dot | disc | hex | spark | ring | flake | petal | leaf | streak
  final int n, col;
  final List<double> size, vx, vy, region;
  final double wob, a;
  final bool tw, glow, spin;
  final int? tier;
  const _Grp(this.shape, this.n, this.col,
      {this.size = const [3, 6], this.vx = const [0, 0], this.vy = const [0, 0], this.region = const [0, 1],
      this.wob = 0, this.a = .8, this.tw = false, this.glow = false, this.spin = false, this.tier});
}

/// Per-theme speck recipe (same values as fxRecipe in the prototype).
List<_Grp> kbFxRecipe(KbTheme th, KbPalette P) {
  final warm = kbMix(th.reward, kWhite, .4), lit = P.dark ? kbMix(th.bright, kWhite, .4) : kbMix(th.reward, kWhite, .55);
  final base = [
    _Grp('hex', 5, lit, size: const [20, 36], vx: const [-4, 4], vy: const [-3, -1], tier: 2, a: .2),
    _Grp('spark', 6, kWhite, size: const [5, 10], vx: const [-2, 2], vy: const [-2, 2], tier: 1, a: .9, tw: true, glow: true),
  ];
  final water = [
    _Grp('ring', 16, kWhite, size: const [4, 10], vx: const [-4, 4], vy: const [-24, -10], wob: 10, a: .75, region: const [.42, 1]),
    _Grp('dot', 12, kWhite, size: const [2.5, 6], vx: const [-6, 6], vy: const [-6, -2], a: .6),
  ];
  List<_Grp> snow(int n) => [
        _Grp('flake', n, kWhite, size: const [4, 10], vx: const [-6, 6], vy: const [16, 34], wob: 14, spin: true, a: .9),
        _Grp('dot', n ~/ 2, kWhite, size: const [2, 4], vx: const [-4, 4], vy: const [18, 30], a: .7),
      ];
  final dust = [
    _Grp('dot', 26, warm, size: const [2, 5], vx: const [-4, 4], vy: const [-5, -1], wob: 8, a: .8),
    _Grp('disc', 6, warm, size: const [9, 18], vx: const [-3, 3], vy: const [-3, -1], a: .26),
  ];
  final Map<String, List<_Grp>> r = {
    'ocean': water, 'lagoon': water, 'sunset': dust, 'sunrise': dust, 'frozen': snow(24), 'snowy': snow(34),
    'desert': [
      _Grp('dot', 40, kbMix(th.reward, 0xFFF1D6, .5), size: const [1.4, 3.2], vx: const [40, 80], vy: const [-4, 4], wob: 6, a: .75, region: const [.3, 1]),
      _Grp('disc', 6, warm, size: const [8, 16], vx: const [10, 20], vy: const [-2, 2], a: .26),
    ],
    'night': [
      _Grp('spark', 18, kWhite, size: const [3, 8], tw: true, a: .9, region: const [0, .5], tier: 0, glow: true),
      _Grp('dot', 12, kbMix(th.reward, kWhite, .5), size: const [2.5, 5], vx: const [-3, 3], vy: const [-4, -1], a: .6),
    ],
    'forest': [
      _Grp('dot', 14, 0xF4FF9A, size: const [3, 7], vx: const [-8, 8], vy: const [-8, 8], wob: 20, tw: true, a: .95, glow: true, region: const [.35, 1]),
      _Grp('leaf', 9, kbMix(th.bright, th.reward, .4), size: const [5, 9], vx: const [6, 16], vy: const [14, 26], wob: 18, spin: true, a: .85),
    ],
    'blossom': [
      _Grp('petal', 18, kbMix(th.bright, kWhite, .45), size: const [4, 8], vx: const [8, 18], vy: const [12, 24], wob: 20, spin: true, a: .9),
      _Grp('dot', 10, warm, size: const [2, 4], vx: const [-3, 3], vy: const [-4, -1], a: .7),
    ],
    'rain': [
      _Grp('streak', 50, kbMix(th.bright, kWhite, .6), size: const [9, 16], vx: const [-30, -30], vy: const [380, 520], a: .5),
      _Grp('ring', 6, kWhite, size: const [4, 8], vx: const [-2, 2], vy: const [-2, 2], a: .3, tier: 2),
    ],
    'cave': [_Grp('dot', 22, th.reward, size: const [2.5, 5.5], vx: const [-3, 3], vy: const [-10, -4], wob: 10, tw: true, glow: true, a: .85)],
  };
  return [...base, ...(r[th.id] ?? dust)];
}

class _Pt {
  final _Grp g;
  final int tier;
  double x, y, s, vx, vy, ph, rot, blur, a, y0, y1;
  double sx = 0, sy = 0, da = 0, ds = 0; // screen position / alpha / size this frame
  _Pt(this.g, this.tier, this.x, this.y, this.s, this.vx, this.vy, this.ph, this.rot, this.blur, this.a, this.y0, this.y1);
}

const _pf = [.35, .6, .9], _tf = [6.0, 12.0, 20.0]; // parallax + tilt per depth tier

/// Speck simulation + Ultra scene life. Owned by KbParallaxBackdrop's state.
class KbFxSystem extends ChangeNotifier {
  final _rnd = math.Random();
  List<_Pt> parts = [];
  String _key = '';
  double t = 0;
  Offset cam = Offset.zero, tilt = Offset.zero;
  Offset? sun; // screen-space sun (light-mode sun themes)
  bool ultra = false;

  void ensure(KbTheme th, KbMode mode, KbPalette P, double W, double H) {
    final k = '${th.id}|$mode|${W.round()}';
    if (k == _key) return;
    _key = k;
    final s = W / kbDesignWidth;
    double rn(List<double> a) => a[0] + _rnd.nextDouble() * (a[1] - a[0]);
    parts = [];
    for (final g in kbFxRecipe(th, P)) {
      for (var i = 0; i < g.n; i++) {
        final tier = g.tier ?? (_rnd.nextDouble() < .3 ? 0 : _rnd.nextDouble() < .72 ? 1 : 2), sp = [.6, 1.0, 1.45][tier];
        parts.add(_Pt(g, tier, _rnd.nextDouble() * W, (g.region[0] + _rnd.nextDouble() * (g.region[1] - g.region[0])) * H,
            rn(g.size) * [.7, 1.0, 1.55][tier] * s, rn(g.vx) * sp * s, rn(g.vy) * sp * s, _rnd.nextDouble() * math.pi * 2, _rnd.nextDouble() * math.pi * 2,
            g.shape == 'streak' ? 0 : [2.5, 0.0, 4.0][tier], (g.a) * [.6, 1.0, .8][tier], g.region[0] * H - 40, g.region[1] * H + 40));
      }
    }
  }

  void step(double dt, double W, double H, {Offset? pointer}) {
    t += dt;
    double mod(double v, double m) => ((v % m) + m) % m;
    for (final p in parts) {
      final g = p.g, wob = g.wob;
      p.x += (p.vx + wob * math.cos(t * .8 + p.ph)) * dt;
      p.y += (p.vy + wob * .6 * math.sin(t * .6 + p.ph * 1.3)) * dt;
      if (g.spin) p.rot += dt * (.6 + p.ph * .15) * (p.ph > 3 ? 1 : -1);
      final span = p.y1 - p.y0;
      if (p.y < p.y0) p.y += span;
      if (p.y > p.y1) p.y -= span;
      p.sx = mod(p.x - cam.dx * _pf[p.tier] - tilt.dx * _tf[p.tier] + 40, W + 80) - 40;
      p.sy = p.y0 + mod(p.y - cam.dy * _pf[p.tier] * .8 - tilt.dy * _tf[p.tier] - p.y0, span);
      if (ultra && pointer != null) {
        final d = p.sx - pointer.dx, e = p.sy - pointer.dy, dd = math.sqrt(d * d + e * e);
        if (dd < 90 && dd > .1) {
          final f = (90 - dd) * math.max(dt, .016) * 5;
          p.x += d / dd * f;
          p.y += e / dd * f;
        }
      }
      var a = p.a, s = p.s;
      if (g.tw) a *= .35 + .65 * math.pow(.5 + .5 * math.sin(t * 2.2 + p.ph * 5), 2);
      if (ultra && sun != null) {
        final d = p.sx - sun!.dx, e = p.sy - sun!.dy, k = math.exp(-(d * d + e * e) / (W * W * .12));
        a = math.min(1, a * (1 + 1.8 * k));
        s *= 1 + .25 * k;
      }
      p.da = a;
      p.ds = s;
    }
    notifyListeners();
  }
}

void _shape(Canvas c, String shape, double r, int col, double a, double blur) {
  final p = Paint()..color = kbC(col, a);
  if (blur > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  switch (shape) {
    case 'dot':
      c.drawCircle(Offset.zero, r, p..shader = ui.Gradient.radial(Offset.zero, r, [kbC(col, a), kbC(col, a * .55), kbC(col, 0)], [0, .55, 1]));
    case 'disc':
      c.drawCircle(Offset.zero, r, Paint()..color = kbC(col, a * .5)..maskFilter = p.maskFilter);
      c.drawCircle(Offset.zero, r, p..style = PaintingStyle.stroke..strokeWidth = r * .08);
    case 'hex':
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final an = i * math.pi / 3 + math.pi / 6;
        i == 0 ? path.moveTo(r * math.cos(an), r * math.sin(an)) : path.lineTo(r * math.cos(an), r * math.sin(an));
      }
      path.close();
      c.drawPath(path, Paint()..color = kbC(col, a * .4)..maskFilter = p.maskFilter);
      c.drawPath(path, p..color = kbC(col, a * .9)..style = PaintingStyle.stroke..strokeWidth = r * .08);
    case 'spark':
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final an = i * math.pi / 4 - math.pi / 2, q = i.isOdd ? r * .16 : r;
        i == 0 ? path.moveTo(q * math.cos(an), q * math.sin(an)) : path.lineTo(q * math.cos(an), q * math.sin(an));
      }
      c.drawPath(path..close(), p);
      c.drawCircle(Offset.zero, r * .5, Paint()..shader = ui.Gradient.radial(Offset.zero, r * .5, [kbC(col, a * .8), kbC(col, 0)]));
    case 'ring':
      c.drawCircle(Offset.zero, r * .85, p..style = PaintingStyle.stroke..strokeWidth = r * .1);
      c.drawCircle(Offset(-r * .35, -r * .35), r * .18, Paint()..color = kbC(col, a * .8));
    case 'flake':
      p..style = PaintingStyle.stroke..strokeWidth = r * .12..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        c.rotate(math.pi / 3);
        c.drawLine(Offset.zero, Offset(0, -r), p);
        c.drawLine(Offset(0, -r * .55), Offset(r * .25, -r * .78), p);
        c.drawLine(Offset(0, -r * .55), Offset(-r * .25, -r * .78), p);
      }
    case 'petal':
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.1), p);
    case 'leaf':
      c.drawPath(Path()..moveTo(-r, 0)..quadraticBezierTo(0, -r * .7, r, 0)..quadraticBezierTo(0, r * .7, -r, 0), p);
    case 'streak':
      c.drawRect(Rect.fromLTRB(-1.2, -r, 1.2, r), Paint()..shader = ui.Gradient.linear(Offset(0, -r), Offset(0, r), [kbC(col, 0), kbC(col, a)]));
  }
}

/// Normal-blend layer: specks, shooting star, clouds, birds.
class KbFxPainter extends CustomPainter {
  final KbFxSystem fx;
  final KbTheme th;
  final KbPalette P;
  KbFxPainter(this.fx, this.th, this.P) : super(repaint: fx);
  @override
  void paint(Canvas c, Size size) {
    final W = size.width, H = size.height, t = fx.t, tl = fx.tilt, cam = fx.cam;
    if (fx.ultra && !P.dark && th.id != 'cave' && th.id != 'rain') {
      // clouds
      for (var i = 0; i < 3; i++) {
        final m = W + 260, y = H * (.07 + .09 * i) - tl.dy * (3 + i);
        final cx = ((kbHash(i + 11) * W + t * (4 + i * 2.5) - cam.dx * (.04 + .02 * i) - tl.dx * (3 + i)) % m + m) % m - 130;
        for (var j = 0; j < 5; j++) {
          final D = 60 + 40 * kbHash(i * 7 + j);
          c.drawOval(Rect.fromCenter(center: Offset(cx + (j - 2) * 34, y + math.sin(j * 1.3) * 10), width: D * .8, height: D * .56),
              Paint()..color = kbC(kWhite, .32 - .06 * i)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        }
      }
      // birds
      const per = 22.0;
      final cyc = (t / per).floor(), q = (t % per) / per;
      if (q < .7) {
        final bx = -40 + (W + 80) * (q / .7), by = H * (.14 + .1 * kbHash(cyc)) - cam.dy * .1 - tl.dy * 5;
        final bp = Paint()..color = kbC(kbMix(th.deep, kBlack, .35), .6)..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round;
        for (var b = 0; b < 4; b++) {
          final ox = bx - b * 16 - cam.dx * .12 - tl.dx * 6, oy = by + (b.isOdd ? 6 : -2) + b * 3, f = math.sin(t * 9 + b * 1.4) * 3.2, w = 5.5 - b * .4;
          c.drawPath(Path()..moveTo(ox - w, oy - f)..quadraticBezierTo(ox - w * .4, oy - f * .2, ox, oy)..quadraticBezierTo(ox + w * .4, oy - f * .2, ox + w, oy - f), bp);
        }
      }
    }
    if (th.stars || th.id == 'night' || (P.dark && P.stars)) {
      const per = 7.0;
      final cyc = (t / per).floor(), q = (t % per) / per;
      if (q < .16) {
        final k = q / .16, x0 = W * (.6 + .3 * kbHash(cyc)), y0 = H * (.04 + .08 * kbHash(cyc + 9)), x1 = x0 - W * .5, y1 = y0 + H * .16;
        final hx = x0 + (x1 - x0) * k, hy = y0 + (y1 - y0) * k, ux = x0 - x1, uy = y0 - y1, n = math.sqrt(ux * ux + uy * uy);
        final tail = Offset(hx + ux / n * 70, hy + uy / n * 70);
        c.drawLine(Offset(hx, hy), tail, Paint()
          ..strokeWidth = 2..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(Offset(hx, hy), tail, [kbC(kWhite, math.sin(k * math.pi)), kbC(kWhite, 0)]));
      }
    }
    for (final p in fx.parts) {
      final rot = p.g.shape == 'streak' ? -math.atan2(p.vx, p.vy) : (p.g.spin ? p.rot : 0.0);
      c.save();
      c.translate(p.sx, p.sy);
      if (rot != 0) c.rotate(rot);
      _shape(c, p.g.shape, p.ds, p.g.col, p.da, p.blur);
      c.restore();
    }
  }
  @override
  bool shouldRepaint(KbFxPainter o) => o.th.id != th.id || o.P != P;
}

/// Screen-blend layer (Ultra): god rays, water glints, halos. Must NOT be inside its own RepaintBoundary.
class KbFxLightPainter extends CustomPainter {
  final KbFxSystem fx;
  final KbTheme th;
  KbFxLightPainter(this.fx, this.th) : super(repaint: fx);
  @override
  void paint(Canvas c, Size size) {
    if (!fx.ultra) return;
    final W = size.width, H = size.height, t = fx.t, sun = fx.sun;
    Paint scr() => Paint()..blendMode = BlendMode.screen;
    if (sun != null) {
      final col = kbMix(th.reward, 0xFFF3D4, .6), len = H * 1.15;
      for (var i = 0; i < 14; i++) {
        final a0 = i * math.pi * 2 / 14 + t * .012 + math.sin(t * .07 + i * 1.7) * .06, w = .045 + .05 * kbHash(i + 3);
        final al = .13 * (.55 + .45 * math.sin(t * .35 + i * 2.1));
        final path = Path()..moveTo(sun.dx, sun.dy)..arcTo(Rect.fromCircle(center: sun, radius: len), a0 - w, w * 2, false)..close();
        c.drawPath(path, scr()..shader = ui.Gradient.radial(sun, len, [kbC(col, al), kbC(col, al * .4), kbC(col, 0)], [W * .04 / len, .5, 1]));
      }
      final wi = th.ridges.indexWhere((r) => r.kind == 'wave');
      if (wi >= 0) {
        final yr = th.ridges[wi].base * H;
        for (var i = 0; i < 22; i++) {
          final dep = kbHash(i * 5 + 1), y = yr + 10 + dep * 110, gx = sun.dx + (kbHash(i * 5 + 2) - .5) * 2 * W * (.05 + .22 * dep) - fx.cam.dx * .1;
          final al = math.pow(math.max(0, math.sin(t * 2.6 + i * 7.3)), 4) * .75 * (1 - dep * .5);
          c.drawOval(Rect.fromCenter(center: Offset(gx, y), width: (6 + dep * 12) * 2, height: (1 + dep * 1.4) * 2), scr()..color = kbC(0xFFF6DC, al.toDouble()));
        }
      }
    }
    for (final p in fx.parts) {
      if (!p.g.glow) continue;
      final r = p.ds * 3.2;
      c.drawCircle(Offset(p.sx, p.sy), r, scr()..shader = ui.Gradient.radial(Offset(p.sx, p.sy), r, [kbC(p.g.col, p.da * .5), kbC(p.g.col, 0)]));
    }
  }
  @override
  bool shouldRepaint(KbFxLightPainter o) => o.th.id != th.id;
}

// ---------------------------------------------------------------- colour helpers
/// Hue rotate (degrees) + brightness, as a ColorFilter.matrix list. Used for the Ultra sky shimmer.
List<double> kbHueBright(double deg, double b) {
  final a = deg * math.pi / 180, cs = math.cos(a), sn = math.sin(a);
  final m = [
    .213 + cs * .787 - sn * .213, .715 - cs * .715 - sn * .715, .072 - cs * .072 + sn * .928,
    .213 - cs * .213 + sn * .143, .715 + cs * .285 + sn * .140, .072 - cs * .072 - sn * .283,
    .213 - cs * .213 - sn * .787, .715 - cs * .715 + sn * .715, .072 + cs * .928 + sn * .072,
  ];
  return [m[0] * b, m[1] * b, m[2] * b, 0, 0, m[3] * b, m[4] * b, m[5] * b, 0, 0, m[6] * b, m[7] * b, m[8] * b, 0, 0, 0, 0, 0, 1, 0];
}

/// Soft vignette (Ultra).
class KbVignette extends StatelessWidget {
  const KbVignette({super.key});
  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -.16), radius: 1.0, colors: [Color(0x00000000), Color(0x00000000), Color(0x4D000000)], stops: [0, .55, 1]),
          ),
        ),
      );
}
