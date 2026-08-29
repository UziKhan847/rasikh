import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart';
import '../../data/kids_sentences.dart';
import '../../data/letters.dart';
import '../../data/tracing_levels.dart';
import '../../widgets/common.dart';
import '../tracing_screen.dart' show TracingBoard;
import 'kids_desktop_nav.dart';
import 'kids_widgets.dart';

/// The per-letter micro-lesson: trace each shape → read the sentence →
/// Great job! Reuses the existing tracing engine and audio player rather than
/// rebuilding either.
///
/// One widget covers all four tracing blocks of the Kids path, because they
/// differ only in which glyphs they hand it:
///  * *Letters* trace the isolated shape ([forms] = `['iso']`);
///  * *Joining Forms* trace that letter's real shapes one at a time
///    (`['ini', 'med', 'fin']`, or just `['fin']` for a non-joiner);
///  * the "fewer strokes" pass of each is the same again at [levelId]
///    `'naskh_few'`.
class KidsLetterFlow extends StatefulWidget {
  final String letter;

  /// Which tracing level's glyph set to trace — `'naskh_more'` (the beginner
  /// breakdown, more strokes) or `'naskh_few'` (the same letter in fewer,
  /// longer strokes). Both already ship in `tracing_levels.dart`.
  final String levelId;

  /// The joining forms to trace, in writing order.
  final List<String> forms;

  /// Where completion is recorded. Defaults to the original
  /// `kids.letter.<char>` id so progress earned before the path became
  /// multi-block is not orphaned.
  final String? progressId;

  const KidsLetterFlow({
    super.key,
    required this.letter,
    this.levelId = 'naskh_more',
    this.forms = const ['iso'],
    this.progressId,
  });

  @override
  State<KidsLetterFlow> createState() => _KidsLetterFlowState();
}

enum _Step { trace, sentence, result }

/// 'iso' | 'ini' | 'med' | 'fin' → the reader's language. The same four
/// labels the grown-up Joining Forms lesson uses.
String _formLabel(BuildContext context, String form) => switch (form) {
      'ini' => context.l10n.formStart,
      'med' => context.l10n.formMiddle,
      'fin' => context.l10n.formEnd,
      _ => context.l10n.formAlone,
    };

class _KidsLetterFlowState extends State<KidsLetterFlow> {
  _Step _step = _Step.trace;
  int _formIndex = 0;
  final List<int> _starsPerForm = [];

  ArabicLetter get letter => letterFor(widget.letter);

  /// The worst shape carries the grade — a lesson is only as learned as its
  /// weakest form.
  int get _traceStars =>
      _starsPerForm.isEmpty ? 0 : _starsPerForm.reduce((a, b) => a < b ? a : b);

  /// Only the plain isolated-letter lesson ends on its sentence: a joining-
  /// forms lesson is about the shape, and re-reading the same sentence once
  /// per form would be three helpings of the same thing.
  bool get _hasSentence =>
      widget.forms.length == 1 &&
      widget.forms.single == 'iso' &&
      sentenceForLetter(widget.letter) != null;

  KidsSentence? get _sentence => sentenceForLetter(widget.letter);

  int get _stepCount => widget.forms.length + (_hasSentence ? 1 : 0);

  /// The trace is graded but no longer auto-advances — the child chooses
  /// "Try again" or "Next" from [_TraceStep]'s own panel.
  void _onTraceDone(int stars) {
    if (_step != _Step.trace) return;
    _starsPerForm.add(stars);
    if (_formIndex + 1 < widget.forms.length) {
      setState(() => _formIndex++);
    } else if (_hasSentence) {
      setState(() => _step = _Step.sentence);
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
    for (final b in kidsBadgeDefs(context)) {
      if (b.earned(prog)) prog.unlockBadge(b.id);
    }
    setState(() => _step = _Step.result);
  }

  /// 1-based, for "Step N of M".
  int get _stepNumber =>
      _step == _Step.trace ? _formIndex + 1 : widget.forms.length + 1;

  Widget _content(BuildContext context) => switch (_step) {
        _Step.trace => _TraceStep(
            // Keyed by form so moving on to the next shape remounts the board
            // rather than leaving the previous one's strokes on it.
            key: ValueKey('${widget.letter}.${widget.forms[_formIndex]}'),
            letter: letter,
            levelId: widget.levelId,
            form: widget.forms[_formIndex],
            onDone: _onTraceDone,
          ),
        _Step.sentence =>
          _SentenceStep(sentence: _sentence!, onDone: _finish),
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
        _Step.trace => 520.0,
        _Step.sentence => 560.0,
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

class _TraceStep extends StatefulWidget {
  final ArabicLetter letter;
  final String levelId;
  final String form; // 'iso' | 'ini' | 'med' | 'fin'

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
      required this.onDone});

  @override
  State<_TraceStep> createState() => _TraceStepState();
}

class _TraceStepState extends State<_TraceStep> {
  /// Bumped by "Try again" to remount [TracingBoard] with a fresh key — the
  /// attempt-counter remount tracing_screen.dart already documents as its
  /// reset mechanism, so the board itself needs no new API.
  int _attempt = 0;
  int? _stars; // null until this attempt has been graded

  Future<void> _hear() async {
    final parts = widget.letter.exampleRef.split(':');
    final s = int.tryParse(parts[0]);
    final a = int.tryParse(parts.length > 1 ? parts[1] : '');
    if (s == null || a == null) return;
    await AyahAudio.instance.play(s, a);
  }

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
                  // a lesson teaches more than the isolated letter.
                  if (widget.form != 'iso')
                    Text(_formLabel(context, widget.form),
                        style:
                            kidsStyle(context, size: 12.5, color: p.textDim)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _hear,
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
                if (_stars == null) setState(() => _stars = s);
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

class _SentenceStep extends StatelessWidget {
  final KidsSentence sentence;
  final VoidCallback onDone;
  const _SentenceStep({required this.sentence, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Geo.gapLg, 0, Geo.gapLg, Geo.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.kidsReadTheSentence,
              style: kidsStyle(context, size: 17, weight: FontWeight.w800)),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: highlightSpans(
                          sentence.sentence,
                          sentence.targetWord,
                          arabicStyle(context, size: 28),
                          arabicStyle(context, size: 28, color: p.accent)),
                    ),
                  ),
                  const SizedBox(height: Geo.gapLg),
                  // A transliteration chip, not a play button. These
                  // sentences are authored MSA, not corpus text, so there is
                  // no recitation to attach — this used to be a speaker icon
                  // wired to comingSoon(), which is a dead control in a
                  // child's lesson.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius:
                            BorderRadius.circular(Geo.radiusPill)),
                    child: Text(sentence.translit,
                        style: kidsStyle(context,
                            size: 14, weight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Text(sentence.gloss,
                      style: kidsStyle(context, size: 13, color: p.textDim)),
                ],
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: onDone,
            child: Text(context.l10n.continueLabel),
          ),
        ],
      ),
    );
  }
}

class _ResultStep extends StatelessWidget {
  final ArabicLetter letter;
  final int stars;
  const _ResultStep({required this.letter, required this.stars});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final prog = ProgressScope.of(context);
    final p = kidsPal(context);
    final gender = s.activeKidsProfile?.gender ?? '';
    final shownStars = stars == 0 ? 1 : stars;
    return Stack(children: [
      // Scrollable, not a bare Center: on a short phone — or at a large text
      // scale — this column is taller than the viewport, and the one control
      // that matters, "Continue", sits at the bottom of it.
      SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * .6),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Geo.gapLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const KidsMascot(),
                  const SizedBox(height: Geo.gapMd),
                  Text(context.l10n.kidsGreatJob,
                      style: kidsStyle(context,
                          size: 22, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(kidsPraiseArabic(gender),
                      textDirection: TextDirection.rtl,
                      style: quranicStyle(context, size: 22, color: p.accent)),
                  const SizedBox(height: Geo.gapMd),
                  StarRow(shownStars, size: 36),
                  const SizedBox(height: Geo.gapMd),
                  Text(context.l10n.kidsXpEarned(kidsXpPerStar * shownStars),
                      style: kidsStyle(context,
                          size: 15, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(context.l10n.streakDaysLabel(prog.streakDays),
                      style: kidsStyle(context, size: 13, color: p.textDim)),
                  const SizedBox(height: Geo.gapXl),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16)),
                    onPressed: () => closeKidsOverlayOrPop(context),
                    child: Text(context.l10n.continueLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const Positioned.fill(child: KidsConfetti()),
    ]);
  }
}
