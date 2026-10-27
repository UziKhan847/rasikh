import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/script_diff.dart';
import '../data/small_letters.dart';
import '../data/waqf.dart';
import '../ui/kit.dart';
import '../widgets/common.dart';
import '../widgets/lesson.dart';
import 'lessons/script_lessons.dart';

final _rng = math.Random();

/// 📜 Script & Symbols — everything on the page that isn't a letter: waqf
/// signs, sajdah, the small marks, and the real differences between the
/// Madani (Uthmānī) and Indo-Pak scripts this app bundles. A reference
/// section, not a beginner path — every unit is Learn → Test → Practice,
/// nothing locked.
class ScriptScreen extends StatelessWidget {
  const ScriptScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final units = scriptUnits(context);
    final prog = ProgressScope.of(context);
    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(context.l10n.scriptSymbols)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            QColumn(
              child: Text(context.l10n.scriptLead,
                  style: displayStyle(context, size: 24, height: 1.3)),
            ),
            QColumn(child: QSectionLabel(context.l10n.units)),
            QColumn(
              child: TwoColumnWrap(children: [
                for (final u in units)
                  UnitCard(
                    glyph: u.arabicBadge,
                    title: u.title,
                    subtitle: u.subtitle,
                    stars: prog.starsFor(u.progressId),
                    onTap: () => pushAdaptive(context, ScriptUnitHub(unit: u)),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// A unit of the Script & Symbols reference — mirrors [QaidahUnit]'s
/// three-phase shape (Learn → Test → Practice, nothing locked).
class ScriptUnit {
  final String title;
  final String subtitle;
  final String arabicBadge;
  final String progressId;
  final List<UnitPhase> phases;
  const ScriptUnit(this.title, this.subtitle, this.arabicBadge, this.progressId,
      {required this.phases});
}

List<ScriptUnit> scriptUnits(BuildContext context) => [
      ScriptUnit(context.l10n.unitScriptFamilies, context.l10n.unitScriptFamiliesSub,
          '۩', 'script.families',
          phases: standardPhases(context,
              learn: (_) => _familiesLearn(context),
              test: (c) => _familiesQuiz(c),
              practice: (c) => _familiesQuiz(c, graded: false))),
      ScriptUnit(context.l10n.unitMarksSigns, context.l10n.unitMarksSignsSub,
          'ﹺﹻ', 'script.marks',
          phases: standardPhases(context,
              learn: (_) => _marksLearn(context),
              test: (c) => _marksQuiz(c),
              practice: (c) => _marksQuiz(c, graded: false))),
      ScriptUnit(context.l10n.unitWaqfStopping, context.l10n.unitWaqfStoppingSub,
          'صلى', 'script.waqf',
          phases: standardPhases(context,
              learn: (_) => _waqfLearn(context),
              test: (c) => _waqfQuiz(c),
              practice: (c) => _waqfQuiz(c, graded: false))),
      ScriptUnit(context.l10n.unitPageMarks, context.l10n.unitPageMarksSub,
          '۩', 'script.page',
          phases: standardPhases(context,
              learn: (_) => _pageLearn(context),
              test: (c) => _pageQuiz(c),
              practice: (c) => _pageQuiz(c, graded: false))),
    ];

/// The Learn → Test → Practice hub for one unit — mirrors [QaidahUnitHub].
class ScriptUnitHub extends StatelessWidget {
  final ScriptUnit unit;
  const ScriptUnitHub({super.key, required this.unit});

  @override
  Widget build(BuildContext context) => Scaffold(
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

// ── Unit 1: Script Families ─────────────────────────────────────────────

Widget _familiesLearn(BuildContext context) => lessonEntryScreen(familiesLessonRoot(context));

QuizQuestion _familiesQuestion(BuildContext context, ScriptDifference d, bool isMadani) {
  final word = isMadani ? d.madaniWord : d.indopakWord;
  final options = [context.l10n.madaniUthmani, context.l10n.indoPak];
  final correctIdx = isMadani ? 0 : 1;
  return QuizQuestion(
    prompt: context.l10n.qpWhichScriptIsThis,
    arabic: word,
    reviewId: 'script.family.${d.id}.$isMadani',
    options: options,
    correct: correctIdx,
    explain: d.note,
  );
}

QuizScreen _familiesQuiz(BuildContext context, {bool graded = true}) {
  final instances = <(ScriptDifference, bool)>[
    for (final d in scriptDifferences) ...[(d, true), (d, false)],
  ];
  final qs = [
    for (final (d, isMadani) in pickN(instances, 8, _rng))
      _familiesQuestion(context, d, isMadani),
  ];
  return QuizScreen(
      title: context.l10n.unitScriptFamilies,
      progressId: 'script.families',
      questions: qs,
      graded: graded);
}

// ── Unit 2: Marks & Signs ───────────────────────────────────────────────

Widget _marksLearn(BuildContext context) => lessonEntryScreen(marksLessonRoot(context));

QuizQuestion _smallLetterQuestion(
    BuildContext context, SmallLetter s, String text, String hl) {
  final pool = smallLetters.map((x) => x.name).toList();
  final o = buildOptions(s.name, pool, _rng, count: pool.length);
  return QuizQuestion(
    prompt: context.l10n.qpWhichSmallMark,
    arabic: text,
    highlight: hl,
    reviewId: 'script.small.${s.id}',
    options: o.options,
    correct: o.correct,
    explain: s.note,
  );
}

QuizScreen _marksQuiz(BuildContext context, {bool graded = true}) {
  final smallInstances = <(SmallLetter, String, String)>[
    for (final s in smallLetters) ...[
      (s, s.example, s.highlight),
      for (final (t, _, h) in s.moreExamples) (s, t, h),
    ],
  ];
  final qs = <QuizQuestion>[
    for (final (s, t, h) in pickN(smallInstances, 8, _rng))
      _smallLetterQuestion(context, s, t, h),
  ]..shuffle(_rng);
  return QuizScreen(
      title: context.l10n.unitMarksSigns,
      progressId: 'script.marks',
      questions: qs,
      graded: graded);
}

// ── Unit 3: Waqf & Stopping ─────────────────────────────────────────────
// stopMarkIds/pageMarkIds/actionLabel live in lessons/script_lessons.dart —
// shared between that tree and this file's quiz code.

Widget _waqfLearn(BuildContext context) => lessonEntryScreen(waqfLessonRoot(context));

QuizQuestion _waqfQuestion(BuildContext context, WaqfMark m, String text) {
  final pool = stopMarkIds.map((i) => actionLabel(context, waqfMarkById(i).action)).toSet().toList();
  final o = buildOptions(actionLabel(context, m.action), pool, _rng, count: pool.length);
  return QuizQuestion(
    prompt: context.l10n.qpWhichWaqfMark,
    arabic: text,
    reviewId: 'script.waqf.${m.id}',
    options: o.options,
    correct: o.correct,
    explain: m.note,
  );
}

QuizScreen _waqfQuiz(BuildContext context, {bool graded = true}) {
  final instances = <(WaqfMark, String)>[
    for (final id in stopMarkIds) ...[
      (waqfMarkById(id), waqfMarkById(id).example),
      for (final (t, _, _) in waqfMarkById(id).moreExamples) (waqfMarkById(id), t),
    ],
  ];
  final qs = [
    for (final (m, t) in pickN(instances, 8, _rng)) _waqfQuestion(context, m, t),
  ];
  return QuizScreen(
      title: context.l10n.unitWaqfStopping,
      progressId: 'script.waqf',
      questions: qs,
      graded: graded);
}

// ── Unit 4: Page Marks ──────────────────────────────────────────────────

Widget _pageLearn(BuildContext context) => lessonEntryScreen(pageLessonRoot(context));

QuizQuestion _pageQuestion(BuildContext context, WaqfMark m, String text) {
  final pool = pageMarkIds.map((i) => waqfMarkById(i).name).toList();
  final o = buildOptions(m.name, pool, _rng, count: pool.length);
  return QuizQuestion(
    prompt: context.l10n.qpWhichPageMark,
    arabic: text,
    reviewId: 'script.page.${m.id}',
    options: o.options,
    correct: o.correct,
    explain: m.note,
  );
}

QuizScreen _pageQuiz(BuildContext context, {bool graded = true}) {
  final instances = <(WaqfMark, String)>[
    for (final id in pageMarkIds) ...[
      (waqfMarkById(id), waqfMarkById(id).example),
      for (final (t, _, _) in waqfMarkById(id).moreExamples) (waqfMarkById(id), t),
    ],
  ];
  final qs = [
    for (final (m, t) in pickN(instances, 6, _rng)) _pageQuestion(context, m, t),
  ];
  return QuizScreen(
      title: context.l10n.unitPageMarks,
      progressId: 'script.page',
      questions: qs,
      graded: graded);
}
