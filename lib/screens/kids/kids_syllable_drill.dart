import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/letter_audio.dart';
import '../../core/theme.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart' show kidsLetterPath;
import '../../data/letters.dart';
import '../../data/tashkeel.dart';
import '../../widgets/common.dart' show starsForFraction;
import 'kids_checkpoint_quiz.dart' show kidsCheckpointEvery;
import 'kids_choice_card.dart';
import 'kids_widgets.dart';

final _rng = math.Random();

/// The letters a ḥarakah drill walks: the alphabet without alif, which takes
/// none of these marks (it is a madd letter, met on its own).
List<ArabicLetter> get kidsSyllableLetters => [
  for (final l in kidsLetterPath)
    if (l.char != 'ا') l,
];

/// How many sessions each mark's drill is split into.
const kidsDrillSessions = 3;

/// The `[start, end)` slice of [kidsSyllableLetters] each session covers —
/// near-equal, in order, and together exactly the whole list.
List<(int, int)> kidsDrillRanges() {
  final n = kidsSyllableLetters.length;
  return [
    for (var i = 0; i < kidsDrillSessions; i++)
      ((n * i) ~/ kidsDrillSessions, (n * (i + 1)) ~/ kidsDrillSessions),
  ];
}

/// How [l] with [m] is said in Latin letters — `ba`, `bi`, `bu`, `ban`, a bare
/// `b` for sukūn, `bb` for a shaddah. Every mark's [TashkilItem.sound] is
/// spelled on a bā’ carrier, so the vowel part is everything after its first
/// character; sukūn has none, and a shaddah doubles the letter instead.
String kidsSyllableSound(ArabicLetter l, TashkilItem m) => switch (m.id) {
  'sukun' => l.translit,
  'shadda' => '${l.translit}${l.translit}',
  _ => '${l.translit}${m.sound.substring(1)}',
};

/// One thing to do inside a [KidsSyllableDrill]: meet a syllable, or answer
/// a quick recognition check over the ones just met.
sealed class _Step {
  const _Step();
}

class _LetterStep extends _Step {
  final ArabicLetter letter;
  const _LetterStep(this.letter);
}

class _CheckStep extends _Step {
  final ArabicLetter answer;
  final List<ArabicLetter> options;
  const _CheckStep({required this.answer, required this.options});
}

/// Qāʿidah Nūrāniyyah's own drill for one mark: walked letter by letter
/// through the whole alphabet — بَ تَ ثَ جَ … — rather than a single page of
/// prose about the mark in the abstract. Alif takes none of these eight marks
/// (it is a madd letter, met on its own in the Letters stage), so it is
/// skipped here the same way `qaidah_screen.dart`'s own `_syllableQuiz`
/// already does.
///
/// A short recognition check-up is woven in every five letters — the same
/// cumulative-checkup rhythm the Letters and Joining Shapes stages use
/// (`kidsCheckpointEvery`) — rather than one long unbroken walk.
///
/// The whole alphabet in one sitting is ~32 steps, which is well past what a
/// 4–6 year old sustains (roughly 8–10 minutes; the leading kids' apps aim
/// for 3–5). The path therefore opens each mark as [kidsDrillSessions]
/// shorter sessions, each a [start]..[end] slice of the letters; the default
/// (no slice) is still the whole alphabet. Check-up distractors are always
/// drawn from the WHOLE alphabet, since every letter is already known by the
/// time this stage is reached, not just this session's slice.
class KidsSyllableDrill extends StatefulWidget {
  final TashkilItem mark;
  final String progressId;

  /// The slice of the alif-less alphabet this session covers.
  final int start;
  final int? end;
  const KidsSyllableDrill({
    super.key,
    required this.mark,
    required this.progressId,
    this.start = 0,
    this.end,
  });

  @override
  State<KidsSyllableDrill> createState() => _KidsSyllableDrillState();
}

class _KidsSyllableDrillState extends State<KidsSyllableDrill> {
  /// The bare combining mark(s) — [TashkilItem.mark] is that mark already
  /// shown on a ب carrier (e.g. `'بَ'`), so dropping the first character
  /// leaves just the mark, ready to compose onto ANY letter the same way
  /// `_syllableQuiz` already builds `'${l.char}$mark'`.
  String get _mark => widget.mark.mark.substring(1);

  late final List<ArabicLetter> _all = kidsSyllableLetters;
  late final List<ArabicLetter> _letters = _all.sublist(
    widget.start,
    widget.end ?? _all.length,
  );
  late final List<_Step> _steps = _buildSteps();

  int _index = 0;
  int _correct = 0;
  int _total = 0;

  List<_Step> _buildSteps() {
    final out = <_Step>[];
    for (var i = 0; i < _letters.length; i++) {
      out.add(_LetterStep(_letters[i]));
      final done = i + 1;
      if (done % kidsCheckpointEvery == 0 && done != _letters.length) {
        final pool = _letters.sublist(
          math.max(0, done - kidsCheckpointEvery),
          done,
        );
        final answer = pool[_rng.nextInt(pool.length)];
        final rest = [..._all]..shuffle(_rng);
        final options = <ArabicLetter>[answer];
        for (final l in rest) {
          if (options.length >= 4) break;
          if (l != answer) options.add(l);
        }
        options.shuffle(_rng);
        out.add(_CheckStep(answer: answer, options: options));
      }
    }
    return out;
  }

  bool get _done => _index >= _steps.length;

  /// A drill with no checkpoints at all (a mark with fewer than five letters
  /// — none today, but nothing here assumes eight) has nothing to grade
  /// itself on, so it earns a perfect mark for having been walked at all.
  int get _stars =>
      _total == 0 ? 3 : starsForFraction(_correct / _total, kids: true);

  bool _reported = false;

  void _advance() => setState(() => _index++);

  /// Files the check in the review queue: a miss the moment it happens, a
  /// promotion only for a first-try right answer.
  void _recordCheck(
    bool correct,
    ArabicLetter answer,
    List<ArabicLetter> options,
  ) {
    // The Warm-up card asks "how does this sound?", so what it stores is the
    // syllable and its SOUND — storing the syllable as its own answer would
    // put the answer on the card's face.
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'kids.syllable.${widget.mark.id}.${answer.char}',
      arabic: '${answer.char}$_mark',
      answer: kidsSyllableSound(answer, widget.mark),
      distractors: [
        for (final o in options)
          if (o != answer) kidsSyllableSound(o, widget.mark),
      ],
      optionsArabic: false,
    );
  }

  void _answerCheck(
    bool firstTry,
    ArabicLetter answer,
    List<ArabicLetter> options,
  ) {
    _total++;
    if (firstTry) {
      _correct++;
      _recordCheck(true, answer, options);
    }
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    if (_done && !_reported) {
      // Reported exactly once, after this build commits — not from inside
      // build() itself, which must stay free of side effects.
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => kidsFinishLesson(
          context,
          progressId: widget.progressId,
          stars: _stars,
        ),
      );
    }
    return KidsLessonScaffold(
      index: _index,
      total: _steps.length,
      done: _done,
      child: _done
          ? KidsLessonResult(stars: _stars)
          : switch (_steps[_index]) {
              _LetterStep(:final letter) => _SyllableStep(
                key: ValueKey('letter.${letter.char}'),
                letter: letter,
                mark: _mark,
                onNext: _advance,
              ),
              _CheckStep(:final answer, :final options) => _CheckWidget(
                key: ValueKey('check.${answer.char}'),
                answer: answer,
                options: options,
                mark: _mark,
                onMiss: () => _recordCheck(false, answer, options),
                onDone: (firstTry) => _answerCheck(firstTry, answer, options),
              ),
            },
    );
  }
}

/// One letter's turn: the syllable, big; a Listen button; "I said it" to move
/// on — the same reinforcement shape `KidsLetterFlow`'s say-it-aloud step
/// uses, just once per letter here rather than five times on one letter,
/// since walking the whole alphabet IS the repetition.
class _SyllableStep extends StatelessWidget {
  final ArabicLetter letter;
  final String mark;
  final VoidCallback onNext;
  const _SyllableStep({
    super.key,
    required this.letter,
    required this.mark,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final syllable = '${letter.char}$mark';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: Container(
              width: 180,
              height: 180,
              alignment: Alignment.center,
              decoration: kidsCard(context),
              child: Text(
                syllable,
                textDirection: TextDirection.rtl,
                style: quranicStyle(context, size: 90, height: 1.3),
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapMd),
        Center(
          child: Text(
            letterName(context, letter),
            style: kidsStyle(context, size: 17, weight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: Geo.gapSm),
        Center(
          child: TextButton.icon(
            onPressed: () => LetterAudio.playOrComingSoonRaw(context, syllable),
            icon: Icon(Icons.volume_up_rounded, color: p.accent2),
            label: Text(
              context.l10n.listen,
              style: kidsStyle(context, color: p.accent2),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () {
            // Ambient reinforcement, same as every other "I said it" tap in
            // Kids Mode — quiet on a missing clip, no coming-soon toast.
            LetterAudio.playRaw(syllable);
            onNext();
          },
          child: Text(context.l10n.kidsSaidIt),
        ),
      ],
    );
  }
}

/// The check-up: which syllable did you just practise? Four glyph options,
/// one correct, drawn only from the five letters just covered — never the
/// whole alphabet, which would make an unmet letter a "distractor" that is
/// really just noise.
class _CheckWidget extends StatefulWidget {
  final ArabicLetter answer;
  final List<ArabicLetter> options;
  final String mark;
  final VoidCallback onMiss;
  final void Function(bool firstTry) onDone;
  const _CheckWidget({
    super.key,
    required this.answer,
    required this.options,
    required this.mark,
    required this.onMiss,
    required this.onDone,
  });

  @override
  State<_CheckWidget> createState() => _CheckWidgetState();
}

class _CheckWidgetState extends State<_CheckWidget> {
  @override
  void initState() {
    super.initState();
    LetterAudio.playRaw('${widget.answer.char}${widget.mark}');
  }

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return KidsChoiceCard(
      prompt: context.l10n.kidsWhichDidYouSay,
      display: Center(
        child: TextButton.icon(
          onPressed: () => LetterAudio.playOrComingSoonRaw(
            context,
            '${widget.answer.char}${widget.mark}',
          ),
          icon: Icon(Icons.volume_up_rounded, color: p.accent2),
          label: Text(
            context.l10n.listen,
            style: kidsStyle(context, color: p.accent2),
          ),
        ),
      ),
      options: [
        for (final l in widget.options)
          Text(
            '${l.char}${widget.mark}',
            textDirection: TextDirection.rtl,
            style: quranicStyle(context, size: 40),
          ),
      ],
      correct: widget.options.indexOf(widget.answer),
      aspect: 1.4,
      hint: context.l10n.kidsHintSyllable,
      settle: const Duration(milliseconds: 700),
      onMiss: (_) => widget.onMiss(),
      onDone: widget.onDone,
    );
  }
}
