import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/letter_audio.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/glyph_ink.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart';
import '../../data/kids_sentences.dart' show kidsPraiseArabic;
import '../../data/letters.dart';
import '../../data/tracing_levels.dart';
import '../../widgets/common.dart';
import '../tracing_screen.dart' show TracingBoard;
import 'kids_desktop_nav.dart';
// Mutual import with kids_path.dart, which builds these lessons: the
// celebration step reads the path back to name what comes next.
import 'kids_path.dart';
import 'kids_widgets.dart';

/// One thing to trace in a lesson: which glyph set, and which joining form.
class KidsTraceStep {
  /// `'naskh_more'` (the beginner breakdown) or `'naskh_few'` (the same shape
  /// in fewer, longer strokes). Both already ship in `tracing_levels.dart`.
  final String levelId;
  final String form; // 'iso' | 'ini' | 'med' | 'fin'

  /// How many times in a row this shape is traced. Handwriting is learned by
  /// repetition, so the fewer-strokes pass — the one nearest to actually
  /// writing the letter — is done several times before the lesson ends.
  /// Each pass is its own step, and the shape is graded on the **best** of
  /// them, so practising cannot lower the mark.
  final int repeat;

  const KidsTraceStep(this.levelId, this.form, {this.repeat = 1});
}

/// One pass over one shape: which trace it belongs to, and where in that
/// trace's repetitions it falls.
typedef _Pass = ({KidsTraceStep trace, int traceIndex, int pass, int passes});

/// The per-letter micro-lesson: meet the shape → say it out loud → trace it →
/// Great job! Reuses the existing tracing engine and audio player rather than
/// rebuilding either.
///
/// The order is deliberate, and it is a Qāʿidah's: a child sees the letter and
/// hears it, says it back until it sticks, and only then writes it. It ends
/// there. It used to end on "Read the sentence" — a full voweled MSA sentence
/// shown to a child who had just met their first letter and knew no ḥarakāt,
/// which asked for something they could not possibly do. Reading words is a
/// stage of its own, much further along the path.
///
/// One widget covers both tracing stages of the path, because they differ only
/// in the glyphs they hand it — each shape traced with the beginner stroke
/// breakdown once and then written in fewer, longer strokes several times:
///  * *Letters* take the isolated shape through that pair;
///  * *Joining Forms* take each shape the letter really has (`ini`, `med`,
///    `fin`, or just `fin` for a non-joiner) through the same pair in turn.
class KidsLetterFlow extends StatefulWidget {
  final String letter;

  /// The shapes to trace, in order.
  final List<KidsTraceStep> traces;

  /// Show the "this is the letter" card and the say-it-aloud drill before
  /// tracing. Both tracing stages of the path set this: the joining-forms
  /// lesson used to go straight to the shapes on the grounds that the sound
  /// was already known, but naming the letter before writing it is how a
  /// Qāʿidah runs, and it costs two steps at the top of the lesson rather
  /// than two per shape.
  final bool introduce;

  /// How many times the child says the letter out loud before writing it.
  /// Zero skips the step.
  final int sayTimes;

  /// Where completion is recorded. Defaults to the original
  /// `kids.letter.<char>` id so progress earned before the path became
  /// multi-stage is not orphaned.
  final String? progressId;

  const KidsLetterFlow({
    super.key,
    required this.letter,
    this.traces = const [KidsTraceStep('naskh_more', 'iso')],
    this.introduce = true,
    this.sayTimes = 5,
    this.progressId,
  });

  @override
  State<KidsLetterFlow> createState() => _KidsLetterFlowState();
}

enum _Step { shape, say, trace, result }

/// 'iso' | 'ini' | 'med' | 'fin' → the reader's language. The same four
/// labels the grown-up Joining Forms lesson uses.
String _formLabel(BuildContext context, String form) => switch (form) {
      'ini' => context.l10n.formStart,
      'med' => context.l10n.formMiddle,
      'fin' => context.l10n.formEnd,
      _ => context.l10n.formAlone,
    };

class _KidsLetterFlowState extends State<KidsLetterFlow> {
  late _Step _step = widget.introduce ? _Step.shape : _Step.trace;

  /// Every trace this lesson asks for, repetitions flattened out, so a
  /// repeated shape counts honestly towards "Step N of M" instead of the
  /// label sticking on the last step while the child traces four more times.
  late final List<_Pass> _passes = [
    for (var t = 0; t < widget.traces.length; t++)
      for (var i = 0; i < widget.traces[t].repeat; i++)
        (
          trace: widget.traces[t],
          traceIndex: t,
          pass: i + 1,
          passes: widget.traces[t].repeat,
        ),
  ];

  int _passIndex = 0;

  /// Best mark per shape, keyed by index into `widget.traces`. Best, not
  /// last: repetitions are practice, and a slip on the fifth try should not
  /// undo four clean ones.
  final Map<int, int> _bestPerTrace = {};

  ArabicLetter get letter => letterFor(widget.letter);

  bool get _hasSay => widget.introduce && widget.sayTimes > 0;

  /// The worst *shape* carries the grade — a lesson is only as learned as its
  /// weakest form.
  int get _traceStars => _bestPerTrace.isEmpty
      ? 0
      : _bestPerTrace.values.reduce((a, b) => a < b ? a : b);

  int get _stepCount =>
      (widget.introduce ? 1 : 0) + (_hasSay ? 1 : 0) + _passes.length;

  /// 1-based, for "Step N of M".
  int get _stepNumber {
    final intro = widget.introduce ? 1 : 0;
    return switch (_step) {
      _Step.shape => 1,
      _Step.say => intro + 1,
      _ => intro + (_hasSay ? 1 : 0) + _passIndex + 1,
    };
  }

  void _afterShape() =>
      setState(() => _step = _hasSay ? _Step.say : _Step.trace);

  void _afterSay() => setState(() => _step = _Step.trace);

  /// The trace is graded but does not auto-advance — the child chooses
  /// "Try again" or "Next" from [_TraceStep]'s own panel.
  void _onTraceDone(int stars) {
    if (_step != _Step.trace) return;
    final t = _passes[_passIndex].traceIndex;
    final best = _bestPerTrace[t];
    if (best == null || stars > best) _bestPerTrace[t] = stars;
    if (_passIndex + 1 < _passes.length) {
      setState(() => _passIndex++);
    } else {
      _finish();
    }
  }

  void _finish() {
    final prog = ProgressScope.of(context);
    final stars = _traceStars == 0 ? 1 : _traceStars;
    prog.report(
        widget.progressId ?? 'kids.letter.${widget.letter}', stars);
    prog.awardXp(kidsXpPerStar * stars);
    prog.awardGems(
        kidsGemsPerLesson + (stars >= 3 ? kidsGemsBonusPerfect : 0));
    // Badges are synced centrally from the store this reports into — see
    // `kidsSyncBadges` and `KidsProfileGate` — so any badge earned here,
    // there, or by a quiz unlocks the same way.
    setState(() => _step = _Step.result);
  }

  Widget _content(BuildContext context) => switch (_step) {
        _Step.shape => _ShapeStep(letter: letter, onNext: _afterShape),
        _Step.say => _SayStep(
            letter: letter, times: widget.sayTimes, onDone: _afterSay),
        _Step.trace => _TraceStep(
            // Keyed by pass so moving on to the next one — including the next
            // repetition of the same shape — remounts the board rather than
            // leaving the previous strokes on it.
            key: ValueKey('${widget.letter}.$_passIndex'),
            letter: letter,
            levelId: _passes[_passIndex].trace.levelId,
            form: _passes[_passIndex].trace.form,
            pass: _passes[_passIndex].pass,
            passes: _passes[_passIndex].passes,
            onDone: _onTraceDone,
          ),
        _Step.result => _ResultStep(letter: letter, stars: _traceStars),
      };

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    if (useDesktop(context)) {
      // The shell's own top bar carries the back control while an overlay
      // is open (see KidsDesktopOverlay) — this just centres the step
      // content to the design's per-step max width, plus the step label
      // mobile otherwise shows in its AppBar title.
      final maxWidth = switch (_step) {
        _Step.shape || _Step.say => 460.0,
        _Step.trace => 520.0,
        _Step.result => 460.0,
      };
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.all(Geo.gapXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step != _Step.result) ...[
                  Text(context.l10n.kidsStepOf(_stepNumber, _stepCount),
                      style: kidsStyle(context, size: 13, color: p.textDim)),
                  const SizedBox(height: Geo.gapSm),
                ],
                Expanded(child: _content(context)),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: p.bg,
      appBar: _step == _Step.result
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              title: Text(context.l10n.kidsStepOf(_stepNumber, _stepCount),
                  style: kidsStyle(context, size: 13, color: p.textDim)),
            ),
      body: SafeArea(child: _content(context)),
    );
  }
}

/// Step 1: meet the letter. Its shape, big; its name; and a button to hear
/// it in a real word. Nothing is asked yet.
class _ShapeStep extends StatelessWidget {
  final ArabicLetter letter;
  final VoidCallback onNext;
  const _ShapeStep({required this.letter, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Geo.gapLg, 0, Geo.gapLg, Geo.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.kidsThisIsLetter(letterName(context, letter)),
              style: kidsStyle(context, size: 17, weight: FontWeight.w800)),
          const SizedBox(height: Geo.gapMd),
          Expanded(child: _GlyphHero(letter.char)),
          const SizedBox(height: Geo.gapMd),
          Center(child: _HearButton(letter: letter)),
          const SizedBox(height: Geo.gapLg),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: onNext,
            child: Text(context.l10n.kidsNextCard),
          ),
        ],
      ),
    );
  }
}

/// Step 2: say it out loud, [times] times — the child taps once per
/// repetition. Nothing here can be graded (there is no microphone), so the
/// counter is the whole mechanic: it paces the repetition instead of leaving
/// "say it a few times" as a line of text nobody acts on.
class _SayStep extends StatefulWidget {
  final ArabicLetter letter;
  final int times;
  final VoidCallback onDone;
  const _SayStep(
      {required this.letter, required this.times, required this.onDone});

  @override
  State<_SayStep> createState() => _SayStepState();
}

class _SayStepState extends State<_SayStep> {
  int _said = 0;

  void _tap() {
    // Every repetition answers back with the letter's own sound, so the child
    // hears the model immediately after saying it rather than practising an
    // unchecked guess five times over. Fire-and-forget: the counter must not
    // wait on a media player, and [LetterAudio] swallows its own failures.
    LetterAudio.play(widget.letter);
    if (_said + 1 >= widget.times) {
      widget.onDone();
      return;
    }
    setState(() => _said++);
  }

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Geo.gapLg, 0, Geo.gapLg, Geo.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.kidsSayItAloud,
              style: kidsStyle(context, size: 17, weight: FontWeight.w800)),
          const SizedBox(height: Geo.gapMd),
          Expanded(child: _GlyphHero(widget.letter.char)),
          const SizedBox(height: Geo.gapMd),
          // The name is what the child actually says, so it is spelled out
          // under the shape rather than left for them to remember.
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(letterName(context, widget.letter),
                  style: kidsStyle(context,
                      size: 30, weight: FontWeight.w800, color: p.accent)),
            ),
          ),
          const SizedBox(height: Geo.gapMd),
          // A dot per repetition, so how many are left is visible at a glance
          // rather than something to read and count.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.times; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _said ? p.amber : p.surfaceHigh,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Geo.gapMd),
          Center(child: _HearButton(letter: widget.letter)),
          const SizedBox(height: Geo.gapLg),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _tap,
            child: Text(context.l10n.kidsSaidIt),
          ),
        ],
      ),
    );
  }
}

/// The letter, as big as the space allows and its INK centred in the card —
/// not its line box. `FittedBox` centres a `Text` widget's line box, and for
/// an isolated Arabic letter the two are very different things: UthmanicHafs'
/// natural line leaves headroom sized for a full word's tashkīl, and how much
/// ink sits above vs. below the baseline swings wildly by letter (kāf reaches
/// +0.68em above it, jīm/ḥā/khā/ʿayn/ghayn/mīm reach −0.44em below it — see
/// `glyph_ink.dart`). Centring the line box left a wide gap above some
/// letters and crowded others against the bottom of their card.
///
/// Deliberately not `quranicStyle` — that scales with the user's Arabic-size
/// reading preference, but this card sizes the glyph to fill itself, not to
/// a reading preference.
class _GlyphHero extends StatelessWidget {
  final String glyph;
  const _GlyphHero(this.glyph);

  @override
  Widget build(BuildContext context) {
    final ink = kUthmanicInk[glyph];
    return LayoutBuilder(builder: (context, c) {
      final side =
          math.min(c.maxWidth, c.maxHeight).clamp(120.0, 280.0).toDouble();
      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: Container(
            decoration: kidsCard(context),
            padding: const EdgeInsets.all(Geo.gapXl),
            // The old `Text` widget exposed the glyph to a screen reader for
            // free; painting it on a canvas does not. Restore that with an
            // explicit label rather than leaving the card silent — the
            // heading above already says the letter's name, so this is
            // ExcludeSemantics'd down to the one label rather than merging
            // whatever the fallback branch's own `Text` would add.
            child: Semantics(
              label: glyph,
              child: ExcludeSemantics(
                child: ink == null
                    // No measured bounds for this glyph (never hit by the 28
                    // taught letters, all of which are in the table) — fall
                    // back to line-box centring rather than crash.
                    ? SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(glyph,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                  fontFamily: 'UthmanicHafs',
                                  fontSize: 100,
                                  color: kidsPal(context).text)),
                        ),
                      )
                    : SizedBox.expand(
                        child: CustomPaint(
                          painter: _InkCenteredGlyphPainter(
                              glyph: glyph,
                              top: ink.$1,
                              bottom: ink.$2,
                              color: kidsPal(context).text),
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Paints [glyph] as large as possible with its measured ink bounds — not its
/// line box — centred in [size]. See [_GlyphHero].
class _InkCenteredGlyphPainter extends CustomPainter {
  final String glyph;
  final double top; // ink top, em above the baseline
  final double bottom; // ink bottom, em above the baseline (negative if below)
  final Color color;
  const _InkCenteredGlyphPainter(
      {required this.glyph,
      required this.top,
      required this.bottom,
      required this.color});

  TextPainter _layout(double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
          text: glyph,
          style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: fontSize,
              height: 1.0,
              color: color)),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
    );
    tp.layout();
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (top <= bottom || size.height <= 0 || size.width <= 0) return;

    var fontSize = glyphInkFontSize(size.height, top, bottom);
    var tp = _layout(fontSize);
    // tp.width is the line's own advance width, a looser bound than the
    // glyph's actual ink width but a safe one — if it would overflow the
    // card, scale down to fit it and accept the resulting vertical margin.
    if (tp.width > size.width) {
      fontSize *= size.width / tp.width;
      tp = _layout(fontSize);
    }

    final offset = glyphInkOffset(
      size: size,
      fontSize: fontSize,
      top: top,
      bottom: bottom,
      lineWidth: tp.width,
      baseline: tp.computeDistanceToActualBaseline(TextBaseline.alphabetic),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    tp.paint(canvas, offset);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InkCenteredGlyphPainter old) =>
      old.glyph != glyph ||
      old.top != top ||
      old.bottom != bottom ||
      old.color != color;
}

/// Says the letter out loud — see [LetterAudio] for what "the letter's
/// audio" actually resolves to.
class _HearButton extends StatelessWidget {
  final ArabicLetter letter;
  const _HearButton({required this.letter});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return TextButton.icon(
      onPressed: () => LetterAudio.play(letter),
      icon: Icon(Icons.volume_up_rounded, color: p.accent2),
      label: Text(context.l10n.listen,
          style: kidsStyle(context, color: p.accent2)),
    );
  }
}

class _TraceStep extends StatefulWidget {
  final ArabicLetter letter;
  final String levelId;
  final String form; // 'iso' | 'ini' | 'med' | 'fin'

  /// Which repetition of this shape this is, and how many there are. Shown
  /// only when there is more than one, so the child can see that tracing it
  /// again is the plan rather than a mistake.
  final int pass;
  final int passes;

  /// Called when the child taps "Next", NOT the moment the trace completes —
  /// finishing a trace used to advance on a 700ms timer while [TracingBoard]'s
  /// own grown-up result popup was still appearing, so the popup was yanked
  /// away before it could be read. The child decides when to move on now.
  final void Function(int stars) onDone;
  const _TraceStep(
      {super.key,
      required this.letter,
      required this.levelId,
      required this.form,
      required this.onDone,
      this.pass = 1,
      this.passes = 1});

  @override
  State<_TraceStep> createState() => _TraceStepState();
}

class _TraceStepState extends State<_TraceStep> {
  /// Bumped by "Try again" to remount [TracingBoard] with a fresh key — the
  /// attempt-counter remount tracing_screen.dart already documents as its
  /// reset mechanism, so the board itself needs no new API.
  int _attempt = 0;
  int? _stars; // null until this attempt has been graded

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final level = tracingLevels.firstWhere((l) => l.id == widget.levelId,
        orElse: () => tracingLevels.firstWhere((l) => !l.words));
    final glyph = level.glyphForIn(widget.letter.char, widget.form);
    final stars = _stars;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Geo.gapLg, 0, Geo.gapLg, Geo.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      context.l10n
                          .kidsTraceThe(letterName(context, widget.letter)),
                      style: kidsStyle(context,
                          size: 17, weight: FontWeight.w800)),
                  // Which of the four shapes this is — only meaningful once
                  // a lesson teaches more than the isolated letter — and,
                  // where the shape is practised several times over, which
                  // go this is.
                  if (widget.form != 'iso' || widget.passes > 1)
                    Text(
                        [
                          if (widget.form != 'iso')
                            _formLabel(context, widget.form),
                          if (widget.passes > 1)
                            context.l10n
                                .kidsTracePass(widget.pass, widget.passes),
                        ].join(' · '),
                        style:
                            kidsStyle(context, size: 12.5, color: p.textDim)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => LetterAudio.play(widget.letter),
              icon: Icon(Icons.volume_up_rounded, color: p.accent2),
              label: Text(context.l10n.listen,
                  style: kidsStyle(context, color: p.accent2)),
            ),
          ]),
          const SizedBox(height: Geo.gapSm),
          Expanded(
            child: TracingBoard(
              key: ValueKey(
                  '${widget.letter.char}.${widget.form}.$_attempt'),
              glyph: glyph,
              mode: 'guided',
              // The board's own overlay is the grown-up "Perfect trace / Try
              // again" card, in the adult palette. Kids Mode shows its own
              // below instead — the same reason the quizzes suppress it.
              showOverlay: false,
              onStars: (s) {
                if (_stars != null) return;
                // The shape has just been drawn and is still on screen: this
                // is the moment the sound and the sight of the letter line
                // up, so the letter says itself. Same reinforcement as the
                // say-it-aloud step, on the writing half of the lesson.
                LetterAudio.play(widget.letter);
                setState(() => _stars = s);
              },
            ),
          ),
          if (stars != null) ...[
            const SizedBox(height: Geo.gapMd),
            _TraceResultPanel(
              stars: stars,
              onRetry: () => setState(() {
                _attempt++;
                _stars = null;
              }),
              onNext: () => widget.onDone(stars),
            ),
          ],
        ],
      ),
    );
  }
}

/// The kids-styled "you finished this trace" panel: how it went, then the
/// two choices — trace it again, or move on.
class _TraceResultPanel extends StatelessWidget {
  final int stars;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  const _TraceResultPanel(
      {required this.stars, required this.onRetry, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Container(
      padding: const EdgeInsets.all(Geo.gapMd),
      decoration: kidsCard(context),
      child: Column(children: [
        StarRow(stars, size: 28),
        const SizedBox(height: Geo.gapSm),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                  foregroundColor: p.textDim,
                  side: BorderSide(color: p.surfaceHigh, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.traceAgain,
                  style: kidsStyle(context,
                      size: 14, weight: FontWeight.w700, color: p.textDim)),
            ),
          ),
          const SizedBox(width: Geo.gapSm),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: onNext,
              // Already a plain "Next" in every locale, not "Next card".
              child: Text(context.l10n.kidsNextCard,
                  style: kidsStyle(context,
                      size: 14,
                      weight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ResultStep extends StatelessWidget {
  final ArabicLetter letter;
  final int stars;
  const _ResultStep({required this.letter, required this.stars});

  /// What the child moves on to, or null once the whole path is cleared.
  ///
  /// Read *after* [_KidsLetterFlowState._finish] has reported this lesson, so
  /// it really is the next one — and it crosses into the following stage on
  /// its own when this lesson was a stage's last. It is here so "Continue" is
  /// a door with something written on it.
  KidsItem? _next(BuildContext context, ProgressStore prog) {
    final path = kidsPath(context);
    final block = path[kidsCurrentBlockIndex(context, prog)];
    final items = block.items(context);
    final i = kidsCurrentItemIndex(prog, items);
    return i < items.length ? items[i] : null;
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final gender = s.activeKidsProfile?.gender ?? '';
    final shownStars = stars == 0 ? 1 : stars;
    final next = _next(context, prog);
    // Centred on the space it actually has, not on a guess at it: the minimum
    // height used to be 60% of the window, which parked the whole celebration
    // in the top half of a tall phone with the bottom half left empty. The
    // scroll view stays, because on a short screen at a large text scale this
    // column outgrows the viewport and "Continue" is the last thing in it.
    return LayoutBuilder(builder: (context, c) {
      return Stack(children: [
        SizedBox(
          height: c.maxHeight,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Geo.gapLg, vertical: Geo.gapLg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const KidsMascot(size: 116),
                      const SizedBox(height: Geo.gapMd),
                      Text(context.l10n.kidsGreatJob,
                          style: kidsStyle(context,
                              size: 24, weight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(kidsPraiseArabic(gender),
                          textDirection: TextDirection.rtl,
                          style:
                              quranicStyle(context, size: 22, color: p.accent)),
                      const SizedBox(height: Geo.gapMd),
                      StarRow(shownStars, size: 40),
                      const SizedBox(height: Geo.gapMd),
                      Text(
                          context.l10n
                              .kidsXpEarned(kidsXpPerStar * shownStars),
                          style: kidsStyle(context,
                              size: 15, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(context.l10n.streakDaysLabel(prog.streakDays),
                          style:
                              kidsStyle(context, size: 13, color: p.textDim)),
                      const SizedBox(height: Geo.gapXl),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: p.accent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16)),
                        onPressed: () => closeKidsOverlayOrPop(context),
                        child: Text(context.l10n.continueLabel),
                      ),
                      if (next != null) ...[
                        const SizedBox(height: Geo.gapLg),
                        _NextUpChip(item: next),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(child: KidsConfetti()),
      ]);
    });
  }
}

/// "Next: Tāʾ", with the glyph — a signpost, not a second button. The one
/// thing to tap on this screen stays "Continue"; this only says where it
/// goes.
class _NextUpChip extends StatelessWidget {
  final KidsItem item;
  const _NextUpChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: p.surfaceHigh.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(Geo.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.glyph.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(item.glyph,
                  textDirection: TextDirection.rtl,
                  style: quranicStyle(context,
                      size: 19, height: 1.05, color: p.accent2)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(item.icon, size: 17, color: p.accent2),
            ),
          Text(context.l10n.kidsNextUp(item.label(context)),
              style: kidsStyle(context,
                  size: 13, weight: FontWeight.w700, color: p.textDim)),
        ],
      ),
    );
  }
}
