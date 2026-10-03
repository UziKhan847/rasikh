// Port of palette / drawOrn / drawRidge / drawScene / drawMotes / drawBokeh from
// source/Kids Backdrops.dc.html (v2: lighting pass, horizon suns, silhouettes, parallax layers).
// Canvas 2D -> Flutter mapping used throughout:
//   createLinearGradient      -> ui.Gradient.linear
//   createRadialGradient      -> ui.Gradient.radial (r0/r1 folded into stops; off-centre -> focal)
//   ctx.filter = blur(Npx)    -> saveLayer(Paint()..imageFilter = ImageFilter.blur(sigma N))
//   setLineDash               -> _dash()
//   destination-out           -> saveLayer + BlendMode.dstOut
//   globalAlpha               -> multiplied into the colour alpha
// Keep names aligned with the JS so diffs stay readable. Do NOT "simplify" constants —
// every number is tuned against the reference PNGs.
//
// Coordinates: every function works in the 390 x 844 design space scaled by s = W / 390.
// x0 = horizontal world offset (parallax): a layer painted with x0 = 0 over a canvas wider than W
// continues the same landscape seamlessly to the right.

import 'dart:math' as math;
import 'dart:ui' as ui;
// APP ADAPTATION: not re-exported by widgets.dart/material.dart in this Flutter.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'kb_themes.dart';

const double kbDesignWidth = 390; // JS const S
const double tau = math.pi * 2;
const int kWhite = 0xFFFFFF;
const int kBlack = 0x000000;

enum KbMode { light, dark, oled }

/// APP ADAPTATION: fade the far-ridge haze out in every palette (see kbPaintRidge).
/// The reference comparison turns it off to check the port against the design as drawn.
bool kbSoftHazeEdge = true;

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
  final bool orig, dark, stars, lit;
  final int base, top, bot, far, midC, nearC;
  final int? mid;
  final int midHi, nearHi, rim, nearRim, orn, ornCore, warm, shade;
  final double k, halo;
  final Color haze;
  const KbPalette({
    this.orig = false, required this.dark, required this.stars, this.lit = false,
    required this.base, required this.top, this.mid, required this.bot,
    required this.far, required this.midC, required this.nearC,
    this.midHi = 0, this.nearHi = 0, this.rim = 0, this.nearRim = 0, this.orn = 0, this.ornCore = 0,
    this.warm = 0, this.shade = 0, this.k = 1, this.halo = 0, this.haze = const Color(0x00000000),
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
  if (L && th.lit) {
    // Lighting pass: rich sky, warm horizon glow, one clear light source.
    final top = kbMix(th.color(th.litTop ?? th.skyTop ?? 'accent'), th.deep, .3);
    final bot = th.hotHorizon ? kbMix(th.bright, th.reward, .45) : kbMix(kbMix(th.bright, th.reward, .55), kWhite, .35);
    return KbPalette(
      base: base, top: top, mid: kbMix(kbMix(th.accent, th.bright, .35), top, .35), bot: bot,
      far: kbMix(kbMix(th.bright, th.accent2, .35), bot, .35),
      midC: kbMix(th.accent, th.deep, .25), midHi: kbMix(th.accent, th.bright, .35),
      nearC: kbMix(th.deep, kBlack, .3), nearHi: kbMix(th.deep, th.accent, .45),
      rim: kbMix(th.reward, kWhite, .35), nearRim: kbMix(th.reward, kWhite, .15),
      orn: kbMix(th.reward, kWhite, .2), ornCore: kbMix(th.reward, kWhite, .8), halo: .7,
      haze: kbC(kbMix(th.reward, kWhite, .4), .35), stars: th.stars, dark: false, lit: true,
      warm: kbMix(th.reward, kWhite, .25), shade: th.deep,
    );
  }
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

/// Radial gradient from a list of [t, colour] stops.
Shader _radialStops(Offset c, double r, List<(double, Color)> stops) =>
    ui.Gradient.radial(c, r, [for (final s in stops) s.$2], [for (final s in stops) s.$1]);

void _blurLayer(Canvas c, double sigma, Rect bounds, void Function() draw) {
  c.saveLayer(bounds, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal));
  draw();
  c.restore();
}

void _crescent(Canvas c, Offset ctr, double R, Color c1, Color c2) {
  c.saveLayer(Rect.fromCircle(center: ctr, radius: R * 1.25), Paint());
  c.drawCircle(ctr, R, Paint()
    ..shader = ui.Gradient.radial(ctr, R, [c1, c2], null, TileMode.clamp, null, ctr + Offset(-.3 * R, .2 * R), .1 * R));
  c.drawCircle(ctr + Offset(.52 * R, -.20 * R), .95 * R, Paint()..blendMode = BlendMode.dstOut);
  c.restore();
}

/// Sky gradient + stars. Static layer (does not move with parallax).
void kbPaintSky(Canvas c, Size size, KbTheme th, KbPalette P) {
  final W = size.width, H = size.height, s = W / kbDesignWidth;
  c.drawRect(Offset.zero & size, Paint()
    ..shader = ui.Gradient.linear(Offset.zero, Offset(0, H * .64),
        [kbC(P.top), if (P.mid != null) kbC(P.mid!), kbC(P.bot)], P.mid != null ? [0, .55, 1] : [0, 1]));
  final stars = P.orig ? th.stars : P.stars;
  if (stars) {
    for (var i = 0; i < 40; i++) {
      final col = P.orig && !P.dark ? kbC(th.text, .2) : kbC(kWhite, .35 + .55 * kbHash(i + 77));
      c.drawCircle(Offset(kbHash(i * 3 + 1) * W, kbHash(i * 3 + 2) * H * .5), (.6 + kbHash(i * 3 + 3) * 1.1) * s, _fill(col));
    }
  }
}

/// Sun / moon / clouds / aurora. W,H = screen size (the canvas may be wider for parallax).
void kbPaintOrn(Canvas c, double W, double H, KbTheme th, KbPalette P) {
  final o = th.orn, s = W / kbDesignWidth;
  if (o == null || (P.orig && o.isNew)) return;
  final cx = o.x * W, cy = o.y * H, R = o.r * W, ctr = Offset(cx, cy);
  final wide = Rect.fromLTWH(-W, 0, W * 3, H * 1.5);

  if (o.kind == 'clouds') {
    _blurLayer(c, 5 * s, Rect.fromLTWH(-W, 0, W * 3, H), () {
      for (var i = 0; i < 7; i++) {
        final x0 = kbHash(i + 11) * W, y0 = H * (.27 + kbHash(i + 23) * .16);
        for (var j = 0; j < 8; j++) {
          final m = 1 - (j - 3.5).abs() / 4, r = (20 + kbHash(i * 7 + j) * 22) * s * (.8 + .45 * m), bx = x0 + (j - 3.5) * 22 * s;
          c.drawCircle(Offset(bx, y0 - kbHash(i * 3 + j) * 12 * s - m * 14 * s), r, _fill(P.dark ? kbC(kWhite, .07) : kbC(kWhite, .2)));
          c.drawCircle(Offset(bx, y0 + r * .55), r * .8, _fill(kbC(kBlack, .07)));
        }
      }
    });
    return;
  }
  if (o.kind == 'aurora') {
    _blurLayer(c, 7 * s, Rect.fromLTWH(-W, 0, W * 3, H), () {
      final bands = [(th.reward, .22, .0), (th.bright, .29, 1.7), (th.accent2, .36, 3.1)];
      for (var j = 0; j < bands.length; j++) {
        final (col, yy, ph) = bands[j];
        final path = Path();
        for (double x = 0; x <= W; x += 6 * s) {
          final y = H * yy + math.sin(x / W * tau * 1.2 + ph) * H * .03 + math.sin(x / W * tau * 2.7 + ph * 2) * H * .012;
          x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        c.drawPath(path, _stroke(kbC(kWhite), (22 - j * 4) * s)
          ..shader = ui.Gradient.linear(Offset.zero, Offset(W, 0),
              [kbC(col, 0), kbC(col, P.dark ? .55 : .45), kbC(col, P.dark ? .4 : .3), kbC(col, 0)], [0, .35, .75, 1]));
      }
    });
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

  // Over-exposed sun: white-hot core blends straight into the bloom, so no disc edge is visible.
  // Light modes: every sun except Sunrise (softSun). Dark/OLED: only dusk themes (Sunset, Sunrise).
  if (o.kind == 'sun' && ((!P.dark && !th.softSun) || (P.dark && th.dusk))) {
    final D = P.dark, hasL = o.hasLight;
    final x = (hasL ? o.lx! : o.x) * W, y = (hasL ? o.ly! : o.y) * H, r = (hasL ? o.lr! : o.r) * W * (hasL ? 1 : 1.7);
    final orange = th.hotHorizon || D;
    final hot = D ? 0xFFE4B8 : 0xFFF6DC;
    final warm = D ? 0xFF9A52 : orange ? 0xFFC27A : kbMix(th.reward, kWhite, .35);
    final glow = D ? (th.darkGlow ?? (th.hotHorizon ? 0xD9442E : 0xE0703A)) : orange ? 0xFF9A4A : th.reward;
    final k = D ? .9 : 1.3, p = Offset(x, y); // light modes: 1.3× stronger glow (alphas clamp at 1)
    final stops = hasL || D
        ? [(0.0, hot, 1.0), (.2, hot, 1.0), (.32, warm, .9), (.48, glow, .55), (.7, glow, .2), (1.0, glow, 0.0)]
        : [(0.0, hot, .95), (.05, hot, .8), (.13, warm, .6), (.26, glow, .36), (.45, glow, .16), (.7, glow, .05), (1.0, glow, 0.0)];
    if (!hasL && !D) {
      // wide sky wash so the whole sky grades toward the sun
      c.drawRect(wide, Paint()..shader = _radialStops(p, W * 1.3, [(0, kbC(glow, .6)), (.45, kbC(glow, .24)), (1, kbC(glow, 0))]));
    }
    c.drawRect(wide, Paint()..shader = _radialStops(p, r * (D ? 3.6 : 4.6), [for (final st in stops) (st.$1, kbC(st.$2, (st.$3 * k).clamp(0.0, 1.0)))]));
    return;
  }

  final hr = o.soft ? 3.2 : 2.6;
  c.drawCircle(ctr, R * hr, Paint()
    ..shader = _radialStops(ctr, R * hr, [for (final (t, a) in [(0.0, 1.0), (.36, 1.0), (.5, .58), (.66, .28), (.83, .09), (1.0, 0.0)]) (t, kbC(P.orn, P.halo * a))]));
  if (o.kind == 'sun' && !P.dark && !o.soft) {
    final bc = P.lit ? kbMix(th.reward, kWhite, .3) : kWhite, br = P.lit ? 9.0 : 6.0;
    c.drawCircle(ctr, R * br, Paint()
      ..shader = ui.Gradient.radial(ctr, R * br, [kbC(bc, P.lit ? .5 : .28), kbC(bc, P.lit ? .18 : .1), kbC(bc, 0)], [1 / br, 1 / br + (1 - 1 / br) * .35, 1]));
  }
  if (o.kind == 'moon') {
    _crescent(c, ctr, R, kbC(P.ornCore), kbC(P.orn));
    return;
  }
  c.drawCircle(ctr, R, Paint()
    ..shader = ui.Gradient.radial(ctr, R, [kbC(P.ornCore), kbC(P.orn)], null, TileMode.clamp, null, Offset(cx - R * .3, cy - R * .3), R * .1));
}

/// One ridge. Paints from x = xFrom to x = xTo (canvas coords) and down to hE.
/// x0 = world offset; with parallax paint the layer once over its full extended width with x0 = 0.
void kbPaintRidge(Canvas c, double W, double H, KbTheme th, KbRidge r, int i, String role, KbPalette P,
    {double x0 = 0, double xFrom = 0, double? xTo, double? hE}) {
  final s = W / kbDesignWidth, bottom = hE ?? H, right = xTo ?? W;
  final ph = i * .37 + .13;
  final seed = (i + 1) * 101;
  double fy(double x) => kbYAt(r.kind, r.base, r.amp, r.wavelength, ph, (x + x0) / W, seed) * H;
  final pts = <Offset>[];
  for (double px = xFrom; px <= right + 2 * s; px += 2 * s) {
    pts.add(Offset(px, fy(px)));
  }
  final top = (r.base - r.amp) * H; // fixed per ridge so gradients line up across parallax
  final fill = Path()..moveTo(xFrom, bottom);
  for (final p in pts) {
    fill.lineTo(p.dx, p.dy);
  }
  fill..lineTo(right + 2 * s, bottom)..close();
  Path line(double dy) {
    final l = Path();
    for (var j = 0; j < pts.length; j++) {
      j == 0 ? l.moveTo(pts[j].dx, pts[j].dy + dy) : l.lineTo(pts[j].dx, pts[j].dy + dy);
    }
    return l;
  }

  final span = Rect.fromLTRB(xFrom - 10, top - 10, right + 10, bottom + 10);
  if (P.orig) {
    c.drawPath(fill, _fill(kbC(role == 'far' ? P.far : role == 'mid' ? P.midC : P.nearC)));
    return;
  }
  if (role == 'far') {
    _blurLayer(c, 1.6 * s, span.inflate(20), () => c.drawPath(fill, _fill(kbC(P.far))));
    final hzB = r.base * H + 50 * s;
    // Port fix: the design's unlit haze (dark/OLED, Rain, Night) ends at full
    // strength, a hard line across the screen. Fade it back out like the lit one.
    final soft = P.lit || kbSoftHazeEdge;
    c.drawRect(Rect.fromLTRB(xFrom, top, right, hzB), Paint()
      ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, hzB),
          soft ? [kbC(kWhite, 0), P.haze, kbC(kWhite, 0)] : [kbC(kWhite, 0), P.haze], soft ? [0, .6, 1] : [0, 1]));
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
  if (th.sil) {
    final sil = P.dark ? (th.silD ?? 0x0B0506) : (th.silC ?? 0x2A1418);
    c.drawPath(fill, _fill(kbC(near ? sil : kbMix(sil, P.bot, P.dark ? .3 : .38))));
  }
  if (r.kind == 'wave') {
    c.drawPath(_dash(line(10 * s), 12 * s, 16 * s), _stroke(kbC(kWhite, .45), 2 * s));
    if (near) c.drawPath(_dash(line(26 * s), 5 * s, 22 * s), _stroke(kbC(kWhite, .25), 2 * s));
  }
  if (r.kind == 'dune') {
    for (final d in [14, 30, 50]) {
      c.drawPath(line(d * s), _stroke(P.dark ? kbC(kWhite, .08) : kbC(kBlack, .14), 1.4 * s));
    }
  }
  // Port fix: the JS lights ridges only when `th.orn.x != null`, i.e. a sun or
  // moon. KbOrnament defaults x to 0, so an aurora (Frozen) was lit from the left edge.
  final o = (th.orn?.kind == 'sun' || th.orn?.kind == 'moon') ? th.orn : null;
  final lx = o == null ? null : (o.hasLight ? o.lx! : o.x), ly = o == null ? null : (o.hasLight ? o.ly! : o.y);
  if (P.lit && lx != null && !th.sil) {
    // warm side facing the light, cool shade on the far side
    final sx = lx * W - x0, dir = lx > .5 ? -1.0 : 1.0;
    c.save();
    c.clipPath(fill);
    c.drawRect(span, Paint()
      ..shader = ui.Gradient.linear(Offset(sx, 0), Offset(sx + dir * W * 1.1, 0),
          [kbC(P.warm, near ? .34 : .4), kbC(P.warm, 0), kbC(P.shade, 0), kbC(P.shade, near ? .3 : .24)], [0, .4, .62, 1]));
    c.drawRect(Rect.fromLTRB(xFrom - 10, top, right + 10, top + H * .12),
        Paint()..shader = ui.Gradient.linear(Offset(0, top), Offset(0, top + H * .12), [kbC(P.warm, .18), kbC(P.warm, 0)]));
    c.restore();
  }
  if (near) c.drawPath(line(7 * s), _stroke(kbC(kBlack, P.lit ? .3 : .2), (P.lit ? 4 : 3) * s));
  final snowRim = th.snowcap || r.kind == 'ice';
  final rimCol = snowRim ? (P.dark ? kbMix(kWhite, P.base, .15) : kWhite) : near ? P.nearRim : P.rim;
  c.drawPath(line((near ? 1.5 : 1.0) * s), _stroke(kbC(rimCol), (snowRim ? (near ? 6.0 : 4.5) : near ? (P.lit ? 5.0 : 4.5) : (P.lit ? 3.0 : 2.5)) * s));
  if (P.lit && lx != null && ly != null) {
    // sun-facing slopes catch a bright rim, 4 intensity buckets
    final sx = lx * W - x0, sy = ly * H;
    final buckets = [Path(), Path(), Path(), Path()];
    final used = [false, false, false, false];
    for (var j = 1; j < pts.length; j++) {
      final a = pts[j - 1], b = pts[j];
      final dx = b.dx - a.dx, dy = b.dy - a.dy, l = math.max(1e-6, math.sqrt(dx * dx + dy * dy));
      final nx = dy / l, ny = -dx / l, lxv = sx - (a.dx + b.dx) / 2, lyv = sy - (a.dy + b.dy) / 2;
      final ll = math.max(1e-6, math.sqrt(lxv * lxv + lyv * lyv)), f = (nx * lxv + ny * lyv) / ll;
      if (f > .25) {
        final q = math.min(3, ((f - .25) / .75 * 4).floor());
        buckets[q]..moveTo(a.dx, a.dy + 1.5 * s)..lineTo(b.dx, b.dy + 1.5 * s);
        used[q] = true;
      }
    }
    final rc = kbMix(th.reward, kWhite, .55);
    for (var q = 0; q < 4; q++) {
      if (used[q]) c.drawPath(buckets[q], _stroke(kbC(rc, .3 + q * .22), (near ? 7 : 4.5) * s));
    }
  }
  if (r.kind == 'hill' && !th.snowcap) {
    final p = _fill(kbC(near ? P.nearRim : P.rim));
    final step = near ? 4 : 6;
    // global index so tufts don't jump when x0 changes
    final g0 = ((xFrom + x0) / (2 * s)).round();
    for (var j = 0; j < pts.length; j++) {
      final gj = g0 + j;
      if (gj % step != 0) continue;
      final x = pts[j].dx, y = pts[j].dy, h = (near ? 5.0 : 3.5) + kbHash(seed + gj) * (near ? 5.0 : 3.0);
      c.drawPath(Path()..moveTo(x - 3 * s, y + 2 * s)..lineTo(x + (kbHash(gj) - .5) * 3 * s, y - h * s)..lineTo(x + 3 * s, y + 2 * s)..close(), p);
    }
  }
}

List<String> kbRidgeRoles(KbTheme th) => th.ridges.length == 2 ? ['mid', 'near'] : ['far', 'mid', 'near'];

/// Whole static scene in one canvas (theme icons, reference test, no-parallax fallback).
KbPalette kbPaintScene(Canvas c, Size size, KbTheme th, KbMode mode, KbStyle style) {
  final P = kbPalette(th, mode, style);
  final W = size.width, H = size.height;
  c.save();
  c.clipRect(Offset.zero & size);
  kbPaintSky(c, size, th, P);
  kbPaintOrn(c, W, H, th, P);
  final roles = kbRidgeRoles(th);
  for (var i = 0; i < th.ridges.length; i++) {
    kbPaintRidge(c, W, H, th, th.ridges[i], i, roles[i], P);
  }
  c.restore();
  return P;
}

/// Animated particles. t in [0,1) loops every 24 s. ox = parallax offset (wraps horizontally).
void kbPaintMotes(Canvas c, Size size, KbTheme th, KbPalette P, double t, {double ox = 0, double saturation = 1}) {
  final W = size.width;
  c.save();
  c.clipRect(Offset.zero & size);
  if (ox == 0) {
    _motes0(c, size, th, P, t, saturation);
  } else {
    final o = ((ox % W) + W) % W;
    c.translate(-o, 0);
    _motes0(c, size, th, P, t, saturation);
    c.translate(W, 0);
    _motes0(c, size, th, P, t, saturation);
  }
  c.restore();
}

void _motes0(Canvas c, Size size, KbTheme th, KbPalette P, double t, [double saturation = 1]) {
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
  // APP ADAPTATION: the backdrop's saturation, applied to the motes' colour
  // itself (one solid colour + alpha saturates exactly) instead of filtering the
  // whole layer every frame.
  final rgbS = kbSaturateRgb(rgb, saturation);
  Color col(double ga) => kbC(rgbS, colA * ga);
  final A = P.orig ? 1.0 : .85;
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
}

/// Foreground bokeh: a few big out-of-focus specks (blur them with ImageFiltered, sigma kbDepthBlur['bokeh']).
/// t loops every 60 s. ox = parallax offset.
void kbPaintBokeh(Canvas c, Size size, KbTheme th, KbPalette P, double t, {double ox = 0}) {
  if (P.orig) return;
  final W = size.width, H = size.height, s = W / kbDesignWidth;
  final col = P.dark ? kbMix(th.bright, kWhite, .35) : kbMix(th.reward, kWhite, .55);
  for (var i = 0; i < 6; i++) {
    final h1 = kbHash(i * 17 + 5), h2 = kbHash(i * 17 + 6), h3 = kbHash(i * 17 + 7);
    final span = W * 1.3;
    final x = ((h1 * span - ox * 1.1 + math.sin(tau * (t + h2)) * 30 * s) % span + span) % span - W * .15;
    final y = H * (.52 + h2 * .44) + math.sin(tau * (t * 2 + h3)) * 18 * s, r = (18 + h3 * 22) * s;
    final a = (P.dark ? .22 : .3) * (.55 + .45 * math.sin(tau * (t * 3 + h1)));
    if (a > 0) c.drawCircle(Offset(x, y), r, _fill(kbC(col, a)));
  }
}

/// Sun bloom: light bleeding over the ridges in front of the sun. Light modes, sun themes only.
/// Paint ABOVE the ridges with BlendMode.screen so it only brightens. k: Off 0 · Soft .6 · Medium 1 · Strong 1.5 (default).
bool kbHasBloom(KbTheme th, KbPalette P) => !P.dark && th.orn != null && th.orn!.kind == 'sun';
void kbPaintBloom(Canvas c, Size size, KbTheme th, double W, double H, double k) {
  final o = th.orn!, hasL = o.hasLight;
  final x = (hasL ? o.lx! : o.x) * W, y = (hasL ? o.ly! : o.y) * H, p = Offset(x, y);
  const hot = 0xFFF3D4;
  final warm = kbMix(th.reward, 0xFFD9A0, .5), all = Offset.zero & size;
  Paint sh(List<(double, Color)> st, double r) => Paint()..blendMode = BlendMode.screen..shader = _radialStops(p, r, st);
  c.drawRect(all, sh([(0, kbC(hot, .9 * k)), (.12, kbC(hot, .62 * k)), (.32, kbC(warm, .3 * k)), (.62, kbC(warm, .1 * k)), (1, kbC(warm, 0))], W * .38));
  c.drawRect(all, sh([(0, kbC(warm, .3 * k)), (.4, kbC(warm, .12 * k)), (1, kbC(warm, 0))], W * 1.15));
  // soft lens flare: a short oval glow through the sun that fades out sideways (no hard band)
  c.save();
  c.translate(x, y);
  c.scale(1, .16);
  final fr = W * .42;
  c.drawCircle(Offset.zero, fr, Paint()..blendMode = BlendMode.screen..shader = _radialStops(Offset.zero, fr, [(0, kbC(hot, .34 * k)), (.25, kbC(hot, .16 * k)), (.6, kbC(warm, .05 * k)), (1, kbC(warm, 0))]));
  c.restore();
}

/// APP ADAPTATION: [kbSaturation] applied to one 0xRRGGBB colour.
int kbSaturateRgb(int rgb, double s) {
  if (s == 1) return rgb;
  final m = kbSaturation(s);
  final r = _ch(rgb, 16).toDouble(), g = _ch(rgb, 8).toDouble(), b = _ch(rgb, 0).toDouble();
  int ch(int row) => (m[row * 5] * r + m[row * 5 + 1] * g + m[row * 5 + 2] * b).round().clamp(0, 255).toInt();
  return (ch(0) << 16) | (ch(1) << 8) | ch(2);
}

/// Saturation boost for the backdrop (1 = none). Use as ColorFilter.matrix(kbSaturation(1.15)).
List<double> kbSaturation(double s) {
  const r = .2126, g = .7152, b = .0722;
  final i = 1 - s;
  return [r * i + s, g * i, b * i, 0, 0, r * i, g * i + s, b * i, 0, 0, r * i, g * i, b * i + s, 0, 0, 0, 0, 0, 1, 0];
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
  final ValueListenable<double>? ox;
  /// APP ADAPTATION: the backdrop's saturation (1 = none).
  final double saturation;
  KbMotesPainter(this.theme, this.mode, this.style, this.t, {this.ox, this.saturation = 1}) : super(repaint: ox == null ? t : Listenable.merge([t, ox]));
  // APP ADAPTATION: the palette is the same every frame; work it out once, not 60×/s.
  KbPalette? _p;
  @override
  void paint(Canvas canvas, Size size) => kbPaintMotes(canvas, size, theme, _p ??= kbPalette(theme, mode, style), t.value, ox: ox?.value ?? 0, saturation: saturation);
  @override
  bool shouldRepaint(KbMotesPainter o) => o.theme.id != theme.id || o.mode != mode || o.style != style || o.t != t || o.saturation != saturation;
}
