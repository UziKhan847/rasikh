import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/glyph_names.dart';
import '../../data/muqattaat.dart';
import '../../data/small_letters.dart';
import '../../data/tajweed.dart';
import '../../data/tanwin_allographs.dart';
import '../../data/tanwin_forms.dart';
import '../../data/tashkeel.dart';
import '../../data/wasl.dart';
import '../../widgets/common.dart';
import '../../widgets/lesson.dart';
import '../tashkeel_screen.dart' show CountsStudio;
import '../../ui/app_icons.dart';

// ── Ḥarakāt ──────────────────────────────────────────────────────────────

LessonNode harakatLessonRoot(BuildContext context) {
  final items = tashkil.where((t) => ['fatha', 'kasra', 'damma'].contains(t.id)).toList();
  return LessonNode(
    id: 'qaidah.harakat',
    title: context.l10n.unitHarakat,
    children: [for (final t in items) _tashkilNode(context, t)],
  );
}

LessonNode _tashkilNode(BuildContext context, TashkilItem t) => LessonNode(
      id: 'tashkil.${t.id}',
      glyph: t.mark,
      title: tashkilName(context, t),
      summary: t.sound,
      detail: LessonDetail(
        hero: t.mark,
        intro: tashkilNote(context, t),
        facts: [(context.l10n.lsnSound, t.sound)],
        examples: conceptExamples(t.example, t.ref, t.moreExamples, t.highlight),
      ),
    );

// ── Tanwīn: 3 entries, then their types ──────────────────────────────────

LessonNode tanwinLessonRoot(BuildContext context) => LessonNode(
      id: 'qaidah.tanwin',
      title: context.l10n.unitTanwin,
      children: [
        for (final id in ['fathatan', 'kasratan', 'dammatan']) _tanwinTypeNode(context, id),
      ],
    );

LessonNode _tanwinTypeNode(BuildContext context, String tanwinId) {
  final t = tashkil.firstWhere((x) => x.id == tanwinId);
  final forms = tanwinId == 'fathatan' ? tanwinForms : const <TanwinForm>[];
  final allographs = tanwinAllographs.where((a) => a.tanwinId == tanwinId).toList();
  return LessonNode(
    id: 'qaidah.tanwin.$tanwinId',
    glyph: t.mark,
    title: tashkilName(context, t),
    summary: t.sound,
    children: [
      for (final f in forms) _tanwinFormNode(context, f),
      for (final a in allographs) _tanwinAllographNode(context, a),
    ],
  );
}

LessonNode _tanwinFormNode(BuildContext context, TanwinForm f) => LessonNode(
      id: 'tanwin.form.${f.id}',
      glyph: f.highlight,
      title: f.name,
      group: context.l10n.lsnHowWritten,
      detail: LessonDetail(
        hero: f.highlight,
        intro: f.note,
        facts: [(context.l10n.lsnOnWaqf, f.waqfNote)],
        examples: conceptExamples(f.example, f.ref, f.moreExamples, f.highlight),
      ),
    );

String _allographFormLabel(String form) => switch (form) {
      'parallel' => 'Parallel Shape',
      'alternate' => 'Alternate (Stacked) Shape',
      _ => 'Small Mīm (Iqlāb)',
    };

LessonNode _tanwinAllographNode(BuildContext context, TanwinAllograph a) {
  final rule = tajwidRules.firstWhere((r) => r.id == a.ruleId);
  return LessonNode(
    id: 'tanwin.allograph.${a.id}',
    glyph: a.highlight,
    title: _allographFormLabel(a.form),
    summary: tajwidName(context, rule),
    group: context.l10n.lsnShapeSignals,
    detail: LessonDetail(
      hero: a.highlight,
      intro: tajwidHow(context, rule),
      facts: [(context.l10n.when, tajwidTrigger(context, rule))],
      examples: conceptExamples(a.example, a.ref, a.moreExamples, a.highlight),
    ),
  );
}

// ── Sukūn / Shaddah: single-concept units, open the explanation directly ──

LessonNode sukunLessonRoot(BuildContext context) {
  final t = tashkil.firstWhere((x) => x.id == 'sukun');
  final fatha = tashkil.firstWhere((x) => x.id == 'fatha');
  return LessonNode(
    id: 'tashkil.sukun',
    glyph: t.mark,
    title: tashkilName(context, t),
    detail: LessonDetail(
      hero: t.mark,
      intro: tashkilNote(context, t),
      build: LessonBuild(
        caption: 'A letter with a vowel, closed off — no vowel of its own. It joins '
            'straight onto the vowel that came before it, with no pause.',
        cells: [
          ('', fatha.mark, tashkilName(context, fatha)),
          ('→', t.mark, tashkilName(context, t)),
        ],
      ),
      examples: conceptExamples(t.example, t.ref, t.moreExamples, t.highlight),
    ),
  );
}

LessonNode shaddaLessonRoot(BuildContext context) {
  final t = tashkil.firstWhere((x) => x.id == 'shadda');
  final sukun = tashkil.firstWhere((x) => x.id == 'sukun');
  final fatha = tashkil.firstWhere((x) => x.id == 'fatha');
  return LessonNode(
    id: 'tashkil.shadda',
    glyph: t.mark,
    title: context.l10n.shaddah,
    detail: LessonDetail(
      hero: t.mark,
      intro: tashkilNote(context, t),
      build: LessonBuild(
        caption: 'One letter, written once, pronounced twice: first closed (sākin), '
            'then voweled.',
        cells: [
          ('', sukun.mark, tashkilName(context, sukun)),
          ('+', fatha.mark, tashkilName(context, fatha)),
          ('=', t.mark, tashkilName(context, t)),
        ],
      ),
      examples: conceptExamples(t.example, t.ref, t.moreExamples, t.highlight),
    ),
  );
}

// ── Madd/Tashkīl: used both by Qaidah Unit 7 (madd-only) and the standalone
// Tashkīl Lab (all 16 marks) — one surface, not two. ──────────────────────

LessonNode tashkilLessonRoot(BuildContext context, {bool focusCounts = false}) {
  final items = focusCounts ? tashkil.where((t) => t.counts >= 2).toList() : tashkil;
  return LessonNode(
    id: focusCounts ? 'qaidah.madd' : 'tashkil.lab',
    title: focusCounts ? context.l10n.maddCounts : context.l10n.tashkilLab,
    children: [for (final t in items) _tashkilLabNode(context, t)],
  );
}

String _countLabel(BuildContext context, TashkilItem item) {
  final suffix = item.id == 'madd45' || item.id == 'madd4'
      ? '–5'
      : item.id == 'madd246'
          ? ' / 4 / 6'
          : '';
  return item.counts == 0
      ? context.l10n.noCount
      : suffix.isEmpty
          ? context.l10n.countLabelPlural(item.counts)
          : '${context.l10n.countsN(item.counts)}$suffix';
}

LessonNode _tashkilLabNode(BuildContext context, TashkilItem t) => LessonNode(
      id: 'tashkil.${t.id}',
      glyph: t.mark,
      title: tashkilName(context, t),
      summary: t.sound,
      detail: LessonDetail(
        hero: t.mark,
        intro: tashkilNote(context, t),
        facts: [(context.l10n.lsnCounts, _countLabel(context, t))],
        examples: conceptExamples(t.example, t.ref, t.moreExamples, t.highlight),
        extra: t.counts < 1
            ? null
            : (context) => SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: pal(context).acc,
                        side: BorderSide(color: pal(context).acc)),
                    onPressed: () => pushAdaptive(
                        context,
                        CountsStudio(
                            initialCounts: t.counts, word: t.example, highlight: t.highlight)),
                    icon: const Icon(AppIcons.timer),
                    label: Text(context.l10n.trainCountTiming(t.counts)),
                  ),
                ),
      ),
    );

// ── Waṣl ─────────────────────────────────────────────────────────────────

LessonNode waslLessonRoot(BuildContext context) {
  final shamsiyya = tajwidRules.firstWhere((r) => r.id == 'shamsiyya');
  final qamariyya = tajwidRules.firstWhere((r) => r.id == 'qamariyya');
  final waslTashkil = tashkil.firstWhere((t) => t.id == 'wasl');
  final waslConcept = waslOfKind('wasl').first;
  final solarLetters = waslOfKind('solar').map((w) => w.letter);
  final lunarLetters = waslOfKind('lunar').map((w) => w.letter);
  return LessonNode(
    id: 'qaidah.wasl',
    title: context.l10n.unitWasl,
    children: [
      LessonNode(
        id: 'wasl.hamzat_wasl',
        glyph: waslTashkil.mark,
        title: tashkilName(context, waslTashkil),
        detail: LessonDetail(
          hero: waslTashkil.mark,
          intro: tashkilNote(context, waslTashkil),
          examples:
              conceptExamples(waslConcept.example, waslConcept.ref, waslConcept.moreExamples, waslConcept.highlight),
        ),
      ),
      LessonNode(
        id: 'wasl.solar',
        glyph: solarLetters.join(),
        glyphIsLetterSet: true,
        title: context.l10n.solarLetters14,
        summary: tajwidName(context, shamsiyya),
        children: [for (final w in waslOfKind('solar')) _waslLetterNode(context, w)],
      ),
      LessonNode(
        id: 'wasl.lunar',
        glyph: lunarLetters.join(),
        glyphIsLetterSet: true,
        title: context.l10n.lunarLetters14,
        summary: tajwidName(context, qamariyya),
        children: [for (final w in waslOfKind('lunar')) _waslLetterNode(context, w)],
      ),
      _waslZeroNode(context, waslOfKind('zero_rect').first, context.l10n.zeroRectTitle,
          context.l10n.zeroRectNote),
      _waslZeroNode(context, waslOfKind('zero_round').first, context.l10n.zeroRoundTitle,
          context.l10n.zeroRoundNote),
      LessonNode(
        id: 'wasl.tanwin_wasl',
        glyph: 'ً ٱ',
        title: context.l10n.tanwinMeetsWaslTitle,
        detail: LessonDetail(
          hero: 'ً ٱ',
          intro: context.l10n.tanwinMeetsWaslNote,
          examples: conceptExamples(waslOfKind('tanwin_wasl').first.example,
              waslOfKind('tanwin_wasl').first.ref, waslOfKind('tanwin_wasl').first.moreExamples,
              waslOfKind('tanwin_wasl').first.highlight),
        ),
      ),
    ],
  );
}

LessonNode _waslLetterNode(BuildContext context, WaslItem w) {
  final rule = tajwidRules.firstWhere((r) => r.id == (w.kind == 'solar' ? 'shamsiyya' : 'qamariyya'));
  return LessonNode(
    id: 'wasl.${w.id}',
    glyph: w.letter,
    title: w.letter,
    detail: LessonDetail(
      hero: w.highlight,
      intro: tajwidHow(context, rule),
      examples: conceptExamples(w.example, w.ref, w.moreExamples, w.highlight),
    ),
  );
}

LessonNode _waslZeroNode(BuildContext context, WaslItem w, String title, String note) => LessonNode(
      id: 'wasl.${w.id}',
      glyph: w.highlight,
      title: title,
      detail: LessonDetail(
        hero: w.highlight,
        intro: note,
        examples: conceptExamples(w.example, w.ref, w.moreExamples, w.highlight),
      ),
    );

// ── Ḥurūf Muqaṭṭaʿāt ─────────────────────────────────────────────────────

LessonNode muqattaatLessonRoot(BuildContext context) => LessonNode(
      id: 'qaidah.muqattaat',
      title: context.l10n.unitMuqattaat,
      children: [for (final m in muqattaatSets) _muqattaatNode(context, m)],
    );

LessonNode _muqattaatNode(BuildContext context, MuqattaatSet m) => LessonNode(
      id: 'muqattaat.${m.id}',
      glyph: m.displayText,
      title: m.displayText,
      summary: context.l10n.surahsList(m.surahs.join(', ')),
      detail: LessonDetail(
        hero: m.displayText,
        intro: context.l10n.muqattaatCountsNote(
            [for (final l in m.letters.split('')) '$l:${muqattaatCounts[l]}'].join('  ')),
        letters: m.letters,
        examples: m.ref == '42:1-2'
            ? const []
            : conceptExamples(
                m.example, m.ref, [for (final (text, ref) in m.moreExamples) (text, ref, m.example)]),
      ),
    );

// ── Review — the table of contents IS the index ──────────────────────────

LessonNode reviewLessonRoot(BuildContext context) => LessonNode(
      id: 'qaidah.review',
      title: context.l10n.qaidahReview,
      children: [
        LessonNode(
            id: 'review.letters', glyph: 'ا ب', title: context.l10n.unitLetters,
            detail: LessonDetail(hero: 'ا ب', intro: context.l10n.unitLettersSub)),
        LessonNode(
            id: 'review.forms', glyph: 'ـبـ', title: context.l10n.unitJoiningForms,
            detail: LessonDetail(hero: 'ـبـ', intro: context.l10n.unitJoiningFormsSub)),
        LessonNode(
            id: 'review.harakat', glyph: 'بَ', title: context.l10n.unitHarakat,
            detail: LessonDetail(hero: 'بَ', intro: context.l10n.unitHarakatSub)),
        LessonNode(
            id: 'review.tanwin', glyph: 'بً', title: context.l10n.unitTanwin,
            detail: LessonDetail(hero: 'بً', intro: context.l10n.unitTanwinSub)),
        LessonNode(
            id: 'review.sukun',
            glyph: 'بۡ',
            title: tashkilName(context, tashkil.firstWhere((t) => t.id == 'sukun')),
            detail: LessonDetail(hero: 'بۡ', intro: context.l10n.unitSukunSub)),
        LessonNode(
            id: 'review.shadda', glyph: 'بّ', title: context.l10n.shaddah,
            detail: LessonDetail(hero: 'بّ', intro: context.l10n.unitShaddahSub)),
        LessonNode(
            id: 'review.madd', glyph: 'بَا', title: context.l10n.unitMaddLin,
            detail: LessonDetail(hero: 'بَا', intro: context.l10n.unitMaddLinSub)),
        LessonNode(
            id: 'review.words', glyph: 'قُلۡ', title: context.l10n.readingWords,
            detail: LessonDetail(hero: 'قُلۡ', intro: context.l10n.unitReadingWordsSub)),
      ],
    );

// ── A small letter's own lesson page — Unit 1's dagger alif / small wāw /
// small yāʼ, which used to be an inert display-only Wrap. ──────────────────

LessonNode smallLetterLessonNode(BuildContext context, SmallLetter s) => LessonNode(
      id: 'small.${s.id}',
      glyph: s.mark,
      title: s.name,
      detail: LessonDetail(
        hero: s.mark,
        intro: s.note,
        examples: conceptExamples(s.example, s.ref, s.moreExamples, s.highlight),
      ),
    );
