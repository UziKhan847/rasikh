import '../core/audio.dart';
import '../core/l10n.dart';
import '../core/responsive.dart';
import 'dart:async';
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
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(Duration(milliseconds: widget.delayMs), () => _c.forward());
  }

  @override
  void dispose() {
    // A long staggered list (e.g. Joining Forms' 28-letter + Special Shapes
    // picker) can scroll an item out of view — and get it disposed by Sliver
    // virtualization — before its delay elapses. Without canceling here,
    // that leaves a dangling Timer for the rest of the app's lifetime.
    _delay?.cancel();
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
  final String? highlight; // substring of [arabic] to color as the accent
  final List<String> options;
  final int correct;
  final bool optionsAreArabic;
  final String? explain;

  /// Stable spaced-repetition queue key (e.g. `'tashkil.shadda'`,
  /// `'letter.ب'`) — from the underlying data, not the displayed Arabic
  /// text, so correcting that text later doesn't orphan review progress.
  /// Falls back to [arabic] when unset (still functional, just not stable
  /// across future text edits).
  final String? reviewId;

  /// Multi-select: indices into [options] that must ALL be picked, and only
  /// those, for a correct grade (e.g. "choose every letter with a dot on
  /// top"). When set, [correct] is unused and the quiz renders a Submit
  /// button instead of grading on first tap.
  final Set<int>? correctSet;

  /// Ordering: the correct tap sequence, as the exact strings from [options]
  /// in the order they must be tapped (e.g. "list these letters backwards").
  /// When set, [correct] is unused and the quiz builds a running answer strip
  /// as options are tapped, grading once every option has been placed.
  final List<String>? sequence;

  const QuizQuestion({
    required this.prompt,
    this.arabic,
    this.highlight,
    required this.options,
    this.correct = -1,
    this.optionsAreArabic = false,
    this.explain,
    this.reviewId,
    this.correctSet,
    this.sequence,
  });
}

/// Splits [text] into spans with [hl] (its first occurrence) styled as
/// [hlStyle] and the rest as [base] — the shared "highlight one substring"
/// renderer for Arabic example words across the quizzes and study cards.
List<TextSpan> highlightSpans(
    String text, String hl, TextStyle base, TextStyle hlStyle) {
  final i = text.indexOf(hl);
  if (i < 0 || hl.isEmpty) return [TextSpan(text: text, style: base)];
  return [
    if (i > 0) TextSpan(text: text.substring(0, i), style: base),
    TextSpan(text: hl, style: hlStyle),
    if (i + hl.length < text.length)
      TextSpan(text: text.substring(i + hl.length), style: base),
  ];
}

/// A reusable multiple-choice runner with animated feedback, ending in a
/// star score reported to [ProgressStore] under [progressId] — unless
/// [graded] is false (a Qaidah unit's Practice phase), in which case misses
/// and correct answers still feed the spaced-repetition review queue but no
/// star report is ever sent, so practice can be repeated freely without
/// affecting the unit's Test-phase stars.
class QuizScreen extends StatefulWidget with DesktopAware {
  final String title;
  final String progressId;
  final List<QuizQuestion> questions;
  final bool graded;
  const QuizScreen({
    super.key,
    required this.title,
    required this.progressId,
    required this.questions,
    this.graded = true,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _i = 0;
  int _score = 0;
  int? _picked; // single-choice
  final Set<int> _multiPicked = {}; // multi-select
  final List<int> _orderPicked = []; // ordering: option indices, in tap order
  bool _locked = false; // multi-select / ordering: graded, awaiting advance
  bool _wasCorrect = false;
  bool _done = false;

  QuizQuestion get q => widget.questions[_i];
  bool get _isMulti => q.correctSet != null;
  bool get _isOrder => q.sequence != null;
  bool get _isLocked => _isMulti || _isOrder ? _locked : _picked != null;

  void _pickSingle(int idx) {
    if (_picked != null) return;
    setState(() => _picked = idx);
    _finishQuestion(idx == q.correct);
  }

  void _toggleMulti(int idx) {
    if (_locked) return;
    setState(() {
      if (!_multiPicked.remove(idx)) _multiPicked.add(idx);
    });
  }

  void _submitMulti() {
    if (_locked || _multiPicked.isEmpty) return;
    final correct = _multiPicked.length == q.correctSet!.length &&
        _multiPicked.every(q.correctSet!.contains);
    setState(() => _locked = true);
    _finishQuestion(correct);
  }

  void _appendOrder(int idx) {
    if (_locked || _orderPicked.contains(idx)) return;
    setState(() => _orderPicked.add(idx));
    if (_orderPicked.length != q.sequence!.length) return;
    final tapped = [for (final i in _orderPicked) q.options[i]];
    var correct = true;
    for (var k = 0; k < tapped.length; k++) {
      if (tapped[k] != q.sequence![k]) {
        correct = false;
        break;
      }
    }
    setState(() => _locked = true);
    _finishQuestion(correct);
  }

  /// Display string for the correct answer, joined for multi-select/ordering
  /// so a miss can still be recorded through the existing single-`String`
  /// [ReviewItem.answer] field — no persistence-shape change needed.
  String get _answerDisplay {
    if (_isMulti) {
      final idxs = q.correctSet!.toList()..sort();
      return idxs.map((i) => q.options[i]).join(', ');
    }
    if (_isOrder) return q.sequence!.join(' ');
    return q.options[q.correct];
  }

  List<String> get _distractorsDisplay {
    if (_isMulti) {
      return [
        for (var k = 0; k < q.options.length; k++)
          if (!q.correctSet!.contains(k)) q.options[k]
      ];
    }
    if (_isOrder) return const [];
    return [
      for (var k = 0; k < q.options.length; k++)
        if (k != q.correct) q.options[k]
    ];
  }

  void _finishQuestion(bool correct) async {
    setState(() => _wasCorrect = correct);
    final settings = SettingsScope.of(context);
    if (correct) _score++;
    // feed the Reading Coach's spaced-repetition review queue
    final prog = ProgressScope.of(context);
    final glyph = q.arabic;
    if (glyph != null && glyph.trim().isNotEmpty) {
      final reviewKey = q.reviewId ?? glyph;
      if (correct) {
        prog.reviewCorrect(reviewKey); // promote / graduate
      } else {
        prog.recordMiss(reviewKey, glyph,
            answer: _answerDisplay,
            prompt: q.prompt,
            distractors: _distractorsDisplay,
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
        _multiPicked.clear();
        _orderPicked.clear();
        _locked = false;
        _wasCorrect = false;
      });
    } else {
      if (widget.graded) {
        final frac = _score / widget.questions.length;
        final stars = frac >= 0.95 ? 3 : (frac >= 0.7 ? 2 : (frac >= 0.4 ? 1 : 0));
        ProgressScope.of(context).report(widget.progressId, stars);
      }
      setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _ResultView(
          title: widget.title,
          score: _score,
          total: widget.questions.length,
          graded: widget.graded);
    }
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
      body: SafeArea(
        top: false,
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
        padding: const EdgeInsets.all(20),
        // Multi-select and ordering questions can add enough option tiles
        // and controls (strip, Submit button) to exceed a phone's height —
        // scroll instead of overflowing. The Arabic-display area used to be
        // Expanded (fills whatever space is left); it's a generous fixed
        // height instead so the whole thing can live in a plain
        // SingleChildScrollView (IntrinsicHeight isn't an option — the
        // options grid below has its own LayoutBuilder, and LayoutBuilder
        // can't compute intrinsic dimensions).
        child: SingleChildScrollView(
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
              SizedBox(
                height: 220,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: RichText(
                      key: ValueKey(_i),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: highlightSpans(
                          q.arabic!,
                          q.highlight ?? '',
                          quranicStyle(context, size: 96),
                          quranicStyle(context,
                              size: 96, color: pal(context).accent),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 24),
            if (_isOrder) _orderStrip(context),
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
            if (_isMulti) _submitButton(context),
            if (_isLocked && !_wasCorrect && q.explain != null)
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
      ),
      ),
    );
  }
  String _qOf(BuildContext context) =>
      context.l10n.questionOf(_i + 1, widget.questions.length);

  /// Multi-select: a Submit button, enabled once at least one option is
  /// picked, disabled after grading.
  Widget _submitButton(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed:
                (_multiPicked.isEmpty || _locked) ? null : _submitMulti,
            child: Text(context.l10n.submitAnswer),
          ),
        ),
      );

  /// Ordering: a running strip of what's been tapped so far, in tap order.
  Widget _orderStrip(BuildContext context) {
    if (_orderPicked.isEmpty) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in _orderPicked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: pal(context).accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(q.options[i],
                  textDirection:
                      q.optionsAreArabic ? TextDirection.rtl : TextDirection.ltr,
                  style: q.optionsAreArabic
                      ? quranicStyle(context, size: 20)
                      : uiStyle(context, size: 14, weight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _optionTile(BuildContext context, int i, {double vpad = 14}) {
    Color border = pal(context).surfaceHigh;
    Color fill = pal(context).surface;
    Widget? badge;
    if (_isMulti) {
      final selected = _multiPicked.contains(i);
      if (_locked) {
        if (q.correctSet!.contains(i)) {
          border = AppColors.ok;
          fill = AppColors.ok.withValues(alpha: .14);
        } else if (selected) {
          border = AppColors.bad;
          fill = AppColors.bad.withValues(alpha: .14);
        }
      } else if (selected) {
        border = pal(context).accent;
        fill = pal(context).accent.withValues(alpha: .12);
      }
    } else if (_isOrder) {
      final pos = _orderPicked.indexOf(i);
      final used = pos != -1;
      if (used) {
        if (_locked) {
          final right = q.sequence![pos] == q.options[i];
          border = right ? AppColors.ok : AppColors.bad;
          fill = (right ? AppColors.ok : AppColors.bad).withValues(alpha: .14);
        } else {
          border = pal(context).accent;
          fill = pal(context).accent.withValues(alpha: .12);
        }
        badge = Positioned(
          top: -8,
          right: -8,
          child: CircleAvatar(
            radius: 11,
            backgroundColor: pal(context).accent,
            child: Text('${pos + 1}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ),
        );
      }
    } else if (_picked != null) {
      if (i == q.correct) {
        border = AppColors.ok;
        fill = AppColors.ok.withValues(alpha: .14);
      } else if (i == _picked) {
        border = AppColors.bad;
        fill = AppColors.bad.withValues(alpha: .14);
      }
    }
    final tile = AnimatedContainer(
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
            ? quranicStyle(context, size: 26)
            : uiStyle(context, size: 17, weight: FontWeight.w600),
      ),
    );
    return TapScale(
      onTap: () {
        if (_isMulti) {
          _toggleMulti(i);
        } else if (_isOrder) {
          _appendOrder(i);
        } else {
          _pickSingle(i);
        }
      },
      child: badge == null
          ? tile
          : Stack(clipBehavior: Clip.none, children: [tile, badge]),
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
      body: SafeArea(
        child: Center(
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
                                  child: RichText(
                                    key: ValueKey(_i),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      children: highlightSpans(
                                        q.arabic!,
                                        q.highlight ?? '',
                                        quranicStyle(context, size: 120),
                                        quranicStyle(context,
                                            size: 120,
                                            color: p.accent),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (_isLocked && !_wasCorrect && q.explain != null)
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
                            if (_isOrder) _orderStrip(context),
                            for (var i = 0; i < q.options.length; i++) ...[
                              _optionTile(context, i, vpad: 20),
                              if (i != q.options.length - 1)
                                const SizedBox(height: 16),
                            ],
                            if (_isMulti) _submitButton(context),
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
      ),
    );
  }

}

class _ResultView extends StatelessWidget {
  final String title;
  final int score;
  final int total;
  final bool graded;
  const _ResultView(
      {required this.title,
      required this.score,
      required this.total,
      this.graded = true});

  @override
  Widget build(BuildContext context) {
    final frac = score / total;
    final stars = frac >= 0.95 ? 3 : (frac >= 0.7 ? 2 : (frac >= 0.4 ? 1 : 0));
    final msg = !graded
        ? context.l10n.practiceRoundComplete
        : stars == 3
            ? context.l10n.perfectScore
            : stars >= 1
                ? context.l10n.wellDoneKeepGoing
                : context.l10n.reviewLessonTryAgain;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Center(
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
                if (graded) StarRow(stars, size: 40),
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

/// Samples [n] items from [pool] without replacement; if `n > pool.length`,
/// cycles through additional reshuffled passes so nothing repeats until
/// every item in the pool has appeared once. This is the "shuffle once, take
/// N" pattern several quiz builders already used ad hoc (`_letterQuiz`,
/// `_formsQuiz`, `_wordQuiz`) — shared here so every quiz session draws
/// without replacement instead of risking the same question twice by chance.
List<T> pickN<T>(List<T> pool, int n, math.Random rng) {
  if (pool.isEmpty || n <= 0) return const [];
  final out = <T>[];
  var shuffled = [...pool]..shuffle(rng);
  var i = 0;
  while (out.length < n) {
    if (i >= shuffled.length) {
      shuffled = [...pool]..shuffle(rng);
      i = 0;
    }
    out.add(shuffled[i]);
    i++;
  }
  return out;
}

// ─────────────────────── Learn-phase shared surface ───────────────────────

/// The Listen/Watch row every lesson card carries. Watch always falls back to
/// a coming-soon message — there is no video infrastructure anywhere in the
/// app. Listen plays real recitation via [AyahAudio.instance] when [ref] is a
/// `surah:ayah` reference (the range form `surah:ayah-ayah`, as muqaṭṭaʿāt
/// sets use, plays its first āyah); with no ref — an isolated letter or a
/// makhraj that has no single verse to point to — it falls back too.
class MediaRow extends StatelessWidget {
  final String? ref;
  const MediaRow({super.key, this.ref});

  (int, int)? get _surahAyah {
    final parts = ref?.split(':');
    if (parts == null || parts.length != 2) return null;
    final s = int.tryParse(parts[0]);
    final a = int.tryParse(parts[1].split('-').first);
    if (s == null || a == null) return null;
    return (s, a);
  }

  Future<void> _listen(BuildContext context) async {
    final sa = _surahAyah;
    if (sa == null) {
      comingSoon(context, context.l10n.audio);
      return;
    }
    final err = await AyahAudio.instance
        .play(sa.$1, sa.$2, reciter: SettingsScope.of(context).reciter);
    if (!context.mounted || err == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(err)));
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      TextButton.icon(
        onPressed: () => _listen(context),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: Text(context.l10n.listen),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8)),
      ),
      TextButton.icon(
        onPressed: () => comingSoon(context, context.l10n.video),
        icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
        label: Text(context.l10n.watch),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8)),
      ),
    ]);
  }
}

/// One real Qurʼanic example demonstrating a lesson's concept (see
/// `LessonDetail.examples` in `widgets/lesson.dart`): the word/phrase, its
/// surah:ayah ref, and an optional substring to highlight.
typedef ConceptExample = ({String text, String ref, String? highlight});

/// Builds a `LessonDetail.examples` list from a primary (text, ref) pair plus
/// its data class's `moreExamples`/`examples` tuples — the shared "one
/// primary example + several more" shape every Learn-phase data file uses
/// (`TajwidRule.moreExamples`, `WaslItem.moreExamples`, `WaqfMark.moreExamples`,
/// etc.), so call sites don't each hand-roll the same conversion.
List<ConceptExample> conceptExamples(
        String primary, String primaryRef,
        [List<(String, String, String)> more = const [],
        String? primaryHighlight]) =>
    [
      (text: primary, ref: primaryRef, highlight: primaryHighlight),
      for (final (t, r, h) in more) (text: t, ref: r, highlight: h),
    ];

// ──────────────────────── Learn → Test → Practice hub ─────────────────────

/// One phase of a unit path (Qaidah, Tajwīd, Script & Symbols). A null
/// [builder] means "listed but not open yet" — [PhaseHub] dims that card and
/// taps it through to [comingSoon] instead of navigating, the same treatment
/// `home_screen.dart`'s `_ModuleCard` gives the Qirā’āt module.
class UnitPhase {
  final IconData icon;
  final String label;
  final String sub;
  final WidgetBuilder? builder;
  const UnitPhase(
      {required this.icon, required this.label, required this.sub, this.builder});
}

/// The three standard phases (Learn → Test → Practice) shared by every
/// Qaidah and Script & Symbols unit.
List<UnitPhase> standardPhases(BuildContext context,
        {required WidgetBuilder learn,
        required WidgetBuilder test,
        required WidgetBuilder practice}) =>
    [
      UnitPhase(
          icon: Icons.menu_book_rounded,
          label: context.l10n.phaseLearn,
          sub: context.l10n.phaseLearnSub,
          builder: learn),
      UnitPhase(
          icon: Icons.quiz_rounded,
          label: context.l10n.phaseTest,
          sub: context.l10n.phaseTestSub,
          builder: test),
      UnitPhase(
          icon: Icons.refresh_rounded,
          label: context.l10n.phasePractice,
          sub: context.l10n.phasePracticeSub,
          builder: practice),
    ];

/// The phase picker every unit path routes through — Qaidah's Learn → Test →
/// Practice, Tajwīd's five-phase path (with a disabled Recite), and Script &
/// Symbols. Nothing enabled is locked; a phase with a null [UnitPhase.builder]
/// is listed but dimmed, and taps through to a coming-soon message.
class PhaseHub extends StatelessWidget {
  final String subtitle;
  final List<UnitPhase> phases;
  final void Function(int index) onPick;
  const PhaseHub(
      {super.key, required this.subtitle, required this.phases, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Text(subtitle, style: uiStyle(context, size: 14, color: pal(context).textDim)),
        const SizedBox(height: 16),
        for (var i = 0; i < phases.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TapScale(
              onTap: () {
                if (phases[i].builder == null) {
                  comingSoon(context, phases[i].label);
                } else {
                  onPick(i);
                }
              },
              child: Opacity(
                opacity: phases[i].builder == null ? .55 : 1,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: pal(context).surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pal(context).surfaceHigh),
                  ),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: pal(context).surfaceHigh,
                          borderRadius: BorderRadius.circular(16)),
                      child: Icon(phases[i].icon, color: pal(context).accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(phases[i].label,
                              style:
                                  uiStyle(context, size: 16.5, weight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(phases[i].sub,
                              style: uiStyle(context, size: 13, color: pal(context).textDim)),
                        ],
                      ),
                    ),
                    Icon(
                        phases[i].builder == null
                            ? Icons.lock_clock_rounded
                            : Icons.chevron_right_rounded,
                        color: pal(context).textDim),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
