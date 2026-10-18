import '../core/audio.dart';
import '../core/l10n.dart';
import '../core/responsive.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/settings.dart';
import '../core/theme.dart';
import '../ui/kit.dart';
import 'drag_kit.dart';
import '../ui/app_icons.dart';

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
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section labels keep their own case (finders and screen readers
          // see the real words); the label style carries the look.
          Text(title, style: labelStyle(context).copyWith(fontSize: 13)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!,
                  style: uiStyle(context,
                      size: 13, color: pal(context).ink3, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  final int stars;
  final double size;

  /// The colour of a filled star. Null is the app-wide star gold.
  final Color? color;
  const StarRow(this.stars, {super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Icon(
          i < stars ? AppIcons.star : AppIcons.starOutline,
          size: size,
          color: i < stars ? (color ?? pal(context).gold) : pal(context).line3,
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
        painter: _RingPainter(v, track ?? pal(context).track,
            [pal(context).acc, pal(context).acc]),
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

  /// A substring of [arabic] drawn as an empty slot rather than as text — the
  /// gap in "مَلَا__ِكَة", where the learner picks the missing letter *in its
  /// correct joining form*. Distinct from [highlight], which colors a
  /// substring that is still shown.
  final String? blank;

  /// With [blank]: the options can also be DRAGGED onto the word to fill its
  /// gap (tapping one still answers). Off by default so the grown-up quizzes
  /// keep their plain tap-to-answer feel.
  final bool dragToGap;

  /// Lay the options out as a grid this many columns wide instead of the
  /// default 1–2 wide rows. Needed for glyph options: a dozen joining forms
  /// read as a grid of shapes, not as a stack of wide text buttons.
  final int? optionColumns;

  /// Tile aspect ratio when [optionColumns] is set. Square (1.0) suits a
  /// single glyph; the text default is much wider.
  final double? optionAspect;

  /// `'surah:ayah'` — renders a play button over the shared [AyahAudio]
  /// recitation, for "listen, then pick" questions.
  final String? audioRef;

  /// Offers a "Next" control that moves past this question without grading
  /// it: neither right nor wrong, and excluded from the final score's
  /// denominator. Set on listening questions, whose only audio source is
  /// whole-āyah recitation that needs the network — a child must never be
  /// stuck on a question the device cannot actually ask.
  final bool skippable;

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
    this.blank,
    this.dragToGap = false,
    this.optionColumns,
    this.optionAspect,
    this.audioRef,
    this.skippable = false,
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

/// Splits [text] for a fill-the-gap question: [gap]'s first occurrence
/// becomes an empty slot, the rest stays as [base]. Companion to
/// [highlightSpans] — that one colors a substring still on screen, this one
/// takes it away and leaves a hole to fill.
///
/// The slot is an underlined run of spaces, not a box or a dash: an inline
/// widget would break the shaping of the letters on either side of it, and a
/// dash character is not in UthmanicHafs at all — it rendered as a stray
/// glyph sitting over the word. Spaces plus an underline decoration are in
/// every font.
List<TextSpan> blankSpans(
    String text, String gap, TextStyle base, Color slotColor) {
  final i = text.indexOf(gap);
  if (i < 0 || gap.isEmpty) return [TextSpan(text: text, style: base)];
  return [
    if (i > 0) TextSpan(text: text.substring(0, i), style: base),
    // A tatweel run, not spaces-with-an-underline: an underline decoration is
    // drawn at the bottom of the span's line box, and `quranicStyle`'s 1.8
    // line height dropped it a whole line below the word. Tatweel is a real
    // glyph in UthmanicHafs, sits on the baseline, and reads as exactly what
    // it is — a stretch of joined line with its letter missing.
    TextSpan(
        text: '\u0640\u0640\u0640',
        style: base.copyWith(color: slotColor)),
    if (i + gap.length < text.length)
      TextSpan(text: text.substring(i + gap.length), style: base),
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
  int _skipped = 0; // skippable questions passed over: never right OR wrong
  int? _picked; // single-choice
  final Set<int> _multiPicked = {}; // multi-select
  final List<int> _orderPicked = []; // ordering: option indices, in tap order
  bool _locked = false; // multi-select / ordering: graded, awaiting advance
  bool _wasCorrect = false;
  bool _done = false;

  /// Questions that actually counted. A round of nothing but skips would
  /// divide by zero, so it floors at 1 — and scores 0, which is honest:
  /// nothing was answered.
  int get _graded =>
      (widget.questions.length - _skipped).clamp(1, widget.questions.length);

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

  /// Move past a [QuizQuestion.skippable] question without grading it. No
  /// review-queue entry either: not knowing an answer you were never really
  /// asked isn't a miss.
  void _skip() {
    if (_isLocked) return;
    _skipped++;
    _advance();
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
      correct
          ? HapticFeedback.lightImpact()
          : HapticFeedback.heavyImpact();
    }
    await Future.delayed(
        Duration(milliseconds: correct ? 650 : 1400));
    if (!mounted) return;
    _advance();
  }

  /// Next question, or grade the round. Shared by [_finishQuestion] and
  /// [_skip] so the "was that the last one?" logic lives in one place.
  void _advance() {
    if (_i + 1 < widget.questions.length) {
      setState(() {
        _i++;
        _picked = null;
        _multiPicked.clear();
        _orderPicked.clear();
        _locked = false;
        _wasCorrect = false;
      });
      return;
    }
    if (widget.graded) {
      final stars = starsForFraction(_score / _graded);
      ProgressScope.of(context).report(widget.progressId, stars);
    }
    setState(() => _done = true);
  }

  /// The options grid. Text options keep the long-standing 1–2 wide columns;
  /// a question that sets [QuizQuestion.optionColumns] gets that many square
  /// tiles instead, which is the only way a dozen joining forms read as
  /// shapes rather than as a stack of wide buttons.
  Widget _optionsGrid(BuildContext context, {double vpad = 14}) =>
      LayoutBuilder(builder: (context, c) {
        final longest = q.options.fold<int>(0, (m, o) => math.max(m, o.length));
        final cols = q.optionColumns ??
            (c.maxWidth > 520 || (c.maxWidth > 300 && longest <= 14) ? 2 : 1);
        final aspect = q.optionAspect ??
            (cols == 2 ? (c.maxWidth / 2 - 6) / 64 : (cols == 1 ? 5.5 : 1.0));
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: aspect,
          children: List.generate(
              q.options.length, (i) => _optionTile(context, i, vpad: vpad)),
        );
      });

  /// The question's Arabic, with either a colored highlight or a gap to fill.
  /// Once a gap question is answered the whole word is shown, its lifted letter
  /// back in place and picked out — so the shape is seen where it belongs.
  Widget _questionArabic(BuildContext context, double size) {
    final base = quranicStyle(context, size: size);
    final List<TextSpan> spans;
    if (q.blank == null) {
      spans = highlightSpans(q.arabic!, q.highlight ?? '', base,
          quranicStyle(context, size: size, color: pal(context).acc));
    } else if (_picked == null) {
      spans = blankSpans(q.arabic!, q.blank!, base, pal(context).acc);
    } else {
      spans = highlightSpans(q.arabic!, q.blank!, base,
          quranicStyle(context, size: size, color: AppColors.ok));
    }
    final word = RichText(
      key: ValueKey(_i),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
    if (!(q.dragToGap && q.blank != null)) return word;
    // A gap question that takes drags: the whole word is the drop target, lit
    // while a shape is held over it. (The gap itself is a run of tatweel inside
    // the text, not a widget — see [blankSpans] — so it cannot be one.)
    return DropSlot<int>(
      enabled: _picked == null,
      onDrop: _pickSingle,
      builder: (context, hovering) => DropGlow(
        hovering: hovering != null,
        color: pal(context).acc,
        child: Padding(padding: const EdgeInsets.all(10), child: word),
      ),
    );
  }

  /// "Play it" for a listening question.
  Widget _audioButton(BuildContext context) {
    final parts = q.audioRef!.split(':');
    final s = int.tryParse(parts.first);
    final a = int.tryParse(parts.length > 1 ? parts[1] : '');
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: QPrimaryButton(
          context.l10n.listen,
          icon: AppIcons.volume,
          height: 44,
          onTap: (s == null || a == null)
              ? null
              : () => AyahAudio.instance.play(s, a),
        ),
      ),
    );
  }

  /// The escape hatch on a [QuizQuestion.skippable] question.
  Widget _skipButton(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(
          child: TextButton.icon(
            onPressed: _isLocked ? null : _skip,
            icon: const Icon(AppIcons.forward, size: 18),
            label: Text(context.l10n.nextCard),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _ResultView(
          title: widget.title,
          score: _score,
          // Skipped questions are out of the denominator: they were passed
          // over, not failed.
          total: _graded,
          graded: widget.graded);
    }
    final p = pal(context);
    final embedded = QuizHostScope.of(context);
    final canBack = !embedded && Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          // back · progress · "Question n of m"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 20, 8),
            child: QColumn(
              maxWidth: 1080,
              child: Row(children: [
                if (canBack) ...[
                  QIconButton(
                    icon: AppIcons.back,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0, end: (_i + 1) / widget.questions.length),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, v, _) =>
                        QProgressBar(value: v, height: 8, track: p.line),
                  ),
                ),
                const SizedBox(width: 12),
                Text(_qOf(context),
                    style: uiStyle(context,
                        size: 13, weight: FontWeight.w700, color: p.ink3)),
              ]),
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final question = _questionCard(context, wide: wide);
              final answers = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isOrder) _orderStrip(context),
                  _feedback(context),
                  _optionsGrid(context, vpad: wide ? 18 : 14),
                  if (_isMulti) _submitButton(context),
                  if (q.skippable) _skipButton(context),
                ],
              );
              // Multi-select and ordering questions can add enough option
              // tiles and controls to exceed a phone's height — the whole
              // page scrolls instead of overflowing.
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: QColumn(
                  maxWidth: wide ? 1080 : 720,
                  // (No IntrinsicHeight: the options grid has a LayoutBuilder,
                  // which can't report intrinsic sizes.)
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 11, child: question),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 9,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: answers,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [question, answers],
                        ),
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }

  /// The quiz title, the prompt, and the Arabic in a rounded card.
  Widget _questionCard(BuildContext context, {required bool wide}) {
    final p = pal(context);
    final glyphOnly = q.blank == null &&
        q.arabic != null &&
        q.arabic!.trim().runes.length <= 3;
    final arabic = q.arabic == null
        ? null
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _questionArabic(
                context, q.blank != null ? (wide ? 72 : 58) : (wide ? 110 : 88)),
          );
    final body = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
              const {'en', 'fr', 'es'}
                      .contains(SettingsScope.of(context).language)
                  ? widget.title.toUpperCase()
                  : widget.title,
              textAlign: TextAlign.center,
              style: labelStyle(context)),
        ),
        Text(q.prompt,
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 15, color: p.ink2, height: 1.4)),
        if (arabic != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: glyphOnly
                  ? Container(
                      width: wide ? 240 : 180,
                      height: wide ? 240 : 180,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(44),
                        border: Border.all(color: p.line2),
                      ),
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: arabic)),
                    )
                  : QCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      radius: 28,
                      child: arabic,
                    ),
            ),
          )
        else
          const SizedBox(height: 20),
        if (q.audioRef != null) _audioButton(context),
      ],
    );
    if (!wide) {
      return Padding(padding: const EdgeInsets.only(bottom: 4), child: body);
    }
    return QCard(
      radius: 24,
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 380), child: body),
    );
  }

  /// "Correct" / "Not quite" with the explanation, once a question is graded.
  Widget _feedback(BuildContext context) {
    final p = pal(context);
    final show = _isLocked && (!_wasCorrect || q.explain != null);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      alignment: Alignment.topCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : QRiseIn(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: (_wasCorrect ? AppColors.ok : p.red)
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _wasCorrect
                            ? context.l10n.correctAnswer
                            : context.l10n.notQuite,
                        style: uiStyle(context,
                            size: 14,
                            weight: FontWeight.w700,
                            color: _wasCorrect ? AppColors.ok : p.red)),
                    if (!_wasCorrect)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                            q.explain ??
                                context.l10n.theAnswerIs(_answerDisplay),
                            style: uiStyle(context,
                                size: 13, color: p.ink2, height: 1.4)),
                      ),
                  ],
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
                color: pal(context).acc.withValues(alpha: .14),
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
    final p = pal(context);
    Color border = p.line2;
    Color fill = p.card;
    Color ink = p.ink;
    Widget? badge;
    if (_isMulti) {
      final selected = _multiPicked.contains(i);
      if (_locked) {
        if (q.correctSet!.contains(i)) {
          border = AppColors.ok;
          fill = AppColors.ok.withValues(alpha: .14);
        } else if (selected) {
          border = p.red;
          fill = p.red.withValues(alpha: .14);
        }
      } else if (selected) {
        border = p.acc;
        fill = p.accSoft;
      }
    } else if (_isOrder) {
      final pos = _orderPicked.indexOf(i);
      final used = pos != -1;
      if (used) {
        if (_locked) {
          final right = q.sequence![pos] == q.options[i];
          border = right ? AppColors.ok : p.red;
          fill = (right ? AppColors.ok : p.red).withValues(alpha: .14);
        } else {
          border = p.acc;
          fill = p.accSoft;
        }
        badge = Positioned(
          top: -8,
          right: -8,
          child: CircleAvatar(
            radius: 11,
            backgroundColor: p.acc,
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
        ink = AppColors.ok;
      } else if (i == _picked) {
        border = p.red;
        fill = p.red.withValues(alpha: .14);
        ink = p.red;
      }
    }
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: vpad, horizontal: 18),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.5),
      ),
      // Scale-down guard, not a fixed size: `quranicStyle` multiplies by the
      // reader's arabicScale, and a grid tile is square rather than a wide
      // row, so a large setting would otherwise clip the glyph.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          q.options[i],
          textAlign: TextAlign.center,
          textDirection:
              q.optionsAreArabic ? TextDirection.rtl : TextDirection.ltr,
          style: q.optionsAreArabic
              ? quranicStyle(context,
                  size: q.optionColumns != null ? 40 : 26, color: ink)
              : uiStyle(context, size: 16, weight: FontWeight.w700, color: ink),
        ),
      ),
    );
    final tappable = TapScale(
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
    if (q.dragToGap && q.blank != null && !_isMulti && !_isOrder) {
      return DragTile<int>(
          data: i, enabled: _picked == null, child: tappable);
    }
    return tappable;
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
    final stars = starsForFraction(frac);
    final msg = !graded
        ? context.l10n.practiceRoundComplete
        : stars == 3
            ? context.l10n.perfectScore
            : stars >= 1
                ? context.l10n.wellDoneKeepGoing
                : context.l10n.reviewLessonTryAgain;
    final p = pal(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: QColumn(
              maxWidth: 420,
              child: FadeSlideIn(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProgressRing(
                      fraction: frac,
                      size: 170,
                      center: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('$score/$total',
                            style: displayStyle(context, size: 44)),
                        Text(context.l10n.correctLabel,
                            style: uiStyle(context,
                                size: 12,
                                weight: FontWeight.w600,
                                color: p.ink3)),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    if (graded) StarRow(stars, size: 36),
                    const SizedBox(height: 14),
                    Text(msg,
                        textAlign: TextAlign.center,
                        style: displayStyle(context, size: 24)),
                    const SizedBox(height: 26),
                    Row(children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: p.ink,
                            foregroundColor: p.bg,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.l10n.continueLabel),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Star thresholds for a quiz score fraction.
int starsForFraction(double frac) {
  return frac >= 0.95 ? 3 : (frac >= 0.7 ? 2 : (frac >= 0.4 ? 1 : 0));
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
        icon: const Icon(AppIcons.play, size: 18),
        label: Text(context.l10n.listen),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8)),
      ),
      TextButton.icon(
        onPressed: () => comingSoon(context, context.l10n.video),
        icon: const Icon(AppIcons.video, size: 18),
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

/// A unit row on a module hub (Tajwīd chapters, Script & Symbols units): the
/// unit's glyph on a tile, its title and line, its stars and a chevron.
class UnitCard extends StatelessWidget {
  final String glyph;
  final String title;
  final String subtitle;
  final int stars;
  final VoidCallback onTap;
  const UnitCard({
    super.key,
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.stars = 0,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return QCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.track,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(glyph,
              maxLines: 1,
              textDirection: TextDirection.rtl,
              style: arabicStyle(context, size: 21, height: 1.4, color: p.acc)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: uiStyle(context, size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                      uiStyle(context, size: 13, color: p.ink3, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StarRow(stars, size: 14),
        const SizedBox(width: 6),
        Icon(AppIcons.chevronRight, size: 20, color: p.ink3),
      ]),
    );
  }
}

/// Lays [children] out in two columns once the column is wide enough.
class TwoColumnWrap extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final double breakpoint;
  const TwoColumnWrap(
      {super.key, required this.children, this.gap = 10, this.breakpoint = 680});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= breakpoint ? 2 : 1;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final i in children) SizedBox(width: w, child: i),
        ]);
      });
}

/// One phase of a unit path (Qaidah, Tajwīd, Script & Symbols). A null
/// [builder] means "listed but not open yet" — [PhaseHub] dims that card and
/// taps it through to [comingSoon] instead of navigating, the same treatment
/// `home_screen.dart`'s `_ModuleCard` gives the Qirā’āt module.
class UnitPhase {
  final IconData icon;
  final String label;
  final String sub;
  final WidgetBuilder? builder;

  /// True for the one phase that grades the unit — every unit's Qaidah/
  /// Script three-phase shape has this at index 1, but a Tajwīd rule family's
  /// five-phase shape has a read-only "Letters" browse at index 1 and the
  /// real Test at index 2, so callers look for this flag rather than assuming
  /// a fixed index.
  final bool isTest;
  const UnitPhase(
      {required this.icon,
      required this.label,
      required this.sub,
      this.builder,
      this.isTest = false});
}

/// The three standard phases (Learn → Test → Practice) shared by every
/// Qaidah and Script & Symbols unit.
List<UnitPhase> standardPhases(BuildContext context,
        {required WidgetBuilder learn,
        required WidgetBuilder test,
        required WidgetBuilder practice}) =>
    [
      UnitPhase(
          icon: AppIcons.reader,
          label: context.l10n.phaseLearn,
          sub: context.l10n.phaseLearnSub,
          builder: learn),
      UnitPhase(
          icon: AppIcons.quiz,
          label: context.l10n.phaseTest,
          sub: context.l10n.phaseTestSub,
          builder: test,
          isTest: true),
      UnitPhase(
          icon: AppIcons.repeat,
          label: context.l10n.phasePractice,
          sub: context.l10n.phasePracticeSub,
          builder: practice),
    ];

/// The phase picker every unit path routes through — Qaidah's Learn → Test →
/// Practice, Tajwīd's five-phase path (with a disabled Recite), and Script &
/// Symbols. Nothing enabled is locked; a phase with a null [UnitPhase.builder]
/// is listed but dimmed, and taps through to a coming-soon message.
///
/// With a [glyph] and [title] it opens with the unit's big glyph, its title
/// in the display face and the [subtitle]; the graded phase shows the unit's
/// [stars].
class PhaseHub extends StatelessWidget {
  final String subtitle;
  final List<UnitPhase> phases;
  final void Function(int index) onPick;
  final String? glyph;
  final String? title;
  final int stars;
  const PhaseHub({
    super.key,
    required this.subtitle,
    required this.phases,
    required this.onPick,
    this.glyph,
    this.title,
    this.stars = 0,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        QColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (glyph != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 18),
                  child: Column(children: [
                    Text(glyph!,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 72,
                            height: 1.5,
                            color: p.acc)),
                    if (title != null)
                      Text(title!,
                          textAlign: TextAlign.center,
                          style: displayStyle(context, size: 28)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        textAlign: TextAlign.center,
                        style: uiStyle(context,
                            size: 14, color: p.ink2, height: 1.45)),
                  ]),
                )
              else ...[
                Text(subtitle,
                    style: uiStyle(context,
                        size: 14, color: p.ink2, height: 1.45)),
                const SizedBox(height: 16),
              ],
              for (var i = 0; i < phases.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PhaseCard(
                    phase: phases[i],
                    index: i,
                    stars: stars,
                    onTap: () {
                      if (phases[i].builder == null) {
                        comingSoon(context, phases[i].label);
                      } else {
                        onPick(i);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final UnitPhase phase;
  final int index;
  final int stars;
  final VoidCallback onTap;
  const _PhaseCard(
      {required this.phase,
      required this.index,
      required this.stars,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final open = phase.builder != null;
    // Learn in the accent, Test in gold, the rest in soft hue tints.
    final (Color bg, Color fg) = index == 0
        ? (p.accSoft, p.acc)
        : phase.isTest
            ? (p.sel, p.gold)
            : (() {
                final t = hueTint(context, index.isEven ? 220 : 280);
                return (t.bg, t.fg);
              })();
    return Opacity(
      opacity: open ? 1 : .55,
      child: QCard(
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(phase.icon, size: 22, color: fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phase.label,
                    style: uiStyle(context, size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(phase.sub,
                    style: uiStyle(context,
                        size: 13, color: p.ink3, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!open)
            Icon(AppIcons.lock, size: 18, color: p.ink3)
          else if (phase.isTest && stars > 0)
            StarRow(stars, size: 15)
          else
            Icon(AppIcons.chevronRight, size: 20, color: p.ink3),
        ]),
      ),
    );
  }
}
