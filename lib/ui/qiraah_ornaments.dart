// Qiraah — gradients + ornaments (Update 6). No external packages required.
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'classic_ornaments.dart';

import '../core/theme.dart' show AppTheme;

/// Very slight, dark gradients. When Settings → Gradients is off, use the flat fallbacks.
class QGradients {
  final List<Color> hero, primary, screen, side;
  final Color heroFlat, primaryFlat, screenFlat, sideFlat;
  const QGradients(
    this.hero,
    this.primary,
    this.screen,
    this.side,
    this.heroFlat,
    this.primaryFlat,
    this.screenFlat,
    this.sideFlat,
  );
  static const light = QGradients(
    [Color(0xFF09271F), Color(0xFF0C3229), Color(0xFF0F3B32)],
    [Color(0xFF0B5F4C), Color(0xFF0E7059)],
    [Color(0xFFF4F2EC), Color(0xFFEFECE4)],
    [Color(0xFFFAF9F5), Color(0xFFF5F2EB)],
    Color(0xFF0F3B32),
    Color(0xFF0F7A62),
    Color(0xFFF5F3EE),
    Color(0xFFFBFAF7),
  );
  static const mono = QGradients(
    [Color(0xFF0A0A0A), Color(0xFF151515), Color(0xFF1E1E1E)],
    [Color(0xFF0A0A0A), Color(0xFF1E1E1E)],
    [Color(0xFFF3F3F3), Color(0xFFEDEDED)],
    [Color(0xFFFAFAFA), Color(0xFFF4F4F4)],
    Color(0xFF1A1A1A),
    Color(0xFF111111),
    Color(0xFFF4F4F4),
    Color(0xFFFAFAFA),
  );
  static const night = QGradients(
    [Color(0xFF061915), Color(0xFF09251F), Color(0xFF0C2E27)],
    [Color(0xFF106E58), Color(0xFF14806A)],
    [Color(0xFF0F1513), Color(0xFF0C1210)],
    [Color(0xFF121916), Color(0xFF0F1513)],
    Color(0xFF0F3B32),
    Color(0xFF16856A),
    Color(0xFF0E1412),
    Color(0xFF121916),
  );
  static const oled = QGradients(
    [Color(0xFF020C0A), Color(0xFF06190F), Color(0xFF08221C)],
    [Color(0xFF106E58), Color(0xFF14806A)],
    [Color(0xFF000000), Color(0xFF000000)],
    [Color(0xFF000000), Color(0xFF000000)],
    Color(0xFF0F3B32),
    Color(0xFF16856A),
    Color(0xFF000000),
    Color(0xFF000000),
  );
  static QGradients of(AppTheme t) => switch (t) {
    AppTheme.light => light,
    AppTheme.mono => mono,
    AppTheme.night => night,
    AppTheme.oled => oled,
  };

  // CSS 140deg ≈ top-left → bottom-right
  Decoration heroDeco(bool on, {double r = 26}) => BoxDecoration(
    borderRadius: BorderRadius.circular(r),
    color: on ? null : heroFlat,
    gradient: on
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hero,
            stops: const [0, .55, 1],
          )
        : null,
  );
  Decoration primaryDeco(bool on, {double r = 999}) => BoxDecoration(
    borderRadius: BorderRadius.circular(r),
    color: on ? null : primaryFlat,
    gradient: on
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: primary,
          )
        : null,
  );
  Decoration screenDeco(bool on) => BoxDecoration(
    color: on ? null : screenFlat,
    gradient: on
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: screen,
          )
        : null,
  );
}

/// 8-point star (two overlapping squares). Used for rosettes and āyah markers.
Path _star(Offset c, double half) {
  final p = Path();
  for (final rot in [0.0, math.pi / 4]) {
    final pts = List.generate(4, (i) {
      final a = rot + math.pi / 4 + i * math.pi / 2;
      return c + Offset(math.cos(a), math.sin(a)) * half * math.sqrt2;
    });
    p.addPolygon(pts, true);
  }
  return p;
}

/// Small filled rosette shown at both ends of surah headers (Ornate borders on).
class Rosette extends StatelessWidget {
  final double size;
  final Color color, background;
  const Rosette({
    super.key,
    this.size = 18,
    required this.color,
    required this.background,
  });
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _RosettePainter(color, background),
  );
}

class _RosettePainter extends CustomPainter {
  final Color c, bg;
  _RosettePainter(this.c, this.bg);
  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 24, o = Offset(12 * k, 12 * k);
    canvas.drawPath(_star(o, 7 * k), Paint()..color = c);
    canvas.drawCircle(o, 4.4 * k, Paint()..color = bg);
    canvas.drawCircle(o, 1.8 * k, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_RosettePainter o) => o.c != c || o.bg != bg;
}

/// Āyah end marker: outlined 8-point star + inner ring, Arabic-Indic numeral centred.
/// Reader/word-grid: 30px badge. Inline in Muṣḥaf/recite text: 1.35em.
class AyahMarker extends StatelessWidget {
  final String numeralAr;
  final double size;
  final Color stroke, fill, textColor;

  /// Classic: the traced āyah circle (Update 8).
  final bool classic;
  const AyahMarker({
    super.key,
    required this.numeralAr,
    required this.size,
    required this.stroke,
    required this.fill,
    required this.textColor,
    this.classic = false,
  });
  @override
  Widget build(BuildContext context) => classic
      ? ClassicAyahMarker(
          numeralAr: numeralAr,
          size: size,
          stroke: stroke,
          fill: fill,
          textColor: textColor)
      : SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _MarkerPainter(stroke, fill),
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(top: size * .07),
          child: Text(
            numeralAr,
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: size * .43,
              height: 1,
              color: textColor,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MarkerPainter extends CustomPainter {
  final Color s, f;
  _MarkerPainter(this.s, this.f);
  @override
  void paint(Canvas canvas, Size sz) {
    final k = sz.width / 40,
        o = Offset(20 * k, 20 * k),
        path = _star(o, 11.5 * k);
    canvas.drawPath(path, Paint()..color = f);
    final st = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * k
      ..color = s;
    canvas.drawPath(path, st);
    canvas.drawCircle(o, 10.5 * k, st);
  }

  @override
  bool shouldRepaint(_MarkerPainter o) => o.s != s || o.f != f;
}

/// Muṣḥaf illuminated surah header. [frame], [paper], [soft], [accent] come from the current page colour (MushafPaper).
class SurahHeader extends StatelessWidget {
  final String title;
  final bool ornate;

  /// Classic: the traced sūrah border (Update 8) instead of the drawn one.
  final bool classic;
  final double lineHeight;
  final Color frame, paper, soft, accent;

  /// Classic on white-filled papers: what the cartouche is filled with.
  final Color? fill;
  final TextStyle textStyle;
  const SurahHeader({
    super.key,
    required this.title,
    required this.ornate,
    this.classic = false,
    required this.lineHeight,
    required this.frame,
    required this.paper,
    required this.soft,
    required this.accent,
    this.fill,
    required this.textStyle,
  });
  @override
  Widget build(BuildContext context) {
    final fs = textStyle.fontSize ?? 22;
    final h = math.min(lineHeight * (ornate ? .96 : .78), fs * 2.5);
    if (classic) {
      return ClassicSurahBorder(
        height: h,
        color: frame,
        fill: fill,
        child: Text(
          title,
          maxLines: 1,
          softWrap: false,
          textDirection: TextDirection.rtl,
          style: textStyle.copyWith(color: accent, height: 1.6),
        ),
      );
    }
    final band = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: ornate ? fs * .3 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ornate ? 3 : 4),
        border: Border.all(color: frame),
        color: ornate ? null : soft,
        gradient: ornate
            ? LinearGradient(
                colors: [
                  frame.withValues(alpha: .25),
                  soft,
                  soft,
                  frame.withValues(alpha: .25),
                ],
                stops: const [0, .22, .78, 1],
              )
            : null,
      ),
      child: Row(
        children: [
          if (ornate) Rosette(size: fs * 1.15, color: frame, background: paper),
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                margin: EdgeInsets.symmetric(horizontal: ornate ? fs * .3 : 0),
                padding: EdgeInsets.symmetric(
                  horizontal: ornate ? fs * 1.4 : 0,
                ),
                decoration: ornate
                    ? ShapeDecoration(
                        color: paper,
                        shape: StadiumBorder(side: BorderSide(color: frame)),
                      )
                    : null,
                // Scales down rather than wrapping when the title is wider
                // than the cartouche (narrow phone pages).
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    textDirection: TextDirection.rtl,
                    style: textStyle.copyWith(
                      color: accent,
                      fontSize: fs * (ornate ? .82 : 1),
                      height: 1.75,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (ornate) Rosette(size: fs * 1.15, color: frame, background: paper),
        ],
      ),
    );
    // outer second rule (CSS outline offset 2px) + inner inset rule
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: frame),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ornate
          ? DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: frame.withValues(alpha: .66)),
              ),
              child: band,
            )
          : band,
    );
  }
}
