import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../data/script_diff.dart';
import '../data/small_letters.dart';
import '../data/tajwid_cases.dart';
import '../data/tanwin_allographs.dart';
import '../data/waqf.dart';
import '../data/wasl.dart';
import '../widgets/common.dart';

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
    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(context.l10n.scriptSymbols)),
      body: SafeArea(
        top: false,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          itemCount: units.length,
          itemBuilder: (context, i) {
            final u = units[i];
            return FadeSlideIn(
              delayMs: 50 * i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TapScale(
                  onTap: () => pushAdaptive(context, ScriptUnitHub(unit: u)),
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
                        child: Text(u.arabicBadge,
                            style: quranicStyle(context, size: 20, height: 1.3,
                                color: pal(context).accent)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.title,
                                style: uiStyle(context, size: 16.5, weight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(u.subtitle,
                                style: uiStyle(context, size: 13, color: pal(context).textDim)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: pal(context).textDim),
                    ]),
                  ),
                ),
              ),
            );
          },
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

// ── Unit 1: Script Families ─────────────────────────────────────────────

Widget _familiesLearn(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.unitScriptFamilies)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            for (var i = 0; i < scriptDifferences.length; i++)
              FadeSlideIn(delayMs: 40 * i, child: _diffCard(context, scriptDifferences[i])),
          ],
        ),
      ),
    );

Widget _diffCard(BuildContext context, ScriptDifference d) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pal(context).surfaceHigh),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.topic, style: uiStyle(context, size: 15.5, weight: FontWeight.w700)),
        const SizedBox(height: 12),
        _scriptRow(context, context.l10n.madaniUthmani, d.madaniWord),
        const SizedBox(height: 8),
        _scriptRow(context, context.l10n.indoPak, d.indopakWord),
        const SizedBox(height: 12),
        Text(d.note, style: uiStyle(context, size: 13, color: pal(context).textDim)),
        const SizedBox(height: 8),
        Text(context.l10n.surahRef(d.ref),
            style: uiStyle(context, size: 11.5, color: pal(context).textDim)),
        const SizedBox(height: 4),
        const MediaRow(),
      ]),
    );

Widget _scriptRow(BuildContext context, String label, String word) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 76,
            child: Text(label,
                style: uiStyle(context,
                    size: 12, weight: FontWeight.w700, color: pal(context).accent))),
        Expanded(
            child: Text(word,
                textDirection: TextDirection.rtl,
                style: quranicStyle(context, size: 21))),
      ],
    );

QuizQuestion _familiesQuestion(BuildContext context) {
  final d = scriptDifferences[_rng.nextInt(scriptDifferences.length)];
  final isMadani = _rng.nextBool();
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
  final qs = [for (var i = 0; i < 8; i++) _familiesQuestion(context)];
  return QuizScreen(
      title: context.l10n.unitScriptFamilies,
      progressId: 'script.families',
      questions: qs,
      graded: graded);
}

// ── Unit 2: Marks & Signs ───────────────────────────────────────────────

Widget _marksLearn(BuildContext context) => ConceptLearnScreen(
      title: context.l10n.unitMarksSigns,
      cards: [
        for (final a in tanwinAllographs)
          ConceptCard(
            glyph: a.highlight,
            title: '${a.tanwinId} · ${a.form}',
            example: a.example,
            exampleRef: a.ref,
          ),
        for (final s in smallLetters)
          ConceptCard(
            glyph: s.mark,
            title: s.name,
            note: s.note,
            example: s.example,
            exampleRef: s.ref,
          ),
        for (final w in [...waslOfKind('zero_rect'), ...waslOfKind('zero_round')])
          ConceptCard(
            glyph: w.highlight,
            title: w.kind == 'zero_rect'
                ? context.l10n.zeroRectTitle
                : context.l10n.zeroRoundTitle,
            note: w.kind == 'zero_rect'
                ? context.l10n.zeroRectNote
                : context.l10n.zeroRoundNote,
            example: w.example,
            exampleRef: w.ref,
          ),
        for (final c in tajwidCases.where((c) => c.id.startsWith('sin_over_sad')))
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

QuizQuestion _zeroQuestion(BuildContext context) {
  final items = [...waslOfKind('zero_rect'), ...waslOfKind('zero_round')]..shuffle(_rng);
  final w = items.first;
  final sounded = w.kind == 'zero_rect';
  final options = [context.l10n.optSoundedOnStopOnly, context.l10n.optNeverSounded];
  return QuizQuestion(
    prompt: context.l10n.qpAlifSoundsWhen,
    arabic: w.example,
    highlight: w.highlight,
    reviewId: 'script.zero.${w.id}',
    options: options,
    correct: sounded ? 0 : 1,
  );
}

QuizQuestion _smallLetterQuestion(BuildContext context) {
  final s = smallLetters[_rng.nextInt(smallLetters.length)];
  final pool = smallLetters.map((x) => x.name).toList();
  final o = buildOptions(s.name, pool, _rng, count: pool.length);
  return QuizQuestion(
    prompt: context.l10n.qpWhichSmallMark,
    arabic: s.example,
    highlight: s.highlight,
    reviewId: 'script.small.${s.id}',
    options: o.options,
    correct: o.correct,
    explain: s.note,
  );
}

QuizScreen _marksQuiz(BuildContext context, {bool graded = true}) {
  final qs = <QuizQuestion>[
    for (var i = 0; i < 4; i++) _zeroQuestion(context),
    for (var i = 0; i < 4; i++) _smallLetterQuestion(context),
  ]..shuffle(_rng);
  return QuizScreen(
      title: context.l10n.unitMarksSigns,
      progressId: 'script.marks',
      questions: qs,
      graded: graded);
}

// ── Unit 3: Waqf & Stopping ─────────────────────────────────────────────

const _stopMarkIds = ['lazim', 'mamnu', 'jaiz', 'wasl_awla', 'waqf_awla', 'muanaqah'];

String _actionLabel(BuildContext context, String action) => switch (action) {
      'must_stop' => context.l10n.optMustStop,
      'must_not_stop' => context.l10n.optMustNotStop,
      'either' => context.l10n.optEitherOk,
      'either_not_both' => context.l10n.optStopAtOneNotBoth,
      'preferred_continue' => context.l10n.optPreferContinue,
      'preferred_stop' => context.l10n.optPreferStop,
      _ => context.l10n.optPageMark,
    };

Widget _waqfLearn(BuildContext context) => ConceptLearnScreen(
      title: context.l10n.unitWaqfStopping,
      cards: [
        for (final id in _stopMarkIds)
          ConceptCard(
            glyph: waqfMarkById(id).arabicName.split(' — ').first,
            title: waqfMarkById(id).name,
            subtitle: _actionLabel(context, waqfMarkById(id).action),
            note: waqfMarkById(id).note,
            example: waqfMarkById(id).example,
            exampleRef: waqfMarkById(id).ref,
          ),
      ],
    );

QuizQuestion _waqfQuestion(BuildContext context) {
  final id = _stopMarkIds[_rng.nextInt(_stopMarkIds.length)];
  final m = waqfMarkById(id);
  final pool = _stopMarkIds.map((i) => _actionLabel(context, waqfMarkById(i).action)).toSet().toList();
  final o = buildOptions(_actionLabel(context, m.action), pool, _rng, count: pool.length);
  return QuizQuestion(
    prompt: context.l10n.qpWhichWaqfMark,
    arabic: m.example,
    reviewId: 'script.waqf.${m.id}',
    options: o.options,
    correct: o.correct,
    explain: m.note,
  );
}

QuizScreen _waqfQuiz(BuildContext context, {bool graded = true}) {
  final qs = [for (var i = 0; i < 8; i++) _waqfQuestion(context)];
  return QuizScreen(
      title: context.l10n.unitWaqfStopping,
      progressId: 'script.waqf',
      questions: qs,
      graded: graded);
}

// ── Unit 4: Page Marks ──────────────────────────────────────────────────

const _pageMarkIds = ['sajdah', 'rub'];

Widget _pageLearn(BuildContext context) => ConceptLearnScreen(
      title: context.l10n.unitPageMarks,
      cards: [
        for (final id in _pageMarkIds)
          ConceptCard(
            glyph: waqfMarkById(id).arabicName.split(' — ').first,
            title: waqfMarkById(id).name,
            note: waqfMarkById(id).note,
            example: waqfMarkById(id).example,
            exampleRef: waqfMarkById(id).ref,
          ),
      ],
    );

QuizQuestion _pageQuestion(BuildContext context) {
  final id = _pageMarkIds[_rng.nextInt(_pageMarkIds.length)];
  final m = waqfMarkById(id);
  final pool = _pageMarkIds.map((i) => waqfMarkById(i).name).toList();
  final o = buildOptions(m.name, pool, _rng, count: pool.length);
  return QuizQuestion(
    prompt: context.l10n.qpWhichPageMark,
    arabic: m.example,
    reviewId: 'script.page.${m.id}',
    options: o.options,
    correct: o.correct,
    explain: m.note,
  );
}

QuizScreen _pageQuiz(BuildContext context, {bool graded = true}) {
  final qs = [for (var i = 0; i < 6; i++) _pageQuestion(context)];
  return QuizScreen(
      title: context.l10n.unitPageMarks,
      progressId: 'script.page',
      questions: qs,
      graded: graded);
}
