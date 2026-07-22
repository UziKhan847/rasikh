import '../core/l10n.dart';
import '../core/responsive.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/settings.dart';
import '../core/theme.dart';

/// Press-down scale feedback for any tappable card.
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const TapScale({super.key, required this.child, required this.onTap});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fade + slide entrance with a per-item delay for staggered lists.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .08), end: Offset.zero)
            .animate(curved),
        child: widget.child,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionHeader(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 5, height: 22,
              decoration: BoxDecoration(
                color: pal(context).accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text(title, style: uiStyle(context, size: 19, weight: FontWeight.w700)),
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 15),
              child: Text(subtitle!,
                  style: uiStyle(context, size: 13.5, color: pal(context).textDim)),
            ),
        ],
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  final int stars;
  final double size;
  const StarRow(this.stars, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < stars ? AppColors.star : pal(context).surfaceHigh,
        );
      }),
    );
  }
}

class ProgressRing extends StatelessWidget {
  final double fraction;
  final double size;
  final Widget? center;
  final Color? track;
  const ProgressRing(
      {super.key, required this.fraction, this.size = 64, this.center, this.track});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(v, track ?? pal(context).surfaceHigh,
            [pal(context).accent, pal(context).accentBright, pal(context).accent2]),
        child: SizedBox.square(dimension: size, child: Center(child: center)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color track;
  final List<Color> ring;
  _RingPainter(this.v, this.track, this.ring);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 5;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = track;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: ring)
          .createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * v, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.track != track;
}

// ───────────────────────────── Quiz engine ─────────────────────────────

/// Marks a [QuizScreen] as living *inside* the desktop Qaidah shell (hosted
/// under its back-header), rather than pushed as its own full-screen route.
/// When embedded, the quiz drops its redundant floating-panel chrome and lays
/// itself out flat across the content pane. Absent (the default), quizzes keep
/// their self-contained card so a pushed route still has a title and a way back.
class QuizHostScope extends InheritedWidget {
  final bool embedded;
  const QuizHostScope({super.key, required this.embedded, required super.child});

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<QuizHostScope>()
          ?.embedded ??
      false;

  @override
  bool updateShouldNotify(QuizHostScope old) => old.embedded != embedded;
}

class QuizQuestion {
  final String prompt; // UI-language prompt
  final String? arabic; // optional big Arabic display
  final List<String> options;
  final int correct;
  final bool optionsAreArabic;
  final String? explain;

  const QuizQuestion({
    required this.prompt,
    this.arabic,
    required this.options,
    required this.correct,
    this.optionsAreArabic = false,
    this.explain,
  });
}

/// A reusable multiple-choice runner with animated feedback, ending in a
/// star score reported to [ProgressStore] under [progressId].
class QuizScreen extends StatefulWidget with DesktopAware {
  final String title;
  final String progressId;
  final List<QuizQuestion> questions;
  const QuizScreen({
    super.key,
    required this.title,
    required this.progressId,
    required this.questions,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _i = 0;
  int _score = 0;
  int? _picked;
  bool _done = false;

  QuizQuestion get q => widget.questions[_i];

  void _pick(int idx) async {
    if (_picked != null) return;
    final settings = SettingsScope.of(context);
    setState(() => _picked = idx);
    final correct = idx == q.correct;
    if (correct) _score++;
    // feed the Reading Coach's spaced-repetition review queue
    final prog = ProgressScope.of(context);
    final glyph = q.arabic;
    if (glyph != null && glyph.trim().isNotEmpty) {
      if (correct) {
        prog.reviewCorrect(glyph); // promote / graduate
      } else {
        final others = [
          for (var k = 0; k < q.options.length; k++)
            if (k != q.correct) q.options[k]
        ];
        prog.recordMiss(glyph,
            answer: q.options[q.correct],
            prompt: q.prompt,
            distractors: others,
            optionsArabic: q.optionsAreArabic);
      }
    }
    if (settings.haptics) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
    await Future.delayed(Duration(milliseconds: correct ? 650 : 1400));
    if (!mounted) return;
    if (_i + 1 < widget.questions.length) {
      setState(() {
        _i++;
        _picked = null;
      });
    } else {
      final frac = _score / widget.questions.length;
      final stars = frac >= 0.95 ? 3 : (frac >= 0.7 ? 2 : (frac >= 0.4 ? 1 : 0));
      ProgressScope.of(context).report(widget.progressId, stars);
      setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _ResultView(title: widget.title, score: _score, total: widget.questions.length);
    if (useDesktop(context)) return _desktopBuild(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(_qOf(context),
                  style: uiStyle(context,
                      size: 13,
                      weight: FontWeight.w800,
                      color: pal(context).textDim)),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (_i + 1) / widget.questions.length),
              duration: const Duration(milliseconds: 350),
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: v, minHeight: 8,
                  backgroundColor: pal(context).surfaceHigh,
                  valueColor: AlwaysStoppedAnimation(pal(context).accent),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(q.prompt,
                textAlign: TextAlign.center,
                style: uiStyle(context, size: 17, color: pal(context).textDim)),
            if (q.arabic != null)
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      q.arabic!,
                      key: ValueKey(_i),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: arabicStyle(context, size: 96),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 24),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 520 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cols == 2 ? 3.4 : 5.5,
                children: List.generate(
                    q.options.length, (i) => _optionTile(context, i)),
              );
            }),
            if (_picked != null && _picked != q.correct && q.explain != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(q.explain!,
                    textAlign: TextAlign.center,
                    style: uiStyle(context, size: 13.5, color: pal(context).textDim)),
              ),
          ],
        ),
      ),
        ),
      ),
    );
  }
  String _qOf(BuildContext context) =>
      context.l10n.questionOf(_i + 1, widget.questions.length);

  Widget _optionTile(BuildContext context, int i, {double vpad = 14}) {
    Color border = pal(context).surfaceHigh;
    Color fill = pal(context).surface;
    if (_picked != null) {
      if (i == q.correct) {
        border = AppColors.ok;
        fill = AppColors.ok.withValues(alpha: .14);
      } else if (i == _picked) {
        border = AppColors.bad;
        fill = AppColors.bad.withValues(alpha: .14);
      }
    }
    return TapScale(
      onTap: () => _pick(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: vpad, horizontal: 18),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.6),
        ),
        child: Text(
          q.options[i],
          textAlign: TextAlign.center,
          textDirection:
              q.optionsAreArabic ? TextDirection.rtl : TextDirection.ltr,
          style: q.optionsAreArabic
              ? arabicStyle(context, size: 26, height: 1.4)
              : uiStyle(context, size: 17, weight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Desktop: quizzes and drills share ONE layout. See [_flatDesktopBuild].
  Widget _desktopBuild(BuildContext context) => _flatDesktopBuild(context);

  /// The shared flat layout for every desktop quiz and drill: a title +
  /// progress bar across the top, the question in a card on the left, and the
  /// answers as tall buttons on the right. When it is hosted inside the Qaidah
  /// shell the shell supplies the back-header; when it is pushed as its own
  /// route (Letter, Forms, Tajwid, Tashkil, review quizzes) we add a back
  /// button here, so the format is identical either way.
  Widget _flatDesktopBuild(BuildContext context) {
    final p = pal(context);
    final embedded = QuizHostScope.of(context);
    final showBack = !embedded && Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // heading (optional back button) + question counter
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showBack) ...[
                      Material(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.maybePop(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                border: Border.all(color: p.surfaceHigh),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.arrow_back_rounded,
                                size: 20, color: p.text),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: uiStyle(context,
                                size: 20, weight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Container(
                          width: 46,
                          height: 3,
                          decoration: BoxDecoration(
                              color: p.accent,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(_qOf(context),
                        style: uiStyle(context,
                            size: 13,
                            weight: FontWeight.w800,
                            color: p.textDim)),
                  ],
                ),
                const SizedBox(height: 18),
                // progress
                TweenAnimationBuilder<double>(
                  tween: Tween(
                      begin: 0, end: (_i + 1) / widget.questions.length),
                  duration: const Duration(milliseconds: 350),
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: p.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(p.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // question card (left) + answers (right)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 11,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 440),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: p.surfaceHigh.withValues(alpha: .6)),
                            boxShadow: [
                              BoxShadow(
                                  color: p.shadow,
                                  blurRadius: 20,
                                  offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(q.prompt,
                                  textAlign: TextAlign.center,
                                  style: uiStyle(context,
                                      size: 16, color: p.textDim)),
                              if (q.arabic != null) ...[
                                const SizedBox(height: 26),
                                AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  child: Text(
                                    q.arabic!,
                                    key: ValueKey(_i),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.center,
                                    style: arabicStyle(context, size: 120),
                                  ),
                                ),
                              ],
                              if (_picked != null &&
                                  _picked != q.correct &&
                                  q.explain != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: Text(q.explain!,
                                      textAlign: TextAlign.center,
                                      style: uiStyle(context,
                                          size: 13.5, color: p.textDim)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 9,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < q.options.length; i++) ...[
                              _optionTile(context, i, vpad: 20),
                              if (i != q.options.length - 1)
                                const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    ],
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

class _ResultView extends StatelessWidget {
  final String title;
  final int score;
  final int total;
  const _ResultView({required this.title, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    final frac = score / total;
    final stars = frac >= 0.95 ? 3 : (frac >= 0.7 ? 2 : (frac >= 0.4 ? 1 : 0));
    final msg = stars == 3
        ? 'مَا شَاءَ اللّٰه — flawless!'
        : stars >= 1
            ? context.l10n.wellDoneKeepGoing
            : context.l10n.reviewLessonTryAgain;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressRing(
                fraction: frac, size: 130,
                center: Text('$score/$total',
                    style: uiStyle(context, size: 24, weight: FontWeight.w700)),
              ),
              const SizedBox(height: 18),
              StarRow(stars, size: 40),
              const SizedBox(height: 10),
              Text(msg, style: uiStyle(context, size: 17)),
              const SizedBox(height: 26),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context),
                child:  Text(context.l10n.continueLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds shuffled multiple-choice options containing the answer.
({List<String> options, int correct}) buildOptions(
    String answer, List<String> pool, math.Random rng,
    {int count = 4}) {
  final distractors = pool.where((p) => p != answer).toList()..shuffle(rng);
  final opts = <String>[answer, ...distractors.take(count - 1)]..shuffle(rng);
  return (options: opts, correct: opts.indexOf(answer));
}
