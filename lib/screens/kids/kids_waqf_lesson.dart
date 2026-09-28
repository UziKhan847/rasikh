import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../data/waqf.dart';
import '../../screens/lessons/script_lessons.dart'
    show actionLabel, stopMarkIds;
import '../../widgets/common.dart'
    show MediaRow, buildOptions, pickN, starsForFraction;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_ui.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC, kbMix;
import 'kids_choice_card.dart';
import 'kids_widgets.dart';

final _rng = math.Random();

/// One thing to do inside a [KidsWaqfLesson]: meet the traffic-light idea,
/// meet one of the six stop marks, or check what a mark means.
sealed class _Step {
  const _Step();
}

class _IntroStep extends _Step {
  const _IntroStep();
}

class _MarkStep extends _Step {
  final WaqfMark mark;
  const _MarkStep(this.mark);
}

class _CheckStep extends _Step {
  final WaqfMark answer;
  final String verse;
  const _CheckStep({required this.answer, required this.verse});
}

/// What a mark's action means, in a sentence a child can act on — the reason a
/// check gives, and the line under each mark. (The data's own `note` is the
/// scholarly wording, with details like which muṣḥaf prints the sign.)
String _waqfWhy(BuildContext context, WaqfMark m) => switch (m.action) {
  'must_stop' => context.l10n.kidsWaqfWhyMustStop,
  'must_not_stop' => context.l10n.kidsWaqfWhyMustNotStop,
  'either' => context.l10n.kidsWaqfWhyEither,
  'either_not_both' => context.l10n.kidsWaqfWhyPair,
  'preferred_stop' => context.l10n.kidsWaqfWhyPreferStop,
  'preferred_continue' => context.l10n.kidsWaqfWhyPreferGo,
  _ => m.note,
};

/// Emoji and colours for a stop mark's action — the "traffic light" a child
/// already knows, standing in for the six classical actions — in the design's
/// feedback tokens: red is its "bad", green its "good", amber its reward.
/// Returns (emoji, ink, solid pill face).
(String, int, int) _waqfVisual(String action, KbUi ui) => switch (action) {
  'must_stop' => ('🛑', KbUi.badEdge, ui.badBg),
  'must_not_stop' => ('🚫', KbUi.badEdge, ui.badBg),
  'either' => ('🟢', KbUi.goodEdge, ui.goodBg),
  'preferred_continue' => ('🟡', ui.rewardInk, kbMix(ui.reward, ui.surface, .55)),
  'preferred_stop' => ('🟠', ui.rewardInk, kbMix(ui.reward, ui.surface, .55)),
  _ => ('🔗', ui.linkInk, ui.tile), // either_not_both
};

/// Waqf & Stopping, one sign at a time, read through the traffic light a
/// child already knows — stop, go, or either — rather than the reused Learn
/// page's flat list of six rows with no visual distinction between "must"
/// and "preferred".
class KidsWaqfLesson extends StatefulWidget {
  final String progressId;

  /// The stage's Test: no teaching cards, just [kidsQuizLength] "what does
  /// this mark mean?" checks drawn from every sign.
  final bool quiz;
  const KidsWaqfLesson({
    super.key,
    required this.progressId,
    this.quiz = false,
  });

  @override
  State<KidsWaqfLesson> createState() => _KidsWaqfLessonState();
}

class _KidsWaqfLessonState extends State<KidsWaqfLesson> {
  late final List<WaqfMark> _marks = [
    for (final id in stopMarkIds) waqfMarkById(id),
  ];
  late final List<_Step> _steps = _buildSteps();

  List<_Step> _buildSteps() {
    final out = <_Step>[
      if (!widget.quiz) ...[
        const _IntroStep(),
        for (final m in _marks) _MarkStep(m),
      ],
    ];
    final instances = <(WaqfMark, String)>[];
    for (final m in _marks) {
      instances.add((m, m.example));
      for (final e in m.moreExamples) {
        instances.add((m, e.$1));
      }
    }
    final chosen = pickN(
      instances,
      math.min(widget.quiz ? kidsQuizLength : 3, instances.length),
      _rng,
    );
    for (final (mark, verse) in chosen) {
      out.add(_CheckStep(answer: mark, verse: verse));
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
  void _recordCheck(bool correct, WaqfMark answer, List<String> options) {
    final answerLabel = actionLabel(context, answer.action);
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'kids.waqf.${answer.id}',
      arabic: answer.arabicName.split(' — ').first,
      answer: answerLabel,
      distractors: [
        for (final o in options)
          if (o != answerLabel) o,
      ],
      optionsArabic: false,
    );
  }

  void _answerCheck(bool firstTry, WaqfMark answer, List<String> options) {
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
              _MarkStep(:final mark) => _MarkCard(
                key: ValueKey(mark.id),
                mark: mark,
                onNext: _advance,
              ),
              _CheckStep(:final answer, :final verse) => _CheckCard(
                key: ValueKey('check.${answer.id}.$verse'),
                answer: answer,
                verse: verse,
                allMarks: _marks,
                onMiss: (options) => _recordCheck(false, answer, options),
                onDone: (firstTry, options) =>
                    _answerCheck(firstTry, answer, options),
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
    final ui = kbUi(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KidsCentered(
            child: KidsLessonCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🚦', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: Geo.gapMd),
                  Text(
                    context.l10n.unitWaqfStopping,
                    style: kbText(24, kbC(ui.ink)),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    context.l10n.kidsWaqfIntro,
                    textAlign: TextAlign.center,
                    style: kbText(18, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        KidsNextButton(context.l10n.kidsNextCard, onTap: onNext),
      ],
    );
  }
}

class _MarkCard extends StatelessWidget {
  final WaqfMark mark;
  final VoidCallback onNext;
  const _MarkCard({super.key, required this.mark, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final (emoji, ink, face) = _waqfVisual(mark.action, ui);
    final symbol = mark.arabicName.split(' — ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KidsCentered(
            child: KidsLessonCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    symbol,
                    textDirection: TextDirection.rtl,
                    style: kbText(40, kbC(ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    mark.name,
                    style: kbText(21, kbC(ui.ink)),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kbC(face),
                      borderRadius: BorderRadius.circular(Geo.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        // Flexible so a long label ("Stop at exactly one, not
                        // both", or any translation) wraps inside the pill
                        // instead of running off a narrow phone.
                        Flexible(
                          child: Text(
                            actionLabel(context, mark.action),
                            textAlign: TextAlign.center,
                            style: kbText(16, kbC(ink), weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Geo.gapMd),
                  Text(
                    _waqfWhy(context, mark),
                    textAlign: TextAlign.center,
                    style: kbText(16, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35),
                  ),
                  const SizedBox(height: Geo.gapMd),
                  Text(
                    mark.example,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: kbText(22, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  MediaRow(ref: mark.ref),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Geo.gapLg),
        KidsNextButton(context.l10n.kidsNextCard, onTap: onNext),
      ],
    );
  }
}

class _CheckCard extends StatefulWidget {
  final WaqfMark answer;
  final String verse;
  final List<WaqfMark> allMarks;
  final void Function(List<String> options) onMiss;
  final void Function(bool firstTry, List<String> options) onDone;
  const _CheckCard({
    super.key,
    required this.answer,
    required this.verse,
    required this.allMarks,
    required this.onMiss,
    required this.onDone,
  });

  @override
  State<_CheckCard> createState() => _CheckCardState();
}

class _CheckCardState extends State<_CheckCard> {
  String? _correctLabel;
  List<String>? _options;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built once, not on every rebuild: `buildOptions` shuffles and samples
    // distractors, so recomputing it after picking would report a
    // different set of options to the review queue than the ones actually
    // shown on screen. `context.l10n` (via `actionLabel`) isn't safe to
    // resolve from `initState` — `didChangeDependencies` is the framework's
    // own answer for inherited-widget reads that should only run once.
    if (_options != null) return;
    final correctLabel = actionLabel(context, widget.answer.action);
    final otherLabels = [
      for (final m in widget.allMarks)
        if (m.id != widget.answer.id) actionLabel(context, m.action),
    ];
    _correctLabel = correctLabel;
    _options = buildOptions(correctLabel, otherLabels, _rng).options;
  }

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final options = _options!;
    return KidsChoiceCard(
      prompt: context.l10n.kidsWhatDoesMarkMean,
      // The verse is scrollable inside the card: most marks' examples are a
      // single word, but muʼānaqah's is a full āyah (two linked stop points
      // need a whole sentence to show both).
      display: KidsLessonCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.verse,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: kbText(22, kbC(ui.ink), family: kbFontQuran, weight: FontWeight.w400, height: 1.9),
        ),
      ),
      options: [
        for (final label in options)
          Text(
            label,
            textAlign: TextAlign.center,
            style: kbText(16, kbC(ui.ink), weight: FontWeight.w700),
          ),
      ],
      correct: options.indexOf(_correctLabel!),
      aspect: 1.9,
      hint: context.l10n.kidsHintWaqf,
      explain: _waqfWhy(context, widget.answer),
      onMiss: (_) => widget.onMiss(options),
      onDone: (firstTry) => widget.onDone(firstTry, options),
    );
  }
}
