import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/theme.dart';

/// The Home screen's daily-goal ring — Kids Mode's own amber-toned variant
/// of `widgets/common.dart`'s `ProgressRing` (that one always paints in the
/// active theme-family accent; this always paints in kids amber, regardless
/// of which Kids Mode appearance — light/dark/OLED — is active).
class KidsGoalRing extends StatelessWidget {
  final double fraction;
  final double size;
  final Widget? center;

  /// Overrides for the ring's two strokes. Default to the kids amber on the
  /// palette's raised surface; the Home screen's daily-goal card sits on a
  /// filled coral panel and passes white-on-white-tint instead.
  final Color? color;
  final Color? trackColor;
  final double strokeWidth;

  const KidsGoalRing({
    super.key,
    required this.fraction,
    this.size = 74,
    this.center,
    this.color,
    this.trackColor,
    this.strokeWidth = 7,
  });

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
            v, trackColor ?? p.surfaceHigh, color ?? p.amber, strokeWidth),
        child: SizedBox.square(dimension: size, child: Center(child: center)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color track;
  final Color color;
  final double stroke;
  _RingPainter(this.v, this.track, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - stroke / 2 - 1.5;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * v, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.v != v ||
      old.track != track ||
      old.color != color ||
      old.stroke != stroke;
}

/// A section heading with its Arabic companion set opposite it — the pairing
/// the Kids Mode design uses for "Alphabet / الأبجدية" and "Letters / الحروف".
///
/// [arabic] comes from the .arb files and is **empty in the Arabic locale**
/// on purpose (the heading there is already Arabic), so an empty string means
/// "no companion", not "missing translation".
class KidsSectionHeader extends StatelessWidget {
  final String title;
  final String arabic;
  final double size;
  final double arabicSize;
  final Color? arabicColor;
  const KidsSectionHeader({
    super.key,
    required this.title,
    this.arabic = '',
    this.size = 15,
    this.arabicSize = 14,
    this.arabicColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  kidsStyle(context, size: size, weight: FontWeight.w800)),
        ),
        if (arabic.isNotEmpty)
          Text(arabic,
              textDirection: TextDirection.rtl,
              style: arabicStyle(context,
                  size: arabicSize,
                  height: 1.2,
                  color: arabicColor ?? p.textDim)),
      ],
    );
  }
}

/// True when the viewer has asked the OS to reduce motion. Every repeating
/// animation in Kids Mode checks it and renders a still frame instead — real
/// accessibility behaviour, and the thing that keeps `pumpAndSettle()` from
/// hanging forever in the widget tests (a repeating controller never lets it
/// return; see `kids_shell_navigation_test.dart` on `TracingBoard`'s pulse).
bool kidsReduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// The Kids Mode mascot — the design's warm round character, drawn rather
/// than fetched: it stays crisp at any size, tints itself from the palette,
/// adds no asset to `pubspec.yaml` and needs no CREDITS entry. Floats gently
/// and breathes, which is what the design's `nfloat` keyframes describe.
class KidsMascot extends StatefulWidget {
  final double size;
  const KidsMascot({super.key, this.size = 96});

  @override
  State<KidsMascot> createState() => _KidsMascotState();
}

class _KidsMascotState extends State<KidsMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kidsReduceMotion(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final face = CustomPaint(
      size: Size.square(widget.size),
      painter: _MascotPainter(p.amber),
    );
    if (kidsReduceMotion(context)) return face;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -7 * t),
          child: Transform.scale(scale: 1 + .03 * t, child: child),
        );
      },
      child: face,
    );
  }
}

class _MascotPainter extends CustomPainter {
  final Color base;
  _MascotPainter(this.base);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Body: a sphere lit from the upper left, so it reads as round rather
    // than as a flat disc.
    final lighter = Color.alphaBlend(Colors.white.withValues(alpha: .34), base);
    final deeper = Color.alphaBlend(Colors.black.withValues(alpha: .16), base);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.4),
          radius: 1.05,
          colors: [lighter, base, deeper],
          stops: const [0, .55, 1],
        ).createShader(rect),
    );

    // Specular highlight.
    canvas.drawCircle(
      c + Offset(-r * .38, -r * .42),
      r * .17,
      Paint()..color = Colors.white.withValues(alpha: .40),
    );

    final ink = Paint()..color = const Color(0xFF4A3527);

    // Eyes — rounded ovals, set slightly high and wide, which is what makes
    // a plain circle read as friendly rather than blank.
    for (final dx in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c + Offset(dx * r * .30, -r * .13),
            width: r * .17,
            height: r * .27,
          ),
          Radius.circular(r * .09),
        ),
        ink,
      );
    }

    // Smile.
    canvas.drawArc(
      Rect.fromCenter(
          center: c + Offset(0, r * .12), width: r * .62, height: r * .50),
      0.15 * 3.14159,
      0.70 * 3.14159,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .075
        ..strokeCap = StrokeCap.round
        ..color = ink.color,
    );
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.base != base;
}

/// The celebration screen's falling shapes — Kids Mode's take on the design's
/// `nfall` keyframes: pieces drift down, fade out near the bottom, and new
/// ones keep arriving from the top, continuously.
///
/// The loop is what makes it read as ambient rather than as a one-off burst.
/// Each piece carries its own phase offset into the same controller, so they
/// arrive staggered instead of pulsing in unison — one repeating controller,
/// not [count] of them.
class KidsConfetti extends StatefulWidget {
  final int count;
  const KidsConfetti({super.key, this.count = 42});

  @override
  State<KidsConfetti> createState() => _KidsConfettiState();
}

enum _PieceShape { square, circle, diamond, sparkle }

class _ConfettiPiece {
  final double x, size, phase, sway, rotSpeed, fallSpeed;
  final Color color;
  final _PieceShape shape;
  _ConfettiPiece(this.x, this.size, this.phase, this.sway, this.rotSpeed,
      this.fallSpeed, this.color, this.shape);
}

class _KidsConfettiState extends State<KidsConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200));
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    const colors = [
      Color(0xFFF4B23E),
      Color(0xFFEC6A4B),
      Color(0xFF1FA89B),
      Color(0xFF8B85F0),
    ];
    _pieces = List.generate(
        widget.count,
        (_) => _ConfettiPiece(
              rng.nextDouble(),
              5 + rng.nextDouble() * 7,
              rng.nextDouble(), // phase, not delay: the loop is continuous
              rng.nextDouble() * 44 - 22,
              rng.nextDouble() * 6 - 3,
              .75 + rng.nextDouble() * .5,
              colors[rng.nextInt(colors.length)],
              _PieceShape.values[rng.nextInt(_PieceShape.values.length)],
            ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kidsReduceMotion(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_pieces, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  void _drawShape(Canvas canvas, _PieceShape shape, double s, Paint paint) {
    switch (shape) {
      case _PieceShape.square:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: s, height: s * 1.5),
                Radius.circular(s * .25)),
            paint);
      case _PieceShape.circle:
        canvas.drawCircle(Offset.zero, s * .55, paint);
      case _PieceShape.diamond:
        canvas.drawPath(
            Path()
              ..moveTo(0, -s * .8)
              ..lineTo(s * .6, 0)
              ..lineTo(0, s * .8)
              ..lineTo(-s * .6, 0)
              ..close(),
            paint);
      case _PieceShape.sparkle:
        // A four-point star: two crossed slivers, the shape the design
        // scatters around its mascot.
        final path = Path();
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2;
          path.moveTo(0, 0);
          path.lineTo(math.cos(a - .28) * s * .95, math.sin(a - .28) * s * .95);
          path.lineTo(math.cos(a) * s * 1.25, math.sin(a) * s * 1.25);
          path.lineTo(math.cos(a + .28) * s * .95, math.sin(a + .28) * s * .95);
          path.close();
        }
        canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      // Wraps at 1.0, so a piece leaving the bottom immediately re-enters at
      // the top — the continuous fall, from one shared controller.
      final local = (t * piece.fallSpeed + piece.phase) % 1.0;
      final y = size.height * local;
      final x =
          piece.x * size.width + piece.sway * math.sin(local * math.pi * 2);
      // Fade in as it arrives and out as it leaves, so nothing pops.
      final opacity = local < .10
          ? local / .10
          : local > .80
              ? (1 - local) / .20
              : 1.0;
      final paint = Paint()
        ..color = piece.color.withValues(alpha: opacity.clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * piece.rotSpeed * math.pi);
      _drawShape(canvas, piece.shape, piece.size, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// One badge/reward tile — earned in full color, locked dimmed with a hint.
class KidsBadgeTile extends StatelessWidget {
  final String emoji;
  final String title;
  final bool earned;
  const KidsBadgeTile(
      {super.key, required this.emoji, required this.title, required this.earned});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Opacity(
      opacity: earned ? 1 : .45,
      child: Container(
        padding: const EdgeInsets.all(Geo.gapSm),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(Geo.radiusMd),
          border: Border.all(
              color: earned ? p.amber : p.surfaceHigh, width: earned ? 2 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 6),
          Text(title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kidsStyle(context, size: 11.5, weight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// A pill-shaped gem/XP counter chip, used in the top bar of several screens.
class KidsStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const KidsStatChip(
      {super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Geo.radiusPill),
        boxShadow: [
          BoxShadow(color: p.shadow, blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: kidsStyle(context, size: 13, weight: FontWeight.w800)),
      ]),
    );
  }
}
