import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/glyph_names.dart';
import '../../data/script_diff.dart';
import '../../data/small_letters.dart';
import '../../data/tajwid_cases.dart';
import '../../data/tajweed.dart';
import '../../data/tanwin_allographs.dart';
import '../../data/tashkeel.dart';
import '../../data/waqf.dart';
import '../../data/wasl.dart';
import '../../widgets/common.dart';
import '../../widgets/lesson.dart';

// ── Script Families: a bespoke side-by-side detail (see LessonNode.customDetail) ──

LessonNode familiesLessonRoot(BuildContext context) => LessonNode(
      id: 'script.families',
      title: context.l10n.unitScriptFamilies,
      children: [for (final d in scriptDifferences) _familyNode(context, d)],
    );

LessonNode _familyNode(BuildContext context, ScriptDifference d) => LessonNode(
      id: 'script.family.${d.id}',
      title: d.topic,
      summary: d.note,
      customDetail: (context) => _familyDetailScreen(context, d),
    );

/// Centers and width-caps one piece of content at 760px, keeping it its own
/// [ListView] item rather than folding everything into one shared Column —
/// see [LessonDetailScreen._capped] for why that granularity matters.
Widget _capped(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );

Widget _familyDetailScreen(BuildContext context, ScriptDifference d) {
  final desktop = useDesktop(context);
  // The back header spans the full width, flush left — like
  // [LetterDetail._desktopBuild]'s own header — not sit inside the same
  // centered/width-capped column as the reading content below it.
  return Scaffold(
      backgroundColor: desktop ? pal(context).bg : null,
      appBar: desktop ? null : AppBar(title: Text(d.topic)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, desktop ? 12 : 16, 20, 30),
          children: [
            if (desktop) ...[
              lessonDesktopHeader(context, d.topic),
              const SizedBox(height: 16),
            ],
            _capped(_bigScriptRow(context, context.l10n.madaniUthmani, d.madaniWord)),
            const SizedBox(height: 16),
            _capped(_bigScriptRow(context, context.l10n.indoPak, d.indopakWord)),
            const SizedBox(height: 20),
            _capped(Text(d.note,
                style: uiStyle(context, size: 15, color: pal(context).ink)
                    .copyWith(height: 1.55))),
            const SizedBox(height: 10),
            _capped(Text(context.l10n.surahRef(d.ref),
                style: uiStyle(context, size: 12.5, color: pal(context).ink3))),
            const SizedBox(height: 16),
            _capped(const MediaRow()),
          ],
        ),
      ),
    );
}

Widget _bigScriptRow(BuildContext context, String label, String word) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration:
          BoxDecoration(color: pal(context).card, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: uiStyle(context, size: 13, weight: FontWeight.w700, color: pal(context).acc)),
        const SizedBox(height: 10),
        Text(word,
            textDirection: TextDirection.rtl,
            style: quranicStyle(context, size: 26, height: 1.8)),
      ]),
    );

// ── Marks & Signs: grouped — tanwīn shapes · small letters · the two zeros ·
// sīn over ṣād ─────────────────────────────────────────────────────────────

LessonNode marksLessonRoot(BuildContext context) => LessonNode(
      id: 'script.marks',
      title: context.l10n.unitMarksSigns,
      children: [
        for (final a in tanwinAllographs) _allographNode(context, a),
        for (final s in smallLetters) _smallLetterMarkNode(context, s),
        for (final w in [...waslOfKind('zero_rect'), ...waslOfKind('zero_round')])
          _zeroNode(context, w),
        for (final c in tajwidCases.where((c) => c.id == 'sin_over_sad'))
          _caseAsMarkNode(context, c),
      ],
    );

LessonNode _allographNode(BuildContext context, TanwinAllograph a) {
  final rule = tajwidRules.firstWhere((r) => r.id == a.ruleId);
  final tanwinItem = tashkil.firstWhere((t) => t.id == a.tanwinId);
  return LessonNode(
    id: 'script.mark.${a.id}',
    glyph: a.highlight,
    title: '${tashkilName(context, tanwinItem)} · ${a.form}',
    summary: tajwidName(context, rule),
    group: context.l10n.lsnTanwinShapes,
    detail: LessonDetail(
      hero: a.highlight,
      intro: tajwidHow(context, rule),
      facts: [(context.l10n.when, tajwidTrigger(context, rule))],
      examples: conceptExamples(a.example, a.ref, a.moreExamples, a.highlight),
    ),
  );
}

LessonNode _smallLetterMarkNode(BuildContext context, SmallLetter s) => LessonNode(
      id: 'script.mark.${s.id}',
      glyph: s.mark,
      title: s.name,
      group: context.l10n.lsnSmallLetters,
      detail: LessonDetail(
        hero: s.mark,
        intro: s.note,
        examples: conceptExamples(s.example, s.ref, s.moreExamples, s.highlight),
      ),
    );

LessonNode _zeroNode(BuildContext context, WaslItem w) => LessonNode(
      id: 'script.mark.${w.id}',
      glyph: w.highlight,
      title: w.kind == 'zero_rect' ? context.l10n.zeroRectTitle : context.l10n.zeroRoundTitle,
      group: context.l10n.lsnTwoZeros,
      detail: LessonDetail(
        hero: w.highlight,
        intro: w.kind == 'zero_rect' ? context.l10n.zeroRectNote : context.l10n.zeroRoundNote,
        examples: conceptExamples(w.example, w.ref, w.moreExamples, w.highlight),
      ),
    );

LessonNode _caseAsMarkNode(BuildContext context, TajwidCase c) => LessonNode(
      id: 'script.mark.${c.id}',
      glyph: c.highlight,
      title: c.name,
      arabicName: c.arabicName,
      group: context.l10n.lsnSinOverSad,
      detail: LessonDetail(
        hero: c.highlight,
        intro: c.note,
        examples: conceptExamples(c.example, c.ref, c.moreExamples, c.highlight),
      ),
    );

// ── Waqf & Stopping / Page Marks — shared with script_screen.dart's quiz
// code, which is why these are public rather than private to this file. ────

const stopMarkIds = ['lazim', 'mamnu', 'jaiz', 'wasl_awla', 'waqf_awla', 'muanaqah'];
const pageMarkIds = ['sajdah', 'rub'];

String actionLabel(BuildContext context, String action) => switch (action) {
      'must_stop' => context.l10n.optMustStop,
      'must_not_stop' => context.l10n.optMustNotStop,
      'either' => context.l10n.optEitherOk,
      'either_not_both' => context.l10n.optStopAtOneNotBoth,
      'preferred_continue' => context.l10n.optPreferContinue,
      'preferred_stop' => context.l10n.optPreferStop,
      _ => context.l10n.optPageMark,
    };

LessonNode waqfLessonRoot(BuildContext context) => LessonNode(
      id: 'script.waqf',
      title: context.l10n.unitWaqfStopping,
      children: [for (final id in stopMarkIds) _waqfNode(context, waqfMarkById(id))],
    );

LessonNode _waqfNode(BuildContext context, WaqfMark m) => LessonNode(
      id: 'script.waqf.${m.id}',
      glyph: m.arabicName.split(' — ').first,
      title: m.name,
      summary: actionLabel(context, m.action),
      detail: LessonDetail(
        hero: m.arabicName.split(' — ').first,
        intro: m.note,
        facts: [(context.l10n.lsnRequirement, actionLabel(context, m.action))],
        examples: conceptExamples(m.example, m.ref, m.moreExamples),
      ),
    );

LessonNode pageLessonRoot(BuildContext context) => LessonNode(
      id: 'script.page',
      title: context.l10n.unitPageMarks,
      children: [for (final id in pageMarkIds) _pageMarkNode(context, waqfMarkById(id))],
    );

LessonNode _pageMarkNode(BuildContext context, WaqfMark m) => LessonNode(
      id: 'script.page.${m.id}',
      glyph: m.arabicName.split(' — ').first,
      title: m.name,
      detail: LessonDetail(
        hero: m.arabicName.split(' — ').first,
        intro: m.note,
        examples: conceptExamples(m.example, m.ref, m.moreExamples),
      ),
    );
