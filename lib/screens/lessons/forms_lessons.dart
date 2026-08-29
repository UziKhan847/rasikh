import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../data/glyph_names.dart';
import '../../data/letters.dart';
import '../../data/special_shapes.dart';
import '../../data/variants.dart';
import '../../widgets/common.dart';
import '../../widgets/lesson.dart';

/// Joining Forms, restructured (Round 13) to match Unit 1's own pattern: a
/// picker (here, the 28 letters plus a Special Shapes group), then a real
/// detail page per entry — not a single screen mixing the picker with the
/// content, which read as crowded and "almost like an afterthought."
LessonNode formsLessonRoot(BuildContext context) => LessonNode(
      id: 'forms',
      title: context.l10n.unitJoiningForms,
      children: [
        for (final l in letters) _letterFormNode(context, l),
        ligaturesGroupNode(context),
        kafWrapGroupNode(context),
        stackingGroupNode(context),
        heightsGroupNode(context),
      ],
    );

// ── One page per letter: its shapes, then real words carrying it ───────

LessonNode _letterFormNode(BuildContext context, ArabicLetter l) {
  final shapes = l.joins
      ? <(String, String)>[
          (l.finalForm, context.l10n.formEnd),
          (l.medial, context.l10n.formMiddle),
          (l.initial, context.l10n.formStart),
          (l.char, context.l10n.formAlone),
        ]
      : <(String, String)>[
          (l.finalForm, context.l10n.formJoined),
          (l.char, context.l10n.formAlone),
        ];
  final words = letterExamples[l.char] ?? const <LetterExample>[];
  return LessonNode(
    id: 'forms.letter.${l.char}',
    glyph: l.char,
    title: letterName(context, l),
    gridTile: true,
    detail: LessonDetail(
      hero: l.char,
      build: LessonBuild(cells: [for (final (glyph, caption) in shapes) ('', glyph, caption)]),
      examples: [
        ...conceptExamples(l.exampleWord, l.exampleRef),
        for (final w in words) (text: w.word, ref: '', highlight: null),
      ],
    ),
  );
}

// ── Special Shapes: the compound shapes a tatweel-joined form can't show ──
//
// Each group mixes real [SpecialShape] tiles (hand-drawn art — see
// special_shapes.dart) with any [pendingVariantIds] entries that belong to
// it, shown locked/dimmed until their own shape is drawn.

LessonNode ligaturesGroupNode(BuildContext context) => LessonNode(
      id: 'forms.special.ligatures',
      icon: Icons.link_rounded,
      title: context.l10n.lsnLigatures,
      group: context.l10n.lsnSpecialShapes,
      children: [
        for (final s in specialShapes.where((s) => s.group == 'ligature')) _shapeNode(context, s),
      ],
    );

LessonNode kafWrapGroupNode(BuildContext context) => LessonNode(
      id: 'forms.special.kaf',
      icon: Icons.route_rounded,
      title: context.l10n.lsnKafsWrap,
      group: context.l10n.lsnSpecialShapes,
      children: [
        for (final s in specialShapes.where((s) => s.group == 'kaf')) _shapeNode(context, s),
      ],
    );

LessonNode stackingGroupNode(BuildContext context) => LessonNode(
      id: 'forms.special.stacking',
      icon: Icons.layers_rounded,
      title: context.l10n.lsnStacking,
      group: context.l10n.lsnSpecialShapes,
      children: [
        for (final s in specialShapes.where((s) => s.group == 'stacking')) _shapeNode(context, s),
        _lockedVariantNode(context, variantById('lam.tucks_mim')),
      ],
    );

LessonNode heightsGroupNode(BuildContext context) => LessonNode(
      id: 'forms.special.heights',
      icon: Icons.height_rounded,
      title: context.l10n.lsnHeightsAndTails,
      group: context.l10n.lsnSpecialShapes,
      children: [
        for (final s in specialShapes.where((s) => s.group == 'tails')) _shapeNode(context, s),
        for (final id in [
          'tooth.elevated',
          'tooth.before_ain_tah',
          'tooth.after_descender',
          'haa.word_final',
          'taa_marbuta.word_final',
          'yeh.dotless_final',
        ])
          _lockedVariantNode(context, variantById(id)),
      ],
    );

LessonNode _shapeNode(BuildContext context, SpecialShape s) {
  final primary = s.forms.first;
  return LessonNode(
    id: 'forms.shape.${s.id}',
    svg: primary.asset,
    svgMm: shapeSvgMm[primary.asset]!,
    title: s.title,
    detail: LessonDetail(
      heroSvg: primary.asset,
      heroSvgMm: shapeSvgMm[primary.asset]!,
      intro: s.note,
      facts: [(context.l10n.lsnTellApart, s.tellApart)],
      build: _shapeBuild(context, s),
      shapeExamples: [
        for (final e in s.examples)
          LessonShapeExample(
            asset: e.asset,
            mm: e.asset.isNotEmpty ? shapeSvgMm[e.asset]! : (0, 0),
            text: e.word,
            ref: e.ref,
            highlight: e.highlight.isEmpty ? null : e.highlight,
          ),
      ],
    ),
  );
}

/// A [LetterVariant] with no hand-drawn shape yet — listed, dimmed, tapping
/// through to `comingSoon()` instead of navigating (see
/// special_shapes.dart's `pendingVariantIds`). Reuses [LetterVariant.note]
/// as the row's own summary and the pre-Round-14 title switch below, so the
/// content stays meaningful even while its art is still pending.
LessonNode _lockedVariantNode(BuildContext context, LetterVariant v) => LessonNode(
      id: 'forms.variant.${v.id}',
      glyph: v.highlight,
      title: _variantTitle(v.id),
      summary: v.note,
      locked: true,
    );

/// The second base letter shown alongside [SpecialShape.forms] first entry
/// for a single-form tile's "apart" half — only needed for the fused-letter
/// stacking shapes; height/tail shapes and every multi-form tile skip this
/// entirely (see [_shapeBuild]).
const _apartPartner = {
  'mim_over_jim': 'م ج',
  'lam_over_jim': 'ل ج',
  'tooth_over_jim': 'ب ج',
  'ayn_over_jim': 'ع ج',
  'faqaf_over_jim': 'ف ج',
  'mim_over_mim': 'م م',
};

/// The build strip for a shape tile:
///  - more than one hand-drawn form -> one cell per form, captioned by
///    where/how it differs (position, or [ShapeForm.label]).
///  - exactly one form in a fused-letter family (ligature/kaf/stacking) ->
///    the old "Apart -> Joined as One Shape" pair, now drawn on the joined
///    side.
///  - a height/tail shape (one letter shifting under its neighbours, not
///    two letters fusing) -> no strip at all, same as before.
LessonBuild? _shapeBuild(BuildContext context, SpecialShape s) {
  if (s.forms.length > 1) {
    return LessonBuild(shapeCells: [
      for (final f in s.forms)
        LessonShapeCell(
          asset: f.asset,
          mm: shapeSvgMm[f.asset]!,
          caption: _formCaption(context, f),
        ),
    ]);
  }
  if (s.group == 'tails') return null;
  final partner = _apartPartner[s.id];
  if (partner == null) return null;
  final f = s.forms.first;
  return LessonBuild(shapeCells: [
    LessonShapeCell(glyph: partner, caption: context.l10n.lsnApart),
    LessonShapeCell(
        op: '→', asset: f.asset, mm: shapeSvgMm[f.asset]!, caption: context.l10n.lsnJoinedShape),
  ]);
}

String _formCaption(BuildContext context, ShapeForm f) => f.position != null
    ? switch (f.position!) {
        ShapePosition.isolated => context.l10n.formAlone,
        ShapePosition.beginning => context.l10n.formStart,
        ShapePosition.middle => context.l10n.formMiddle,
        ShapePosition.ending => context.l10n.formEnd,
      }
    : f.label;

String _variantTitle(String id) => switch (id) {
      'lam_alif.ligature' => 'Lām + Alif',
      'lam_alif.hamza_above' => 'Lām + Hamzah (Above Alif)',
      'lam_alif.hamza_below' => 'Lām + Hamzah (Below Alif)',
      'kaf.wraps_alif' => 'Kāf + Alif',
      'kaf.wraps_lam' => 'Kāf + Lām',
      'mim.stacks_jeem' => 'Mīm over Jīm',
      'mim.stacks_hah' => 'Mīm over Ḥāʼ',
      'mim.stacks_khah' => 'Mīm over Khāʼ',
      'lam.stacks_hah' => 'Lām over Ḥāʼ',
      'lam.stacks_khah' => 'Lām over Khāʼ',
      'lam.stacks_jeem' => 'Lām over Jīm',
      'lam.tucks_mim' => 'Lām + Mīm',
      'tooth.elevated' => 'A Tooth Letter, Elevated',
      'tooth.before_ain_tah' => 'A Tooth Letter Before ʿAyn or Ṭāʼ',
      'tooth.after_descender' => 'A Tooth Letter After a Descender',
      'mim.final_after_tooth' => 'Final Mīm After a Tooth Letter',
      'haa.medial_after_lam' => 'Hāʼ After Lām',
      'haa.word_final' => 'Hāʼ at the End of a Word',
      'taa_marbuta.word_final' => 'Tāʼ Marbūṭah at the End of a Word',
      'yeh.dotless_final' => 'A Dotless Final Yāʼ',
      _ => id,
    };
