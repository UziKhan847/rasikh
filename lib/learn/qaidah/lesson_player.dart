import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../../core/letter_audio.dart';
import '../../core/responsive.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../data/glyph_names.dart';
import '../../data/letters.dart';
import '../../data/strokes.dart' show glyphFor;
import '../../screens/tracing_screen.dart' show TracingBoard;
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';
import '../../widgets/common.dart';
import 'lesson.dart';

/// A lesson, one step at a time: something to look at, to write, or to
/// answer — the answer shown at once — then Continue. On a phone, the step
/// fills the screen under a progress bar; on a wide window the lesson's
/// outline stands beside it. Enter continues, 1–4 answer, the arrows step.
/// At the end: the stars, the mistakes to go over, and the next lesson.
/// Left halfway, a lesson opens again where it was (the same questions: it's
/// built from the seed it was saved with).
class LessonPlayer extends StatefulWidget with DesktopAware {
  /// Where the lesson's stars and place are kept (its [QLesson.progressId]).
  final String id;

  /// The lesson, from a seed (its questions' order and choices).
  final QLesson Function(int seed) build;

  /// Opens the next lesson (null: there's none).
  final VoidCallback? onNext;
  const LessonPlayer({super.key, required this.id, required this.build, this.onNext});

  @override
  State<LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends State<LessonPlayer> {
  late int _seed;
  late QLesson _lesson;
  late List<QStep> _steps;
  int _i = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final place = ProgressScope.read(context).lessonPlace(widget.id);
    _seed = place?.seed ?? DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    _lesson = widget.build(_seed);
    _steps = _lesson.steps;
    if (place != null && place.total == _steps.length) {
      _i = place.step.clamp(0, _steps.length - 1);
      _picked.addAll(place.picks);
    }
  }

  /// Notes where the lesson is (not while going over mistakes).
  void _savePlace() {
    if (_reviewing || _done) return;
    ProgressScope.read(context).saveLessonPlace(widget.id,
        LessonPlace(seed: _seed, step: _i, total: _steps.length, picks: Map.of(_picked)));
  }

  /// The option picked at each answered step.
  final Map<int, int> _picked = {};
  bool _done = false;
  bool _reviewing = false;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  QStep get _step => _steps[_i];

  bool get _canGo => _step is! PickStep || _picked.containsKey(_i);

  void _go() {
    if (!_canGo) return;
    if (_i + 1 < _steps.length) {
      setState(() => _i++);
      _savePlace();
    } else {
      _finish();
    }
  }

  void _back() {
    if (_i > 0) setState(() => _i--);
  }

  void _pick(int option) {
    final s = _step;
    if (s is! PickStep || _picked.containsKey(_i)) return;
    setState(() => _picked[_i] = option);
    _savePlace();
    final q = s.question;
    final right = option == q.correct;
    // Into the review queue, as every quiz does.
    final prog = ProgressScope.read(context);
    final glyph = q.arabic ?? (q.optionsAreArabic ? q.options[q.correct] : null);
    if (glyph != null) {
      final id = q.reviewId ?? glyph;
      if (right) {
        prog.reviewCorrect(id);
      } else {
        prog.recordMiss(id, glyph,
            answer: q.options[q.correct],
            prompt: q.prompt,
            distractors: [for (var k = 0; k < q.options.length; k++) if (k != q.correct) q.options[k]],
            optionsArabic: q.optionsAreArabic);
      }
    }
    if (SettingsScope.of(context).haptics) {
      right ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
  }

  (int, int) get _score {
    var right = 0, total = 0;
    for (var k = 0; k < _steps.length; k++) {
      final s = _steps[k];
      if (s is PickStep && s.graded) {
        total++;
        if (_picked[k] == s.question.correct) right++;
      }
    }
    return (right, total);
  }

  void _finish() {
    if (!_reviewing) {
      final (right, total) = _score;
      final prog = ProgressScope.read(context)..clearLessonPlace(widget.id);
      if (total > 0) prog.report(widget.id, starsForFraction(right / total));
    }
    setState(() => _done = true);
  }

  /// The questions answered wrongly, again (not counted).
  void _reviewMistakes() {
    final wrong = [
      for (var k = 0; k < _steps.length; k++)
        if (_steps[k] case final PickStep s when _picked[k] != s.question.correct)
          PickStep(s.question),
    ];
    if (wrong.isEmpty) return;
    setState(() {
      _steps = wrong;
      _picked.clear();
      _i = 0;
      _done = false;
      _reviewing = true;
    });
  }

  /// The lesson again, with new questions.
  void _retry() => setState(() {
        _seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
        _lesson = widget.build(_seed);
        _steps = _lesson.steps;
        _picked.clear();
        _i = 0;
        _done = false;
        _reviewing = false;
      });

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (_done) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _go();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      final forward = (k == LogicalKeyboardKey.arrowRight) ==
          (Directionality.of(context) == TextDirection.ltr);
      forward ? _go() : _back();
      return KeyEventResult.handled;
    }
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ];
    final d = digits.indexOf(k);
    if (d >= 0 && _step is PickStep && d < (_step as PickStep).question.options.length) {
      _pick(d);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 1000;
            final stage = _done ? _result(context) : _stage(context, wide);
            final body = Column(children: [
              _top(context),
              Expanded(child: stage),
              if (!_done) _footer(context, wide),
            ]);
            if (!wide) return body;
            return Row(children: [
              SizedBox(width: 300, child: _outline(context)),
              VerticalDivider(width: 1, color: p.line2),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880), child: body),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _top(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
      child: Row(children: [
        QIconButton(
          icon: AppIcons.back,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_lesson.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: uiStyle(context, size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _done ? 1 : (_i + 1) / _steps.length,
                minHeight: 6,
                color: p.acc,
                backgroundColor: p.track,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  /// Wide windows: the lesson's steps, the current one marked.
  Widget _outline(BuildContext context) {
    final p = pal(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        Text(_lesson.title, style: displayStyle(context, size: 22)),
        const SizedBox(height: 14),
        for (var k = 0; k < _steps.length; k++)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: k <= _i || _picked.containsKey(k - 1) ? () => setState(() => _i = k) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Row(children: [
                Icon(
                  k < _i
                      ? AppIcons.check
                      : (_steps[k] is PickStep ? AppIcons.quiz : AppIcons.chevronRight),
                  size: 16,
                  color: k == _i ? p.acc : (k < _i ? p.acc : p.ink3),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_stepTitle(context, _steps[k]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiStyle(context,
                          size: 13.5,
                          weight: k == _i ? FontWeight.w700 : FontWeight.w500,
                          color: k == _i ? p.ink : p.ink2)),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  String _stepTitle(BuildContext context, QStep s) => switch (s) {
        ExplainStep(:final title) => title,
        MeetStep(:final letter) => context.l10n.qcMeet(letterName(context, letter)),
        FormsStep(:final letter) => context.l10n.qcFormsTitle(letterName(context, letter)),
        TraceStep(:final letter) => context.l10n.qcTraceTitle(letterName(context, letter)),
        PickStep(:final question) => question.prompt,
      };

  Widget _footer(BuildContext context, bool wide) {
    final s = _step;
    final picked = _picked[_i];
    final p = pal(context);
    String? note;
    Color? noteColor;
    if (s is PickStep && picked != null) {
      final right = picked == s.question.correct;
      note = right ? context.l10n.qcRight : context.l10n.qcNotQuite;
      noteColor = right ? p.acc : p.red;
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, wide ? 20 : 14),
      child: Row(children: [
        if (note != null)
          Expanded(
            child: Text(note,
                style: uiStyle(context, size: 14, weight: FontWeight.w700, color: noteColor)),
          )
        else
          const Spacer(),
        QPrimaryButton(
          context.l10n.continueLabel,
          height: 48,
          onTap: _canGo ? _go : null,
        ),
      ]),
    );
  }

  Widget _stage(BuildContext context, bool wide) {
    final big = wide ? 1.35 : 1.0;
    final child = switch (_step) {
      final ExplainStep s => _explain(context, s, big),
      final MeetStep s => _meet(context, s.letter, big),
      final FormsStep s => _forms(context, s.letter, big),
      final TraceStep s => _trace(context, s.letter),
      final PickStep s => _question(context, s.question, big),
    };
    return SingleChildScrollView(
      key: ValueKey('${_reviewing}_$_i'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: child,
    );
  }

  Widget _explain(BuildContext context, ExplainStep s, double big) {
    final p = pal(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.title, style: displayStyle(context, size: 26 * big)),
      const SizedBox(height: 10),
      Text(s.body, style: uiStyle(context, size: 15.5, color: p.ink2, height: 1.5)),
      if (s.glyphs.isNotEmpty) ...[
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          textDirection: TextDirection.rtl,
          children: [
            for (final g in s.glyphs)
              Container(
                width: 92 * big,
                height: 104 * big,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.line2),
                ),
                child: Text(g, style: quranicStyle(context, size: 52 * big, height: 1.6)),
              ),
          ],
        ),
      ],
    ]);
  }

  Widget _meet(BuildContext context, ArabicLetter x, double big) {
    final p = pal(context);
    return Column(children: [
      Text(context.l10n.qcMeet(letterName(context, x)),
          textAlign: TextAlign.center, style: displayStyle(context, size: 26 * big)),
      const SizedBox(height: 18),
      Container(
        width: 200 * big,
        height: 200 * big,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: p.line2),
        ),
        child: Text(x.char, style: quranicStyle(context, size: 110 * big, height: 1.5)),
      ),
      const SizedBox(height: 18),
      Text(context.l10n.qcSoundsLike(x.translit),
          style: uiStyle(context, size: 17, weight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(dotsDescForLetter(context, x),
          textAlign: TextAlign.center,
          style: uiStyle(context, size: 14.5, color: p.ink2)),
      const SizedBox(height: 16),
      // Listening, where a recording of the letter exists.
      FutureBuilder<bool>(
        future: LetterAudio.has(x.char),
        builder: (context, has) => has.data == true
            ? QOutlineButton(context.l10n.listen,
                icon: AppIcons.volume, onTap: () => LetterAudio.play(x))
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _forms(BuildContext context, ArabicLetter x, double big) {
    final p = pal(context);
    final l = context.l10n;
    final shapes = x.joins
        ? [(x.char, l.formAlone), (x.initial, l.formStart), (x.medial, l.formMiddle), (x.finalForm, l.formEnd)]
        : [(x.char, l.formAlone), (x.finalForm, l.formJoined)];
    final words = letterExamples[x.char] ?? const <LetterExample>[];
    String pos(String w) => switch (w) {
          'beginning' => l.posBeginning,
          'middle' => l.posMiddle,
          _ => l.posEnd,
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.qcFormsTitle(letterName(context, x)), style: displayStyle(context, size: 26 * big)),
      const SizedBox(height: 8),
      Text(x.joins ? l.qcFormsBody : l.qcFormsBodyNoJoin(letterName(context, x)),
          style: uiStyle(context, size: 15, color: p.ink2, height: 1.5)),
      const SizedBox(height: 18),
      // Read right to left, as a word: alone on the right.
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        textDirection: TextDirection.rtl,
        children: [
          for (final (g, caption) in shapes)
            Container(
              width: 104 * big,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.line2),
              ),
              child: Column(children: [
                Text(g,
                    textDirection: TextDirection.rtl,
                    style: quranicStyle(context, size: 50 * big, height: 1.6)),
                Text(caption, style: uiStyle(context, size: 12.5, color: p.ink3)),
              ]),
            ),
        ],
      ),
      if (words.isNotEmpty) ...[
        const SizedBox(height: 22),
        Text(l.qcInTheQuran,
            style: uiStyle(context, size: 13, weight: FontWeight.w700, color: p.ink3)),
        const SizedBox(height: 8),
        for (final w in words)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Text('${pos(w.position)} · ${w.translit}',
                    style: uiStyle(context, size: 13, color: p.ink2)),
              ),
              _marked(context, w.word, x.char, 30 * big),
            ]),
          ),
      ],
    ]);
  }

  Widget _trace(BuildContext context, ArabicLetter x) {
    final p = pal(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(context.l10n.qcTraceTitle(letterName(context, x)), style: displayStyle(context, size: 26)),
      const SizedBox(height: 8),
      Text(context.l10n.qcTraceBody, style: uiStyle(context, size: 15, color: p.ink2, height: 1.5)),
      const SizedBox(height: 14),
      Center(
        child: SizedBox.square(
          dimension: 340,
          child: TracingBoard(glyph: glyphFor(x.char, 'iso'), mode: 'guided'),
        ),
      ),
    ]);
  }

  /// [word] with the first [letter] in it in the accent colour.
  Widget _marked(BuildContext context, String word, String? letter, double size) {
    final p = pal(context);
    final st = quranicStyle(context, size: size, height: 1.7);
    final at = letter == null ? -1 : word.indexOf(letter);
    if (at < 0) return Text(word, textDirection: TextDirection.rtl, style: st);
    return Text.rich(
      TextSpan(style: st, children: [
        TextSpan(text: word.substring(0, at)),
        TextSpan(
            text: word.substring(at, at + letter!.length),
            style: TextStyle(color: p.acc, backgroundColor: p.accSoft)),
        TextSpan(text: word.substring(at + letter.length)),
      ]),
      textDirection: TextDirection.rtl,
    );
  }

  Widget _question(BuildContext context, QuizQuestion q, double big) {
    final p = pal(context);
    final picked = _picked[_i];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(q.prompt, textAlign: TextAlign.center, style: displayStyle(context, size: 24 * big)),
      if (q.arabic != null) ...[
        const SizedBox(height: 18),
        Center(child: _marked(context, q.arabic!, q.highlight, 84 * big)),
      ],
      const SizedBox(height: 22),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var k = 0; k < q.options.length; k++)
            _option(context, q, k, picked, big),
        ],
      ),
      if (picked != null && q.explain != null) ...[
        const SizedBox(height: 16),
        Text(q.explain!,
            textAlign: TextAlign.center,
            style: uiStyle(context, size: 14, color: p.ink2, height: 1.45)),
      ],
    ]);
  }

  Widget _option(BuildContext context, QuizQuestion q, int k, int? picked, double big) {
    final p = pal(context);
    final isRight = k == q.correct;
    final shown = picked != null;
    final Color border, bg;
    if (shown && isRight) {
      border = p.acc;
      bg = p.accSoft;
    } else if (shown && k == picked) {
      border = p.red;
      bg = p.red.withValues(alpha: .12);
    } else {
      border = p.line2;
      bg = p.card;
    }
    return SizedBox(
      width: q.optionsAreArabic ? 104 * big : 200 * big,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border, width: shown && (isRight || k == picked) ? 2 : 1)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: shown ? null : () => _pick(k),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Text('${k + 1}', style: uiStyle(context, size: 11, color: p.ink3)),
              Expanded(
                child: Text(
                  q.options[k],
                  textAlign: TextAlign.center,
                  textDirection: q.optionsAreArabic ? TextDirection.rtl : null,
                  style: q.optionsAreArabic
                      ? quranicStyle(context, size: 40 * big, height: 1.6)
                      : uiStyle(context, size: 15.5, weight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context) {
    final p = pal(context);
    final (right, total) = _score;
    final stars = total == 0 ? 0 : starsForFraction(right / total);
    final anyWrong = [
      for (var k = 0; k < _steps.length; k++)
        if (_steps[k] case final PickStep s when _picked[k] != s.question.correct) k,
    ].isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.l10n.qcResultTitle, style: displayStyle(context, size: 30)),
          const SizedBox(height: 12),
          if (!_reviewing && total > 0) ...[
            StarRow(stars, size: 36),
            const SizedBox(height: 8),
            Text(context.l10n.qcResultScore(right, total),
                style: uiStyle(context, size: 15, color: p.ink2)),
          ],
          const SizedBox(height: 24),
          Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
            if (anyWrong)
              QOutlineButton(context.l10n.qcReviewMistakes,
                  icon: AppIcons.repeat, onTap: _reviewMistakes),
            QOutlineButton(context.l10n.qcRetry, icon: AppIcons.repeat, onTap: _retry),
            if (widget.onNext != null)
              QPrimaryButton(context.l10n.qcNextLesson, height: 48, onTap: () {
                Navigator.of(context).pop();
                widget.onNext!();
              })
            else
              QPrimaryButton(context.l10n.continueLabel,
                  height: 48, onTap: () => Navigator.of(context).maybePop()),
          ]),
        ]),
      ),
    );
  }
}
