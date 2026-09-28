// Line-by-line port of drawScene / drawMotes from Kids Backdrops.dc.html.
// Canvas 2D -> Flutter mapping used throughout:
//   createLinearGradient      -> ui.Gradient.linear
//   createRadialGradient      -> ui.Gradient.radial (r0/r1 folded into stops; off-centre -> focal)
//   ctx.filter = blur(Npx)    -> MaskFilter.blur(BlurStyle.normal, N)
//   setLineDash               -> _dash()
//   destination-out           -> saveLayer + BlendMode.dstOut
//   globalAlpha               -> multiplied into the colour alpha
// Keep function and variable names aligned with the JS so diffs stay readable.
// Do NOT "simplify" constants — every number is tuned against the reference PNGs.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'kb_themes.dart';

const double kbDesignWidth = 390; // JS const S
const double tau = math.pi * 2;
const int kWhite = 0xFFFFFF;
const int kBlack = 0x000000;

enum KbMode { light, dark, oled }

enum KbStyle { vivid, original }

double kbHash(num n) {
  final s = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return s - s.floorToDouble();
}

int _ch(int c, int sh) => (c >> sh) & 255;

/// JS mix(a,b,t) on 0xRRGGBB ints.
int kbMix(int a, int b, double t) {
  int m(int sh) => (_ch(a, sh) + (_ch(b, sh) - _ch(a, sh)) * t).round().clamp(0, 255).toInt();
  return (m(16) << 16) | (m(8) << 8) | m(0);
}

/// JS rgba(hex, a) / solid colour.
Color kbC(int rgb, [double a = 1]) =>
    Color.fromRGBO(_ch(rgb, 16), _ch(rgb, 8), _ch(rgb, 0), a.clamp(0.0, 1.0).toDouble());

double _lin(int v) {
  final x = v / 255;
  return x <= .03928 ? x / 12.92 : math.pow((x + .055) / 1.055, 2.4).toDouble();
}

double kbLum(int rgb) => .2126 * _lin(_ch(rgb, 16)) + .7152 * _lin(_ch(rgb, 8)) + .0722 * _lin(_ch(rgb, 0));

double kbYAt(String k, double b, double A, double wl, double ph, double x, int seed) {
  switch (k) {
    case 'wave':
      final t = x / wl + ph;
      return b - (.62 * A * math.sin(tau * t) + .38 * A * math.sin(2 * tau * t + 1.1));
    case 'dune':
      var t = x / wl + ph;
      t -= t.floorToDouble();
      final u = t < .35 ? t / .35 * .5 : .5 + (t - .35) / .65 * .5;
      return b - A * (.5 - .5 * math.cos(tau * u));
    case 'hill':
      final t = x / wl + ph;
      final n = t.floor();
      final f = t - n;
      return b - A * (n.abs() % 2 == 1 ? .68 : 1.0) * math.sin(math.pi * f);
    case 'crag':
      final sp = wl / 6, t = x / sp + ph * 6;
      final i = t.floor();
      final f = t - i, h0 = kbHash(seed + i), h1 = kbHash(seed + i + 1);
      return b - A * (.35 + .65 * (h0 + (h1 - h0) * f));
  }
  // 'tree' and 'ice'
  final ice = k == 'ice';
  final sp = wl / (ice ? 8.0 : 7.0), w = sp * (ice ? .45 : .62);
  var y = b;
  final j0 = (x / sp).floor();
  for (var j = j0 - 2; j <= j0 + 2; j++) {
    final cx = (j + .5) * sp + (kbHash(seed + j) - .5) * sp * .4, d = (x - cx).abs();
    if (d < w) {
      final h = A * (.45 + .55 * kbHash(seed * 7 + j + 3));
      y = math.min(y, b - h * (1 - d / w));
    }
  }
  return y;
}

class KbPalette {
  final bool orig, dark, stars;
  final int base, top, bot, far, midC, nearC;
  final int? mid;
  final int midHi, nearHi, rim, nearRim, orn, ornCore;
  final double k, halo;
  final Color haze;
  const KbPalette({
    this.orig = false, required this.dark, required this.stars,
    required this.base, required this.top, this.mid, required this.bot,
    required this.far, required this.midC, required this.nearC,
    this.midHi = 0, this.nearHi = 0, this.rim = 0, this.nearRim = 0, this.orn = 0, this.ornCore = 0,
    this.k = 1, this.halo = 0, this.haze = const Color(0x00000000),
  });
}

KbPalette kbPalette(KbTheme th, KbMode mode, KbStyle style) {
  final L = mode == KbMode.light, o = mode == KbMode.oled;
  final base = L ? th.bg : o ? kBlack : th.dark;
  if (style == KbStyle.original) {
    final tint = th.id == 'desert' ? th.reward : th.accent;
    final st = L ? [.028, .07, .10, .17, .26] : [.02, .05, .07, .12, .19];
    return KbPalette(
      orig: true, base: base, top: kbMix(base, tint, st[0]), bot: kbMix(base, tint, st[1]),
      far: kbMix(base, th.accent, st[2]), midC: kbMix(base, th.accent, st[3]), nearC: kbMix(base, th.accent, st[4]),
      k: L ? 1 : .42, dark: !L, stars: th.stars,
    );
  }
  final tt = th.color(th.skyTop ?? 'accent');
  if (L) {
    final top = kbMix(kbMix(tt, th.bright, .3), th.deep, .42), bot = kbMix(th.color(th.skyBot ?? 'bright'), kWhite, .5);
    return KbPalette(
      base: base, top: top, mid: kbMix(top, bot, .35), bot: bot, far: kbMix(bot, th.accent2, .4),
      midC: kbMix(th.accent, th.deep, .15), midHi: kbMix(th.accent, th.bright, .5),
      nearC: kbMix(th.deep, kBlack, .22), nearHi: kbMix(th.deep, th.accent, .5),
      rim: kbMix(th.bright, kWhite, .35), nearRim: kbMix(th.bright, th.reward, .35),
      orn: th.reward, ornCore: kbMix(th.reward, kWhite, .65), halo: .55,
      haze: kbC(kWhite, .3), stars: th.stars, dark: false,
    );
  }
  final b0 = o ? kBlack : base, top = o ? kBlack : kbMix(base, kBlack, .35), bot = kbMix(base, th.accent, o ? .4 : .5);
  return KbPalette(
    base: base, top: top, mid: kbMix(top, bot, .3), bot: bot, far: kbMix(b0, th.accent2, .42),
    midC: kbMix(b0, th.deep, .6), midHi: kbMix(base, th.accent, .55),
    nearC: o ? kBlack : kbMix(base, kBlack, .55), nearHi: kbMix(b0, th.deep, .5),
    rim: kbMix(th.bright, base, .3), nearRim: th.bright,
    orn: kbMix(th.reward, kWhite, .25), ornCore: kbMix(th.reward, kWhite, .75), halo: .35,
    haze: kbC(th.accent, .12), stars: true, dark: true,
  );
}

Path _dash(Path src, double on, double off) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0;
    var draw = true;
    while (d < m.length) {
      final len = draw ? on : off;
      if (draw) out.addPath(m.extractPath(d, math.min(d + len, m.length)), Offset.zero);
      d += len;
      draw = !draw;
    }
  }
  return out;
}

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double w, {StrokeCap cap = StrokeCap.round}) => Paint()
  ..style = PaintingStyle.stroke
  ..color = c
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round;

/// Concentric radial gradient with inner radius r0 (canvas semantics).
Shader _radial(Offset c, double r0, double r1, Color c0, Color c1) =>
    ui.Gradient.radial(c, r1, [c0, c1], [r1 <= 0 ? 0 : r0 / r1, 1]);

void _crescent(Canvas c, Offset ctr, double R, Color c1, Color c2) {
  c.saveLayer(Rect.fromCircle(center: ctr, radius: R * 1.25), Paint());
  c.drawCircle(ctr, R, Paint()
    ..shader = ui.Gradient.radial(ctr, R, [c1, c2], null, TileMode.clamp, null, ctr + Offset(-.3 * R, .2 * R), .1 * R));
  c.drawCircle(ctr + Offset(.52 * R, -.20 * R), .95 * R, Paint()..blendMode = BlendMode.dstOut);
  c.restore();
}

void _drawOrn(Canvas c, double W, double H, KbTheme th, KbPalette P, double s) {
  final o = th.orn;
  if (o == null || (P.orig && o.isNew)) return;
  final cx = o.x * W, cy = o.y * H, R = o.r * W, ctr = Offset(cx, cy);

  if (o.kind == 'shafts') {
    c.drawRect(Rect.fromLTWH(0, 0, W, H * .5),
        Paint()..shader = ui.Gradient.radial(ctr, 150 * s, [P.dark ? kbC(th.bright, .25) : kbC(kWhite, .6), kbC(kWhite, 0)]));
    for (var i = 0; i < 5; i++) {
      final a = (o.a0 ?? .62) + i * .17, sp = .03 + kbHash(i + 4) * .03, lr = H * .8;
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx + math.cos(a - sp) * lr, cy + math.sin(a - sp) * lr)
        ..lineTo(cx + math.cos(a + sp) * lr, cy + math.sin(a + sp) * lr)
        ..close();
      final end = Offset(cx + math.cos(a) * lr, cy + math.sin(a) * lr);
      c.drawPath(path, Paint()..shader = ui.Gradient.linear(ctr, end, [P.dark ? kbC(th.bright, .18) : kbC(kWhite, .34), kbC(kWhite, 0)]));
    }
    return;
  }
  if (o.kind == 'clouds') {
    final blur = MaskFilter.blur(BlurStyle.normal, 5 * s);
    for (var i = 0; i < 7; i++) {
      final x0 = kbHash(i + 11) * W, y0 = H * (.27 + kbHash(i + 23) * .16);
      for (var j = 0; j < 4; j++) {
        final r = (26 + kbHash(i * 7 + j) * 26) * s, x = x0 + (j - 1.5) * 30 * s;
        c.drawCircle(Offset(x, y0 - kbHash(i * 3 + j) * 14 * s), r, _fill(P.dark ? kbC(kWhite, .07) : kbC(kWhite, .2))..maskFilter = blur);
        c.drawCircle(Offset(x, y0 + r * .55), r * .8, _fill(kbC(kBlack, .07))..maskFilter = blur);
      }
    }
    return;
  }
  if (o.kind == 'aurora') {
    final bands = [[th.reward, .22, .0], [th.bright, .29, 1.7], [th.accent2, .36, 3.1]];
    for (var j = 0; j < bands.length; j++) {
      final col = bands[j][0] as int, yy = bands[j][1] as double, ph = bands[j][2] as double;
      final path = Path();
      for (double x = 0; x <= W; x += 6 * s) {
        final y = H * yy + math.sin(x / W * tau * 1.2 + ph) * H * .03 + math.sin(x / W * tau * 2.7 + ph * 2) * H * .012;
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      c.drawPath(path, _stroke(kbC(kWhite), (22 - j * 4) * s)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * s)
        ..shader = ui.Gradient.linear(Offset.zero, Offset(W, 0),
            [kbC(col, 0), kbC(col, P.dark ? .55 : .45), kbC(col, P.dark ? .4 : .3), kbC(col, 0)], [0, .35, .75, 1]));
    }
    return;
  }
  if (P.orig) {
    c.drawCircle(ctr, R * 2.1, Paint()..shader = _radial(ctr, R, R * 2.1, kbC(th.reward, .13 * P.k), kbC(th.reward, 0)));
    final col = kbC(th.reward, .4 * P.k);
    if (o.kind == 'moon') {
      _crescent(c, ctr, R, col, col);
    } else {
      c.drawCircle(ctr, R, _fill(col));
    }
    return;
  }
  final hr = o.soft ? 3.2 : 2.6;
  c.drawCircle(ctr, R * hr, Paint()..shader = _radial(ctr, R * .8, R * hr, kbC(P.orn, P.halo), kbC(P.orn, 0)));
  if (o.kind == 'sun' && !P.dark && !o.soft) {
    final rays = Paint()..shader = _radial(ctr, R, R * 4.5, kbC(kWhite, .22), kbC(kWhite, 0));
    final rect = Rect.fromCircle(center: ctr, radius: R * 4.5);
    for (var i = 0; i < 16; i += 2) {
      final a = i * tau / 16;
      c.drawPath(Path()..moveTo(cx, cy)..arcTo(rect, a, tau / 16, false)..close(), rays);
    }
  }
  if (o.kind == 'moon') {
    _crescent(c, ctr, R, kbC(P.ornCore), kbC(P.orn));
    return;
  }
  c.drawCircle(ctr, R, Paint()
    ..shader = ui.Gradient.radial(ctr, R, [kbC(P.ornCore), kbC(P.orn)], null, TileMode.clamp, null, Offset(cx - R * .3, cy - R * .3), R * .1));
  c.drawCircle(ctr, R * 1.14, _stroke(kbC(kWhite, .4), 3 * s));
}

void _drawRidge(Canvas c, double W, double H, KbTheme th, KbRidge r, int i, String role, KbPalette P, double s) {
  final ph = i * .37 + .13;
  final seed = (i + 1) * 101;
  double fy(double x) => kbYAt(r.kind, r.base, r.amp, r.wavelength, ph, x / W, seed) * H;
  final pts = <Offset>[];
  for (double px = 0; px <= W + 2 * s; px += 2 * s) {
    pts.add(Offset(px, fy(px)));
  }
  var top = H;
  for (final p in pts) {
    if (p.dy < top) top = p.dy;
  }
  final fill = Path()..moveTo(0, H);
  for (final p in pts) {
    fill.lineTo(p.dx, p.dy);
  }
  fill..lineTo(W, H)..close();
  Path line(double dy) {
    final l = Path();
    for (var j = 0; j < pts.length; j++) {
      j == 0 ? l.moveTo(pts[j].dx, pts[j].dy + dy) : l.lineTo(pts[j].dx, pts[j].dy + dy);
    }
    return l;
  }

  if (P.orig) {
    c.drawPath(fill, _fill(kbC(role == 'far' ? P.far : role == 'mid' ? P.midC : P.nearC)));
    return;
  }
  if (role == 'far') {
    c.drawPath(fill, _fill(kbC(P.far))..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6 * s));
    final bottom = r.base * H + 50 * s;
    c.drawRect(Rect.fromLTRB(0, top, W, bottom),
        Paint()..shader = ui.Gradient.linear(Offset(0, top), Offset(0, bottom), [kbC(kWhite, 0), P.haze]));
    return;
  }
  final near = role == 'near';
  final List<Color> cols;
  final List<double> stops;
  if (near && th.ground == 'snow') {
    cols = [kbC(P.dark ? kbMix(th.bright, P.base, .35) : kWhite), kbC(P.dark ? kbMix(th.bright, P.base, .65) : kbMix(th.bright, kWhite, .4))];
    stops = [0, 1];
  } else if (near) {
    cols = [kbC(P.nearHi), kbC(P.nearC), kbC(P.nearC)];
    stops = [0, .35, 1];
  } else {
    cols = [kbC(P.midHi), kbC(P.midC)];
    stops = [0, 1];
  }
  c.drawPath(fill, Paint()..shader = ui.Gradient.linear(Offset(0, top), Offset(0, near ? H : top + H * .22), cols, stops));

  if (r.kind == 'wave') {
    c.drawPath(_dash(line(10 * s), 12 * s, 16 * s), _stroke(kbC(kWhite, .45), 2 * s));
    if (near) c.drawPath(_dash(line(26 * s), 5 * s, 22 * s), _stroke(kbC(kWhite, .25), 2 * s));
  }
  if (r.kind == 'dune') {
    for (final d in [14, 30, 50]) {
      c.drawPath(line(d * s), _stroke(P.dark ? kbC(kWhite, .08) : kbC(kBlack, .14), 1.4 * s));
    }
  }
  if (near) c.drawPath(line(7 * s), _stroke(kbC(kBlack, .2), 3 * s));
  final snowRim = th.snowcap || r.kind == 'ice';
  final rimCol = snowRim ? (P.dark ? kbMix(kWhite, P.base, .15) : kWhite) : near ? P.nearRim : P.rim;
  c.drawPath(line((near ? 1.5 : 1.0) * s), _stroke(kbC(rimCol), (snowRim ? (near ? 6.0 : 4.5) : near ? 4.5 : 2.5) * s));

  if (near && th.crystals) {
    for (var j = 0; j < 14; j++) {
      final x = (.04 + kbHash(seed + j * 5) * .92) * W, y = fy(x) + (20 + kbHash(seed + j * 7) * 90) * s;
      final cw = (4 + kbHash(j) * 3) * s, chh = cw * 2.4;
      c.drawCircle(Offset(x, y), chh * 1.6, Paint()..shader = _radial(Offset(x, y), 0, chh * 1.6, kbC(th.reward, .55), kbC(th.reward, 0)));
      c.drawPath(Path()..moveTo(x, y - chh)..lineTo(x + cw, y)..lineTo(x, y + chh * .5)..lineTo(x - cw, y)..close(), _fill(kbC(kbMix(th.reward, kWhite, .35))));
      c.drawPath(Path()..moveTo(x, y - chh)..lineTo(x - cw, y)..lineTo(x, y)..close(), _fill(kbC(kWhite, .6)));
    }
  }
  if (r.kind == 'hill' && !th.snowcap) {
    final p = _fill(kbC(near ? P.nearRim : P.rim));
    for (var j = 0; j < pts.length; j += near ? 4 : 6) {
      final x = pts[j].dx, y = pts[j].dy, h = (near ? 5.0 : 3.5) + kbHash(seed + j) * (near ? 5.0 : 3.0);
      c.drawPath(Path()..moveTo(x - 3 * s, y + 2 * s)..lineTo(x + (kbHash(j) - .5) * 3 * s, y - h * s)..lineTo(x + 3 * s, y + 2 * s)..close(), p);
    }
  }
  if (near && th.flowers) {
    final petal = _fill(kbC(kbMix(th.bright, kWhite, .55))), core = _fill(kbC(th.reward));
    for (var j = 0; j < 22; j++) {
      final x = kbHash(seed + j * 5) * W, y = fy(x) + (14 + kbHash(seed + j * 7) * 80) * s, rr = 2.6 * s;
      for (var p = 0; p < 5; p++) {
        final a = p * tau / 5;
        c.drawCircle(Offset(x + math.cos(a) * rr * 1.2, y + math.sin(a) * rr * 1.2), rr, petal);
      }
      c.drawCircle(Offset(x, y), rr * .8, core);
    }
  }
}

/// Static layer. Paints sky, stars, ornament and ridges. Returns the palette (motes need it).
KbPalette kbPaintScene(Canvas c, Size size, KbTheme th, KbMode mode, KbStyle style) {
  final P = kbPalette(th, mode, style);
  final W = size.width, H = size.height, s = W / kbDesignWidth;
  c.save();
  c.clipRect(Offset.zero & size);
  c.drawRect(Offset.zero & size, Paint()
    ..shader = ui.Gradient.linear(Offset.zero, Offset(0, H * .64),
        [kbC(P.top), if (P.mid != null) kbC(P.mid!), kbC(P.bot)], P.mid != null ? [0, .55, 1] : [0, 1]));
  if (P.stars) {
    for (var i = 0; i < 40; i++) {
      final col = P.orig && !P.dark ? kbC(th.text, .2) : kbC(kWhite, .35 + .55 * kbHash(i + 77));
      c.drawCircle(Offset(kbHash(i * 3 + 1) * W, kbHash(i * 3 + 2) * H * .5), (.6 + kbHash(i * 3 + 3) * 1.1) * s, _fill(col));
    }
  }
  _drawOrn(c, W, H, th, P, s);
  final roles = th.ridges.length == 2 ? ['mid', 'near'] : ['far', 'mid', 'near'];
  for (var i = 0; i < th.ridges.length; i++) {
    _drawRidge(c, W, H, th, th.ridges[i], i, roles[i], P, s);
  }
  c.restore();
  return P;
}

/// Animated layer. t in [0,1) loops every 24 s.
void kbPaintMotes(Canvas c, Size size, KbTheme th, KbPalette P, double t) {
  final W = size.width, H = size.height, s = W / kbDesignWidth;
  final type = th.moteType, n = th.moteCount;
  late final int rgb;
  var colA = 1.0;
  if (P.orig) {
    rgb = th.accent;
    colA = P.dark ? .5 : .35;
  } else {
    rgb = switch (type) {
      'bubble' => kWhite,
      'dust' => kbMix(th.reward, kWhite, .45),
      'twinkle' => kbMix(th.reward, kWhite, .5),
      'firefly' => kbMix(th.reward, 0xFFFBE0, .5),
      'petal' => P.dark ? th.bright : kbMix(th.bright, kWhite, .45),
      'rain' => 0xE4F0FF,
      'snow' => kWhite,
      'spore' => kbMix(th.reward, kWhite, .3),
      _ => kWhite,
    };
  }
  Color col(double ga) => kbC(rgb, colA * ga);
  final A = P.orig ? 1.0 : .85;
  c.save();
  c.clipRect(Offset.zero & size);
  for (var i = 0; i < n; i++) {
    final h1 = kbHash(i * 13 + 1), h2 = kbHash(i * 13 + 2), h3 = kbHash(i * 13 + 3);
    final k = 1 + (h3 * 2).floor();
    switch (type) {
      case 'bubble': {
        final p = (t * k + h1) % 1, y = H * (1.02 - p * .62), x = h2 * W + math.sin(tau * (t * k * 3 + h1)) * 8 * s, r = (3 + h3 * 6) * s;
        final a = A * math.min(1.0, (1 - p) * 3) * math.min(1.0, p * 8);
        c.drawCircle(Offset(x, y), r, _stroke(col(a), 1.6 * s));
        c.drawCircle(Offset(x, y), r, _fill(col(a * .2)));
        c.drawCircle(Offset(x - r * .35, y - r * .35), r * .25, _fill(col(a)));
      }
      case 'dust': {
        final x = ((h2 + t * k) % 1) * (W + 40 * s) - 20 * s, y = H * (.5 + h1 * .45) + math.sin(tau * (t * k * 2 + h1)) * 6 * s;
        c.drawCircle(Offset(x, y), (1.4 + h3 * 1.8) * s, _fill(col(A * .8)));
      }
      case 'twinkle': {
        final x = h1 * W, y = H * (.05 + h2 * .45), a = .25 + .75 * (.5 + .5 * math.sin(tau * (t * k * 3 + h3))), l = 7 * s * a;
        c.drawCircle(Offset(x, y), 1.8 * s, _fill(col(A * a)));
        c.drawPath(Path()..moveTo(x - l, y)..lineTo(x + l, y)..moveTo(x, y - l)..lineTo(x, y + l), _stroke(col(A * a), 1.2 * s, cap: StrokeCap.butt));
      }
      case 'firefly': {
        final cx = (.08 + h1 * .84) * W, cy = H * (.56 + h2 * .36);
        final x = cx + math.sin(tau * (t * k + h3)) * 28 * s, y = cy + math.sin(tau * (t * k * 2 + h1)) * 14 * s, pu = .5 + .5 * math.sin(tau * (t * k * 4 + h2));
        c.drawCircle(Offset(x, y), 12 * s, Paint()..shader = _radial(Offset(x, y), 0, 12 * s, P.orig ? col(1) : kbC(rgb, .75 * pu), kbC(kWhite, 0)));
        c.drawCircle(Offset(x, y), 2.2 * s, _fill(col(.5 + .5 * pu)));
      }
      case 'rain': {
        final kk = 6 + (h3 * 5).floor(), p = (t * kk + h1) % 1, y = p * (H + 60 * s) - 30 * s, x = h2 * (W + 80 * s) - 20 * s - p * 60 * s;
        c.drawLine(Offset(x, y), Offset(x + 4 * s, y - 18 * s), _stroke(col(A * (.35 + .35 * h3)), 1.4 * s));
      }
      case 'snow': {
        final p = (t * k + h1) % 1, y = p * (H + 20 * s) - 10 * s, x = h2 * W + math.sin(tau * (t * k * 3 + h3)) * 14 * s;
        c.drawCircle(Offset(x, y), (1.5 + h3 * 2.5) * s, _fill(col(A * (.6 + .4 * h3))));
      }
      case 'spore': {
        final p = (t * k + h1) % 1, y = H * (1 - p * .6), x = h2 * W + math.sin(tau * (t * k * 2 + h3)) * 10 * s;
        final a = math.min(1.0, p * 6) * math.min(1.0, (1 - p) * 3);
        c.drawCircle(Offset(x, y), 9 * s, Paint()..shader = _radial(Offset(x, y), 0, 9 * s, P.orig ? col(1) : kbC(rgb, .7 * a), kbC(kWhite, 0)));
        c.drawCircle(Offset(x, y), 1.8 * s, _fill(col(a)));
      }
      case 'petal': {
        final p = (t * k + h1) % 1, y = p * H * 1.08 - 20 * s, sw = math.sin(tau * (t * k * 4 + h3)), x = h2 * W + sw * 18 * s;
        c.save();
        c.translate(x, y);
        c.rotate(sw * .9 + h1 * 3);
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 11 * s, height: 6.4 * s), _fill(col(A)));
        c.restore();
      }
    }
  }
  c.restore();
}

class KbScenePainter extends CustomPainter {
  final KbTheme theme;
  final KbMode mode;
  final KbStyle style;
  const KbScenePainter(this.theme, this.mode, this.style);
  @override
  void paint(Canvas canvas, Size size) => kbPaintScene(canvas, size, theme, mode, style);
  @override
  bool shouldRepaint(KbScenePainter o) => o.theme.id != theme.id || o.mode != mode || o.style != style;
}

class KbMotesPainter extends CustomPainter {
  final KbTheme theme;
  final KbMode mode;
  final KbStyle style;
  final Animation<double> t;
  KbMotesPainter(this.theme, this.mode, this.style, this.t) : super(repaint: t);
  @override
  void paint(Canvas canvas, Size size) => kbPaintMotes(canvas, size, theme, kbPalette(theme, mode, style), t.value);
  @override
  bool shouldRepaint(KbMotesPainter o) => o.theme.id != theme.id || o.mode != mode || o.style != style || o.t != t;
}
