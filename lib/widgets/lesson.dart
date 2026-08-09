import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import 'common.dart';

/// A node of a Learn-phase lesson tree (Round 12 — "drill down, then teach").
/// [children] makes this an index screen; an empty [children] with a
/// non-null [detail] makes it a leaf. A section with exactly ONE child is
/// transparent to the user — [openLesson] walks straight through it, so a
/// unit holding a single concept (Shaddah, Sukūn, the Oral Cavity, Khayshūm)
/// never shows a menu with one row in it.
class LessonNode {
  final String id;
  final String glyph; // Arabic badge; '' falls back to [icon]
  final IconData? icon;
  final String title;
  final String arabicName; // '' when [title] already IS the Arabic name
  final String summary; // one line under the title in the index
  final String group; // '' or a heading this node sits under, in its parent's index
  final List<LessonNode> children;
  final LessonDetail? detail;

  /// [glyph] (and the leaf's [LessonDetail.hero], if it falls back to glyph)
  /// is a SET of individual letters — e.g. a makhraj's 'بمو' — rather than a
  /// real word or name, so it must render as separate glyphs, never shaped
  /// as one cursive string. Real words (muqaṭṭaʿāt display text, rule
  /// Arabic names, verse highlights) must leave this false.
  final bool glyphIsLetterSet;

  /// Escape hatch for a leaf whose page genuinely isn't the standard
  /// hero/intro/facts/examples shape — e.g. Script Families' side-by-side
  /// Madani/Indo-Pak comparison. When set, [lessonEntryScreen] renders this
  /// instead of building a [LessonDetailScreen] from [detail].
  final Widget Function(BuildContext)? customDetail;

  /// Render this node as a compact square glyph tile in its parent's index
  /// (matching Unit 1's letter grid) instead of the default full-width row.
  /// Only meaningful for a node whose [glyph] alone identifies it — a bare
  /// letter, not a word or a name that needs [summary]/[arabicName] to read.
  /// A group renders as a grid only when EVERY node in it opts in, so a
  /// group mixing plain letters with named entries still falls back to rows.
  final bool gridTile;

  /// A hand-drawn shape (assets/special_cases/*.svg) for the index badge, in
  /// place of [glyph]. '' → today's text/icon badge; only Joining Forms'
  /// Special Shapes sets this. [svgMm] is the asset's own intrinsic size in
  /// millimetres (see special_shapes.dart's `shapeSvgMm`), required whenever
  /// [svg] is set so the drawn shape scales without distortion.
  final String svg;
  final (double, double) svgMm;

  /// Listed but not open yet — the same treatment [PhaseHub] gives a phase
  /// with a null builder: dimmed, tagged, tapping through to [comingSoon]
  /// instead of navigating. Used for a [LetterVariant] with no hand-drawn
  /// shape yet (see special_shapes.dart's `pendingVariantIds`).
  final bool locked;

  const LessonNode({
    required this.id,
    this.glyph = '',
    this.icon,
    required this.title,
    this.arabicName = '',
    this.summary = '',
    this.group = '',
    this.children = const [],
    this.detail,
    this.glyphIsLetterSet = false,
    this.customDetail,
    this.gridTile = false,
    this.svg = '',
    this.svgMm = (0, 0),
    this.locked = false,
  });
}

/// A leaf's page — a few sentences, not an essay, plus whatever structured
/// facts/letters/build/examples actually apply to that concept.
class LessonDetail {
  final String hero; // big Arabic display; falls back to the node's glyph
  final String intro;
  final List<(String, String)> facts; // ('When', '…'), ('Counts', '4–5')
  final String letters; // '' → no letter row
  final LessonBuild? build;
  final List<ConceptExample> examples;
  final String? ref; // MediaRow fallback when no example carries a ref

  /// A hand-drawn shape for the hero, in place of [hero] text. '' → the text
  /// hero. [heroSvgMm] is required whenever this is set.
  final String heroSvg;
  final (double, double) heroSvgMm;

  /// Examples backed by hand-drawn art rather than a text fragment. Rendered
  /// under the SAME "Examples" header as [examples], right after them — a
  /// parallel list rather than widening [ConceptExample] (a record typedef,
  /// so widening it would force every other Learn-phase page's example
  /// literals to carry permanently-null art fields).
  final List<LessonShapeExample> shapeExamples;

  /// An optional trailing widget below the examples — e.g. Madd's "Train the
  /// timing" button into [CountsStudio], which is a real feature and must
  /// survive a concept moving onto this shared surface.
  final Widget Function(BuildContext)? extra;

  const LessonDetail({
    this.hero = '',
    this.intro = '',
    this.facts = const [],
    this.letters = '',
    this.build,
    this.examples = const [],
    this.ref,
    this.heroSvg = '',
    this.heroSvgMm = (0, 0),
    this.shapeExamples = const [],
    this.extra,
  });
}

/// One [LessonDetail.shapeExamples] entry — a real example that may be
/// drawn art, degrading to plain UthmanicHafs text when [asset] is ''.
class LessonShapeExample {
  final String asset;
  final (double, double) mm;
  final String text; // verbatim Uthmani — a11y label AND text fallback
  final String ref; // 'surah:ayah'
  final String? highlight;
  const LessonShapeExample(
      {this.asset = '', this.mm = (0, 0), required this.text, this.ref = '', this.highlight});
}

/// The step-by-step strip on a detail page: cells joined by an operator,
/// each with its own caption underneath. E.g. Shaddah is بۡ + بَ = بَّ; Madd
/// Muttaṣil is قَالَ (2 counts) → جَآءَ (4–5, a hamzah follows in the same
/// word).
class LessonBuild {
  final String caption;

  /// (operator before this cell — '' for the first cell, glyph, caption)
  final List<(String, String, String)> cells;

  /// SVG-drawn strip cells. Non-empty → these REPLACE [cells] entirely; the
  /// two lists are never merged, since their sizing rules differ. An
  /// individual cell may still be text (see [LessonShapeCell.glyph]), e.g.
  /// a single-form shape's "apart" half stays plain letters while the
  /// "joined" half is drawn.
  final List<LessonShapeCell> shapeCells;

  const LessonBuild({this.caption = '', this.cells = const [], this.shapeCells = const []});
}

/// One [LessonBuild.shapeCells] entry — drawn art when [asset] is set, else
/// falls back to [glyph] as plain UthmanicHafs text.
class LessonShapeCell {
  final String op; // '' for the first cell, '→' for a transformation
  final String asset; // '' → render [glyph] as text instead
  final (double, double) mm;
  final String glyph;
  final String caption;
  const LessonShapeCell(
      {this.op = '', this.asset = '', this.mm = (0, 0), this.glyph = '', required this.caption});
}

/// Builds the screen [node] resolves to — [LessonDetailScreen] for a leaf,
/// [LessonIndexScreen] for a section — walking through any single-child
/// chain first, so the "don't show a menu with one row in it" rule lives in
/// exactly one place. Used both as a Learn phase's entry screen (a unit
/// whose root has exactly one concept, like Shaddah or Sukūn, opens straight
/// onto that concept instead of a one-row menu) and, via [openLesson], for
/// every row tap within an index.
Widget lessonEntryScreen(LessonNode node) {
  var n = node;
  while (n.children.length == 1) {
    n = n.children.first;
  }
  if (n.children.isEmpty) {
    return n.customDetail != null
        ? _LessonCustomScreen(n.customDetail!)
        : LessonDetailScreen(node: n);
  }
  return LessonIndexScreen(title: n.title, subtitle: n.summary, nodes: n.children);
}

/// Pushes [lessonEntryScreen] for [node] — the row-tap navigation used
/// inside a [LessonIndexScreen].
void openLesson(BuildContext context, LessonNode node) =>
    pushAdaptive(context, lessonEntryScreen(node));

/// Renders [letters] as visually SEPARATE glyphs, never shaped as one
/// cursive string — for a [LessonNode.glyph]/leaf hero that names a set of
/// letters (a makhraj's 'بمو') rather than a real word. [max] truncates a
/// long set (a whole zone's letters) down to a representative few, meant for
/// use inside a small badge; leave it null for a hero, where every letter in
/// the set should show.
Widget separatedLetters(BuildContext context, String letters,
    {required double size, Color? color, int? max}) {
  final chars = letters.split('');
  final shown = max != null && chars.length > max ? chars.sublist(0, max) : chars;
  return Wrap(
    alignment: WrapAlignment.center,
    spacing: size * 0.2,
    runSpacing: size * 0.15,
    children: [
      for (final ch in shown)
        Text(ch, textDirection: TextDirection.rtl, style: quranicStyle(context, size: size, color: color)),
    ],
  );
}

/// A hero's per-glyph size stepped down as a letter set grows, so up to ~6
/// letters still fit within a couple of wrapped rows at hero width.
double heroSetGlyphSize(int count, double heroSize) {
  if (count <= 2) return heroSize * 0.8;
  if (count <= 4) return heroSize * 0.55;
  if (count <= 7) return heroSize * 0.4;
  return heroSize * 0.3;
}

/// The tallest/widest hand-drawn special_cases shape is ~21.2mm. Every
/// [shapeSvg] box derives its px-per-mm from this one constant, so a 21mm
/// lām-alif and an 8mm tooth-over-mīm keep their true RELATIVE sizes on
/// screen — [BoxFit.contain] alone would inflate every shape to the same
/// optical size and erase a distinction that's part of the lesson.
const double kShapeMaxMm = 21.3;

/// A hand-drawn muṣḥaf shape (assets/special_cases/*.svg), tinted to the
/// current palette. The art is monochrome with hardcoded dark fills
/// (#000000 / #211e1e / #231f20, and several files with no fill declared at
/// all), every one of which would vanish on the dark and OLED palettes — so
/// it is ALWAYS recolored via [ColorFilter.mode]/[BlendMode.srcIn], which
/// maps every opaque pixel to [color] and keeps the anti-aliased alpha
/// regardless of the source fill. [width]/[height] are both always set
/// explicitly (never left for [SvgPicture] to infer) so a shape inside a
/// [Wrap] or [Row] cell gets its true aspect ratio, not a stretched one.
Widget shapeSvg(
  BuildContext context,
  String asset, {
  required (double, double) mm,
  required double boxSide,
  Color? color,
  String? semanticsLabel,
}) {
  final k = boxSide / kShapeMaxMm;
  return SvgPicture.asset(
    asset,
    width: mm.$1 * k,
    height: mm.$2 * k,
    fit: BoxFit.contain,
    alignment: Alignment.center,
    colorFilter: ColorFilter.mode(color ?? pal(context).text, BlendMode.srcIn),
    semanticsLabel: semanticsLabel,
  );
}

/// A leaf whose page doesn't fit [LessonDetail]'s standard shape (see
/// [LessonNode.customDetail]). Marked [DesktopAware] so [pushAdaptive] pushes
/// it bare instead of wrapping it in the mobile-sized [_DesktopFrame] — the
/// builder is expected to draw its own desktop-appropriate layout, exactly
/// like [LessonDetailScreen] does.
class _LessonCustomScreen extends StatelessWidget with DesktopAware {
  final Widget Function(BuildContext) builder;
  const _LessonCustomScreen(this.builder);
  @override
  Widget build(BuildContext context) => builder(context);
}

/// The desktop title row every pushed lesson screen shares: a back tile when
/// this screen is a real pushed route (not the shell-embedded phase root,
/// which already has its own back-header — see [QuizHostScope]), just the
/// title otherwise.
Widget lessonDesktopHeader(BuildContext context, String title) {
  final embedded = QuizHostScope.of(context);
  final showBack = !embedded && Navigator.of(context).canPop();
  return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
    if (showBack) ...[
      Material(
        color: pal(context).surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                border: Border.all(color: pal(context).surfaceHigh),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_back_rounded, size: 20, color: pal(context).text),
          ),
        ),
      ),
      const SizedBox(width: 14),
    ],
    Expanded(
        child: Text(title,
            style: uiStyle(context, size: 22, weight: FontWeight.w900))),
  ]);
}

/// The "browse these, tap one" index — one row per [LessonNode], grouped
/// under a heading wherever nodes carry a non-empty [LessonNode.group].
class LessonIndexScreen extends StatelessWidget with DesktopAware {
  final String title;
  final String subtitle;
  final List<LessonNode> nodes;
  const LessonIndexScreen(
      {super.key, required this.title, this.subtitle = '', required this.nodes});

  /// Nodes in their original order, bucketed by [LessonNode.group] (ungrouped
  /// nodes share the '' bucket) — so a group that isn't contiguous in the
  /// source list still renders as one heading, not several.
  Map<String, List<LessonNode>> get _groups {
    final out = <String, List<LessonNode>>{};
    for (final n in nodes) {
      out.putIfAbsent(n.group, () => []).add(n);
    }
    return out;
  }

  /// A group renders as a compact glyph grid (matching Unit 1's letter grid)
  /// only when every node in it opts in via [LessonNode.gridTile].
  bool _isGridGroup(List<LessonNode> group) => group.every((n) => n.gridTile);

  /// The tap gate every tile builder below routes through: a [n.locked]
  /// node shows [comingSoon] instead of navigating — [PhaseHub]'s own rule,
  /// applied here since [LessonNode] had no locked state before.
  void _open(BuildContext context, LessonNode n) =>
      n.locked ? comingSoon(context, n.title) : openLesson(context, n);

  @override
  Widget build(BuildContext context) {
    if (useDesktop(context)) return _desktopBuild(context);
    final groups = _groups;
    var i = 0;
    final children = <Widget>[
      if (subtitle.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(subtitle,
              style: uiStyle(context, size: 13.5, color: pal(context).textDim)
                  .copyWith(height: 1.4)),
        ),
    ];
    for (final g in groups.keys) {
      if (g.isNotEmpty) children.add(SectionHeader(g));
      final groupNodes = groups[g]!;
      if (_isGridGroup(groupNodes)) {
        children.add(_grid(context, groupNodes, startDelay: 22 * i));
        i += groupNodes.length;
      } else {
        for (final n in groupNodes) {
          children.add(FadeSlideIn(
            delayMs: 30 * i++,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _row(context, n),
            ),
          ));
        }
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: children,
        ),
      ),
    );
  }

  /// The compact square tile grid — Unit 1's own recipe
  /// ([LettersExplorer]'s `_smallGrid`), reused here so Joining Forms'
  /// letter picker looks and animates exactly the same way.
  Widget _grid(BuildContext context, List<LessonNode> items, {int startDelay = 0}) =>
      GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemCount: items.length,
        itemBuilder: (context, i) => FadeSlideIn(
          delayMs: startDelay + 22 * i,
          child: _gridTile(context, items[i]),
        ),
      );

  Widget _gridTile(BuildContext context, LessonNode n) => TapScale(
        onTap: () => _open(context, n),
        child: Opacity(
          opacity: n.locked ? .55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: pal(context).surface,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: n.svg.isNotEmpty
                ? shapeSvg(context, n.svg,
                    mm: n.svgMm, boxSide: 34, color: pal(context).text, semanticsLabel: n.title)
                : Text(n.glyph,
                    textDirection: TextDirection.rtl,
                    style: quranicStyle(context, size: 34, color: pal(context).text)),
          ),
        ),
      );

  Widget _row(BuildContext context, LessonNode n) => TapScale(
        onTap: () => _open(context, n),
        child: Semantics(
          button: true,
          enabled: !n.locked,
          child: Opacity(
            opacity: n.locked ? .55 : 1,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal(context).surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pal(context).surfaceHigh),
              ),
              child: Row(children: [
                Container(
                  width: 50, height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal(context).surfaceHigh,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: n.svg.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(7),
                          child: shapeSvg(context, n.svg,
                              mm: n.svgMm,
                              boxSide: 36,
                              color: pal(context).accent,
                              semanticsLabel: n.title),
                        )
                      : n.glyph.isEmpty
                          ? Icon(n.icon ?? Icons.menu_book_rounded, color: pal(context).accent)
                          : n.glyphIsLetterSet
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: separatedLetters(context, n.glyph,
                                      size: 20, color: pal(context).accent, max: 3),
                                )
                              : Text(n.glyph,
                                  textDirection: TextDirection.rtl,
                                  style:
                                      quranicStyle(context, size: 20, color: pal(context).accent)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(n.title,
                            style: uiStyle(context, size: 15.5, weight: FontWeight.w700)),
                        if (n.arabicName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(n.arabicName,
                              textDirection: TextDirection.rtl,
                              style: arabicStyle(context, size: 14, color: pal(context).textDim)),
                        ],
                        if (n.locked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: pal(context).surfaceHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(context.l10n.soon,
                                style: uiStyle(context,
                                    size: 9.5,
                                    weight: FontWeight.w800,
                                    color: pal(context).textDim)),
                          ),
                        ],
                      ]),
                      if (n.summary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(n.summary,
                              style: uiStyle(context, size: 12.5, color: pal(context).textDim)),
                        ),
                    ],
                  ),
                ),
                Icon(n.locked ? Icons.lock_clock_rounded : Icons.chevron_right_rounded,
                    color: pal(context).textDim),
              ]),
            ),
          ),
        ),
      );

  Widget _desktopBuild(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      backgroundColor: pal(context).bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
          children: [
            lessonDesktopHeader(context, title),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: uiStyle(context, size: 13.5, color: pal(context).textDim)),
            ],
            const SizedBox(height: 18),
            for (final g in groups.keys) ...[
              if (g.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(g, style: uiStyle(context, size: 15, weight: FontWeight.w700)),
                ),
              if (_isGridGroup(groups[g]!))
                GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 166, mainAxisSpacing: 16, crossAxisSpacing: 16),
                  itemCount: groups[g]!.length,
                  itemBuilder: (context, i) => _deskGridTile(context, groups[g]![i]),
                )
              else
                Wrap(
                  spacing: 16, runSpacing: 16,
                  children: [
                    for (final n in groups[g]!) SizedBox(width: 380, child: _row(context, n)),
                  ],
                ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }

  /// Desktop counterpart of [_gridTile] — [LettersExplorer]'s own desktop
  /// tile recipe (elevated card, glyph + name), reused so Joining Forms'
  /// picker matches Unit 1 on desktop too.
  Widget _deskGridTile(BuildContext context, LessonNode n) => Opacity(
        opacity: n.locked ? .55 : 1,
        child: Material(
          color: pal(context).surface,
          borderRadius: BorderRadius.circular(22),
          elevation: 4,
          shadowColor: pal(context).shadow,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _open(context, n),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: pal(context).surfaceHigh.withValues(alpha: .6)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  n.svg.isNotEmpty
                      ? shapeSvg(context, n.svg,
                          mm: n.svgMm, boxSide: 52, color: pal(context).text, semanticsLabel: n.title)
                      : Text(n.glyph,
                          textDirection: TextDirection.rtl,
                          style: quranicStyle(context, size: 52, color: pal(context).text)),
                  const SizedBox(height: 14),
                  Text(n.title,
                      style: uiStyle(context,
                          size: 13, weight: FontWeight.w600, color: pal(context).textDim)),
                ],
              ),
            ),
          ),
        ),
      );
}

/// A lesson's detail page — the "bigger and clearer" screen the drill-down
/// lands on, modelled on [LetterDetail]/[TajwidRuleScreen]: a hero glyph, an
/// intro, an optional facts table, an optional letters row, an optional
/// build strip, then several real examples at reading size (not crammed
/// into a `Wrap`), and one [MediaRow].
class LessonDetailScreen extends StatelessWidget with DesktopAware {
  final LessonNode node;
  const LessonDetailScreen({super.key, required this.node});

  /// Centers and width-caps one piece of content at 760px — every item
  /// below the header gets this individually (rather than one shared
  /// wrapper around a Column of everything) so the outer [ListView] still
  /// exposes each piece as its own sliver-list item, exactly like before
  /// this wrapping was added. Collapsing them into a single Column child
  /// would make the whole page "exist" in the widget tree from the first
  /// frame, breaking `scrollUntilVisible`/`find.byType` tests that rely on
  /// an item only appearing once actually scrolled near.
  Widget _capped(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = node.detail;
    final desktop = useDesktop(context);
    final heroSize = desktop ? 170.0 : 100.0;
    final hero = (d?.hero.isNotEmpty ?? false) ? d!.hero : node.glyph;
    return Scaffold(
      backgroundColor: desktop ? pal(context).bg : null,
      appBar: desktop ? null : AppBar(title: Text(node.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, desktop ? 12 : 8, 20, 30),
          children: [
            // The back header spans the full width, flush left — like
            // [LetterDetail._desktopBuild]'s own header — so it stays
            // OUTSIDE the width cap, unlike the reading content below it.
            if (desktop) ...[
              lessonDesktopHeader(context, node.title),
              const SizedBox(height: 12),
            ],
            if ((d?.heroSvg.isNotEmpty ?? false) || hero.isNotEmpty)
              _capped(Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: (d?.heroSvg.isNotEmpty ?? false)
                      ? SizedBox(
                          height: heroSize,
                          child: Center(
                            child: shapeSvg(context, d!.heroSvg,
                                mm: d.heroSvgMm,
                                boxSide: heroSize,
                                color: pal(context).accent,
                                semanticsLabel: node.title),
                          ),
                        )
                      : node.glyphIsLetterSet
                          ? separatedLetters(context, hero,
                              size: heroSetGlyphSize(hero.length, heroSize),
                              color: pal(context).accent)
                          : Text(hero,
                              textDirection: TextDirection.rtl,
                              style: quranicStyle(context,
                                  size: heroSize, height: 1.6, color: pal(context).accent)),
                ),
              )),
            _capped(Center(
              child: Column(children: [
                Text(node.title,
                    textAlign: TextAlign.center,
                    style: uiStyle(context,
                        size: desktop ? 24 : 20, weight: FontWeight.w900)),
                if (node.arabicName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(node.arabicName,
                        textDirection: TextDirection.rtl,
                        style: arabicStyle(context, size: 18, color: pal(context).textDim)),
                  ),
              ]),
            )),
            if (d != null && d.intro.isNotEmpty) ...[
              const SizedBox(height: 18),
              _capped(Text(d.intro,
                  style: uiStyle(context, size: 15, color: pal(context).text)
                      .copyWith(height: 1.55))),
            ],
            if (d != null && d.facts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _capped(_factsBlock(context, d.facts)),
            ],
            if (d != null && d.letters.isNotEmpty) ...[
              const SizedBox(height: 20),
              _capped(_lettersRow(context, d.letters)),
            ],
            if (d?.build != null) ...[
              const SizedBox(height: 22),
              _capped(_buildStrip(context, d!.build!)),
            ],
            if (d != null && (d.examples.isNotEmpty || d.shapeExamples.isNotEmpty)) ...[
              const SizedBox(height: 8),
              _capped(SectionHeader(context.l10n.lsnExamples)),
              for (final ex in d.examples) _capped(_exampleRow(context, ex)),
              for (final ex in d.shapeExamples) _capped(_shapeExampleRow(context, ex)),
            ],
            if (d?.extra != null) ...[
              const SizedBox(height: 6),
              _capped(d!.extra!(context)),
            ],
            const SizedBox(height: 10),
            _capped(MediaRow(ref: _mediaRef(d))),
          ],
        ),
      ),
    );
  }

  String? _mediaRef(LessonDetail? d) {
    if (d == null) return null;
    if (d.examples.isNotEmpty && d.examples.first.ref.isNotEmpty) {
      return d.examples.first.ref;
    }
    if (d.shapeExamples.isNotEmpty && d.shapeExamples.first.ref.isNotEmpty) {
      return d.shapeExamples.first.ref;
    }
    return d.ref;
  }

  Widget _factsBlock(BuildContext context, List<(String, String)> facts) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(color: pal(context).surface, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 108,
                  child: Text(facts[i].$1,
                      style: uiStyle(context,
                          size: 12.5, weight: FontWeight.w700, color: pal(context).accent))),
              Expanded(
                  child: Text(facts[i].$2,
                      style: uiStyle(context, size: 14, color: pal(context).textDim)
                          .copyWith(height: 1.4))),
            ]),
          ],
        ]),
      );

  Widget _lettersRow(BuildContext context, String letters) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.lsnLetters,
              style: uiStyle(context, size: 13, weight: FontWeight.w700, color: pal(context).textDim)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              for (final ch in letters.split(''))
                Container(
                  width: 46, height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal(context).surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: pal(context).surfaceHigh),
                  ),
                  child: Text(ch,
                      textDirection: TextDirection.rtl,
                      style: quranicStyle(context, size: 20, color: pal(context).accent)),
                ),
            ],
          ),
        ],
      );

  Widget _buildStrip(BuildContext context, LessonBuild b) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: pal(context).accent.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10, runSpacing: 10,
            children: b.shapeCells.isNotEmpty
                ? [
                    for (final c in b.shapeCells) ...[
                      if (c.op.isNotEmpty)
                        Text(c.op,
                            style: uiStyle(context,
                                size: 22, weight: FontWeight.w700, color: pal(context).accent)),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        c.asset.isNotEmpty
                            ? shapeSvg(context, c.asset,
                                mm: c.mm,
                                boxSide: useDesktop(context) ? 84 : 64,
                                color: pal(context).text)
                            : Text(c.glyph,
                                textDirection: TextDirection.rtl,
                                style: quranicStyle(context, size: 34)),
                        const SizedBox(height: 4),
                        Text(c.caption,
                            textAlign: TextAlign.center,
                            style: uiStyle(context, size: 11, color: pal(context).textDim)),
                      ]),
                    ],
                  ]
                : [
                    for (final (op, glyph, caption) in b.cells) ...[
                      if (op.isNotEmpty)
                        Text(op,
                            style: uiStyle(context,
                                size: 22, weight: FontWeight.w700, color: pal(context).accent)),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(glyph,
                            textDirection: TextDirection.rtl,
                            style: quranicStyle(context, size: 34)),
                        const SizedBox(height: 4),
                        Text(caption,
                            textAlign: TextAlign.center,
                            style: uiStyle(context, size: 11, color: pal(context).textDim)),
                      ]),
                    ],
                  ],
          ),
          if (b.caption.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(b.caption,
                textAlign: TextAlign.center,
                style: uiStyle(context, size: 12.5, color: pal(context).textDim)),
          ],
        ]),
      );

  Widget _exampleRow(BuildContext context, ConceptExample ex) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
            child: RichText(
              textDirection: TextDirection.rtl,
              text: TextSpan(
                children: highlightSpans(
                  ex.text,
                  ex.highlight ?? '',
                  quranicStyle(context, size: 32),
                  quranicStyle(context, size: 32, color: pal(context).accent),
                ),
              ),
            ),
          ),
          if (ex.ref.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(context.l10n.surahRef(ex.ref),
                  style: uiStyle(context, size: 11.5, color: pal(context).textDim)),
            ),
        ]),
      );

  /// Degrades to [_exampleRow] verbatim when [ex] carries no drawn art —
  /// the "an example with no SVG still renders correctly as text" guarantee
  /// [ShapeExample] promises in special_shapes.dart.
  Widget _shapeExampleRow(BuildContext context, LessonShapeExample ex) {
    if (ex.asset.isEmpty) {
      return _exampleRow(context, (text: ex.text, ref: ex.ref, highlight: ex.highlight));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: shapeSvg(context, ex.asset,
                mm: ex.mm, boxSide: 56, color: pal(context).text, semanticsLabel: ex.text),
          ),
        ),
        if (ex.ref.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(context.l10n.surahRef(ex.ref),
                style: uiStyle(context, size: 11.5, color: pal(context).textDim)),
          ),
      ]),
    );
  }
}
