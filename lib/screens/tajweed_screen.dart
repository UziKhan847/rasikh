import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/glyph_names.dart';
import '../data/tajweed.dart';
import '../widgets/common.dart';

/// 🌿 Tajwīd Academy — every core rule, color-coded the way teaching
/// muṣḥafs do it, with a real verse for each and a spot-the-rule quiz.
class TajweedScreen extends StatelessWidget {
  const TajweedScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: embedded ? null : AppBar(title:  Text(context.l10n.tajwidAcademy)),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            context.l10n.tajwidGivingEveryLetterIts,
            style: uiStyle(context, size: 14.5, color: pal(context).textDim),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final r in tajwidRules)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: r.color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: r.color.withValues(alpha: .5)),
                  ),
                  child: Text(tajwidName(context, r),
                      style: uiStyle(context, size: 12, color: r.color,
                          weight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < tajwidRules.length; i++)
            FadeSlideIn(
              delayMs: 35 * i,
              child: _RuleCard(rule: tajwidRules[i]),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: pal(context).accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => pushAdaptive(context, _tajwidQuiz(context)),
            icon: const Icon(Icons.quiz_rounded),
            label:  Text(context.l10n.spotRuleQuiz),
          ),
        ],
      )),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final TajwidRule rule;
  const _RuleCard({required this.rule});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                width: 14, height: 44,
                decoration: BoxDecoration(
                  color: rule.color,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              title: Text(tajwidName(context, rule),
                  style: uiStyle(context, size: 16.5, weight: FontWeight.w700)),
              subtitle: Text(rule.arabicName,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left,
                  style: arabicStyle(context, size: 16, height: 1.4,
                      color: pal(context).textDim)),
              children: [
                _kv(context, context.l10n.when, tajwidTrigger(context, rule)),
                const SizedBox(height: 6),
                _kv(context, context.l10n.how, tajwidHow(context, rule)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: s.paperMode ? pal(context).paper : pal(context).surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    RichText(
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      text: TextSpan(children: [
                        for (final seg in rule.example.segs)
                          TextSpan(
                            text: seg.text,
                            style: arabicStyle(context, size: 30,
                                color: seg.ruleId != null
                                    ? ruleById(seg.ruleId!).color
                                    : null),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    Text(context.l10n.surahRef(rule.example.ref),
                        style: uiStyle(context,
                            size: 12.5, color: pal(context).textDim)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 52,
              child: Text(k,
                  style: uiStyle(context, size: 13, color: rule.color,
                      weight: FontWeight.w700))),
          Expanded(
              child: Text(v,
                  style: uiStyle(context, size: 14, color: pal(context).textDim))),
        ],
      );
}

QuizScreen tajwidQuizScreen(BuildContext context) => _tajwidQuiz(context);

QuizScreen _tajwidQuiz(BuildContext context) {
  final rng = math.Random();
  final pool = tajwidRules.map((r) => tajwidName(context, r)).toList();
  final sample = [...tajwidRules]..shuffle(rng);
  final qs = <QuizQuestion>[];
  for (final r in sample.take(10)) {
    final o = buildOptions(tajwidName(context, r), pool, rng);
    qs.add(QuizQuestion(
      prompt: context.l10n.qpWhichRuleInVerse(r.example.ref),
      arabic: r.example.plain,
      options: o.options,
      correct: o.correct,
      explain: '${tajwidTrigger(context, r)} → ${tajwidHow(context, r)}',
    ));
  }
  return QuizScreen(
      title: context.l10n.spotTheRule, progressId: 'tajwid.quiz', questions: qs);
}

/// A single-rule detail page — opened from global search. [DesktopAware] so it
/// fills the pane on desktop instead of the phone frame; on mobile it's a
/// normal pushed screen with an app-bar back button.
class TajwidRuleScreen extends StatelessWidget with DesktopAware {
  final TajwidRule rule;
  const TajwidRuleScreen({super.key, required this.rule});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tajwidName(context, rule))),
      body: SafeArea(
        top: false,
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(children: [
                Container(
                  width: 14,
                  height: 46,
                  decoration: BoxDecoration(
                      color: rule.color,
                      borderRadius: BorderRadius.circular(7)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tajwidName(context, rule),
                          style: uiStyle(context,
                              size: 22, weight: FontWeight.w900)),
                      Text(rule.arabicName,
                          textDirection: TextDirection.rtl,
                          style: arabicStyle(context,
                              size: 18, color: pal(context).textDim)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _block(context, context.l10n.when, tajwidTrigger(context, rule)),
              const SizedBox(height: 12),
              _block(context, context.l10n.how, tajwidHow(context, rule)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                      s.paperMode ? pal(context).paper : pal(context).surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(children: [
                  RichText(
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    text: TextSpan(children: [
                      for (final seg in rule.example.segs)
                        TextSpan(
                          text: seg.text,
                          style: arabicStyle(context,
                              size: 32,
                              color: seg.ruleId != null
                                  ? ruleById(seg.ruleId!).color
                                  : null),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text(context.l10n.surahRef(rule.example.ref),
                      style: uiStyle(context,
                          size: 12.5, color: pal(context).textDim)),
                ]),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _block(BuildContext context, String k, String v) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k,
                style: uiStyle(context,
                    size: 13, weight: FontWeight.w700, color: rule.color)),
            const SizedBox(height: 4),
            Text(v,
                style: uiStyle(context, size: 14.5, color: pal(context).textDim)),
          ],
        ),
      );
}
