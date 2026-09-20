import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/glyph_names.dart' show letterNameOf;
import '../../data/muqattaat.dart';
import '../../widgets/common.dart'
    show MediaRow, buildOptions, pickN, starsForFraction;
import 'kids_checkpoint_quiz.dart' show kidsCheckpointEvery;
import 'kids_choice_card.dart';
import 'kids_widgets.dart';

final _rng = math.Random();

/// One thing to do inside a [KidsMuqattaatLesson]: meet the idea, meet one
/// of the 14 disjointed-letter sets, or answer a quick "how many counts"
/// check over the letters just met.
sealed class _Step {
  const _Step();
}

class _IntroStep extends _Step {
  const _IntroStep();
}

class _SetStep extends _Step {
  final MuqattaatSet set;
  const _SetStep(this.set);
}

class _CheckStep extends _Step {
  final String letter;
  final String answer;
  final List<String> options;
  const _CheckStep({
    required this.letter,
    required this.answer,
    required this.options,
  });
}

/// Ḥurūf Muqaṭṭaʿāt, one opening set at a time — each letter named on its
/// own, its own madd count shown beside it, and the real sūrahs it opens —
/// rather than the reused Learn page's flat list of 14 rows, each pushing to
/// its own detail screen. The point Qāʿidah Nūrāniyyah makes of this lesson
/// (these are SPELLED, never sounded out as a word) is the intro card's own
/// text, not a fact repeated on every set.
class KidsMuqattaatLesson extends StatefulWidget {
  final String progressId;

  /// The stage's Test: no sets to spell, just [kidsQuizLength] "how many
  /// counts?" checks over the letters that open the sūrahs.
  final bool quiz;
  const KidsMuqattaatLesson({
    super.key,
    required this.progressId,
    this.quiz = false,
  });

  @override
  State<KidsMuqattaatLesson> createState() => _KidsMuqattaatLessonState();
}

class _KidsMuqattaatLessonState extends State<KidsMuqattaatLesson> {
  late final List<_Step> _steps = _buildSteps();

  List<_Step> _buildSteps() {
    if (widget.quiz) {
      final every = <String>{
        for (final s in muqattaatSets) ...s.letters.split(''),
      }.where(muqattaatCounts.containsKey).toList();
      return [
        for (final letter in pickN(
          every,
          math.min(kidsQuizLength, every.length),
          _rng,
        ))
          () {
            final answer = muqattaatCounts[letter]!;
            final restValues = muqattaatCounts.values.toSet().toList()
              ..remove(answer);
            final built = buildOptions(answer, restValues, _rng);
            return _CheckStep(
              letter: letter,
              answer: answer,
              options: built.options,
            );
          }(),
      ];
    }
    final out = <_Step>[const _IntroStep()];
    for (var i = 0; i < muqattaatSets.length; i++) {
      out.add(_SetStep(muqattaatSets[i]));
      final done = i + 1;
      if (done % kidsCheckpointEvery == 0 && done != muqattaatSets.length) {
        final pool = muqattaatSets.sublist(
          math.max(0, done - kidsCheckpointEvery),
          done,
        );
        final letters = <String>{
          for (final s in pool) ...s.letters.split(''),
        }.toList();
        final letter = letters[_rng.nextInt(letters.length)];
        final answer = muqattaatCounts[letter]!;
        final restValues = muqattaatCounts.values.toSet().toList()
          ..remove(answer);
        final built = buildOptions(answer, restValues, _rng);
        out.add(
          _CheckStep(letter: letter, answer: answer, options: built.options),
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
    String letter,
    String answer,
    List<String> options,
  ) {
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'kids.muqattaat.$letter',
      arabic: letter,
      answer: answer,
      distractors: [
        for (final o in options)
          if (o != answer) o,
      ],
      optionsArabic: false,
    );
  }

  void _answerCheck(
    bool firstTry,
    String letter,
    String answer,
    List<String> options,
  ) {
    _total++;
    if (firstTry) {
      _correct++;
      _recordCheck(true, letter, answer, options);
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
              _SetStep(:final set) => _SetCard(
                key: ValueKey(set.id),
                set: set,
                onNext: _advance,
              ),
              _CheckStep(:final letter, :final answer, :final options) =>
                _CheckCard(
                  key: ValueKey('check.$letter.$answer'),
                  letter: letter,
                  answer: answer,
                  options: options,
                  onMiss: () => _recordCheck(false, letter, answer, options),
                  onDone: (firstTry) =>
                      _answerCheck(firstTry, letter, answer, options),
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
                  Text(
                    'الٓمٓ',
                    textDirection: TextDirection.rtl,
                    style: quranicStyle(context, size: 44, color: p.accent),
                  ),
                  const SizedBox(height: Geo.gapMd),
                  Text(
                    context.l10n.unitMuqattaat,
                    textAlign: TextAlign.center,
                    style: kidsStyle(
                      context,
                      size: 19,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    context.l10n.kidsMuqattaatIntro,
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

/// One set's turn: its own letters, spelled out and named one by one, each
/// with its own madd count, plus a real sūrah opening to hear them in.
class _SetCard extends StatelessWidget {
  final MuqattaatSet set;
  final VoidCallback onNext;
  const _SetCard({super.key, required this.set, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    final chars = set.letters.split('');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            set.displayText,
            textDirection: TextDirection.rtl,
            style: quranicStyle(context, size: 36),
          ),
        ),
        const SizedBox(height: Geo.gapMd),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Geo.gapSm,
                  runSpacing: Geo.gapSm,
                  children: [
                    for (final ch in chars)
                      Container(
                        width: 78,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: kidsCard(context),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ch,
                              textDirection: TextDirection.rtl,
                              style: quranicStyle(context, size: 30),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              letterNameOf(context, ch),
                              style: kidsStyle(context, size: 11),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              muqattaatCounts[ch] == '—'
                                  ? context.l10n.kidsMuqattaatNoStretch
                                  : context.l10n.kidsMuqattaatCounts(
                                      muqattaatCounts[ch]!,
                                    ),
                              style: kidsStyle(
                                context,
                                size: 10,
                                color: p.accent2,
                                weight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Geo.gapMd),
                Text(
                  context.l10n.kidsMuqattaatOpensSurah(
                    set.surahs.map((n) => '$n').join(', '),
                  ),
                  textAlign: TextAlign.center,
                  style: kidsStyle(context, size: 12.5, color: p.textDim),
                ),
                const SizedBox(height: Geo.gapSm),
                MediaRow(ref: set.ref),
              ],
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
  final String letter;
  final String answer;
  final List<String> options;
  final VoidCallback onMiss;
  final void Function(bool firstTry) onDone;
  const _CheckCard({
    super.key,
    required this.letter,
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
      prompt: context.l10n.kidsHowManyCounts,
      display: Center(
        child: Text(
          widget.letter,
          textDirection: TextDirection.rtl,
          style: quranicStyle(context, size: 60),
        ),
      ),
      options: [
        for (final value in widget.options)
          Text(
            value == '—'
                ? context.l10n.kidsMuqattaatNoStretch
                : context.l10n.kidsMuqattaatCounts(value),
            textAlign: TextAlign.center,
            style: kidsStyle(context, size: 13, weight: FontWeight.w700),
          ),
      ],
      correct: widget.options.indexOf(widget.answer),
      aspect: 1.8,
      hint: context.l10n.kidsHintMuqattaat,
      onMiss: (_) => widget.onMiss(),
      onDone: widget.onDone,
    );
  }
}
