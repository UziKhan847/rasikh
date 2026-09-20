import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/letter_audio.dart';
import '../../core/theme.dart';
import '../../data/kids_sentences.dart';
import '../../widgets/common.dart' show buildOptions, pickN, starsForFraction;
import 'kids_checkpoint_quiz.dart' show kidsCheckpointEvery;
import 'kids_choice_card.dart';
import 'kids_widgets.dart';

final _rng = math.Random();

/// One thing to do inside a [KidsWordsLesson]: read a sentence, or answer a
/// quick "which word means this" check over the ones just met.
sealed class _Step {
  const _Step();
}

class _IntroStep extends _Step {
  const _IntroStep();
}

class _SentenceStep extends _Step {
  final KidsSentence sentence;
  const _SentenceStep(this.sentence);
}

class _CheckStep extends _Step {
  final KidsSentence answer;
  final List<KidsSentence> options;
  const _CheckStep({required this.answer, required this.options});
}

/// Reading real sentences, one at a time — [kidsSentences]' own 28 entries,
/// written and reviewed but never rendered anywhere until now (see that
/// file's own doc comment: "the natural home is somewhere after
/// `qaidah.harakat`", which is exactly where this stage sits) — rather than
/// the reused Learn page's flat list of 16 single words with no gloss and
/// no sentence context at all.
class KidsWordsLesson extends StatefulWidget {
  final String progressId;

  /// The stage's Test: no sentences to read, just [kidsQuizLength] "which
  /// word is it?" checks over the whole set.
  final bool quiz;
  const KidsWordsLesson({
    super.key,
    required this.progressId,
    this.quiz = false,
  });

  @override
  State<KidsWordsLesson> createState() => _KidsWordsLessonState();
}

class _KidsWordsLessonState extends State<KidsWordsLesson> {
  late final List<_Step> _steps = _buildSteps();

  List<_Step> _buildSteps() {
    if (widget.quiz) {
      final answers = pickN(
        kidsSentences,
        math.min(kidsQuizLength, kidsSentences.length),
        _rng,
      );
      return [
        for (final answer in answers)
          () {
            final restWords = [for (final s in kidsSentences) s.targetWord]
              ..remove(answer.targetWord);
            final built = buildOptions(
              answer.targetWord,
              restWords,
              _rng,
              count: 4,
            );
            return _CheckStep(
              answer: answer,
              options: [
                for (final w in built.options)
                  kidsSentences.firstWhere((s) => s.targetWord == w),
              ],
            );
          }(),
      ];
    }
    final out = <_Step>[const _IntroStep()];
    for (var i = 0; i < kidsSentences.length; i++) {
      out.add(_SentenceStep(kidsSentences[i]));
      final done = i + 1;
      if (done % kidsCheckpointEvery == 0 && done != kidsSentences.length) {
        final pool = kidsSentences.sublist(
          math.max(0, done - kidsCheckpointEvery),
          done,
        );
        final answer = pool[_rng.nextInt(pool.length)];
        final restWords = [for (final s in pool) s.targetWord]
          ..remove(answer.targetWord);
        final built = buildOptions(
          answer.targetWord,
          restWords,
          _rng,
          count: math.min(4, pool.length),
        );
        out.add(
          _CheckStep(
            answer: answer,
            options: [
              for (final w in built.options)
                pool.firstWhere((s) => s.targetWord == w),
            ],
          ),
        );
      }
    }
    return out;
  }

  int _index = 0;
  int _correct = 0;
  int _total = 0;
  bool _reported = false;

  bool get _done => _index >= _steps.length;

  int get _stars =>
      _total == 0 ? 3 : starsForFraction(_correct / _total, kids: true);

  void _advance() => setState(() => _index++);

  /// Files the check in the review queue: a miss the moment it happens, a
  /// promotion only for a first-try right answer.
  void _recordCheck(
    bool correct,
    KidsSentence answer,
    List<KidsSentence> options,
  ) {
    kidsRecordCheck(
      context,
      correct: correct,
      // The check gives the meaning and asks for the word; the Warm-up card
      // turns it round — the word on the card, its meaning to find — so the
      // answer is never sitting on the card's face.
      reviewId: 'kids.word.${answer.letter}',
      arabic: answer.targetWord,
      answer: answer.gloss,
      distractors: [
        for (final o in options)
          if (o != answer) o.gloss,
      ],
      optionsArabic: false,
    );
  }

  void _answerCheck(
    bool firstTry,
    KidsSentence answer,
    List<KidsSentence> options,
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
              _IntroStep() => _IntroCard(onNext: _advance),
              _SentenceStep(:final sentence) => _SentenceCard(
                key: ValueKey(sentence.letter),
                sentence: sentence,
                onNext: _advance,
              ),
              _CheckStep(:final answer, :final options) => _CheckCard(
                key: ValueKey('check.${answer.letter}'),
                answer: answer,
                options: options,
                onMiss: () => _recordCheck(false, answer, options),
                onDone: (firstTry) => _answerCheck(firstTry, answer, options),
              ),
            },
    );
  }
}

class _IntroCard extends StatelessWidget {
  final VoidCallback onNext;
  const _IntroCard({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(Geo.gapLg),
              decoration: kidsCard(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_stories_rounded, size: 44),
                  const SizedBox(height: Geo.gapMd),
                  Text(
                    context.l10n.readingWords,
                    style: kidsStyle(
                      context,
                      size: 19,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    context.l10n.kidsWordsIntro,
                    textAlign: TextAlign.center,
                    style: kidsStyle(context, size: 14, color: p.textDim),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: onNext,
          child: Text(context.l10n.kidsNextCard),
        ),
      ],
    );
  }
}

/// One sentence's turn: the sentence itself with its target word picked out
/// in the accent color, its meaning, and a Listen button — honestly
/// "coming soon" today, since there is no bundled sentence audio, exactly
/// like every other Listen button with no clip behind it yet.
class _SentenceCard extends StatelessWidget {
  final KidsSentence sentence;
  final VoidCallback onNext;
  const _SentenceCard({
    super.key,
    required this.sentence,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final parts = sentence.sentence.split(sentence.targetWord);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(Geo.gapLg),
              decoration: kidsCard(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        for (var i = 0; i < parts.length; i++) ...[
                          if (i > 0)
                            TextSpan(
                              text: sentence.targetWord,
                              style: quranicStyle(
                                context,
                                size: 28,
                                color: p.accent,
                              ).copyWith(fontWeight: FontWeight.w800),
                            ),
                          TextSpan(
                            text: parts[i],
                            style: quranicStyle(context, size: 28),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Geo.gapMd),
                  Text(
                    '${sentence.gloss} — ${sentence.translit}',
                    textAlign: TextAlign.center,
                    style: kidsStyle(context, size: 13, color: p.textDim),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  TextButton.icon(
                    onPressed: () => LetterAudio.playOrComingSoonRaw(
                      context,
                      sentence.sentence,
                    ),
                    icon: Icon(Icons.volume_up_rounded, color: p.accent2),
                    label: Text(
                      context.l10n.listen,
                      style: kidsStyle(context, color: p.accent2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: onNext,
          child: Text(context.l10n.kidsNextCard),
        ),
      ],
    );
  }
}

class _CheckCard extends StatefulWidget {
  final KidsSentence answer;
  final List<KidsSentence> options;
  final VoidCallback onMiss;
  final void Function(bool firstTry) onDone;
  const _CheckCard({
    super.key,
    required this.answer,
    required this.options,
    required this.onMiss,
    required this.onDone,
  });

  @override
  State<_CheckCard> createState() => _CheckCardState();
}

class _CheckCardState extends State<_CheckCard> {
  @override
  Widget build(BuildContext context) {
    return KidsChoiceCard(
      prompt: context.l10n.kidsWhichWordMeans(widget.answer.gloss),
      options: [
        for (final s in widget.options)
          Text(
            s.targetWord,
            textDirection: TextDirection.rtl,
            style: quranicStyle(context, size: 26),
          ),
      ],
      correct: widget.options.indexWhere(
        (s) => s.targetWord == widget.answer.targetWord,
      ),
      aspect: 1.6,
      hint: context.l10n.kidsHintWords,
      // The word said in Latin letters, with what it means.
      explain: '${widget.answer.translit} — ${widget.answer.gloss}',
      onMiss: (_) => widget.onMiss(),
      onDone: widget.onDone,
    );
  }
}
