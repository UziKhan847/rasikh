import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/glyph_names.dart';
import '../data/makharij.dart';
import '../data/sifat.dart';
import '../data/tajweed.dart';
import '../data/tajwid_cases.dart';
import '../data/tajwid_path.dart';
import '../ui/kit.dart';
import '../widgets/common.dart';
import '../widgets/count_trainer.dart';
import '../widgets/lesson.dart';
import 'lessons/tajwid_lessons.dart';
import '../ui/app_icons.dart';

final _rng = math.Random();

/// The example verses are real Qur'anic text (Uthmani orthography, with the
/// Uthmani sukūn/tanwīn marks tajweed.dart's Seg strings match), not general
/// Arabic UI/body text — arabicStyle()'s ScheherazadeNew face is for prose,
/// so these render with [quranicStyle], the same Uthmani face the Qur'an
/// reader uses.
TextStyle _verseStyle(BuildContext context, {double size = 30, Color? color}) =>
    quranicStyle(context, size: size, color: color);

/// 🌿 Tajwīd Academy — a unit path (makhārij → ṣifāt → the rule families →
/// special cases), each unit opening onto a Learn → Letters → Test →
/// Practice → Recite hub (Recite is always "coming soon" — there's no voice
/// pipeline in the app). The flat rule-by-rule browse and the color legend
/// survive as a reference screen reachable from the hub, since the Qur'an
/// reader's highlighting uses the same colors and search still indexes every
/// rule individually.
class TajweedScreen extends StatelessWidget {
  const TajweedScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final units = tajwidUnits(context);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    Widget cap(Widget w) => QColumn(child: w);
    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(context.l10n.tajwidAcademy)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            cap(Text(context.l10n.tajwidLead,
                style: displayStyle(context, size: 24, height: 1.3))),
            cap(QSectionLabel(context.l10n.tajwidRulesLabel)),
            cap(Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in tajwidRules)
                  _RuleChip(
                    rule: r,
                    onTap: () =>
                        pushAdaptive(context, TajwidRuleScreen(rule: r)),
                  ),
              ],
            )),
            const SizedBox(height: 16),
            cap(Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: p.ink,
                  foregroundColor: p.bg,
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                onPressed: () =>
                    pushAdaptive(context, const CountTrainerScreen()),
                icon: const Icon(AppIcons.timer, size: 18),
                label: Text(context.l10n.countTrainer),
              ),
              QOutlineButton(context.l10n.spotRuleQuiz,
                  icon: AppIcons.quiz,
                  onTap: () => pushAdaptive(context, _tajwidQuiz(context))),
              QOutlineButton(context.l10n.browseAllRules,
                  icon: AppIcons.listView,
                  onTap: () =>
                      pushAdaptive(context, const _AllRulesScreen())),
            ])),
            cap(QSectionLabel(context.l10n.chapters)),
            if (wide)
              cap(LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final u in units)
                      SizedBox(
                          width: (c.maxWidth - 10) / 2,
                          child: _chapterCard(context, u)),
                  ],
                ),
              ))
            else
              for (var i = 0; i < units.length; i++)
                cap(QRiseIn(
                  delay: Duration(milliseconds: 30 * i),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _chapterCard(context, units[i]),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _chapterCard(BuildContext context, TajwidUnit u) => UnitCard(
        glyph: u.arabicBadge,
        title: u.title,
        subtitle: u.subtitle,
        stars: ProgressScope.of(context).starsFor(u.progressId),
        onTap: () => pushAdaptive(context, TajwidUnitHub(unit: u)),
      );
}

/// A rule's colour, lifted a little on dark themes so it reads on black.
Color _ruleColour(BuildContext context, TajwidRule r) => pal(context).isDark
    ? Color.lerp(r.color, Colors.white, .28)!
    : r.color;

/// How many counts a rule is held for, where it has a set length.
int? _countsFor(TajwidRule r) => switch (r.id) {
      'madd2' => 2,
      'madd4' || 'madd45' => 4,
      'madd6' => 6,
      'ghunnah' => 2,
      _ => null,
    };

/// A rule chip: a dot and the name, in the rule's own colour.
class _RuleChip extends StatelessWidget {
  final TajwidRule rule;
  final VoidCallback onTap;
  const _RuleChip({required this.rule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = _ruleColour(context, rule);
    return Material(
      color: c.withValues(alpha: .12),
      shape: StadiumBorder(side: BorderSide(color: c.withValues(alpha: .35))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(tajwidName(context, rule),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: uiStyle(context,
                      size: 13, weight: FontWeight.w700, color: c)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The flat browse-all reference — every rule, color-coded, one card each.
/// This was the whole of [TajweedScreen] before the unit path; kept as a
/// dedicated screen so the at-a-glance color reference (which the Qur'an
/// reader's highlighting also uses) is still one tap away.
class _AllRulesScreen extends StatelessWidget {
  const _AllRulesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tajwidAcademy)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            for (var i = 0; i < tajwidRules.length; i++)
              FadeSlideIn(
                delayMs: 35 * i,
                child: _RuleCard(rule: tajwidRules[i]),
              ),
          ],
        ),
      ),
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
          color: pal(context).card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pal(context).line2),
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
                      color: pal(context).ink3)),
              children: [
                _kv(context, context.l10n.when, tajwidTrigger(context, rule)),
                const SizedBox(height: 6),
                _kv(context, context.l10n.how, tajwidHow(context, rule)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: s.paperMode ? pal(context).paper : pal(context).track,
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
                            style: _verseStyle(context, size: 30,
                                color: seg.ruleId != null
                                    ? ruleById(seg.ruleId!).color
                                    : null),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    Text(context.l10n.surahRef(rule.example.ref),
                        style: uiStyle(context,
                            size: 12.5, color: pal(context).ink3)),
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
                  style: uiStyle(context, size: 14, color: pal(context).ink3))),
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
      reviewId: 'tajwid.${r.id}',
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
    final p = pal(context);
    final c = _ruleColour(context, rule);
    final counts = _countsFor(rule);
    final examples = conceptExamples(
        rule.example.plain, rule.example.ref, rule.moreExamples);
    Widget cap(Widget w) => QColumn(child: w);
    return Scaffold(
      appBar: AppBar(title: Text(tajwidName(context, rule))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            cap(Column(children: [
              Text(rule.arabicName,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: quranicStyle(context, size: 60, height: 1.7, color: c)),
              Text(tajwidName(context, rule),
                  textAlign: TextAlign.center,
                  style: displayStyle(context, size: 28)),
            ])),
            const SizedBox(height: 12),
            cap(Text(tajwidHow(context, rule),
                style: uiStyle(context, size: 16, height: 1.5))),
            const SizedBox(height: 14),
            cap(QCard(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.when.toUpperCase(),
                      style: uiStyle(context,
                          size: 11,
                          weight: FontWeight.w700,
                          letterSpacing: .9,
                          color: c)),
                  const SizedBox(height: 4),
                  Text(tajwidTrigger(context, rule),
                      style: uiStyle(context,
                          size: 14, color: p.ink2, height: 1.45)),
                ],
              ),
            )),
            if (rule.letters.isNotEmpty) ...[
              cap(SectionHeader(context.l10n.lsnLetters)),
              cap(Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final l in rule.letters.split('').where((x) => x.trim().isNotEmpty))
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.line2),
                      ),
                      child: Text(l,
                          style: arabicStyle(context, size: 24, color: c)),
                    ),
                ]),
              )),
            ],
            if (counts != null) ...[
              const SizedBox(height: 22),
              cap(HoldCountTrainer(counts: counts)),
            ],
            cap(SectionHeader(context.l10n.lsnExamples)),
            cap(QCard(
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                RichText(
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  text: TextSpan(children: [
                    for (final seg in rule.example.segs)
                      TextSpan(
                        text: seg.text,
                        style: _verseStyle(context,
                            size: 30,
                            color: seg.ruleId != null
                                ? _ruleColour(context, ruleById(seg.ruleId!))
                                : null),
                      ),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(context.l10n.surahRef(rule.example.ref),
                    style: uiStyle(context, size: 12, color: p.ink3)),
              ]),
            )),
            for (final ex in examples.skip(1))
              cap(QCard(
                margin: const EdgeInsets.only(top: 8),
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Text(context.l10n.surahRef(ex.ref),
                        style: uiStyle(context,
                            size: 12, weight: FontWeight.w600, color: p.ink3)),
                  ),
                  Flexible(
                    flex: 3,
                    child: RichText(
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      text: TextSpan(
                        children: highlightSpans(
                          ex.text,
                          ex.highlight ?? '',
                          _verseStyle(context, size: 28),
                          _verseStyle(context, size: 28, color: c),
                        ),
                      ),
                    ),
                  ),
                ]),
              )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════ Unit path ═══════════════════════════════════

/// One unit of the Tajwīd path — mirrors [QaidahUnit] but with up to five
/// phases, since a rule family also needs a "Letters" browse the Qaidah
/// path's three-phase shape doesn't have. Makhārij, Ṣifāt and Special Cases
/// don't have a letter-*trigger* grid the same way a rule family does, so
/// their [phases] list only has four (no Letters).
class TajwidUnit {
  final String title;
  final String subtitle;
  final String arabicBadge;
  final String progressId;
  final List<UnitPhase> phases;
  const TajwidUnit(this.title, this.subtitle, this.arabicBadge, this.progressId,
      {required this.phases});
}

List<TajwidUnit> tajwidUnits(BuildContext context) => [
      TajwidUnit(context.l10n.tjUnitMakharij, context.l10n.tjUnitMakharijSub, 'حلق',
          'tajwid.makharij',
          phases: [
            UnitPhase(
                icon: AppIcons.reader,
                label: context.l10n.phaseLearn,
                sub: context.l10n.phaseLearnSub,
                builder: (_) => _makharijLearn(context)),
            UnitPhase(
                icon: AppIcons.quiz,
                label: context.l10n.phaseTest,
                sub: context.l10n.phaseTestSub,
                builder: (c) => _makharijQuiz(c),
                isTest: true),
            UnitPhase(
                icon: AppIcons.reset,
                label: context.l10n.phasePractice,
                sub: context.l10n.phasePracticeSub,
                builder: (c) => _makharijQuiz(c, graded: false)),
            UnitPhase(
                icon: AppIcons.mic,
                label: context.l10n.phaseRecite,
                sub: context.l10n.phaseReciteSub),
          ]),
      TajwidUnit(context.l10n.tjUnitSifat, context.l10n.tjUnitSifatSub, 'صفة',
          'tajwid.sifat',
          phases: [
            UnitPhase(
                icon: AppIcons.reader,
                label: context.l10n.phaseLearn,
                sub: context.l10n.phaseLearnSub,
                builder: (_) => _sifatLearn(context)),
            UnitPhase(
                icon: AppIcons.quiz,
                label: context.l10n.phaseTest,
                sub: context.l10n.phaseTestSub,
                builder: (c) => _sifatQuiz(c),
                isTest: true),
            UnitPhase(
                icon: AppIcons.reset,
                label: context.l10n.phasePractice,
                sub: context.l10n.phasePracticeSub,
                builder: (c) => _sifatQuiz(c, graded: false)),
            UnitPhase(
                icon: AppIcons.mic,
                label: context.l10n.phaseRecite,
                sub: context.l10n.phaseReciteSub),
          ]),
      _ruleUnit(context, context.l10n.tjUnitNun, context.l10n.tjUnitNunSub, 'نْ',
          'tajwid.nun', 'nun'),
      _ruleUnit(context, context.l10n.tjUnitMim, context.l10n.tjUnitMimSub, 'مْ',
          'tajwid.mim', 'mim'),
      _ruleUnit(context, context.l10n.tjUnitMadd, context.l10n.tjUnitMaddSub, 'بَا',
          'tajwid.madd', 'madd'),
      _ruleUnit(context, context.l10n.tjUnitLam, context.l10n.tjUnitLamSub, 'ال',
          'tajwid.lam', 'lam'),
      _ruleUnit(context, context.l10n.tjUnitRaa, context.l10n.tjUnitRaaSub, 'ر',
          'tajwid.raa', 'raa'),
      _ruleUnit(context, context.l10n.tjUnitQalqalah, context.l10n.tjUnitQalqalahSub,
          'قْ', 'tajwid.qalqalah', 'qalqalah'),
      TajwidUnit(context.l10n.tjUnitCases, context.l10n.tjUnitCasesSub, 'آلْـَٔانَ',
          'tajwid.cases',
          phases: [
            UnitPhase(
                icon: AppIcons.reader,
                label: context.l10n.phaseLearn,
                sub: context.l10n.phaseLearnSub,
                builder: (_) => _casesLearn(context)),
            UnitPhase(
                icon: AppIcons.quiz,
                label: context.l10n.phaseTest,
                sub: context.l10n.phaseTestSub,
                builder: (c) => _casesQuiz(c),
                isTest: true),
            UnitPhase(
                icon: AppIcons.reset,
                label: context.l10n.phasePractice,
                sub: context.l10n.phasePracticeSub,
                builder: (c) => _casesQuiz(c, graded: false)),
            UnitPhase(
                icon: AppIcons.mic,
                label: context.l10n.phaseRecite,
                sub: context.l10n.phaseReciteSub),
          ]),
    ];

/// The shared five-phase shape for the six rule-family units (Nūn, Mīm,
/// Madd, Lām, Rā', Qalqalah) — each backed by [TajwidTopic.ruleIds].
TajwidUnit _ruleUnit(BuildContext context, String title, String subtitle,
    String badge, String progressId, String topicId) {
  final topic = tajwidTopicById(topicId);
  final rules = topic.ruleIds.map(ruleById).toList();
  return TajwidUnit(title, subtitle, badge, progressId, phases: [
    UnitPhase(
        icon: AppIcons.reader,
        label: context.l10n.phaseLearn,
        sub: context.l10n.phaseLearnSub,
        builder: (_) => topicId == 'madd'
            ? lessonEntryScreen(maddLessonRoot(context))
            : _ruleFamilyLearn(context, title, rules)),
    UnitPhase(
        icon: AppIcons.gridView,
        label: context.l10n.phaseLetters,
        sub: context.l10n.phaseLettersSub,
        builder: (_) => _lettersScreen(context, title, rules)),
    UnitPhase(
        icon: AppIcons.quiz,
        label: context.l10n.phaseTest,
        sub: context.l10n.phaseTestSub,
        builder: (c) => _ruleFamilyQuiz(c, title, progressId, rules),
        isTest: true),
    UnitPhase(
        icon: AppIcons.reset,
        label: context.l10n.phasePractice,
        sub: context.l10n.phasePracticeSub,
        builder: (c) =>
            _ruleFamilyQuiz(c, title, progressId, rules, graded: false)),
    UnitPhase(
        icon: AppIcons.mic,
        label: context.l10n.phaseRecite,
        sub: context.l10n.phaseReciteSub),
  ]);
}

/// The Learn → ... → Recite hub for one unit, exactly mirroring
/// [QaidahUnitHub] but for [TajwidUnit].
class TajwidUnitHub extends StatelessWidget {
  final TajwidUnit unit;
  const TajwidUnitHub({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: PhaseHub(
          subtitle: unit.subtitle,
            glyph: unit.arabicBadge,
            title: unit.title,
            stars: ProgressScope.of(context).starsFor(unit.progressId),
          phases: unit.phases,
          onPick: (i) =>
              pushAdaptive(context, Builder(builder: unit.phases[i].builder!)),
        ),
      ),
    );
  }
}

// ── rule-family phases (Nūn, Mīm, Madd, Lām, Rā', Qalqalah) ────────────────

Widget _ruleFamilyLearn(BuildContext context, String title, List<TajwidRule> rules) =>
    lessonEntryScreen(ruleFamilyLessonRoot(context, title, rules));

/// A read-only browse of a rule family's trigger letters — tap a chip to see
/// its name. Not a drill; the drilling happens in Test/Practice.
Widget _lettersScreen(BuildContext context, String title, List<TajwidRule> rules) {
  final letters = <String>{for (final r in rules) ...r.letters.split('')}.toList();
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(context.l10n.tjLettersInThisRule,
              style: uiStyle(context, size: 14, color: pal(context).ink3)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              for (final ch in letters)
                TapScale(
                  onTap: () => ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(SnackBar(
                        content: Text(
                            '$ch — ${letterNameOf(context, ch)}'))),
                  child: Container(
                    width: 64, height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal(context).card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: pal(context).track),
                    ),
                    child: Text(ch,
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(context, size: 26,
                            color: pal(context).acc)),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// One family-quiz question: which rule does this verse's highlighted
/// segment show? [text]/[ref]/[hl] come from one of [r]'s real examples
/// (the primary one or one of its `moreExamples`) — drawn without
/// replacement across a session by [_ruleFamilyQuiz], so a thin family (even
/// Qalqalah's single rule) asks about several different verses instead of
/// repeating the same one. Distractors come from the family first, padded
/// with the full rule set when the family is too small to give four real
/// options. [reviewId] stays keyed to the rule alone (not the verse), so the
/// spaced-repetition queue tracks "review this rule", matching how it
/// behaved when every question showed the same one verse.
QuizQuestion _ruleFamilyQuestion(BuildContext context, TajwidRule r, String text,
    String ref, String hl, List<TajwidRule> rules) {
  var pool = rules.map((x) => tajwidName(context, x)).toSet().toList();
  if (pool.length < 4) {
    final extra = tajwidRules
        .where((x) => !rules.contains(x))
        .map((x) => tajwidName(context, x))
        .toList()
      ..shuffle(_rng);
    pool = [...pool, ...extra.take(4 - pool.length)];
  }
  final o = buildOptions(tajwidName(context, r), pool, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichRuleInVerse(ref),
    arabic: text,
    highlight: hl,
    reviewId: 'tajwid.${r.id}',
    options: o.options,
    correct: o.correct,
    explain: '${tajwidTrigger(context, r)} → ${tajwidHow(context, r)}',
  );
}

QuizScreen _ruleFamilyQuiz(BuildContext context, String title, String progressId,
    List<TajwidRule> rules, {bool graded = true}) {
  final instances = <(TajwidRule, String, String, String)>[
    for (final r in rules) ...[
      (
        r,
        r.example.plain,
        r.example.ref,
        r.example.segs.where((s) => s.ruleId == r.id).map((s) => s.text).join(),
      ),
      for (final (t, ref, h) in r.moreExamples) (r, t, ref, h),
    ],
  ];
  final n = math.max(6, rules.length * 2);
  final qs = [
    for (final (r, t, ref, h) in pickN(instances, n, _rng))
      _ruleFamilyQuestion(context, r, t, ref, h, rules),
  ];
  return QuizScreen(title: title, progressId: progressId, questions: qs, graded: graded);
}

// ── Makhārij phases ─────────────────────────────────────────────────────

Widget _makharijLearn(BuildContext context) => lessonEntryScreen(makharijLessonRoot(context));

QuizQuestion _makharijQuestion(BuildContext context, String letter, Makhraj m) {
  final pool = makharij.where((x) => x.id != 'khayshum').map((x) => x.name).toList();
  final o = buildOptions(m.name, pool, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichMakhrajLetter,
    arabic: letter,
    reviewId: 'makhraj.$letter',
    options: o.options,
    correct: o.correct,
    explain: m.note,
  );
}

QuizScreen _makharijQuiz(BuildContext context, {bool graded = true}) {
  final entries = makhrajOfLetter.entries.toList();
  final qs = [
    for (final e in pickN(entries, 8, _rng))
      _makharijQuestion(context, e.key, makhrajById(e.value)),
  ];
  return QuizScreen(
      title: context.l10n.tjUnitMakharij,
      progressId: 'tajwid.makharij',
      questions: qs,
      graded: graded);
}

// ── Ṣifāt phases ────────────────────────────────────────────────────────

Widget _sifatLearn(BuildContext context) => lessonEntryScreen(sifatLessonRoot(context));

QuizQuestion _sifatQuestion(
    BuildContext context, List<String> axis, Sifah correct, String letter) {
  final values = axis.map(sifahById).toList();
  final pool = values.map((v) => v.name).toList();
  final o = buildOptions(correct.name, pool, _rng, count: pool.length);
  return QuizQuestion(
    prompt: context.l10n.qpWhichQualityDoesThisHave,
    arabic: letter,
    reviewId: 'sifah.${correct.id}.$letter',
    options: o.options,
    correct: o.correct,
    explain: correct.note,
  );
}

QuizScreen _sifatQuiz(BuildContext context, {bool graded = true}) {
  // (axis, sifah-in-that-axis, one of its member letters) — drawing from
  // every axis-letter combination instead of just the 5 axes gives real
  // in-session variety even though there are only 5 opposed-pair axes.
  final instances = <(List<String>, Sifah, String)>[
    for (final axis in sifatAxes)
      for (final id in axis)
        for (final letter in sifahById(id).letters.split(''))
          (axis, sifahById(id), letter),
  ];
  final qs = [
    for (final (axis, correct, letter) in pickN(instances, 8, _rng))
      _sifatQuestion(context, axis, correct, letter),
  ];
  return QuizScreen(
      title: context.l10n.tjUnitSifat,
      progressId: 'tajwid.sifat',
      questions: qs,
      graded: graded);
}

// ── Special cases phases ────────────────────────────────────────────────

Widget _casesLearn(BuildContext context) => lessonEntryScreen(casesLessonRoot(context));

QuizQuestion _casesQuestion(
    BuildContext context, TajwidCase c, String text, String hl) {
  final pool = tajwidCases.map((x) => x.name).toSet().toList();
  final o = buildOptions(c.name, pool, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichSpecialCase,
    arabic: text,
    highlight: hl,
    reviewId: 'tajwid.case.${c.id}',
    options: o.options,
    correct: o.correct,
    explain: c.note,
  );
}

QuizScreen _casesQuiz(BuildContext context, {bool graded = true}) {
  final instances = <(TajwidCase, String, String)>[
    for (final c in tajwidCases) ...[
      (c, c.example, c.highlight),
      for (final (t, _, h) in c.moreExamples) (c, t, h),
    ],
  ];
  final qs = [
    for (final (c, t, h) in pickN(instances, 8, _rng)) _casesQuestion(context, c, t, h),
  ];
  return QuizScreen(
      title: context.l10n.tjUnitCases,
      progressId: 'tajwid.cases',
      questions: qs,
      graded: graded);
}
