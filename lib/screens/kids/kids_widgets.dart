import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/kids_content.dart';
import '../../data/kids_sentences.dart' show kidsPraiseArabic;
import '../../widgets/common.dart' show StarRow;
import 'kids_desktop_nav.dart' show closeKidsOverlayOrPop;

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
          v,
          trackColor ?? p.surfaceHigh,
          color ?? p.amber,
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
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kidsStyle(context, size: size, weight: FontWeight.w800),
          ),
        ),
        if (arabic.isNotEmpty)
          Text(
            arabic,
            textDirection: TextDirection.rtl,
            style: arabicStyle(
              context,
              size: arabicSize,
              height: 1.2,
              color: arabicColor ?? p.textDim,
            ),
          ),
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

/// Wraps [child] in the developer gesture: [_unlockTaps] taps in a row, then a
/// box asking for [kKidsUnlockCode]. Entering it flips
/// [ProgressStore.unlockAll], which lifts every stage and tile lock without
/// marking anything done; entering it again turns that back off.
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
    prog.setUnlockAll(on);
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.kidsDevUnlockTitle),
    content: TextField(
      controller: _code,
      autofocus: true,
      decoration: InputDecoration(labelText: context.l10n.kidsDevUnlockHint),
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_code.text),
        child: Text(context.l10n.continueLabel),
      ),
    ],
  );
}

/// The Kids Mode mascot — the design's warm round character, drawn rather
/// than fetched: it stays crisp at any size, tints itself from the palette,
/// adds no asset to `pubspec.yaml` and needs no CREDITS entry. Floats gently
/// and breathes, which is what the design's `nfloat` keyframes describe.
///
/// Also the host of the developer unlock gesture — see [KidsSecretUnlock].
class KidsMascot extends StatefulWidget {
  final double size;
  const KidsMascot({super.key, this.size = 96});

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
        painter: _MascotPainter(p.amber),
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
        center: c + Offset(0, r * .12),
        width: r * .62,
        height: r * .50,
      ),
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
  _ConfettiPiece(
    this.x,
    this.size,
    this.phase,
    this.sway,
    this.rotSpeed,
    this.fallSpeed,
    this.color,
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

/// A child's avatar emoji, with any equipped shop frame drawn as a ring
/// around it. Replaces a bare `Text(profile.avatar)` at every call site —
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
    final ring = kidsFrameColor(profile.frame);
    final emoji = Text(profile.avatar, style: TextStyle(fontSize: size));
    if (ring == null) return emoji;
    return Container(
      padding: EdgeInsets.all(size * .12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: math.max(2, size * .06)),
      ),
      child: emoji,
    );
  }
}

/// One badge/reward tile — earned in full color, locked dimmed with a hint.
class KidsBadgeTile extends StatelessWidget {
  final String emoji;
  final String title;
  final bool earned;
  const KidsBadgeTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.earned,
  });

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
            color: earned ? p.amber : p.surfaceHigh,
            width: earned ? 2 : 1,
          ),
        ),
        // Scaled down to fit rather than sized to hope. A badge cell is only
        // ~100px on a 360px-wide phone, which a 30px emoji plus two lines of
        // label overflows once real fonts are loaded — and badge titles vary
        // from "Bee" to "Muqaṭṭaʿāt", so there is no one size that always
        // fits. Same fix the Learn tiles needed for the same reason.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          // Laid out at a nominal width and scaled to whatever the cell
          // actually is, rather than measured unconstrained — without this
          // the title is one long unwrapped line ("Knows when to stop"), and
          // scaleDown shrinks the whole tile to fit that line's width.
          child: SizedBox(
            width: 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: kidsStyle(
                    context,
                    size: 11.5,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped gem/XP counter chip, used in the top bar of several screens.
class KidsStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const KidsStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: kidsStyle(context, size: 13, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// The common shape of a step-driven kids lesson (`KidsSyllableDrill`,
/// `KidsSolarLunarLesson`, and the ones built on the same pattern since): a
/// "Step X of Y" caption above whatever the current step shows, replaced by
/// [child] outright once the lesson is done (the caption means nothing once
/// there's no "next" left to count toward).
///
/// On mobile this is the ONLY thing standing between the lesson and
/// [pushKidsOverlay]'s bare `MaterialPageRoute` — without a `Material`
/// ancestor here, every `Text` in the lesson fell back to `MaterialApp`'s
/// debug "no Material" style (`_errorTextStyle` in the framework: a double
/// yellow underline), which is exactly what every lesson built after
/// `KidsLetterFlow` was silently doing. `KidsLetterFlow` supplied its own
/// `Scaffold` and so never showed the bug; nothing else did. On desktop the
/// shell's own `Scaffold` (`KidsDesktopShell`) already provides a `Material`
/// ancestor, so a second one here would just nest uselessly — [useDesktop]
/// mirrors the branch `KidsLetterFlow` already uses for the same reason.
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
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(Geo.gapLg, 0, Geo.gapLg, Geo.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!done) ...[
            Text(
              context.l10n.kidsStepOf(index + 1, total),
              style: kidsStyle(context, size: 13, color: p.textDim),
            ),
            const SizedBox(height: Geo.gapSm),
          ],
          Expanded(child: child),
        ],
      ),
    );
    if (useDesktop(context)) return content;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(child: content),
    );
  }
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
class KidsLessonResult extends StatelessWidget {
  final int stars;
  const KidsLessonResult({super.key, required this.stars});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final p = kidsPal(context);
    final gender = s.activeKidsProfile?.gender ?? '';
    final shown = stars == 0 ? 1 : stars;
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            SizedBox(
              height: c.maxHeight,
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Geo.gapLg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const KidsMascot(size: 116),
                          const SizedBox(height: Geo.gapMd),
                          Text(
                            context.l10n.kidsGreatJob,
                            style: kidsStyle(
                              context,
                              size: 24,
                              weight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            kidsPraiseArabic(gender),
                            textDirection: TextDirection.rtl,
                            style: quranicStyle(
                              context,
                              size: 22,
                              color: p.accent,
                            ),
                          ),
                          const SizedBox(height: Geo.gapMd),
                          StarRow(shown, size: 40),
                          const SizedBox(height: Geo.gapMd),
                          Text(
                            context.l10n.kidsXpEarned(kidsXpPerStar * shown),
                            style: kidsStyle(
                              context,
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: Geo.gapXl),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: p.accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () => closeKidsOverlayOrPop(context),
                            child: Text(context.l10n.continueLabel),
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
    final p = kidsPal(context);
    if (kidsReduceMotion(context)) {
      return _StillBeats(counts: widget.counts, color: p.accent);
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
                track: p.surfaceHigh,
                pip: p.textDim,
                arc: p.accent,
              ),
              child: SizedBox.square(
                dimension: 160,
                child: Center(
                  child: Text(
                    _running ? '$beat' : '${widget.counts}',
                    style: kidsStyle(
                      context,
                      size: 48,
                      weight: FontWeight.w800,
                      color: p.accent,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: Geo.gapSm),
        TextButton.icon(
          onPressed: _running ? null : _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(context.l10n.startReciteAlong),
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
