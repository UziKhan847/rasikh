import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/glyph_names.dart' show tajwidHow, tajwidName, tajwidTrigger;
import '../../data/tajweed.dart';
import '../../widgets/common.dart'
    show MediaRow, buildOptions, pickN, starsForFraction;
import 'kids_choice_card.dart';
import 'kids_mouth_map.dart'
    show
        KidsMouthDiagram,
        kidsRuleZone,
        kidsZoneColor,
        kidsZoneEmoji,
        kidsZoneName;
import 'kids_widgets.dart';

final _rng = math.Random();

/// One thing to do inside a [KidsTajwidRuleLesson]: meet the family, meet one
/// of its rules, or spot a rule at play in a real verse.
sealed class _Step {
  const _Step();
}

class _IntroStep extends _Step {
  const _IntroStep();
}

class _RuleStep extends _Step {
  final TajwidRule rule;
  const _RuleStep(this.rule);
}

class _CheckStep extends _Step {
  final TajwidRule answer;
  final String verse;
  final String ref;
  final List<TajwidRule> options;
  const _CheckStep({
    required this.answer,
    required this.verse,
    required this.ref,
    required this.options,
  });
}

/// A rule-family unit (mīm sākinah, nūn sākinah, qalqalah, rā') taught rule
/// by rule — each with its own trigger, technique, and a real colored verse
/// to hear it in — rather than the reused Tajwīd hub's single Learn page (a
/// flat list of every rule in the family, with the letter grid and the quiz
/// living on two separate tabs of their own). One lesson covers any family,
/// however many rules it has: qalqalah (one rule) walks a single step, nūn
/// sākinah (five) walks five, both ending on the same few "spot the rule in
/// this verse" checks.
///
/// The families themselves are NOT re-taught here — [TajwidRule] and its
/// data (`lib/data/tajweed.dart`) are the single source, exactly like
/// [KidsSolarLunarLesson](kids_solar_lunar_lesson.dart) reuses `wasl.dart`
/// rather than restating the lām rule's own facts.
class KidsTajwidRuleLesson extends StatefulWidget {
  final List<String> ruleIds;
  final String progressId;
  final IconData icon;
  final String Function(BuildContext) title;
  final String Function(BuildContext) subtitle;

  /// The stage's Test: no rule cards, just [kidsQuizLength] "which rule is
  /// at play?" checks drawn from every rule in the family.
  final bool quiz;
  const KidsTajwidRuleLesson({
    super.key,
    required this.ruleIds,
    required this.progressId,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.quiz = false,
  });

  @override
  State<KidsTajwidRuleLesson> createState() => _KidsTajwidRuleLessonState();
}

class _KidsTajwidRuleLessonState extends State<KidsTajwidRuleLesson> {
  late final List<TajwidRule> _rules = [
    for (final id in widget.ruleIds) ruleById(id),
  ];
  late final List<_Step> _steps = _buildSteps();

  List<_Step> _buildSteps() {
    final out = <_Step>[
      if (!widget.quiz) ...[
        const _IntroStep(),
        for (final r in _rules) _RuleStep(r),
      ],
    ];
    // A handful of real "which rule is at play here" checks — never the
    // whole `max(6, n*2)` set the reused Test phase already runs; that quiz
    // still follows immediately after as this stage's own Test tile.
    final instances = <(TajwidRule, String, String)>[];
    for (final r in _rules) {
      instances.add((r, r.example.plain, r.example.ref));
      for (final m in r.moreExamples) {
        instances.add((r, m.$1, m.$2));
      }
    }
    final chosen = pickN(
      instances,
      math.min(widget.quiz ? kidsQuizLength : 3, instances.length),
      _rng,
    );
    for (final (rule, verse, ref) in chosen) {
      // Distractor rules come from the FULL rule set, not just this family —
      // a single-rule family (qalqalah) could not otherwise offer four
      // options, and the adult quiz (`_ruleFamilyQuiz`) pads the same way.
      // Built from ids (stable and unique) rather than display names, since
      // the display name is locale-dependent (`tajwidName`) and there is no
      // BuildContext yet at this point in a State's field initializer.
      final poolIds = [for (final other in tajwidRules) other.id]
        ..remove(rule.id);
      final built = buildOptions(rule.id, poolIds, _rng);
      out.add(
        _CheckStep(
          answer: rule,
          verse: verse,
          ref: ref,
          options: [for (final id in built.options) ruleById(id)],
        ),
      );
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
    TajwidRule answer,
    String verse,
    List<TajwidRule> options,
  ) {
    final answerName = tajwidName(context, answer);
    kidsRecordCheck(
      context,
      correct: correct,
      reviewId: 'kids.tajwid.${answer.id}',
      arabic: verse,
      answer: answerName,
      distractors: [
        for (final o in options)
          if (o.id != answer.id) tajwidName(context, o),
      ],
      optionsArabic: false,
    );
  }

  void _answerCheck(
    bool firstTry,
    TajwidRule answer,
    String verse,
    List<TajwidRule> options,
  ) {
    _total++;
    if (firstTry) {
      _correct++;
      _recordCheck(true, answer, verse, options);
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
              _IntroStep() => _IntroCard(
                icon: widget.icon,
                title: widget.title(context),
                subtitle: widget.subtitle(context),
                onNext: _advance,
              ),
              _RuleStep(:final rule) => _RuleCard(
                key: ValueKey(rule.id),
                rule: rule,
                onNext: _advance,
              ),
              _CheckStep(
                :final answer,
                :final verse,
                :final ref,
                :final options,
              ) =>
                _CheckCard(
                  // The verse too: two examples of one rule can share a ref ('1:1' holds
                  // both ٱلرَّحۡمَٰنِ and ٱلرَّحِيمِ), and two checks in a row with one
                  // key would reuse the first's already-answered State.
                  key: ValueKey('check.${answer.id}.$ref.$verse'),
                  answer: answer,
                  verse: verse,
                  options: options,
                  onMiss: () => _recordCheck(false, answer, verse, options),
                  onDone: (firstTry) =>
                      _answerCheck(firstTry, answer, verse, options),
                ),
            },
    );
  }
}

class _IntroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onNext;
  const _IntroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onNext,
  });

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
                  Icon(icon, size: 48, color: p.accent),
                  const SizedBox(height: Geo.gapMd),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: kidsStyle(
                      context,
                      size: 20,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    subtitle,
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

/// One rule's turn: its name, when it applies, how to do it, and a real
/// verse with the rule's own moment colored in — the same color the reused
/// Tajwīd hub uses everywhere else, so a child who moves between the two
/// still sees the same color mean the same rule.
class _RuleCard extends StatelessWidget {
  final TajwidRule rule;
  final VoidCallback onNext;
  const _RuleCard({super.key, required this.rule, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final p = kidsPal(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tajwidName(context, rule),
          style: kidsStyle(context, size: 19, weight: FontWeight.w800),
        ),
        const SizedBox(height: Geo.gapSm),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(Geo.gapLg),
              decoration: kidsCard(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      rule.arabicName,
                      textDirection: TextDirection.rtl,
                      style: quranicStyle(context, size: 30, color: rule.color),
                    ),
                  ),
                  if (rule.letters.isNotEmpty) ...[
                    const SizedBox(height: Geo.gapSm),
                    Center(
                      child: Text(
                        rule.letters.split('').join('  '),
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(context, size: 22),
                      ),
                    ),
                  ],
                  // Where in the mouth it happens, on the same map the Mouth map
                  // teaches — for the rules that happen in one place.
                  if (kidsRuleZone(rule.id) case final zone?) ...[
                    const SizedBox(height: Geo.gapMd),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: KidsMouthDiagram(
                          selected: zone,
                          interactive: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: Geo.gapSm),
                    Center(
                      child: Text(
                        '${kidsZoneEmoji(zone)}  ${kidsZoneName(context, zone)}',
                        style: kidsStyle(
                          context,
                          size: 14,
                          weight: FontWeight.w800,
                          color: kidsZoneColor(p, zone),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Geo.gapMd),
                  Text(
                    tajwidTrigger(context, rule),
                    style: kidsStyle(context, size: 14).copyWith(height: 1.35),
                  ),
                  const SizedBox(height: Geo.gapSm),
                  Text(
                    tajwidHow(context, rule),
                    style: kidsStyle(
                      context,
                      size: 14,
                      color: p.textDim,
                    ).copyWith(height: 1.35),
                  ),
                  const SizedBox(height: Geo.gapMd),
                  Center(child: _ColoredVerse(rule: rule)),
                  const SizedBox(height: Geo.gapSm),
                  Center(child: MediaRow(ref: rule.example.ref)),
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

/// [rule]'s own primary example verse, with the segment the rule colors
/// elsewhere in the app colored here too — the same [Seg]/`ruleId` data the
/// grown-up Tajwīd screen renders, just for one rule instead of a whole verse
/// of several rules at once.
class _ColoredVerse extends StatelessWidget {
  final TajwidRule rule;
  const _ColoredVerse({required this.rule});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          for (final seg in rule.example.segs)
            TextSpan(
              text: seg.text,
              style:
                  quranicStyle(
                    context,
                    size: 24,
                    color: seg.ruleId == rule.id ? rule.color : null,
                  ).copyWith(
                    fontWeight: seg.ruleId == rule.id
                        ? FontWeight.w800
                        : FontWeight.normal,
                  ),
            ),
        ],
      ),
    );
  }
}

/// The check-up: read the verse, pick which rule is happening — no color
/// hint this time, since naming it IS the question.
class _CheckCard extends StatefulWidget {
  final TajwidRule answer;
  final String verse;
  final List<TajwidRule> options;
  final VoidCallback onMiss;
  final void Function(bool firstTry) onDone;
  const _CheckCard({
    super.key,
    required this.answer,
    required this.verse,
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
      prompt: context.l10n.kidsWhichRuleIsThis,
      // Scrollable inside the card: nothing caps how long a real verse
      // excerpt can be (mu'ānaqah's own full-āyah example overflowed one).
      display: Container(
        padding: const EdgeInsets.all(Geo.gapMd),
        decoration: kidsCard(context),
        alignment: Alignment.center,
        child: Text(
          widget.verse,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: quranicStyle(context, size: 24),
        ),
      ),
      options: [
        for (final option in widget.options)
          Text(
            tajwidName(context, option),
            textAlign: TextAlign.center,
            style: kidsStyle(context, size: 14, weight: FontWeight.w700),
          ),
      ],
      correct: widget.options.indexWhere((o) => o.id == widget.answer.id),
      hint: context.l10n.kidsHintTajwid,
      explain: tajwidHow(context, widget.answer),
      onMiss: (_) => widget.onMiss(),
      onDone: widget.onDone,
    );
  }
}
