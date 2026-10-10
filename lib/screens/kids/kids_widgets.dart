import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/display_rate.dart';
import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/kids_content.dart';
import '../../data/kids_sentences.dart' show kidsPraiseArabic;
import '../../widgets/common.dart' show highlightSpans;
import 'kids_avatar_face.dart';
import 'kids_desktop_nav.dart' show closeKidsOverlayOrPop;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_hifi.dart' show KbFidelity;
import '../../kids_backdrops/kb_parallax.dart' show KbParallaxBackdrop;
import '../../kids_backdrops/kb_ui.dart' show KbUi;
import '../../kids_backdrops/kb_scene.dart' show KbStyle, kBlack, kWhite, kbC;
import '../../kids_backdrops/kb_widgets.dart'
    show KbArabicTitle, KbBackdrop, KbHeading;

/// The painted scene behind a whole Kids Mode screen — the design handoff's
/// `KbBackdrop` (`lib/kids_backdrops/`), fed the app's own theme, appearance and
/// Detail level. Mounted once around [KidsShell]'s tab stack and again in
/// [KidsScreenScaffold]'s mobile branch, so every screen gets it.
///
/// The **Detail** dial (Me tab): plain is a no-op — [child] alone, the flat look
/// every screen had before, and the escape hatch for a slow phone. Medium is the
/// design's soft `original` scene, standing still; high is the `vivid` scene with
/// drifting motes. The motes are the only per-frame cost, so they run only on high
/// and never under the platform's reduce-motion flag — a stopped controller, not a
/// hidden one, so nothing ticks.
///
/// [calm] keeps a screen on the soft scene even at high detail.
/// The design's chosen sun bloom (Strong) and backdrop saturation for the vivid
/// scene — fixed values, not settings: the Detail dial is the one control.
const kKidsBloom = 1.5, kKidsSaturation = 1.3;

/// Whether [d] paints the vivid scene: High and Ultra do; Medium is the soft one.
bool kidsVivid(KidsDetail d) => d == KidsDetail.high || d == KidsDetail.ultra;

class KidsBackdrop extends StatelessWidget {
  final Widget child;
  final bool calm;
  const KidsBackdrop({super.key, required this.child, this.calm = false});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    if (s.kidsDetail == KidsDetail.plain) return child;
    final vivid = kidsVivid(s.kidsDetail) && !calm;
    final style = vivid ? KbStyle.vivid : KbStyle.original;
    return KbSceneScope(
      style: style,
      child: KbBackdrop(
        theme: kbThemeFor(s.activeKidsProfile?.theme),
        mode: kbModeFor(s.kidsThemeMode),
        style: style,
        motion: vivid && !kidsReduceMotion(context),
        bloom: kKidsBloom,
        saturation: kKidsSaturation,
        // Lessons stay calm on Ultra: its look, none of its motion.
        ultraStill: vivid && s.kidsDetail == KidsDetail.ultra,
        child: child,
      ),
    );
  }
}

/// The scene behind the five tabs: [KidsBackdrop]'s rules, plus the design's
/// parallax — each layer slides at its own speed as the child scrolls a page
/// ([scrollY]) or swipes between tabs ([cameraX]), the far ridges go soft for
/// depth, and a few out-of-focus specks drift in front.
///
/// All of that belongs to the vivid scene (high detail) and never runs under
/// reduce-motion, as the design specifies; plain and medium are exactly
/// [KidsBackdrop]. Each layer is painted once — a scroll or swipe only moves it.
class KidsTabBackdrop extends StatelessWidget {
  final ValueListenable<double> cameraX;
  final ValueListenable<double> scrollY;

  /// The current page's maxScrollExtent — the vertical travel is spread over
  /// the whole page (see [KbParallaxBackdrop.scrollExtent]).
  final ValueListenable<double>? scrollExtent;
  final Widget child;
  const KidsTabBackdrop({
    super.key,
    required this.cameraX,
    required this.scrollY,
    this.scrollExtent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    if (!kidsVivid(s.kidsDetail)) return KidsBackdrop(child: child);
    final ultra = s.kidsDetail == KidsDetail.ultra, motion = !kidsReduceMotion(context);
    // Ultra's effects take longer than a 120 Hz frame on most phones: hold the
    // screen at an even 60 while they run — not under a pushed lesson (its
    // ticker mode is off there) nor with nothing moving.
    return _HoldSixty(
      active: ultra && motion && TickerMode.valuesOf(context).enabled,
      child: KbSceneScope(
        style: KbStyle.vivid,
        child: KbParallaxBackdrop(
          theme: kbThemeFor(s.activeKidsProfile?.theme),
          mode: kbModeFor(s.kidsThemeMode),
          style: KbStyle.vivid,
          cameraX: cameraX,
          scrollY: scrollY,
          scrollExtent: scrollExtent,
          motion: motion,
          bloom: kKidsBloom,
          saturation: kKidsSaturation,
          // High is the design's Standard fidelity (with its bloom and saturation);
          // Ultra is the design's High + Ultra: grain, effects, mist, tilt, light.
          fidelity: ultra ? KbFidelity.ultra : KbFidelity.standard,
          uiTilt: s.kidsUiTilt,
          grain: s.kidsGrain,
          child: child,
        ),
      ),
    );
  }
}

/// Holds the screen at 60 Hz ([DisplayRate.hold60]) while [active].
class _HoldSixty extends StatefulWidget {
  final bool active;
  final Widget child;
  const _HoldSixty({required this.active, required this.child});

  @override
  State<_HoldSixty> createState() => _HoldSixtyState();
}

class _HoldSixtyState extends State<_HoldSixty> {
  bool _held = false;

  void _sync(bool want) {
    if (want == _held) return;
    _held = want;
    want ? DisplayRate.hold60() : DisplayRate.release60();
  }

  @override
  void initState() {
    super.initState();
    _sync(widget.active);
  }

  @override
  void didUpdateWidget(_HoldSixty old) {
    super.didUpdateWidget(old);
    _sync(widget.active);
  }

  @override
  void dispose() {
    _sync(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

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
    final ui = kbUi(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          v,
          trackColor ?? kbC(ui.track),
          color ?? kbC(ui.accent),
          strokeWidth,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: center),
        ),
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
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * v,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.v != v ||
      old.track != track ||
      old.color != color ||
      old.stroke != stroke;
}

/// True when the viewer has asked the OS to reduce motion. Every repeating
/// animation in Kids Mode checks it and renders a still frame instead — real
/// accessibility behaviour, and the thing that keeps `pumpAndSettle()` from
/// hanging forever in the widget tests (a repeating controller never lets it
/// return; see `kids_shell_navigation_test.dart` on `TracingBoard`'s pulse).
bool kidsReduceMotion(BuildContext context) =>
    // Only the one flag: MediaQuery.maybeOf would rebuild every animated kids
    // widget on any MediaQuery change — each frame of the keyboard sliding.
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// The code that opens every Kids Mode stage for testing. Deliberately a
/// fixed string and not a setting: it exists so the developer can walk the
/// whole path without playing through it, and a child who taps the mascot ten
/// times gets a box they cannot fill in.
const kKidsUnlockCode = 'unlock123';

/// How many taps in a row open the code box, and how long a gap resets the
/// count. Ten deliberate taps is well past anything a child does by accident,
/// and the window means a tap now and a tap tomorrow never add up.
const _unlockTaps = 10;
const _unlockWindow = Duration(seconds: 2);

/// Turns the testing unlock ([ProgressStore.unlockAll]) on or off. On, it
/// lifts every stage and tile lock and lets every theme, frame and avatar be
/// tried on without buying it — nothing is marked done or owned. Off, anything
/// worn only thanks to it comes back off ([kidsTakeOffUnowned]).
void kidsSetTestUnlock(BuildContext context, bool on) {
  final s = SettingsScope.of(context);
  final prog = ProgressScope.of(context);
  prog.setUnlockAll(on);
  final profile = s.activeKidsProfile;
  if (!on && profile != null) {
    final items = kidsShopItems(context);
    s.update(() => kidsTakeOffUnowned(profile, prog.shopOwned, items));
  }
}

/// Wraps [child] in the developer gesture: [_unlockTaps] taps in a row, then a
/// box asking for [kKidsUnlockCode]. Entering it flips the testing unlock
/// ([kidsSetTestUnlock]); entering it again turns that back off.
///
/// Two things wear this — the mascot (which is what the celebration screen
/// puts in front of you after any lesson) and the Me tab's avatar (which is
/// reachable from a fresh install, before any lesson has been finished).
/// Taps land on whatever the wrapped widget already does as well: neither of
/// those does anything on tap, so nothing is stolen.
class KidsSecretUnlock extends StatefulWidget {
  final Widget child;
  const KidsSecretUnlock({super.key, required this.child});

  @override
  State<KidsSecretUnlock> createState() => _KidsSecretUnlockState();
}

class _KidsSecretUnlockState extends State<KidsSecretUnlock> {
  int _taps = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _tap() async {
    final now = DateTime.now();
    _taps = now.difference(_last) > _unlockWindow ? 1 : _taps + 1;
    _last = now;
    if (_taps < _unlockTaps) return;
    _taps = 0;

    // Everything the dialog's answer needs is captured BEFORE awaiting it:
    // the mascot lives on the celebration screen, which the "Continue" button
    // can tear down while the box is still open.
    final prog = ProgressScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final entered = await _ask(context);
    if (entered == null || entered.trim() != kKidsUnlockCode) return;
    final on = !prog.unlockAll;
    if (mounted) {
      kidsSetTestUnlock(context, on);
    } else {
      prog.setUnlockAll(on);
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(on ? l10n.kidsDevUnlockOn : l10n.kidsDevUnlockOff),
        ),
      );
  }

  static Future<String?> _ask(BuildContext context) =>
      showDialog<String>(context: context, builder: (_) => const _CodeDialog());

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: _tap,
    child: widget.child,
  );
}

/// The code box. A widget of its own so the controller's life matches the
/// dialog's: disposing it when `showDialog`'s future completes is too early —
/// the route is still animating out with this field still built.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    // A hero card: the title, the design's name field, Cancel and Continue.
    return Dialog(
      backgroundColor: kbC(kBlack, 0),
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: KbSurface(
        color: ui.surface,
        edge: ui.edge,
        elev: KbElev.hero,
        radius: 32,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.kidsDevUnlockTitle,
                style: kbText(22, kbC(ui.ink), height: 1.15)),
            const SizedBox(height: 16),
            KbTextField(
              ui: ui,
              controller: _code,
              autofocus: true,
              hint: context.l10n.kidsDevUnlockHint,
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                KbPill(context.l10n.cancel,
                    ui: ui,
                    kind: KbPillKind.outlined,
                    fontSize: 16,
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                    onTap: () => Navigator.of(context).pop()),
                KbPill(context.l10n.continueLabel,
                    ui: ui,
                    kind: KbPillKind.deep,
                    fontSize: 16,
                    padding: const EdgeInsets.fromLTRB(20, 9, 20, 7),
                    onTap: () => Navigator.of(context).pop(_code.text)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The Kids Mode mascot — the design's warm round character, drawn rather
/// than fetched: it stays crisp at any size, tints itself from the palette,
/// adds no asset to `pubspec.yaml` and needs no CREDITS entry. Floats gently
/// and breathes, which is what the design's `nfloat` keyframes describe.
///
/// Also the host of the developer unlock gesture — see [KidsSecretUnlock].
class KidsMascot extends StatefulWidget {
  final double size;

  /// The one expression variant this mascot has beyond its default friendly
  /// face — closed happy eyes, a wider smile. [KidsLessonResult] is the only
  /// caller that sets it; everywhere else (the Home greeting, the profile
  /// picker, …) the mascot keeps its everyday face.
  final bool celebrating;
  const KidsMascot({super.key, this.size = 96, this.celebrating = false});

  @override
  State<KidsMascot> createState() => _KidsMascotState();
}

class _KidsMascotState extends State<KidsMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

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
    final face = KidsSecretUnlock(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _MascotPainter(p.amber, celebrating: widget.celebrating),
      ),
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
  final bool celebrating;
  _MascotPainter(this.base, {this.celebrating = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Body: a sphere lit from the upper left, so it reads as round rather
    // than as a flat disc.
    final lighter = Color.alphaBlend(kbC(kWhite, .34), base);
    final deeper = Color.alphaBlend(kbC(kBlack, .16), base);
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
      Paint()..color = kbC(kWhite, .40),
    );

    final ink = Paint()..color = const Color(0xFF4A3527);

    if (celebrating) {
      // Closed, happy eyes — a small upward arc each, the classic
      // ^‿^ — rather than the everyday open ovals.
      for (final dx in [-1.0, 1.0]) {
        final eye = c + Offset(dx * r * .30, -r * .13);
        final path = Path()
          ..moveTo(eye.dx - r * .10, eye.dy + r * .05)
          ..quadraticBezierTo(
              eye.dx, eye.dy - r * .13, eye.dx + r * .10, eye.dy + r * .05);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * .06
            ..strokeCap = StrokeCap.round
            ..color = ink.color,
        );
      }
      // A rosy cheek under each eye — the one flourish this expression gets.
      final blush = Paint()..color = base.withValues(alpha: .0);
      for (final dx in [-1.0, 1.0]) {
        canvas.drawCircle(
          c + Offset(dx * r * .44, r * .08),
          r * .11,
          blush..color = const Color(0xFFE8798A).withValues(alpha: .45),
        );
      }
    } else {
      // Eyes — rounded ovals, set slightly high and wide, which is what
      // makes a plain circle read as friendly rather than blank.
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
    }

    // Smile — wider and more open once celebrating, the same way a grin
    // reads bigger than a plain smile.
    canvas.drawArc(
      Rect.fromCenter(
        center: c + Offset(0, r * (celebrating ? .08 : .12)),
        width: r * (celebrating ? .76 : .62),
        height: r * (celebrating ? .64 : .50),
      ),
      (celebrating ? 0.08 : 0.15) * 3.14159,
      (celebrating ? 0.84 : 0.70) * 3.14159,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .075
        ..strokeCap = StrokeCap.round
        ..color = ink.color,
    );
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.base != base || old.celebrating != celebrating;
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

  /// Which of the theme's four colours this piece is (an index into the list
  /// [_ConfettiPainter] is given) — not a colour itself, so the celebration
  /// is drawn in whatever theme the child has equipped instead of always in
  /// the default coral and teal.
  final int tone;
  final _PieceShape shape;
  _ConfettiPiece(
    this.x,
    this.size,
    this.phase,
    this.sway,
    this.rotSpeed,
    this.fallSpeed,
    this.tone,
    this.shape,
  );
}

class _KidsConfettiState extends State<KidsConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _pieces = List.generate(
      widget.count,
      (_) => _ConfettiPiece(
        rng.nextDouble(),
        5 + rng.nextDouble() * 7,
        rng.nextDouble(), // phase, not delay: the loop is continuous
        rng.nextDouble() * 44 - 22,
        rng.nextDouble() * 6 - 3,
        .75 + rng.nextDouble() * .5,
        rng.nextInt(4),
        _PieceShape.values[rng.nextInt(_PieceShape.values.length)],
      ),
    );
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
    final p = kidsPal(context);
    final tones = [p.amber, p.accent, p.accent2, p.accentBright];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_pieces, _c.value, tones),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double t;
  final List<Color> tones;
  _ConfettiPainter(this.pieces, this.t, this.tones);

  void _drawShape(Canvas canvas, _PieceShape shape, double s, Paint paint) {
    switch (shape) {
      case _PieceShape.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s, height: s * 1.5),
            Radius.circular(s * .25),
          ),
          paint,
        );
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
          paint,
        );
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
        ..color = tones[piece.tone].withValues(alpha: opacity.clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * piece.rotSpeed * math.pi);
      _drawShape(canvas, piece.shape, piece.size, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.t != t || old.tones[0] != tones[0] || old.tones[1] != tones[1];
}

/// A child's avatar — a drawn animal, or the emoji when it has no art (see
/// `KidsAvatarFace`) — with any equipped shop frame drawn as a ring around it. Replaces a bare `Text(profile.avatar)` at every call site —
/// `kids_me_screen.dart`, `kids_home_screen.dart` (×2),
/// `kids_rank_screen.dart` (×2), `kids_profile_picker.dart`,
/// `kids_desktop_shell.dart` — which is what makes a frame purchase visible
/// at all: before this it was a boolean in `ProgressStore.shopOwned` read by
/// exactly one widget, the shop row's own checkmark.
///
/// A ring is deliberately the only decoration here. It surrounds the emoji
/// rather than trying to sit on it, which is why it survives every size this
/// renders at — down to 17px in the desktop nav. A drawn-on accessory does
/// not: a hat shipped briefly and read as a rendering artefact beside a
/// full-colour emoji at any size. See `kidsShopItems` in
/// `data/kids_content.dart`.
class KidsAvatar extends StatelessWidget {
  final KidsProfile profile;
  final double size;
  const KidsAvatar({super.key, required this.profile, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final kind = kidsFrameKind(profile.frame);
    final emoji = KidsAvatarFace(profile.avatar, size: size);
    if (kind == null) return emoji;
    return CustomPaint(
      painter: _FramePainter(kind, kidsPal(context), size),
      child: Padding(padding: EdgeInsets.all(size * .16), child: emoji),
    );
  }
}

/// Draws a shop frame around an avatar. The four kinds differ by shape — a
/// ring, beads, a halo, a sweep — and the last three take their colours from
/// the equipped theme's [Palette], so a frame always suits the screen it is on
/// (a golden ring on an Ocean screen was one of the things that looked wrong).
class _FramePainter extends CustomPainter {
  final KidsFrameKind kind;
  final Palette p;
  final double avatarSize;
  _FramePainter(this.kind, this.p, this.avatarSize);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final w = math.max(2.0, avatarSize * .06);
    // Inset by the stroke and the halo, so nothing is clipped at the edge.
    final r = size.shortestSide / 2 - w - (kind == KidsFrameKind.glow ? avatarSize * .06 : 0);
    switch (kind) {
      case KidsFrameKind.ring:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..color = const Color(0xFFB9C2CC),
        );
      case KidsFrameKind.beads:
        // Beads, not a dashed line: at 17px they stay separate dots.
        const n = 14;
        final bead = math.max(1.4, avatarSize * .055);
        for (var i = 0; i < n; i++) {
          final a = i * 2 * math.pi / n;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * r,
            i.isEven ? bead : bead * .7,
            Paint()..color = i.isEven ? p.amber : p.accentBright,
          );
        }
      case KidsFrameKind.glow:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 2.4
            ..color = p.accentBright.withValues(alpha: .55)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, avatarSize * .09),
        );
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, w * .8)
            ..color = p.accent,
        );
      case KidsFrameKind.sweep:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 1.4
            ..shader = SweepGradient(
              colors: [p.accent, p.accent2, p.amber, p.accent],
            ).createShader(Rect.fromCircle(center: c, radius: r)),
        );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.kind != kind || old.p != p || old.avatarSize != avatarSize;
}

/// The type ladder for Kids Mode's Latin text, in logical pixels at the MEDIUM
/// text size (Me ▸ Appearance ▸ Text size scales all of it — see [kidsStyle]).
///
/// There used to be twenty-two sizes between 9 and 48, chosen one call site at a
/// time, and the smallest were not decoration: 10px carried a lesson's own
/// teaching line, 11px the bottom-navigation labels, 13px the retry hint and
/// the labels on the answer buttons. Five steps, and nothing a child has to read
/// below [kidsCaption]:
///
///  * [kidsCaption] — captions under a tile, tab labels, form labels
///  * [kidsBody]    — explanations, notes, hints, ordinary sentences
///  * [kidsLabel]   — answer tiles and buttons
///  * [kidsPrompt]  — the question at the top of a check
///  * [kidsTitle]   — a card's heading
///
/// Sizes of 22 and up (glyphs, the beat numeral, the mascot's greeting) are
/// already large and stay as they are.
const kidsCaption = 13.0;
const kidsBody = 15.0;
const kidsLabel = 16.0;
const kidsPrompt = 19.0;
const kidsTitle = 21.0;

/// The three sizes Kids Mode text can be drawn at, and what each multiplies.
/// Medium is the default; the ladder above ([kidsBody] and friends) is written
/// at Medium.
const kidsTextSizes = <double>[0.9, 1.0, 1.2];

/// Small · Medium · Large — Kids Mode's own text size dial (Me ▸ Appearance).
/// It scales everything a child reads: the chrome, the lessons, the shared quiz
/// screen and the Arabic. Each tile shows an "A" at its own size, so it can be
/// chosen without reading the word beneath it.
class KidsTextSizePicker extends StatelessWidget {
  /// A compact strip (the desktop sidebar's) instead of the Me tab's tiles.
  final bool compact;
  const KidsTextSizePicker({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final ui = kbUi(context);
    // The design's Text size tiles (kb_screens.dart `KbMeScreen`).
    final options = [
      (context.l10n.kidsTextSmall, kidsTextSizes[0], compact ? 12.0 : 20.0),
      (context.l10n.kidsTextMedium, kidsTextSizes[1], compact ? 15.0 : 28.0),
      (context.l10n.kidsTextLarge, kidsTextSizes[2], compact ? 19.0 : 38.0),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, (label, value, glyph)) in options.indexed) ...[
          if (i > 0) SizedBox(width: compact ? 6 : 12),
          Expanded(
            child: Semantics(
              selected: s.kidsTextScale == value,
              label: '${context.l10n.kidsTextSize}: $label',
              child: Builder(builder: (context) {
                final selected = s.kidsTextScale == value;
                // Never scaled: the "A" must stay its own size whichever
                // option is selected — it is the preview.
                final a = Text('A',
                    textScaler: TextScaler.noScaling,
                    style: kbText(glyph, KbOptionTile.inkOf(ui, selected),
                        height: compact ? 1.1 : 1));
                void pick() => s.update(() => s.kidsTextScale = value);
                if (compact) {
                  return KbSurface(
                    color: selected ? ui.tile : ui.surface,
                    edge: selected ? ui.accentEdge : ui.edge,
                    outline: selected ? ui.accent : null,
                    outlineWidth: 3,
                    elev: KbElev.edge3,
                    radius: 12,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    onTap: pick,
                    child: a,
                  );
                }
                return KbOptionTile(
                  ui: ui,
                  selected: selected,
                  label: label,
                  minHeight: 92,
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
                  onTap: pick,
                  top: a,
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

/// The Me tab's **Detail** dial: plain / medium / high / ultra, as option tiles —
/// the same tiles as [KidsTextSizePicker], so the two read as one family of
/// controls. Four in a row where they fit, two by two on a narrow phone.
///
/// It replaced a single on/off switch. The middle stops are the point: a phone
/// that cannot afford the drifting motes should still get a scene, and Ultra's
/// extra effects are for phones that can.
class KidsDetailPicker extends StatelessWidget {
  const KidsDetailPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return _OptionGrid(
      label: context.l10n.kidsDetailLevel,
      options: [
        (KidsDetail.plain, context.l10n.kidsDetailPlain, 'crop_square'),
        (KidsDetail.medium, context.l10n.kidsDetailMedium, 'landscape'),
        (KidsDetail.high, context.l10n.kidsDetailHigh, 'auto_awesome'),
        (KidsDetail.ultra, context.l10n.kidsDetailUltra, 'stars'),
      ],
      selected: s.kidsDetail,
      keyOf: (d) => 'kidsDetail.${d.name}',
      onSelect: (d) => s.update(() => s.kidsDetail = d),
    );
  }
}

/// The Me tab's **Screen tilt** choice (Off / Subtle / Strong), shown only while
/// Detail is Ultra — the one level where the pages lean with the phone.
class KidsUiTiltPicker extends StatelessWidget {
  const KidsUiTiltPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return _OptionGrid(
      label: context.l10n.kidsUiTilt,
      options: [
        (0.0, context.l10n.kidsUiTiltOff, 'close'),
        (1.0, context.l10n.kidsUiTiltSubtle, 'swap_horiz'),
        (1.6, context.l10n.kidsUiTiltStrong, 'sync_alt'),
      ],
      selected: s.kidsUiTilt,
      keyOf: (v) => 'kidsUiTilt.$v',
      onSelect: (v) => s.update(() => s.kidsUiTilt = v),
    );
  }
}

/// A row of option tiles; two by two when four would be too narrow to read.
class _OptionGrid<T> extends StatelessWidget {
  final String label;
  final List<(T, String, String)> options;
  final T selected;
  final String Function(T) keyOf;
  final ValueChanged<T> onSelect;
  const _OptionGrid({
    required this.label,
    required this.options,
    required this.selected,
    required this.keyOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    Widget tile((T, String, String) o) {
      final (value, text, icon) = o;
      final on = value == selected;
      return Semantics(
        selected: on,
        label: '$label: $text',
        child: KbOptionTile(
          key: ValueKey(keyOf(value)),
          ui: ui,
          selected: on,
          label: text,
          onTap: () => onSelect(value),
          top: KbIcon(icon, size: 28, color: KbOptionTile.inkOf(ui, on)),
        ),
      );
    }

    Widget row(List<(T, String, String)> os) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, o) in os.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: tile(o)),
            ],
          ],
        );

    return LayoutBuilder(builder: (context, c) {
      final perTile = (c.maxWidth - 12 * (options.length - 1)) / options.length;
      if (options.length < 4 || perTile >= 80) return row(options);
      final half = (options.length / 2).ceil();
      return Column(children: [
        row(options.sublist(0, half)),
        const SizedBox(height: 12),
        row(options.sublist(half)),
      ]);
    });
  }
}

/// Centres [child] vertically in the space it is given — and scrolls when the
/// child is taller than that space.
///
/// A lesson card is handed the whole height of the screen, and a bare `Column`
/// (or a `GridView` sized by an aspect ratio, or a scroll view around a card)
/// packs its content to the TOP of it, leaving a dead band underneath: on a
/// tall phone half the screen sat empty. This is the idiom the result screen
/// already used to fix exactly that (`KidsLessonResult`, and
/// `kids_letter_flow.dart`'s own result step, whose comment describes the same
/// bug) — a scroll view whose content is at least as tall as the viewport,
/// centred — pulled out so every card can use it.
///
/// [child] gets the full width (a card stretches; a `Column(stretch)` needs a
/// tight width to stretch to), but only as much height as it needs, so it must
/// not contain an `Expanded`.
class KidsCentered extends StatelessWidget {
  final Widget child;
  const KidsCentered({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}

/// The `Material`/backdrop/width-cap shell EVERY pushed kids destination
/// needs — lessons reach it through [KidsLessonScaffold]; screens with no
/// "Step X of Y" to count (the three board games) use it directly.
///
/// On mobile this is the ONLY thing standing between the screen and
/// [pushKidsOverlay]'s bare `MaterialPageRoute` — without a `Material`
/// ancestor here, every `Text` falls back to `MaterialApp`'s debug "no
/// Material" style (`_errorTextStyle` in the framework: a double yellow
/// underline) on a black background, which is exactly what every lesson built
/// after `KidsLetterFlow` was silently doing, and what the board games did
/// again. `KidsLetterFlow` supplies its own `Scaffold` and so never showed the
/// bug; nothing else did. On desktop the shell's own `Scaffold`
/// (`KidsDesktopShell`) already provides a `Material` ancestor, so a second
/// one here would just nest uselessly — [useDesktop] mirrors the branch
/// `KidsLetterFlow` already uses for the same reason.
///
/// The guard against a third round of this is one line in the screen's own
/// test — `expect(find.byType(Material), findsWidgets)` under a harness whose
/// `home:` is the bare screen. Every kids screen test carries it.
class KidsScreenScaffold extends StatelessWidget {
  final Widget child;

  /// A one-line caption beside the back button — "Step 2 of 7" in a lesson.
  final String? caption;

  /// A heading beside the back button instead ("Warm-up"), and a subtitle
  /// opposite it ("Question 1 of 7") — the design's quiz header.
  final String? title;
  final String? trailing;
  const KidsScreenScaffold(
      {super.key, required this.child, this.caption, this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final desktop = useDesktop(context);
    // The design's lesson page (kb_screens.dart `KbLessonScreen`): the round
    // back button with the step beside it, 22 above the content, all over the
    // scene. Centred and width-capped, like the letter lessons' own desktop
    // layout (`kids_letter_flow.dart`): on a tablet or a desktop pane the
    // screen would otherwise stretch edge to edge, and every grid with an
    // aspect ratio gets wider, shorter and emptier as it does.
    Widget content(BuildContext context) {
      final ui = kbUi(context);
      final pad = MediaQuery.paddingOf(context);
      final rtl = Directionality.of(context) == TextDirection.rtl;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              desktop ? 16 : (pad.top + 8 > 50 ? pad.top + 8 : 50),
              20,
              pad.bottom + 8 > 30 ? pad.bottom + 8 : 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // On desktop the shell's own top bar has the way back.
                if (!desktop ||
                    caption != null ||
                    title != null ||
                    trailing != null) ...[
                  Row(children: [
                    if (!desktop) ...[
                      KbRoundButton(
                        rtl ? 'arrow_forward' : 'arrow_back',
                        ui: ui,
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        onTap: () => Navigator.maybePop(context),
                      ),
                      SizedBox(width: title != null ? 14 : 16),
                    ],
                    if (title != null)
                      Expanded(
                          child: KbHeading(title!,
                              ui: ui, fontSize: 24, height: 1.1))
                    else if (caption != null)
                      Flexible(child: KbSubtitle(caption!, ui: ui))
                    else
                      const Spacer(),
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      // Shares the row with the title on a narrow phone
                      // (wrapping), rather than pushing it off the edge.
                      Flexible(
                        child: KbSubtitle(trailing!,
                            ui: ui, fontSize: 17, align: TextAlign.end),
                      ),
                    ],
                  ]),
                  SizedBox(height: title != null ? 20 : 22),
                ],
                Expanded(child: child),
              ],
            ),
          ),
        ),
      );
    }

    if (desktop) return Builder(builder: content);
    return KidsTextScale(
      child: Scaffold(
        backgroundColor: kbPageBg(kbUi(context)),
        body: KidsBackdrop(child: Builder(builder: content)),
      ),
    );
  }
}

/// The common shape of a step-driven kids lesson (`KidsSyllableDrill`,
/// `KidsSolarLunarLesson`, and the ones built on the same pattern since): a
/// "Step X of Y" caption beside the back button, above whatever the current
/// step shows — gone once the lesson is done (the caption means nothing once
/// there's no "next" left to count toward) — inside [KidsScreenScaffold].
class KidsLessonScaffold extends StatelessWidget {
  final int index;
  final int total;
  final bool done;
  final Widget child;
  const KidsLessonScaffold({
    super.key,
    required this.index,
    required this.total,
    required this.done,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => KidsScreenScaffold(
        caption: done ? null : context.l10n.kidsStepOf(index + 1, total),
        child: child,
      );
}

/// A lesson's instruction or a card's title, on the sky — the design's lesson
/// heading ("Wāw never joins to the letter after it": 29/800, line-height
/// 1.25, white with the outline over the vivid scene). Lesson prompts are the
/// one kind of sentence the design lets sit on the scene; anything longer
/// goes on a [KidsLessonCard].
///
/// Reads the design tokens from ITS OWN context — under the scene the
/// scaffold paints — never from a screen's build above the scaffold, where no
/// scene is known and the heading would come out in plain ink.
class KidsLessonTitle extends StatelessWidget {
  final String text;
  final TextAlign? align;
  final double fontSize;
  final double height;
  const KidsLessonTitle(this.text,
      {super.key, this.align, this.fontSize = 29, this.height = 1.25});

  @override
  Widget build(BuildContext context) => KbHeading(text,
      ui: kbUi(context), fontSize: fontSize, height: height, align: align);
}

/// A one-line subtitle on the sky (the design's `KbSubtitle`) that, like
/// [KidsLessonTitle], reads the tokens from its own context.
class KidsLessonSubtitle extends StatelessWidget {
  final String text;
  final TextAlign? align;
  final double fontSize;
  final double? height;
  const KidsLessonSubtitle(this.text,
      {super.key, this.align, this.fontSize = 19, this.height});

  @override
  Widget build(BuildContext context) => KbSubtitle(text,
      ui: kbUi(context), fontSize: fontSize, height: height, align: align);
}

/// The raised card a lesson's content sits on — the design's lesson letter
/// card (`KbElev.big`, radius 28).
class KidsLessonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const KidsLessonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      elev: KbElev.big,
      radius: 28,
      padding: padding,
      onTap: onTap,
      child: child,
    );
  }
}

/// A Qurʼānic word or phrase as the design sets one: Amiri Quran, line height
/// 1.9, in card ink — with [highlight] (the part being taught) in link ink —
/// on the design's word block (`wordBg`, radius 22) unless [block] is false.
class KidsQuranWord extends StatelessWidget {
  final String word;
  final String? highlight;
  final double size;
  final bool block;
  const KidsQuranWord(this.word,
      {super.key, this.highlight, this.size = 34, this.block = true});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final base = kbText(size, kbC(ui.ink),
        family: kbFontQuran, weight: FontWeight.w400, height: 1.9);
    final text = RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        children: highlight == null || highlight!.isEmpty
            ? [TextSpan(text: word, style: base)]
            : highlightSpans(
                word, highlight!, base, base.copyWith(color: kbC(ui.linkInk))),
      ),
    );
    if (!block) return text;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
      decoration: BoxDecoration(
          color: kbC(ui.wordBg), borderRadius: BorderRadius.circular(22)),
      child: Center(child: text),
    );
  }
}

/// "Listen" — the design's Listen pill (kb_screens.dart `KbLessonScreen`):
/// surface face, link ink, speaker icon.
class KidsListenButton extends StatelessWidget {
  final VoidCallback onTap;
  final String? label;
  const KidsListenButton({super.key, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) => KbPill(label ?? context.l10n.listen,
      ui: kbUi(context),
      icon: 'volume_up',
      fontSize: 20,
      iconSize: 24,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
      onTap: onTap);
}

/// A lesson still fetching what it teaches (a sūrah's words, a reading's
/// verses): the lesson's own page — scene, back button — with the progress
/// ring on it. A bare spinner would be a route with no Material and no scene.
class KidsLoadingScreen extends StatelessWidget {
  const KidsLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => KidsScreenScaffold(
        child: Center(
          child: CircularProgressIndicator(color: kbC(kbUi(context).accent)),
        ),
      );
}

/// A lesson that has nothing to show (its words could not be loaded): the
/// sentence on a card, on the lesson's own page, with the way back.
class KidsMessageScreen extends StatelessWidget {
  final String message;
  const KidsMessageScreen(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return KidsScreenScaffold(
      child: Center(
        child: KidsLessonCard(
          child: Text(message,
              textAlign: TextAlign.center,
              style: kbText(18, kbC(ui.inkSoft),
                  weight: FontWeight.w600, height: 1.35)),
        ),
      ),
    );
  }
}

/// A lesson's primary action — the design's big Next button.
class KidsNextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const KidsNextButton(this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => KbBigButton(label,
      ui: kbUi(context),
      highlight: true,
      fontSize: 22,
      enabled: onTap != null,
      onTap: onTap);
}

/// How many questions a stage's Test asks. A lesson's own check-ups are
/// 3–4 quick ones woven between cards; its Test is the same questions, in the
/// same words, with the cards taken away and more of them.
const kidsQuizLength = 8;

/// Reports a step-driven lesson's result — same three writes every one of
/// them makes: stars (never zero — a lesson walked at all is worth one),
/// XP proportional to stars, and the per-lesson gem bonus (extra when
/// perfect). Call once, from a post-frame callback guarded by a `_reported`
/// flag, never from inside `build()` itself.
void kidsFinishLesson(
  BuildContext context, {
  required String progressId,
  required int stars,
}) {
  // Called from post-frame callbacks: the lesson may already be closed.
  if (!context.mounted) return;
  final shown = stars == 0 ? 1 : stars;
  final prog = ProgressScope.of(context);
  prog.report(progressId, shown);
  prog.awardXp(kidsXpPerStar * shown);
  prog.awardGems(kidsGemsPerLesson + (shown >= 3 ? kidsGemsBonusPerfect : 0));
}

/// Feeds a lesson's own check-up answer into the shared spaced-repetition
/// review queue (`ProgressStore.recordMiss`/`reviewCorrect`) — the SAME
/// queue every grown-up quiz already writes to (`QuizScreen._finishQuestion`,
/// `lib/widgets/common.dart`), keyed by [reviewId]. Before this, a kids
/// lesson's own check card graded a tap and moved on — nothing recorded
/// WHICH item was missed, so a child's mistakes here could never resurface
/// anywhere, unlike every grown-up quiz's mistakes.
///
/// **Review ids** — one card per concept, so every place that asks about a
/// thing files under the same key and the Warm-up shows it once:
///
///  * `letter.<char>` — a letter's name/shape (letter checks, Look-alikes,
///    Write it, Find it, Build the word)
///  * `letter.form.<char>.<ini|med|fin>` — a letter's shape in a place
///  * `kids.syllable.<mark>.<char>` — how a letter with a mark sounds
///  * `kids.word.<letter>` — a word and its meaning
///  * `kids.muqattaat.<letter>`, `kids.madd.<mark>`, `kids.waqf.<mark>`,
///    `kids.tajwid.<rule>`, `kids.mouth.<char>` — one card per rule or mark
///  * `kids.memorise.<surah>.<āyah>` — "what comes after this āyah?"
///
/// A card is a question the Warm-up can ask cold: [arabic] on its face, the
/// [answer] and its [distractors] as the options — so the answer must never be
/// what is on the face. Record a MISS when it happens and a promotion only for
/// a first-try right answer (see `KidsChoiceCard`).
///
/// Not every check fits this shape — a genuine single answer with real
/// distractors, the same thing [QuizQuestion] itself represents. A
/// multi-select "tap every sun letter" or a check over hand-drawn shapes with
/// no text form has nothing honest to store here, so those stay ungraded by
/// this queue on purpose rather than being forced into it.
void kidsRecordCheck(
  BuildContext context, {
  required bool correct,
  required String reviewId,
  required String arabic,
  required String answer,
  String prompt = 'You missed this before — what is it?',
  List<String> distractors = const [],
  bool optionsArabic = true,
}) {
  final prog = ProgressScope.of(context);
  if (correct) {
    prog.reviewCorrect(reviewId);
  } else {
    prog.recordMiss(
      reviewId,
      arabic,
      answer: answer,
      prompt: prompt,
      distractors: distractors,
      optionsArabic: optionsArabic,
    );
  }
}

/// The small celebration every step-driven kids lesson ends on: mascot,
/// stars, XP, confetti, Continue. [stars] may be 0 (a lesson with no graded
/// checkpoints at all is shown as if it scored 3, but one that WAS graded and
/// scored zero is still shown as 1 — see the call sites' own `_stars`
/// getters) so this always shows at least one star regardless.
///
/// [footer] is an optional extra slot below the XP line — `_ResultStep`
/// (`kids_letter_flow.dart`) uses it for the streak count and a "next up"
/// chip, which this file cannot build itself ([KidsItem] lives in
/// `kids_path.dart`, which already imports this one).
///
/// The stars land one at a time rather than appearing all at once: a bloom
/// behind the mascot, the mascot popping in, each EARNED star scaling in with
/// a bounce and a light haptic tap (an unearned star is a plain outline from
/// the start — nothing pops in for a star that wasn't won), the XP rolling up
/// from zero, then the praise line and Continue fading in. Confetti keeps
/// falling regardless of the score, so a one-star finish is never staged as a
/// letdown. `kidsReduceMotion` skips straight to the fully-revealed final
/// frame — the same thing this screen has always shown, unanimated.
class KidsLessonResult extends StatefulWidget {
  final int stars;
  final Widget? footer;
  const KidsLessonResult({super.key, required this.stars, this.footer});

  @override
  State<KidsLessonResult> createState() => _KidsLessonResultState();
}

/// Fraction of the timeline each phase starts at — mirrors the plan's own
/// table (bloom+mascot, star 1/2/3, XP roll, praise+Continue).
const _kidsCelebrationMascotStart = 0.0;
const _kidsCelebrationMascotSpan = 0.18;
const _kidsCelebrationStarSpan = 0.16;
const _kidsCelebrationXpStart = 0.62;
const _kidsCelebrationXpEnd = 0.80;
const _kidsCelebrationTailStart = 0.78;

double _kidsCelebrationStarStart(int i) => 0.20 + i * 0.14;

class _KidsLessonResultState extends State<KidsLessonResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  final List<bool> _hapticFired = [false, false, false];

  int get _shown => widget.stars == 0 ? 1 : widget.stars;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kidsReduceMotion(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value < 1) {
      _c.addListener(_onTick);
      _c.forward();
    }
  }

  void _onTick() {
    if (!SettingsScope.of(context).haptics) return;
    for (var i = 0; i < _shown; i++) {
      if (_hapticFired[i]) continue;
      if (_c.value >= _kidsCelebrationStarStart(i)) {
        _hapticFired[i] = true;
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _starSlot(BuildContext context, KbUi ui, int i) {
    final outline = KbIcon('star_outline', size: 44, color: kbC(ui.inkSoft));
    if (i >= _shown) return outline; // never earned: no animation at all
    final anim = CurvedAnimation(
      parent: _c,
      curve: Interval(
        _kidsCelebrationStarStart(i),
        (_kidsCelebrationStarStart(i) + _kidsCelebrationStarSpan).clamp(
          0.0,
          1.0,
        ),
        curve: Curves.elasticOut,
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        outline,
        FadeTransition(
          opacity: AlwaysStoppedAnimation(anim.value > 0 ? 1.0 : 0.0),
          child: ScaleTransition(
            key: ValueKey('kidsCelebrationStar.$i'),
            scale: anim,
            child: KbIcon('star', size: 44, color: kbC(ui.reward)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final ui = kbUi(context);
    final gender = s.activeKidsProfile?.gender ?? '';
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final mascotT = Interval(
          _kidsCelebrationMascotStart,
          _kidsCelebrationMascotSpan,
          curve: Curves.elasticOut,
        ).transform(t);
        final bloomT = Interval(
          _kidsCelebrationMascotStart,
          _kidsCelebrationMascotSpan,
          curve: Curves.easeOut,
        ).transform(t);
        final tailT = Interval(
          _kidsCelebrationTailStart,
          1.0,
          curve: Curves.easeOut,
        ).transform(t);
        final xpT = Interval(
          _kidsCelebrationXpStart,
          _kidsCelebrationXpEnd,
          curve: Curves.easeOut,
        ).transform(t);
        final xpShown = (kidsXpPerStar * _shown * xpT).round();
        return LayoutBuilder(
          builder: (context, c) {
            return Stack(
              children: [
                // A soft glow in the reward colour behind everything once the
                // mascot pops in — the "bloom" that opens the celebration.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          kbC(ui.reward, .22 * bloomT),
                          kbC(ui.reward, 0),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: c.maxHeight,
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          // The design's hero card (the Hamzah card: radius 32,
                          // `KbElev.hero`) holds the score; the heading and
                          // the praise sit on the sky above it.
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Transform.scale(
                                  scale: mascotT,
                                  child: const KidsMascot(
                                    size: 116,
                                    celebrating: true,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Opacity(
                                opacity: tailT,
                                child: KbHeading(context.l10n.kidsGreatJob,
                                    ui: ui,
                                    fontSize: 32,
                                    align: TextAlign.center),
                              ),
                              Opacity(
                                opacity: tailT,
                                child: Center(
                                  child: KbArabicTitle(
                                      kidsPraiseArabic(gender), ui: ui),
                                ),
                              ),
                              const SizedBox(height: 16),
                              KbSurface(
                                color: ui.surface,
                                edge: ui.edge,
                                elev: KbElev.hero,
                                radius: 32,
                                padding:
                                    const EdgeInsets.fromLTRB(22, 22, 22, 22),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var i = 0; i < 3; i++) ...[
                                          if (i > 0) const SizedBox(width: 6),
                                          _starSlot(context, ui, i),
                                        ],
                                      ],
                                    ),
                                    if (_shown == 3) ...[
                                      const SizedBox(height: 6),
                                      Opacity(
                                        opacity: tailT,
                                        child: Text(
                                          context.l10n.kidsPerfect,
                                          style: kbText(20, kbC(ui.linkInk)),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Text(
                                      context.l10n.kidsXpEarned(xpShown),
                                      style: kbText(18, kbC(ui.ink),
                                          weight: FontWeight.w700),
                                    ),
                                    if (widget.footer != null) ...[
                                      const SizedBox(height: 6),
                                      Opacity(
                                          opacity: tailT, child: widget.footer),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              Opacity(
                                opacity: tailT,
                                child: KbBigButton(
                                  context.l10n.continueLabel,
                                  ui: ui,
                                  highlight: true,
                                  fontSize: 22,
                                  onTap: () => closeKidsOverlayOrPop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(child: KidsConfetti()),
              ],
            );
          },
        );
      },
    );
  }
}

/// A kid-sized, single-purpose stand-in for the grown-up Counts Studio
/// (`tashkeel_screen.dart`'s `CountsStudio`): [counts] is fixed — no tempo
/// slider, no 1/2/4/6 picker a child could set wrong while being taught
/// exactly one of those numbers — and a tap plays exactly three cycles, then
/// stops on its own.
///
/// The adult widget's animation restarts itself forever
/// (`_CountsStudioState`'s own status listener calls `_c.forward(from: 0)`
/// whenever `running` is still true), which is correct for an adult
/// metronome meant to run under live recitation but on a real device reads
/// as a lesson stuck in an endless haptic loop with no obvious way to make it
/// stop. This bounds it instead of asking a child to find a stop button.
class KidsBeatRing extends StatefulWidget {
  final int counts;
  const KidsBeatRing({super.key, required this.counts});

  @override
  State<KidsBeatRing> createState() => _KidsBeatRingState();
}

class _KidsBeatRingState extends State<KidsBeatRing>
    with SingleTickerProviderStateMixin {
  static const _beatMs = 650;
  static const _cycles = 3;

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _cycleDuration)
        ..addListener(_onTick)
        ..addStatusListener(_onStatus);

  bool _running = false;
  int _cyclesDone = 0;
  int _lastBeat = -1;

  Duration get _cycleDuration =>
      Duration(milliseconds: widget.counts * _beatMs + 300);

  double get _activePortion =>
      (widget.counts * _beatMs) / _cycleDuration.inMilliseconds;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _cyclesDone++;
    if (_cyclesDone >= _cycles) {
      setState(() => _running = false);
      return;
    }
    _lastBeat = -1;
    _c.forward(from: 0);
  }

  void _onTick() {
    final t = _c.value / _activePortion;
    if (t > 1) return;
    final beat = (t * widget.counts).floor();
    if (beat != _lastBeat && beat < widget.counts) {
      _lastBeat = beat;
      if (SettingsScope.of(context).haptics) HapticFeedback.mediumImpact();
    }
  }

  void _start() {
    if (_running || kidsReduceMotion(context)) return;
    setState(() {
      _running = true;
      _cyclesDone = 0;
      _lastBeat = -1;
    });
    _c.duration = _cycleDuration;
    _c.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kidsReduceMotion(context) && _running) {
      _c.stop();
      setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    if (kidsReduceMotion(context)) {
      return _StillBeats(counts: widget.counts, color: kbC(ui.accent));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = (_c.value / _activePortion).clamp(0.0, 1.0);
            final beat = _running
                ? math.min((t * widget.counts).floor() + 1, widget.counts)
                : 0;
            return CustomPaint(
              size: const Size.square(160),
              painter: _KidsBeatRingPainter(
                progress: _running ? t : 0,
                counts: widget.counts,
                beat: beat,
                track: kbC(ui.track),
                pip: kbC(ui.inkSoft),
                arc: kbC(ui.accent),
              ),
              child: SizedBox.square(
                dimension: 160,
                child: Center(
                  child: Text(
                    _running ? '$beat' : '${widget.counts}',
                    style: kbText(48, kbC(ui.linkInk), height: 1),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: Geo.gapSm),
        // The design's deep pill; faded (never hidden) while the beats run.
        Opacity(
          opacity: _running ? .5 : 1,
          child: KbPill(context.l10n.startReciteAlong,
              ui: ui,
              kind: KbPillKind.deep,
              icon: 'play_arrow',
              fontSize: 17,
              iconSize: 22,
              elev: KbElev.edge4,
              padding: const EdgeInsets.fromLTRB(14, 8, 18, 6),
              onTap: _running ? null : _start),
        ),
      ],
    );
  }
}

class _KidsBeatRingPainter extends CustomPainter {
  final double progress;
  final int counts;
  final int beat;
  final Color track;
  final Color pip;
  final Color arc;
  _KidsBeatRingPainter({
    required this.progress,
    required this.counts,
    required this.beat,
    required this.track,
    required this.pip,
    required this.arc,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = track,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 10
          ..color = arc,
      );
    }
    for (var i = 0; i < counts; i++) {
      final a = -math.pi / 2 + 2 * math.pi * (i + 1) / counts;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(
        p,
        i < beat ? 7 : 4,
        Paint()..color = i < beat ? arc : pip,
      );
    }
  }

  @override
  bool shouldRepaint(_KidsBeatRingPainter old) =>
      old.progress != progress || old.beat != beat || old.counts != counts;
}

/// [KidsBeatRing] under reduced motion: the same count, shown as a still row
/// of dots rather than an animated ring — nothing to play, nothing to stop.
class _StillBeats extends StatelessWidget {
  final int counts;
  final Color color;
  const _StillBeats({required this.counts, required this.color});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        for (var i = 0; i < counts; i++)
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
      ],
    );
  }
}
