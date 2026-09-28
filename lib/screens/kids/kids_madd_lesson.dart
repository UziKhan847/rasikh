import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../data/glyph_names.dart' show tashkilName, tashkilNote;
import '../../data/kids_glosses.dart' show kidsSmallLetterName, kidsSmallLetterNote;
import '../../data/small_letters.dart';
import '../../data/tashkeel.dart';
import '../../widgets/common.dart' show MediaRow, pickN, starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_choice_card.dart';
import 'kids_desktop_nav.dart' show closeKidsOverlayOrPop;
import 'kids_widgets.dart';

/// Madd & Līn, one stretching mark at a time, each with a kid-sized metronome
/// of its own ([KidsBeatRing] — fixed to the mark's own count, no adult tempo
/// slider or count picker, and it stops itself after three cycles) rather
/// than the reused Learn page's flat list of seven rows, each pushing to a
/// separate full-screen timer of its own.
///
/// No internal check-up: holding a count correctly is something a metronome
/// demonstrates, not something a multiple-choice question can grade, so the
/// lesson itself stays a Learn item — complete on open. What a question CAN
/// grade is whether a child knows which mark gets which count, and that is
/// the stage's Test ([quiz]): "how many counts?" over a real word for each
/// mark, and "which word is stretched longest?" across the three lengths.
class KidsMaddLesson extends StatefulWidget {
  /// The stage's Test instead of the lesson — no cards, no metronome, just
  /// [kidsQuizLength] checks. Needs a [progressId] to report under.
  final bool quiz;
  final String? progressId;
  const KidsMaddLesson({super.key, this.quiz = false, this.progressId})
    : assert(!quiz || progressId != null);

  @override
  State<KidsMaddLesson> createState() => _KidsMaddLessonState();
}

/// One card in the walk: a counted madd mark, or one of the three small
/// letters that ride along with it.
sealed class _Step {
  const _Step();
}

class _MarkStep extends _Step {
  final TashkilItem item;
  const _MarkStep(this.item);
}

class _SmallStep extends _Step {
  final SmallLetter letter;
  const _SmallStep(this.letter);
}

/// Test: "how many counts?" over [item]'s own example word.
class _CountStep extends _Step {
  final TashkilItem item;
  const _CountStep(this.item);
}

/// Test: which of three words — one per length — is the longest or shortest.
class _CompareStep extends _Step {
  final List<TashkilItem> items;
  final bool longest;
  const _CompareStep(this.items, {required this.longest});
}

final _rng = math.Random();

/// The marks a test can ask a count of. Madd ʿāriḍ is left out on purpose:
/// it is 2, 4 or 6 by choice, so no single count is "the" answer.
/// The item of [items] with the most (or fewest) counts.
TashkilItem _extreme(List<TashkilItem> items, {required bool longest}) {
  final sorted = [...items]..sort((a, b) => a.counts.compareTo(b.counts));
  return longest ? sorted.last : sorted.first;
}

const _countedIds = ['madd2', 'lin', 'maddah', 'madd4', 'madd45', 'madd6'];

class _KidsMaddLessonState extends State<KidsMaddLesson> {
  // The seven counted marks first, then the small letters: the dagger alif
  // IS a compact madd alif (same two counts), so it belongs here rather than
  // in a stage of its own, and the small wāw/yāʾ that follow it are the same
  // idea at the end of a word.
  late final List<_Step> _steps = [
    for (final t in tashkil.where((t) => t.counts >= 2)) _MarkStep(t),
    for (final s in smallLetters) _SmallStep(s),
  ];
  int _index = 0;
  int _correct = 0;
  int _total = 0;
  bool _reported = false;

  late final List<_Step> _quizSteps = () {
    final counted = [
      for (final id in _countedIds) tashkil.firstWhere((t) => t.id == id),
    ];
    List<TashkilItem> withCounts(int n) => [
      for (final t in counted)
        if (t.counts == n) t,
    ];
    List<TashkilItem> oneOfEach() => [
      for (final n in const [2, 4, 6]) pickN(withCounts(n), 1, _rng).single,
    ]..shuffle(_rng);
    return [
      for (final t in counted) _CountStep(t),
      _CompareStep(oneOfEach(), longest: true),
      _CompareStep(oneOfEach(), longest: false),
    ]..shuffle(_rng);
  }();

  int get _stars =>
      _total == 0 ? 3 : starsForFraction(_correct / _total, kids: true);

  void _advance() => setState(() => _index++);

  /// Files a count check in the review queue: a miss the moment it happens, a
  /// promotion only for a first-try right answer.
  void _recordCount(bool correct, TashkilItem item, List<String> others) {
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'kids.madd.${item.id}',
      arabic: item.example,
      answer: '${item.counts}',
      distractors: others,
      optionsArabic: false,
    );
  }

  void _answerCheck(
    bool firstTry, {
    TashkilItem? item,
    List<String> others = const [],
  }) {
    _total++;
    if (firstTry) {
      _correct++;
      if (item != null) _recordCount(true, item, others);
    }
    _advance();
  }

  Widget _buildQuiz(BuildContext context) {
    final done = _index >= _quizSteps.length;
    if (done && !_reported) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => kidsFinishLesson(
          context,
          progressId: widget.progressId!,
          stars: _stars,
        ),
      );
    }
    return KidsLessonScaffold(
      index: _index,
      total: _quizSteps.length,
      done: done,
      child: done
          ? KidsLessonResult(stars: _stars)
          : switch (_quizSteps[_index]) {
              _CountStep(:final item) => _MaddCheck(
                key: ValueKey('count.${item.id}'),
                prompt: context.l10n.kidsHowManyCounts,
                item: item,
                options: const ['2', '4', '6'],
                correct: '${item.counts}',
                wide: false,
                hint: context.l10n.kidsHintMadd,
                explain: tashkilNote(context, item),
                onMiss: () => _recordCount(false, item, [
                  for (final n in const ['2', '4', '6'])
                    if (n != '${item.counts}') n,
                ]),
                onDone: (firstTry) => _answerCheck(
                  firstTry,
                  item: item,
                  others: [
                    for (final n in const ['2', '4', '6'])
                      if (n != '${item.counts}') n,
                  ],
                ),
              ),
              _CompareStep(:final items, :final longest) => _MaddCheck(
                key: ValueKey('compare.$longest.${items.map((i) => i.id)}'),
                prompt: longest
                    ? context.l10n.kidsMaddLongest
                    : context.l10n.kidsMaddShortest,
                options: [for (final i in items) i.example],
                correct: _extreme(items, longest: longest).example,
                wide: true,
                hint: context.l10n.kidsHintMadd,
                // Why: the note of the mark that IS the longest (or shortest).
                explain: tashkilNote(
                  context,
                  _extreme(items, longest: longest),
                ),
                onMiss: () {},
                onDone: (firstTry) => _answerCheck(firstTry),
              ),
              _ => const SizedBox.shrink(),
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quiz) return _buildQuiz(context);
    final isLast = _index == _steps.length - 1;
    final onNext = isLast ? () => closeKidsOverlayOrPop(context) : _advance;
    return KidsLessonScaffold(
      index: _index,
      total: _steps.length,
      done: false,
      child: switch (_steps[_index]) {
        _MarkStep(:final item) => _MaddCard(
          key: ValueKey(item.id),
          item: item,
          isLast: isLast,
          onNext: onNext,
        ),
        _SmallStep(:final letter) => _SmallLetterCard(
          key: ValueKey(letter.id),
          letter: letter,
          isLast: isLast,
          onNext: onNext,
        ),
        // Test steps live in [_quizSteps] and never appear in the lesson.
        _CountStep() || _CompareStep() => const SizedBox.shrink(),
      },
    );
  }
}

class _MaddCard extends StatelessWidget {
  final TashkilItem item;
  final bool isLast;
  final VoidCallback onNext;
  const _MaddCard({
    super.key,
    required this.item,
    required this.isLast,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidsLessonTitle(tashkilName(context, item)),
        const SizedBox(height: Geo.gapSm),
        Expanded(
          child: KidsCentered(
            child: KidsLessonCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      item.mark,
                      textDirection: TextDirection.rtl,
                      style: kbText(44, kbC(ui.linkInk), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
                    ),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    tashkilNote(context, item),
                    textAlign: TextAlign.center,
                    style: kbText(16, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35),
                  ),
                  const SizedBox(height: Geo.gapMd),
                  Center(
                    child: KidsQuranWord(item.example, highlight: item.highlight, size: 26, block: false),
                  ),
                  const SizedBox(height: Geo.gapMd),
                  Center(child: KidsBeatRing(counts: item.counts)),
                  const SizedBox(height: Geo.gapSm),
                  Center(child: MediaRow(ref: item.ref)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        KidsNextButton(isLast ? context.l10n.continueLabel : context.l10n.kidsNextCard, onTap: onNext),
      ],
    );
  }
}

/// One of the three small letters. The dagger alif is a full two-count madd
/// (so it gets the same beat ring as the marks before it); the small wāw and
/// yāʾ are a brief rounding of the vowel at a word's end, NOT a full extra
/// count, so they deliberately do not.
class _SmallLetterCard extends StatelessWidget {
  final SmallLetter letter;
  final bool isLast;
  final VoidCallback onNext;
  const _SmallLetterCard({
    super.key,
    required this.letter,
    required this.isLast,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final isDagger = letter.id == 'dagger_alif';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidsLessonTitle(kidsSmallLetterName(context, letter.id)),
        const SizedBox(height: Geo.gapSm),
        Expanded(
          child: KidsCentered(
            child: KidsLessonCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: KidsQuranWord(letter.example, highlight: letter.highlight, size: 40, block: false),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    kidsSmallLetterNote(context, letter.id),
                    textAlign: TextAlign.center,
                    style: kbText(16, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35),
                  ),
                  if (isDagger) ...[
                    const SizedBox(height: Geo.gapMd),
                    const Center(child: KidsBeatRing(counts: 2)),
                  ],
                  const SizedBox(height: Geo.gapSm),
                  Center(child: MediaRow(ref: letter.ref)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        KidsNextButton(isLast ? context.l10n.continueLabel : context.l10n.kidsNextCard, onTap: onNext),
      ],
    );
  }
}

/// One Test question: an optional example word with its mark lit, then the
/// options — big numerals in a row for a count, wide word tiles for a
/// comparison — on the shared check: a second try, a hint, then a reason.
class _MaddCheck extends StatelessWidget {
  final String prompt;
  final TashkilItem? item;
  final List<String> options;
  final String correct;
  final bool wide;
  final String hint;
  final String explain;
  final VoidCallback onMiss;
  final void Function(bool firstTry) onDone;
  const _MaddCheck({
    super.key,
    required this.prompt,
    this.item,
    required this.options,
    required this.correct,
    required this.wide,
    required this.hint,
    required this.explain,
    required this.onMiss,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final item = this.item;
    return KidsChoiceCard(
      prompt: prompt,
      display: item == null
          ? null
          : KidsLessonCard(
              padding: const EdgeInsets.all(16),
              child: KidsQuranWord(item.example,
                  highlight: item.highlight, size: 32, block: false),
            ),
      options: [
        for (final o in options)
          wide
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    o,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: kbText(26, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
                  ),
                )
              : Text(
                  o,
                  style: kbText(30, kbC(ui.ink)),
                ),
      ],
      correct: options.indexOf(correct),
      columns: wide ? 1 : 3,
      aspect: 1.1,
      hint: hint,
      explain: explain,
      onMiss: (_) => onMiss(),
      onDone: onDone,
    );
  }
}
