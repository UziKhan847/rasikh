import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../data/glyph_names.dart';
import '../../data/makharij.dart';
import '../../data/sifat.dart';
import '../../data/tajwid_cases.dart';
import '../../data/tajweed.dart';
import '../../data/tashkeel.dart';
import '../../widgets/common.dart';
import '../../widgets/lesson.dart';

// ── Makhārij: 5 zones, then their points ───────────────────────────────

LessonNode makharijLessonRoot(BuildContext context) => LessonNode(
      id: 'makharij',
      title: context.l10n.tjUnitMakharij,
      children: [for (final z in makhrajZones) _zoneNode(context, z)],
    );

LessonNode _zoneNode(BuildContext context, MakhrajZone zone) {
  final points = makharijOfZone(zone.id);
  return LessonNode(
    id: 'makharij.zone.${zone.id}',
    glyph: points.map((m) => m.letters).join(),
    glyphIsLetterSet: true,
    title: _zoneName(context, zone.id),
    arabicName: zone.arabicName,
    summary: zone.note,
    children: [for (final m in points) _pointNode(context, m)],
  );
}

LessonNode _pointNode(BuildContext context, Makhraj m) => LessonNode(
      id: 'makharij.${m.id}',
      glyph: m.letters,
      glyphIsLetterSet: true,
      title: m.name,
      arabicName: m.arabicName,
      summary: m.note,
      group: m.group.isEmpty ? '' : _tongueGroupName(context, m.group),
      detail: LessonDetail(
        hero: m.letters,
        intro: m.how,
        facts: [(context.l10n.lsnWhere, m.note)],
        letters: m.letters,
        examples: [
          for (final (_, w, ref, hl) in m.examples) (text: w, ref: ref, highlight: hl),
        ],
      ),
    );

String _zoneName(BuildContext context, String id) => switch (id) {
      'jawf' => context.l10n.mkZoneJawf,
      'halq' => context.l10n.mkZoneHalq,
      'lisan' => context.l10n.mkZoneLisan,
      'shafatan' => context.l10n.mkZoneShafatan,
      _ => context.l10n.mkZoneKhayshum,
    };

String _tongueGroupName(BuildContext context, String group) => switch (group) {
      'back' => context.l10n.mkGroupBack,
      'middle' => context.l10n.mkGroupMiddle,
      'edge' => context.l10n.mkGroupEdge,
      _ => context.l10n.mkGroupTip,
    };

/// Every core letter's articulation point — used by [LetterDetail]'s
/// cross-link row (Unit 1 → Tajwīd). Looks up the point directly rather than
/// re-deriving the zone, since [LessonDetailScreen] only needs the leaf.
LessonNode makharijPointNode(BuildContext context, String makhrajId) =>
    _pointNode(context, makhrajById(makhrajId));

// ── Ṣifāt: the 5 opposed axes, plus standalone qualities ───────────────

LessonNode sifatLessonRoot(BuildContext context) => LessonNode(
      id: 'sifat',
      title: context.l10n.tjUnitSifat,
      children: [
        for (final axis in sifatAxes) _axisNode(context, axis),
        _standaloneNode(context),
      ],
    );

LessonNode _axisNode(BuildContext context, List<String> axisIds) {
  final members = axisIds.map(sifahById).toList();
  return LessonNode(
    id: 'sifat.axis.${axisIds.join('_')}',
    glyph: members.first.arabicName,
    title: members.map((s) => s.name).join(' ↔ '),
    arabicName: members.map((s) => s.arabicName).join(' — '),
    children: [for (final s in members) _sifahNode(context, s)],
  );
}

LessonNode _standaloneNode(BuildContext context) => LessonNode(
      id: 'sifat.standalone',
      title: context.l10n.sifatStandaloneGroup,
      children: [for (final s in sifatStandalone) _sifahNode(context, s)],
    );

LessonNode _sifahNode(BuildContext context, Sifah s) => LessonNode(
      id: 'sifat.${s.id}',
      glyph: s.arabicName,
      title: s.name,
      arabicName: s.arabicName,
      summary: s.note,
      detail: LessonDetail(
        hero: s.arabicName,
        intro: s.note,
        letters: s.letters,
        examples: [
          for (final (_, w, ref, hl) in s.examples) (text: w, ref: ref, highlight: hl),
        ],
      ),
    );

// ── Rule families: Nūn, Mīm, Lām, Rāʾ, Qalqalah (Madd has its own root) ──

/// [topicId] keys the family ([TajwidTopic.id]): its node id stays the same
/// in every language.
LessonNode ruleFamilyLessonRoot(BuildContext context, String topicId,
        String title, List<TajwidRule> rules) =>
    LessonNode(
      id: 'rulefamily.$topicId',
      title: title,
      children: [for (final r in rules) _ruleNode(context, r)],
    );

LessonNode _ruleNode(BuildContext context, TajwidRule r) => LessonNode(
      id: 'tajwid.${r.id}',
      glyph: r.arabicName,
      title: tajwidName(context, r),
      arabicName: r.arabicName,
      summary: tajwidTrigger(context, r),
      detail: LessonDetail(
        hero: r.arabicName,
        intro: tajwidHow(context, r),
        facts: [(context.l10n.when, tajwidTrigger(context, r))],
        letters: r.letters,
        examples: conceptExamples(r.example.plain, r.example.ref, r.moreExamples,
            r.example.segs.where((s) => s.ruleId == r.id).map((s) => s.text).join()),
      ),
    );

// ── Madd: the 4 rules, each with a build strip comparing it to the plain
// 2-count baseline — the detail the user specifically asked for. ─────────

LessonNode maddLessonRoot(BuildContext context) {
  final base = tashkil.firstWhere((t) => t.id == 'madd2'); // قَالَ, 2:30 — the baseline
  final rules = ['madd2', 'madd4', 'madd45', 'madd6'].map(ruleById).toList();
  return LessonNode(
    id: 'tajwid.madd',
    title: context.l10n.tjUnitMadd,
    children: [for (final r in rules) _maddNode(context, r, base)],
  );
}

LessonNode _maddNode(BuildContext context, TajwidRule r, TashkilItem base) {
  LessonBuild? build;
  if (r.id == 'madd4') {
    build = LessonBuild(
      caption: 'A madd letter followed by a hamzah in the SAME word — the vowel '
          'stretches from 2 counts to 4–5.',
      cells: [
        ('', base.example, '2 counts'),
        ('→', r.example.plain, '4–5 counts'),
      ],
    );
  } else if (r.id == 'madd45') {
    build = LessonBuild(
      caption: 'A madd letter ends one word; a hamzah starts the very NEXT word — '
          'still 4 (up to 5) counts, even across the word boundary.',
      cells: [
        ('', base.example, '2 counts'),
        ('→', r.example.plain, '4–5 counts'),
      ],
    );
  } else if (r.id == 'madd6') {
    build = LessonBuild(
      caption: 'A madd letter is followed by a permanent sukūn or shaddah — the '
          'longest stretch in tajwīd, a full 6 counts.',
      cells: [
        ('', base.example, '2 counts'),
        ('→', r.example.plain, '6 counts'),
      ],
    );
  }
  final countsFact = switch (r.id) {
    'madd2' => '2 — always',
    'madd4' => '4–5',
    'madd45' => '4–5 in Ḥafṣ (some other riwāyāt read only 2 here)',
    _ => '6 — the longest of any madd rule',
  };
  final reqFact = switch (r.id) {
    'madd2' => 'Natural (ṭabīʿī) — the baseline every other madd rule lengthens beyond.',
    _ => 'Obligatory (wājib) — never shortened.',
  };
  return LessonNode(
    id: 'tajwid.${r.id}',
    glyph: r.arabicName,
    title: tajwidName(context, r),
    arabicName: r.arabicName,
    summary: tajwidTrigger(context, r),
    detail: LessonDetail(
      hero: r.arabicName,
      intro: tajwidHow(context, r),
      facts: [
        (context.l10n.when, tajwidTrigger(context, r)),
        (context.l10n.lsnCounts, countsFact),
        (context.l10n.lsnRequirement, reqFact),
      ],
      build: build,
      examples: conceptExamples(r.example.plain, r.example.ref, r.moreExamples,
          r.example.segs.where((s) => s.ruleId == r.id).map((s) => s.text).join()),
    ),
  );
}

// ── Special Cases ────────────────────────────────────────────────────────

LessonNode casesLessonRoot(BuildContext context) => LessonNode(
      id: 'tajwid.cases',
      title: context.l10n.tjUnitCases,
      children: [for (final c in tajwidCases) _caseNode(context, c)],
    );

LessonNode _caseNode(BuildContext context, TajwidCase c) => LessonNode(
      id: 'tajwid.case.${c.id}',
      glyph: c.highlight,
      title: c.name,
      arabicName: c.arabicName,
      summary: c.note,
      detail: LessonDetail(
        hero: c.highlight,
        intro: c.note,
        examples: conceptExamples(c.example, c.ref, c.moreExamples, c.highlight),
      ),
    );
