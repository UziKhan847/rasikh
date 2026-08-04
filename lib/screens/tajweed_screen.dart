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
import '../widgets/common.dart';

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
    final units = tajwidUnits(context);
    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(context.l10n.tajwidAcademy)),
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
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pushAdaptive(context, const _AllRulesScreen()),
                  icon: const Icon(Icons.list_rounded),
                  label: Text(context.l10n.browseAllRules),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: pal(context).accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => pushAdaptive(context, _tajwidQuiz(context)),
                  icon: const Icon(Icons.quiz_rounded),
                  label: Text(context.l10n.spotRuleQuiz),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            for (var i = 0; i < units.length; i++)
              FadeSlideIn(
                delayMs: 35 * i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TapScale(
                    onTap: () => pushAdaptive(context, TajwidUnitHub(unit: units[i])),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pal(context).surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: pal(context).surfaceHigh),
                      ),
                      child: Row(children: [
                        Container(
                          width: 52, height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal(context).surfaceHigh,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(units[i].arabicBadge,
                              style: quranicStyle(context, size: 22, height: 1.3,
                                  color: pal(context).accent)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(units[i].title,
                                  style: uiStyle(context,
                                      size: 16.5, weight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(units[i].subtitle,
                                  style: uiStyle(context,
                                      size: 13, color: pal(context).textDim)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: pal(context).textDim),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
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
                          style: _verseStyle(context,
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
                icon: Icons.menu_book_rounded,
                label: context.l10n.phaseLearn,
                sub: context.l10n.phaseLearnSub,
                builder: (_) => _makharijLearn(context)),
            UnitPhase(
                icon: Icons.quiz_rounded,
                label: context.l10n.phaseTest,
                sub: context.l10n.phaseTestSub,
                builder: (c) => _makharijQuiz(c)),
            UnitPhase(
                icon: Icons.refresh_rounded,
                label: context.l10n.phasePractice,
                sub: context.l10n.phasePracticeSub,
                builder: (c) => _makharijQuiz(c, graded: false)),
            UnitPhase(
                icon: Icons.mic_none_rounded,
                label: context.l10n.phaseRecite,
                sub: context.l10n.phaseReciteSub),
          ]),
      TajwidUnit(context.l10n.tjUnitSifat, context.l10n.tjUnitSifatSub, 'صفة',
          'tajwid.sifat',
          phases: [
            UnitPhase(
                icon: Icons.menu_book_rounded,
                label: context.l10n.phaseLearn,
                sub: context.l10n.phaseLearnSub,
                builder: (_) => _sifatLearn(context)),
            UnitPhase(
                icon: Icons.quiz_rounded,
                label: context.l10n.phaseTest,
                sub: context.l10n.phaseTestSub,
                builder: (c) => _sifatQuiz(c)),
            UnitPhase(
                icon: Icons.refresh_rounded,
                label: context.l10n.phasePractice,
                sub: context.l10n.phasePracticeSub,
                builder: (c) => _sifatQuiz(c, graded: false)),
            UnitPhase(
                icon: Icons.mic_none_rounded,
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
                icon: Icons.menu_book_rounded,
                label: context.l10n.phaseLearn,
                sub: context.l10n.phaseLearnSub,
                builder: (_) => _casesLearn(context)),
            UnitPhase(
                icon: Icons.quiz_rounded,
                label: context.l10n.phaseTest,
                sub: context.l10n.phaseTestSub,
                builder: (c) => _casesQuiz(c)),
            UnitPhase(
                icon: Icons.refresh_rounded,
                label: context.l10n.phasePractice,
                sub: context.l10n.phasePracticeSub,
                builder: (c) => _casesQuiz(c, graded: false)),
            UnitPhase(
                icon: Icons.mic_none_rounded,
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
        icon: Icons.menu_book_rounded,
        label: context.l10n.phaseLearn,
        sub: context.l10n.phaseLearnSub,
        builder: (_) => _ruleFamilyLearn(context, title, rules)),
    UnitPhase(
        icon: Icons.grid_view_rounded,
        label: context.l10n.phaseLetters,
        sub: context.l10n.phaseLettersSub,
        builder: (_) => _lettersScreen(context, title, rules)),
    UnitPhase(
        icon: Icons.quiz_rounded,
        label: context.l10n.phaseTest,
        sub: context.l10n.phaseTestSub,
        builder: (c) => _ruleFamilyQuiz(c, title, progressId, rules)),
    UnitPhase(
        icon: Icons.refresh_rounded,
        label: context.l10n.phasePractice,
        sub: context.l10n.phasePracticeSub,
        builder: (c) =>
            _ruleFamilyQuiz(c, title, progressId, rules, graded: false)),
    UnitPhase(
        icon: Icons.mic_none_rounded,
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
      appBar: AppBar(title: Text(unit.title)),
      body: SafeArea(
        top: false,
        child: PhaseHub(
          subtitle: unit.subtitle,
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
    ConceptLearnScreen(
      title: title,
      cards: [
        for (final r in rules)
          ConceptCard(
            glyph: r.arabicName,
            title: tajwidName(context, r),
            subtitle: r.arabicName,
            note: '${tajwidTrigger(context, r)} ${tajwidHow(context, r)}',
            example: r.example.plain,
            exampleRef: r.example.ref,
          ),
      ],
    );

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
              style: uiStyle(context, size: 14, color: pal(context).textDim)),
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
                      color: pal(context).surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: pal(context).surfaceHigh),
                    ),
                    child: Text(ch,
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(context, size: 26,
                            color: pal(context).accent)),
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
/// segment show? Distractors come from the family first, padded with the
/// full rule set when the family is too small to give four real options.
QuizQuestion _ruleFamilyQuestion(BuildContext context, List<TajwidRule> rules) {
  final r = rules[_rng.nextInt(rules.length)];
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
    prompt: context.l10n.qpWhichRuleInVerse(r.example.ref),
    arabic: r.example.plain,
    reviewId: 'tajwid.${r.id}',
    options: o.options,
    correct: o.correct,
    explain: '${tajwidTrigger(context, r)} → ${tajwidHow(context, r)}',
  );
}

QuizScreen _ruleFamilyQuiz(BuildContext context, String title, String progressId,
    List<TajwidRule> rules, {bool graded = true}) {
  final qs = [for (var i = 0; i < math.max(6, rules.length * 2); i++) _ruleFamilyQuestion(context, rules)];
  return QuizScreen(title: title, progressId: progressId, questions: qs, graded: graded);
}

// ── Makhārij phases ─────────────────────────────────────────────────────

Widget _makharijLearn(BuildContext context) => ConceptLearnScreen(
      title: context.l10n.tjUnitMakharij,
      cards: [
        for (final m in makharij)
          ConceptCard(
            glyph: m.letters.isEmpty ? '·' : m.letters,
            title: m.name,
            subtitle: m.arabicName,
            note: m.note,
          ),
      ],
    );

QuizQuestion _makharijQuestion(BuildContext context) {
  final entry = makhrajOfLetter.entries.elementAt(_rng.nextInt(makhrajOfLetter.length));
  final letter = entry.key;
  final m = makhrajById(entry.value);
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
  final qs = [for (var i = 0; i < 8; i++) _makharijQuestion(context)];
  return QuizScreen(
      title: context.l10n.tjUnitMakharij,
      progressId: 'tajwid.makharij',
      questions: qs,
      graded: graded);
}

// ── Ṣifāt phases ────────────────────────────────────────────────────────

Widget _sifatLearn(BuildContext context) => ConceptLearnScreen(
      title: context.l10n.tjUnitSifat,
      cards: [
        for (final s in sifat)
          ConceptCard(
            glyph: s.letters,
            title: s.name,
            subtitle: s.arabicName,
            note: s.note,
          ),
      ],
    );

const _sifatAxes = [
  ['hams', 'jahr'],
  ['shidda', 'tawassut', 'rakhawa'],
  ['istila', 'istifal'],
  ['itbaq', 'infitah'],
  ['idhlaq', 'ismat'],
];

QuizQuestion _sifatQuestion(BuildContext context) {
  final axis = _sifatAxes[_rng.nextInt(_sifatAxes.length)];
  final values = axis.map(sifahById).toList();
  final correct = values[_rng.nextInt(values.length)];
  final letters = correct.letters.split('')..shuffle(_rng);
  final letter = letters.first;
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
  final qs = [for (var i = 0; i < 8; i++) _sifatQuestion(context)];
  return QuizScreen(
      title: context.l10n.tjUnitSifat,
      progressId: 'tajwid.sifat',
      questions: qs,
      graded: graded);
}

// ── Special cases phases ────────────────────────────────────────────────

Widget _casesLearn(BuildContext context) => ConceptLearnScreen(
      title: context.l10n.tjUnitCases,
      cards: [
        for (final c in tajwidCases)
          ConceptCard(
            glyph: c.highlight,
            title: c.name,
            subtitle: c.arabicName,
            note: c.note,
            example: c.example,
            exampleRef: c.ref,
          ),
      ],
    );

QuizQuestion _casesQuestion(BuildContext context) {
  final c = tajwidCases[_rng.nextInt(tajwidCases.length)];
  final pool = tajwidCases.map((x) => x.name).toSet().toList();
  final o = buildOptions(c.name, pool, _rng);
  return QuizQuestion(
    prompt: context.l10n.qpWhichSpecialCase,
    arabic: c.example,
    highlight: c.highlight,
    reviewId: 'tajwid.case.${c.id}',
    options: o.options,
    correct: o.correct,
    explain: c.note,
  );
}

QuizScreen _casesQuiz(BuildContext context, {bool graded = true}) {
  final qs = [for (var i = 0; i < 8; i++) _casesQuestion(context)];
  return QuizScreen(
      title: context.l10n.tjUnitCases,
      progressId: 'tajwid.cases',
      questions: qs,
      graded: graded);
}
