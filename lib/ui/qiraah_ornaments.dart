// Qiraah — gradients + ornaments (Update 6). No external packages required.
import 'dart:math' as math;
import 'package:flutter/material.dart';

export 'package:qiraah_ui/gradients.dart';
import 'ornaments/ayah_markers.dart';

/// Very slight, dark gradients. When Settings → Gradients is off, use the flat fallbacks.

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

  /// The marker's drawing: 'font' (this star and ring), or the traced
  /// āyah circle 'madani' / 'indopak'.
  final String art;
  const AyahMarker({
    super.key,
    required this.numeralAr,
    required this.size,
    required this.stroke,
    required this.fill,
    required this.textColor,
    this.art = 'font',
  });
  @override
  Widget build(BuildContext context) => art != 'font'
      ? ClassicAyahMarker(
          numeralAr: numeralAr,
          size: size,
          stroke: stroke,
          fill: fill,
          textColor: textColor,
          art: art)
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
  final double lineHeight;
  final Color frame, paper, soft, accent;
  final TextStyle textStyle;
  const SurahHeader({
    super.key,
    required this.title,
    required this.ornate,
    required this.lineHeight,
    required this.frame,
    required this.paper,
    required this.soft,
    required this.accent,
    required this.textStyle,
  });
  @override
  Widget build(BuildContext context) {
    final fs = textStyle.fontSize ?? 22;
    final h = math.min(lineHeight * (ornate ? .96 : .78), fs * 2.5);
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
