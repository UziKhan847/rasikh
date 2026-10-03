// UI kit — every element type in Kids Backdrops.dc.html, with the exact CSS values.
// Each widget's doc comment quotes the source CSS so you can check it.
//
// The visual language (apply it to anything not covered here):
//  • Solid faces only. No translucent cards, no blur-glass.
//  • Every raised element has a hard bottom EDGE (a darker copy of the shape shifted 3–8 px
//    down) plus a soft black drop shadow. See KbElev.
//  • Selected = 3–4 px accent ring OUTSIDE the shape and the edge switches to accentEdge.
//  • Buttons with text use cardDeep (white label) or surface (linkInk label). Plain accent
//    is only for icon-only buttons and progress fills.
//  • Text on the backdrop is limited to headings and one-line subtitles, drawn white with
//    a deep outline (KbHeading / KbSubtitle).
//  • Font: Baloo Bhaijaan 2, weight 800 for labels, 600–700 for secondary. Arabic letters:
//    Noto Naskh Arabic 600. Quranic words: Amiri Quran.

import 'package:flutter/material.dart';
import 'kb_icons.dart';
import 'kb_scene.dart';
import 'kb_themes.dart';
import 'kb_ui.dart';

const kbFontUi = 'Baloo Bhaijaan 2';
const kbFontArabic = 'Noto Naskh Arabic';
const kbFontQuran = 'Amiri Quran';
const kbFontIcon = 'Material Symbols Rounded';

/// CSS `line-height: normal` for each face — (hhea ascent + descent) / unitsPerEm
/// of the bundled files. The prototype leaves most text at `normal`.
const kbNormalHeight = {kbFontUi: 1.712, kbFontArabic: 1.703, kbFontQuran: 2.449, kbFontIcon: 1.2};

// Step-6 fix: with no `height`, a line is as tall as CSS `normal` makes it. It was
// a fixed 1.2 (30% short), and a bare null would inherit Material's body height.
TextStyle kbText(double size, Color color, {FontWeight weight = FontWeight.w800, double? height, String family = kbFontUi, List<Shadow>? shadows}) =>
    TextStyle(fontFamily: family, fontSize: size, fontWeight: weight, height: height ?? kbNormalHeight[family] ?? 1.2, color: color, shadows: shadows, leadingDistribution: TextLeadingDistribution.even,
        // APP ADAPTATION: the app's own faces catch what the design's do not — Urdu's
        // extra letters (ٹ ڈ ڑ ں ے) and any stray script. Same chain as `kidsStyle`.
        fontFamilyFallback: const ['Baloo2', 'Outfit', 'ScheherazadeNew']);

/// Material Symbols Rounded, FILL 1, wght 600 (by name, e.g. 'arrow_forward').
///
/// Step-6 fix: natural line height (1.2 em for this font), as the prototype's
/// icon spans have — none of them sets a line-height.
///
/// APP ADAPTATION: the design addresses icons by ligature in the 15 MB variable font.
/// The app bundles a 30 KB static cut of that font at exactly FILL 1 / wght 600,
/// subset to the icons in `tool/kb_icons.txt`, and draws each by its codepoint
/// (`kb_icons.dart`, generated). Same glyphs, same look. A name that is not bundled
/// asserts in debug rather than shipping as a blank box — add it to kb_icons.txt and
/// rerun `tool/kb_fonts.py`.
class KbIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const KbIcon(this.name, {super.key, required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    final cp = kbIconCodepoints[name];
    assert(cp != null, 'icon "$name" is not bundled — add it to tool/kb_icons.txt');
    return ExcludeSemantics(
      child: Text(String.fromCharCode(cp ?? 0x20), textScaler: TextScaler.noScaling,
          style: TextStyle(fontFamily: kbFontIcon, fontSize: size, height: kbNormalHeight[kbFontIcon], color: color)),
    );
  }
}

/// Elevation presets — CSS `box-shadow: 0 {edge}px 0 EDGE, 0 {softY}px {blur}px rgba(0,0,0,{alpha})`.
class KbElev {
  final double edge, softY, blur, alpha;
  const KbElev(this.edge, this.softY, this.blur, this.alpha);
  static const edge3 = KbElev(3, 0, 0, 0); //  small chips, word-card pills, arrow dot
  static const edge4 = KbElev(4, 0, 0, 0); //  back button, gem counter, Cancel, Get
  static const edge5 = KbElev(5, 0, 0, 0); //  write-screen buttons
  static const edge6 = KbElev(6, 0, 0, 0); //  big Start / Next buttons
  static const pill = KbElev(4, 10, 20, .2); //  Listen, See the whole path
  static const avatar = KbElev(4, 8, 14, .18); // avatar picker cell
  static const tile = KbElev(5, 10, 20, .18); // badge, stat, option, shop tile
  static const option = KbElev(5, 10, 18, .18); // quiz answer, gender chip
  static const letter = KbElev(5, 10, 18, .2); // bingo cell
  static const field = KbElev(5, 12, 24, .18); // text field
  static const card = KbElev(6, 14, 28, .2); //  list cards, rank row, looks row
  static const cardHi = KbElev(6, 14, 28, .22); // home "Next" card, Me avatar
  static const cardDeep = KbElev(6, 14, 28, .25); // Practice card
  static const game = KbElev(6, 12, 20, .2); //  ttt / memory cells
  static const big = KbElev(7, 16, 30, .25); // lesson letter cards, profile avatar, quiz word
  static const board = KbElev(7, 18, 34, .28); // writing board
  static const hero = KbElev(8, 20, 40, .3); // hamzah card
  List<BoxShadow> shadows(Color edgeColor) => kbCardShadow(edgeColor, edgeY: edge, softY: softY, blur: blur, alpha: alpha);
}

/// The base raised element. Everything else is built from this.
class KbSurface extends StatelessWidget {
  final Widget? child;
  final int color, edge;
  final KbElev elev;
  final double radius;
  final bool circle;
  final EdgeInsetsGeometry? padding;
  final double? width, height;
  final int? outline; // ring colour; CSS `outline: Npx solid` (outside, no layout change)
  final double outlineWidth;
  final bool highlight; // CSS `inset 0 2px 0 rgba(255,255,255,.18)`
  final AlignmentGeometry? alignment;
  final VoidCallback? onTap;
  const KbSurface({super.key, this.child, required this.color, required this.edge, this.elev = KbElev.card, this.radius = 24, this.circle = false, this.padding, this.width, this.height, this.outline, this.outlineWidth = 4, this.highlight = false, this.alignment, this.onTap});

  @override
  Widget build(BuildContext context) {
    final br = circle ? null : BorderRadius.circular(radius);
    Widget box = Container(
      width: width, height: height, padding: padding, alignment: alignment,
      decoration: BoxDecoration(
        color: kbC(color),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: br,
        border: outline == null ? null : Border.all(color: kbC(outline!), width: outlineWidth, strokeAlign: BorderSide.strokeAlignOutside),
        boxShadow: elev.shadows(kbC(edge)),
      ),
      child: child,
    );
    if (highlight) {
      box = Stack(children: [
        box,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: br ?? BorderRadius.circular(999),
              child: Align(alignment: Alignment.topCenter, child: Container(height: 2, color: kbC(kWhite, .18))),
            ),
          ),
        ),
      ]);
    }
    // APP ADAPTATION: tappable surfaces are buttons to a screen reader.
    return onTap == null ? box : Semantics(button: true, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box));
  }
}

// ───────────────────────── text on the backdrop ─────────────────────────

/// One-line text on the sky. CSS `font-size:19px;font-weight:700;color:subInk;text-shadow:subShadow`.
class KbSubtitle extends StatelessWidget {
  final String text;
  final KbUi ui;
  final double fontSize;
  final TextAlign? align;
  final double? height; // Step-6 fix: CSS subtitles are line-height `normal` (the kit had 1.35); Memory's is 1.35
  const KbSubtitle(this.text, {super.key, required this.ui, this.fontSize = 19, this.align, this.height});
  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: align, style: kbText(fontSize, kbC(ui.subInk), weight: FontWeight.w700, height: height, shadows: ui.subShadows));
}

// ───────────────────────── buttons ─────────────────────────

enum KbPillKind { surface, deep, outlined }

/// Rounded pill. CSS e.g. `padding:9px 22px 7px;border-radius:999px;background:surface;box-shadow:0 4px 0 edge, 0 10px 20px rgba(0,0,0,.2);color:linkInk;font-size:18px;font-weight:800`.
/// Uneven top/bottom padding is intentional (Baloo's baseline sits high).
class KbPill extends StatelessWidget {
  final String label;
  final String? icon;
  final KbUi ui;
  final KbPillKind kind;
  final double fontSize;
  final double? iconSize;
  final EdgeInsets padding;
  final KbElev? elev;
  final VoidCallback? onTap;
  const KbPill(this.label, {super.key, required this.ui, this.icon, this.kind = KbPillKind.surface, this.fontSize = 18, this.iconSize, this.padding = const EdgeInsets.fromLTRB(22, 9, 22, 7), this.elev, this.onTap});

  @override
  Widget build(BuildContext context) {
    final deep = kind == KbPillKind.deep, outlined = kind == KbPillKind.outlined;
    final ink = deep ? kbC(kWhite) : outlined ? kbC(ui.ink) : kbC(ui.linkInk);
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[KbIcon(icon!, size: iconSize ?? fontSize + 4, color: ink), SizedBox(width: fontSize <= 16 ? 4 : fontSize >= 20 ? 8 : 6)],
      // APP ADAPTATION: a label longer than the screen (a translation, a large text
      // size on a small phone) wraps instead of overflowing.
      Flexible(child: Text(label, textAlign: TextAlign.center, style: kbText(fontSize, ink, weight: outlined ? FontWeight.w700 : FontWeight.w800))),
    ]);
    if (outlined) {
      // CSS `border:2px solid edge;background:surface` — no shadow
      return Semantics(button: onTap != null, child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(color: kbC(ui.surface), borderRadius: BorderRadius.circular(999), border: Border.all(color: kbC(ui.edge), width: 2)),
          child: row,
        ),
      ));
    }
    return KbSurface(
      color: deep ? ui.cardDeep : ui.surface, edge: deep ? ui.cardDeepEdge : ui.edge,
      elev: elev ?? (deep ? KbElev.edge4 : KbElev.pill), radius: 999, padding: padding, onTap: onTap, child: row,
    );
  }
}

/// Full-width primary button. CSS `height:60px;border-radius:30px;background:cardDeep;box-shadow:0 6px 0 cardDeepEdge[, inset 0 2px 0 rgba(255,255,255,.2)];color:#fff;font-size:21–22px;font-weight:800`.
class KbBigButton extends StatelessWidget {
  final String label;
  final KbUi ui;
  final bool enabled, highlight;
  final double fontSize;
  final VoidCallback? onTap;
  const KbBigButton(this.label, {super.key, required this.ui, this.enabled = true, this.highlight = false, this.fontSize = 21, this.onTap});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: enabled ? ui.cardDeep : ui.disabledBg, edge: enabled ? ui.cardDeepEdge : ui.edge, elev: KbElev.edge6,
        radius: 30, height: 60, highlight: highlight && enabled, alignment: Alignment.center, onTap: enabled ? onTap : null,
        child: Text(label, style: kbText(fontSize, kbC(enabled ? kWhite : ui.inkSoft))),
      );
}

/// Round icon button.
/// surface: CSS `44×44;background:surface;box-shadow:0 4px 0 edge;color:ink;font-size:26px` (back)
/// accent:  CSS `54×54;background:accent;box-shadow:0 5px 0 accentEdge;color:#fff;font-size:28px` (go)
class KbRoundButton extends StatelessWidget {
  final String icon;
  final KbUi ui;
  final bool accent;
  final VoidCallback? onTap;
  final String? tooltip; // APP ADAPTATION: an icon-only button needs a name (screen readers, long-press)
  const KbRoundButton(this.icon, {super.key, required this.ui, this.accent = false, this.onTap, this.tooltip});
  @override
  Widget build(BuildContext context) {
    final b = KbSurface(
        color: accent ? ui.accent : ui.surface, edge: accent ? ui.accentEdge : ui.edge, elev: accent ? KbElev.edge5 : KbElev.edge4,
        circle: true, width: accent ? 54 : 44, height: accent ? 54 : 44, alignment: Alignment.center, onTap: onTap,
        child: KbIcon(icon, size: accent ? 28 : 26, color: kbC(accent ? kWhite : ui.ink)),
      );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// iOS-style switch. CSS `62×36;border-radius:18px;padding:4px;background:on?cardDeep:track`; knob 28 white `0 2px 4px rgba(0,0,0,.25)`.
class KbToggle extends StatelessWidget {
  final bool value;
  final KbUi ui;
  final ValueChanged<bool> onChanged;
  const KbToggle({super.key, required this.value, required this.ui, required this.onChanged});
  @override
  Widget build(BuildContext context) => Semantics(toggled: value, child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 62, height: 36, padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: kbC(value ? ui.cardDeep : ui.track), borderRadius: BorderRadius.circular(18)),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 28, height: 28, decoration: BoxDecoration(color: kbC(kWhite), shape: BoxShape.circle, boxShadow: [BoxShadow(color: kbC(kBlack, .25), offset: const Offset(0, 2), blurRadius: kbCssBlur(4))])),
        ),
      ));
}

// ───────────────────────── progress ─────────────────────────

/// CSS `height:12px;border-radius:6px;background:track` + fill accent. (List cards use 10/5.)
class KbProgress extends StatelessWidget {
  final double value; // 0..1
  final KbUi ui;
  final double height;
  const KbProgress({super.key, required this.value, required this.ui, this.height = 12});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height, color: kbC(ui.track), alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: value.clamp(0, 1).toDouble(), child: Container(decoration: BoxDecoration(color: kbC(ui.accent), borderRadius: BorderRadius.circular(height / 2)))),
        ),
      );
}

/// Quiz bar. CSS `height:14px;border-radius:7px;background:surface;box-shadow:0 3px 0 edge;padding:3px` + inner radius 5 accent.
class KbFramedProgress extends StatelessWidget {
  final double value;
  final KbUi ui;
  const KbFramedProgress({super.key, required this.value, required this.ui});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: ui.surface, edge: ui.edge, elev: KbElev.edge3, radius: 7, height: 14, padding: const EdgeInsets.all(3), alignment: Alignment.centerLeft,
        child: FractionallySizedBox(widthFactor: value.clamp(0, 1).toDouble(), child: Container(decoration: BoxDecoration(color: kbC(ui.accent), borderRadius: BorderRadius.circular(5)))),
      );
}

// ───────────────────────── small bits ─────────────────────────

/// Top-right gem balance. CSS `padding:6px 16px 4px 12px;border-radius:999px;background:surface;box-shadow:0 4px 0 edge`; diamond 22 linkInk; number 21/800 ink.
class KbGemCounter extends StatelessWidget {
  final int gems;
  final KbUi ui;
  const KbGemCounter(this.gems, {super.key, required this.ui});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: ui.surface, edge: ui.edge, elev: KbElev.edge4, radius: 999, padding: const EdgeInsets.fromLTRB(12, 6, 16, 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [KbIcon('diamond', size: 22, color: kbC(ui.linkInk)), const SizedBox(width: 6), Text('$gems', style: kbText(21, kbC(ui.ink)))]),
      );
}

/// Small filled circle with an icon (check marks, badges). e.g. 26 reward + check 17 rewardInk.
class KbDot extends StatelessWidget {
  final String icon;
  final int bg, ink;
  final double size, iconSize;
  final int? ring; // CSS `border:3px solid ring`
  final double ringWidth;
  const KbDot(this.icon, {super.key, required this.bg, required this.ink, this.size = 26, this.iconSize = 17, this.ring, this.ringWidth = 3});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: kbC(bg), shape: BoxShape.circle, border: ring == null ? null : Border.all(color: kbC(ring!), width: ringWidth)),
        child: KbIcon(icon, size: iconSize, color: kbC(ink)),
      );
}

/// Square glyph tile inside cards. CSS `64×64;border-radius:18px;background:tile;color:tileInk;font:600 32px Noto Naskh Arabic`.
class KbGlyphTile extends StatelessWidget {
  final String glyph;
  final double size, radius, fontSize;
  final int bg, ink;
  final bool icon;
  final List<BoxShadow>? shadow;
  const KbGlyphTile(this.glyph, {super.key, required this.bg, required this.ink, this.size = 64, this.radius = 18, this.fontSize = 32, this.icon = false, this.shadow});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: kbC(bg), borderRadius: BorderRadius.circular(radius), boxShadow: shadow),
        child: icon
            ? KbIcon(glyph, size: fontSize, color: kbC(ink))
            // APP ADAPTATION: a joined form or a whole word shrinks to fit the tile.
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(glyph, textDirection: TextDirection.rtl, style: kbText(fontSize, kbC(ink), family: kbFontArabic, weight: FontWeight.w600, height: 1.3))),
              ),
      );
}

// ───────────────────────── cards ─────────────────────────

/// Home "Next" card. CSS `padding:16px;border-radius:24px;background:surface;box-shadow:0 6px 0 edge, 0 14px 28px rgba(0,0,0,.22);gap:14px`.
class KbNextCard extends StatelessWidget {
  final KbUi ui;
  final String glyph, title;
  final double progress;
  final VoidCallback? onGo;
  final String? icon; // APP ADAPTATION: symbol for an item with no letter; the whole card is tappable
  final String goIcon; // APP ADAPTATION: arrow_back in right-to-left
  const KbNextCard({super.key, required this.ui, required this.glyph, required this.title, required this.progress, this.onGo, this.icon, this.goIcon = 'arrow_forward'});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: ui.surface, edge: ui.edge, elev: KbElev.cardHi, padding: const EdgeInsets.all(16), onTap: onGo,
        child: Row(children: [
          KbGlyphTile(icon ?? glyph, icon: icon != null, bg: ui.tile, ink: ui.tileInk),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: kbText(21, kbC(ui.ink), height: 1.1)),
            const SizedBox(height: 8),
            KbProgress(value: progress, ui: ui),
          ])),
          const SizedBox(width: 14),
          KbRoundButton(goIcon, ui: ui, accent: true, onTap: onGo),
        ]),
      );
}

/// Home "Practice" card (deep). CSS `padding:18px 20px;border-radius:24px;background:cardDeep;box-shadow:0 6px 0 cardDeepEdge, inset 0 2px 0 rgba(255,255,255,.18), 0 14px 28px rgba(0,0,0,.25)`.
class KbDeepCard extends StatelessWidget {
  final KbUi ui;
  final String icon, title, subtitle;
  final VoidCallback? onTap;
  const KbDeepCard({super.key, required this.ui, required this.icon, required this.title, required this.subtitle, this.onTap});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: ui.cardDeep, edge: ui.cardDeepEdge, elev: KbElev.cardDeep, highlight: true, padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), onTap: onTap,
        child: Row(children: [
          KbGlyphTile(icon, icon: true, size: 50, radius: 16, fontSize: 30, bg: ui.reward, ink: ui.rewardInk, shadow: [BoxShadow(color: kbC(ui.rewardEdge), offset: const Offset(0, 4))]),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: kbText(21, kbC(kWhite), height: 1.15)),
            Text(subtitle, style: kbText(16, kbC(kWhite, .9), weight: FontWeight.w600)),
          ])),
          KbIcon('chevron_right', size: 28, color: kbC(kWhite)),
        ]),
      );
}

/// Learn-path list card. Current item: 4 px accent ring, edge accentEdge, deep glyph tile.
/// CSS `padding:18px;border-radius:24px;gap:16px`; tile 70/r20; title 20/800; desc 16/600 inkSoft lh1.35; bar 10/5; count 16/800 linkInk.
class KbLearnCard extends StatelessWidget {
  final KbUi ui;
  final String glyph, title, desc;
  final bool glyphIsIcon, current, done;
  final int count, total;
  final VoidCallback? onTap;
  // APP ADAPTATION: a stage not reached yet. The card stays solid (UI_SPEC §1.7);
  // its tile shows a lock instead of the glyph, and there is no progress row.
  final bool locked;
  const KbLearnCard({super.key, required this.ui, required this.glyph, required this.title, required this.desc, this.glyphIsIcon = false, this.current = false, this.done = false, this.count = 0, this.total = 1, this.onTap, this.locked = false});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: ui.surface, edge: current ? ui.accentEdge : ui.edge, outline: current ? ui.accent : null, elev: KbElev.card, padding: const EdgeInsets.all(18), onTap: onTap,
        child: Row(children: [
          KbGlyphTile(locked ? 'lock' : glyph, icon: locked || glyphIsIcon, size: 70, radius: 20, fontSize: 30,
              bg: current ? ui.cardDeep : locked ? ui.disabledBg : ui.tile, ink: current ? kWhite : locked ? ui.inkSoft : ui.tileInk,
              shadow: current ? [BoxShadow(color: kbC(ui.cardDeepEdge), offset: const Offset(0, 4))] : null),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: kbText(20, kbC(ui.ink), height: 1.15)),
            const SizedBox(height: 4),
            Text(desc, style: kbText(16, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35)),
            if (!locked) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: KbProgress(value: done ? 1 : (count / total).clamp(.02, 1).toDouble(), ui: ui, height: 10)),
              const SizedBox(width: 10),
              if (done) KbDot('check', bg: ui.reward, ink: ui.rewardInk) else Text('$count / $total', style: kbText(16, kbC(ui.linkInk))),
            ]),
            ],
          ])),
        ]),
      );
}

/// Leaderboard row. Me: tile bg + accent ring; rank circle cardDeep/white. Others: surface; rank circle reward/rewardInk.
/// CSS `padding:14px 18px;border-radius:22px;gap:14px`; rank 36; avatar 46; name 21/800; level 15/600; xp 21/800.
class KbRankRow extends StatelessWidget {
  final KbUi ui;
  final int rank;
  final KbAvatarInfo? avatar;
  final String name, level, xp;
  final bool me;
  final Widget Function(double faceSize)? face; // APP ADAPTATION: the app's own avatar widget, as KbAvatar.face
  const KbRankRow({super.key, required this.ui, required this.rank, this.avatar, required this.name, required this.level, required this.xp, this.me = false, this.face}) : assert(avatar != null || face != null);
  @override
  Widget build(BuildContext context) {
    final ink = kbC(me ? ui.tileInk : ui.ink), soft = kbC(me ? ui.tileInk : ui.inkSoft);
    return KbSurface(
      color: me ? ui.tile : ui.surface, edge: me ? ui.accentEdge : ui.edge, outline: me ? ui.accent : null, elev: KbElev.card, radius: 22, padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(children: [
        Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: kbC(me ? ui.cardDeep : ui.reward), shape: BoxShape.circle),
            child: Text('$rank', style: kbText(18, kbC(me ? kWhite : ui.rewardInk), height: 1))),
        const SizedBox(width: 14),
        face != null ? SizedBox(width: 46, height: 46, child: Center(child: face!(46))) : Image.asset(avatar!.asset, width: 46, height: 46),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: kbText(21, ink, height: 1.1)),
          Text(level, style: kbText(15, soft, weight: FontWeight.w600)),
        ])),
        Text(xp, style: kbText(21, ink)),
      ]),
    );
  }
}

/// Settings-style card with title, description and a trailing widget (toggle).
/// CSS `padding:18px 20px;border-radius:24px;box-shadow:0 6px 0 edge, 0 14px 28px rgba(0,0,0,.2)`; title 20/800; desc 16/600 lh1.35.
class KbSettingCard extends StatelessWidget {
  final KbUi ui;
  final String title, desc;
  final Widget trailing;
  const KbSettingCard({super.key, required this.ui, required this.title, required this.desc, required this.trailing});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: ui.surface, edge: ui.edge, elev: KbElev.card, padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: kbText(20, kbC(ui.ink))),
            const SizedBox(height: 4),
            Text(desc, style: kbText(16, kbC(ui.inkSoft), weight: FontWeight.w600, height: 1.35)),
          ])),
          const SizedBox(width: 16),
          trailing,
        ]),
      );
}

// ───────────────────────── grid tiles ─────────────────────────

/// Badge. CSS `aspect-ratio:1/1.05;border-radius:20px;background:surface;outline:earned?4px reward;edge earned?rewardEdge:edge`; emoji 34 (grayscale + 40% when locked); label 15/800 centred.
class KbBadgeTile extends StatelessWidget {
  final KbUi ui;
  final String emoji, label;
  final bool earned;
  const KbBadgeTile({super.key, required this.ui, required this.emoji, required this.label, this.earned = false});
  // APP ADAPTATION: grey AND the 40% fade in one matrix — one offscreen pass per
  // locked badge instead of two (was Opacity(.4) around a grey ColorFiltered).
  static const _grey = ColorFilter.matrix([.2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, 0, 0, 0, .4, 0]);
  @override
  Widget build(BuildContext context) {
    Widget e = Text(emoji, style: const TextStyle(fontSize: 34, height: 1));
    if (!earned) e = ColorFiltered(colorFilter: _grey, child: e);
    return AspectRatio(
      aspectRatio: 1 / 1.05,
      child: KbSurface(
        color: ui.surface, edge: earned ? ui.rewardEdge : ui.edge, outline: earned ? ui.reward : null, elev: KbElev.tile, radius: 20, padding: const EdgeInsets.all(8),
        // APP ADAPTATION: a long name (a translation, a large text size) scales the
        // tile's content down to fit, wrapping at the tile's width, rather than overflowing.
        child: LayoutBuilder(builder: (context, c) => Center(child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: c.maxWidth, child: Column(mainAxisSize: MainAxisSize.min, children: [
          e, const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: kbText(15, kbC(earned ? ui.ink : ui.inkSoft), height: 1.15)),
        ]))))),
      ),
    );
  }
}

/// Stat tile. CSS `padding:16px 6px 12px;border-radius:20px`; value 25/800 ink lh1.1; label 15/600 inkSoft.
class KbStatTile extends StatelessWidget {
  final KbUi ui;
  final String value, label;
  const KbStatTile({super.key, required this.ui, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: ui.surface, edge: ui.edge, elev: KbElev.tile, radius: 20, padding: const EdgeInsets.fromLTRB(6, 16, 6, 12),
        child: Column(children: [Text(value, style: kbText(25, kbC(ui.ink), height: 1.1)), Text(label, style: kbText(15, kbC(ui.inkSoft), weight: FontWeight.w600))]),
      );
}

/// Selectable option (Appearance / Text size). Selected: tile bg, 3 px accent ring, accentEdge, tileInk. Else surface / inkSoft.
/// CSS `padding:14px 6px 10px;border-radius:20px`; icon 28; label 17/800.
class KbOptionTile extends StatelessWidget {
  final KbUi ui;
  final bool selected;
  final Widget top; // icon or big "A"
  final String label;
  final double? minHeight;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const KbOptionTile({super.key, required this.ui, required this.selected, required this.top, required this.label, this.minHeight, this.padding = const EdgeInsets.fromLTRB(6, 14, 6, 10), this.onTap});
  static Color inkOf(KbUi ui, bool sel) => kbC(sel ? ui.tileInk : ui.inkSoft);
  @override
  Widget build(BuildContext context) => KbSurface(
        color: selected ? ui.tile : ui.surface, edge: selected ? ui.accentEdge : ui.edge, outline: selected ? ui.accent : null, outlineWidth: 3,
        elev: KbElev.tile, radius: 20, padding: padding, onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight == null ? 0 : minHeight! - padding.vertical),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            top, const SizedBox(height: 2),
            Text(label, style: kbText(17, inkOf(ui, selected))),
          ]),
        ),
      );
}

enum KbCellState { idle, selected, mine, cpu, open, good, bad }

/// Game / answer cell with an Arabic glyph (bingo, three-in-a-row, memory, quiz).
/// idle: surface/edge/ink · selected (bingo): reward/rewardEdge/rewardInk · mine (ttt): cardDeep/white + reward star
/// cpu: cpuBg/cpuEdge · open: surface + 3px accent ring · good/bad: tinted bg + 3px line ring + dark edge.
class KbGlyphCell extends StatelessWidget {
  final KbUi ui;
  final String glyph;
  final KbCellState state;
  final double radius, fontSize;
  final KbElev elev;
  final String family;
  final FontWeight weight;
  final bool faceDown; // memory: shows 'help' icon, inkSoft
  final double? height; // null = square
  final VoidCallback? onTap;
  // APP ADAPTATION: any content (an SVG shape, a word with its meaning) in place
  // of [glyph], and cells whose size the caller sets (a grid's own aspect).
  final Widget? child;
  final bool square;
  const KbGlyphCell({super.key, required this.ui, this.glyph = '', this.state = KbCellState.idle, this.radius = 20, this.fontSize = 38, this.elev = KbElev.letter, this.family = kbFontArabic, this.weight = FontWeight.w600, this.faceDown = false, this.height, this.onTap, this.child, this.square = true});

  /// The ink a cell in [state] draws its content in — for a [child] that
  /// colours itself.
  static int inkOf(KbUi ui, KbCellState state) => switch (state) {
        KbCellState.selected => ui.rewardInk,
        KbCellState.mine => kWhite,
        _ => ui.ink,
      };

  @override
  Widget build(BuildContext context) {
    late int bg, edge, ink;
    int? ring;
    switch (state) {
      case KbCellState.idle:
        bg = ui.surface; edge = ui.edge; ink = faceDown ? ui.inkSoft : ui.ink;
      case KbCellState.selected:
        bg = ui.reward; edge = ui.rewardEdge; ink = ui.rewardInk;
      case KbCellState.mine:
        bg = ui.cardDeep; edge = ui.cardDeepEdge; ink = kWhite;
      case KbCellState.cpu:
        bg = ui.cpuBg; edge = ui.cpuEdge; ink = ui.ink;
      case KbCellState.open:
        bg = ui.surface; edge = ui.accentEdge; ink = ui.ink; ring = ui.accent;
      case KbCellState.good:
        bg = ui.goodBg; edge = KbUi.goodEdge; ink = ui.ink; ring = KbUi.goodLine;
      case KbCellState.bad:
        bg = ui.badBg; edge = KbUi.badEdge; ink = ui.ink; ring = KbUi.badLine;
    }
    final label = faceDown
        ? KbIcon('help', size: 36, color: kbC(ink))
        : child ?? Text(glyph, textDirection: family == kbFontUi ? TextDirection.ltr : TextDirection.rtl, style: kbText(fontSize, kbC(ink), family: family, weight: weight, height: 1.3));
    final content = Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      label,
      if (state == KbCellState.mine) Positioned(top: 8, right: 8, child: KbIcon('star', size: 22, color: kbC(ui.reward))),
    ]);
    final cell = KbSurface(
      color: bg, edge: edge, outline: ring, outlineWidth: 3, elev: elev, radius: radius, height: height,
      // APP ADAPTATION: a free-sized cell centres its content in whatever size it
      // is given, but in a Wrap (loose constraints) sizes to it rather than
      // taking the whole row.
      alignment: square || height != null ? Alignment.center : null,
      onTap: onTap,
      child: square || height != null ? content : Align(widthFactor: 1, heightFactor: 1, child: content),
    );
    return height == null && square ? AspectRatio(aspectRatio: 1, child: cell) : cell;
  }
}

/// Toggle chip (gender). On: cardDeep/white + check icon 22. CSS `padding:10px 22px 8px;border-radius:18px;font-size:20px;font-weight:800`.
class KbChoiceChip extends StatelessWidget {
  final KbUi ui;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const KbChoiceChip(this.label, {super.key, required this.ui, required this.selected, this.onTap});
  @override
  Widget build(BuildContext context) {
    final ink = kbC(selected ? kWhite : ui.ink);
    return KbSurface(
      color: selected ? ui.cardDeep : ui.surface, edge: selected ? ui.cardDeepEdge : ui.edge, elev: KbElev.option, radius: 18, padding: const EdgeInsets.fromLTRB(22, 10, 22, 8), onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (selected) ...[KbIcon('check', size: 22, color: ink), const SizedBox(width: 6)],
        // APP ADAPTATION: a long label (a translation, a large text size) wraps.
        Flexible(child: Text(label, style: kbText(20, ink))),
      ]),
    );
  }
}

/// Text field. CSS `height:62px;padding:0 20px;border-radius:22px;background:surface;box-shadow:0 5px 0 edge, 0 12px 24px rgba(0,0,0,.18)`; text 20/700 ink.
class KbTextField extends StatelessWidget {
  final KbUi ui;
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted; // APP ADAPTATION: a field in a dialog
  final bool autofocus;
  const KbTextField({super.key, required this.ui, this.controller, required this.hint, this.onChanged, this.onSubmitted, this.autofocus = false});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: ui.surface, edge: ui.edge, elev: KbElev.field, radius: 22, height: 62, padding: const EdgeInsets.symmetric(horizontal: 20), alignment: Alignment.centerLeft,
        child: TextField(
          controller: controller, onChanged: onChanged, onSubmitted: onSubmitted, autofocus: autofocus,
          style: kbText(20, kbC(ui.ink), weight: FontWeight.w700),
          cursorColor: kbC(ui.accent),
          decoration: InputDecoration.collapsed(hintText: hint, hintStyle: kbText(20, kbC(ui.inkSoft), weight: FontWeight.w700)),
        ),
      );
}

// ───────────────────────── home lesson path ─────────────────────────

// APP ADAPTATION: `open` — reachable without being cleared (the app's testing
// unlock): the plain face with the letter, and no badge.
enum KbNodeState { done, current, locked, open }

/// One circle on the Home path. Current: 84 px, `0 0 0 5px accent, 0 11px 0 accentEdge` + "Start" tag above.
/// Others: 68 px, `0 6px 0 (done?rewardEdge:edge)`, badge 24 (check on th.deep / lock on lockBg) with 3 px surface ring at right:-4 bottom:-2.
/// All: `0 12px 22px rgba(0,0,0,.25)`. Face: done=reward, else surface. Letter Noto Naskh 600, 36/30.
class KbPathNode extends StatelessWidget {
  final KbUi ui;
  final String letter;
  final KbNodeState state;
  final VoidCallback? onTap;
  // APP ADAPTATION: a path item without a letter (a quiz, a reading) shows this
  // symbol instead; the tag above the current node is localized.
  final String? icon;
  final String startLabel;
  const KbPathNode({super.key, required this.ui, required this.letter, required this.state, this.onTap, this.icon, this.startLabel = 'Start'});
  @override
  Widget build(BuildContext context) {
    final cur = state == KbNodeState.current, done = state == KbNodeState.done;
    final size = cur ? 84.0 : 68.0;
    final face = done ? ui.reward : ui.surface;
    final ink = done ? ui.rewardInk : cur || state == KbNodeState.open ? ui.ink : ui.inkSoft;
    final soft = BoxShadow(color: kbC(kBlack, .25), offset: const Offset(0, 12), blurRadius: kbCssBlur(22));
    final shadows = cur
        ? [soft, BoxShadow(color: kbC(ui.accentEdge), offset: const Offset(0, 11)), BoxShadow(color: kbC(ui.accent), spreadRadius: 5)]
        : [soft, BoxShadow(color: kbC(done ? ui.rewardEdge : ui.edge), offset: const Offset(0, 6))];
    return Semantics(button: onTap != null, child: GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (cur) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 1, 12, 0),
            decoration: BoxDecoration(color: kbC(ui.cardDeep), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: kbC(ui.cardDeepEdge), offset: const Offset(0, 3))]),
            child: Text(startLabel, style: kbText(15, kbC(kWhite))),
          ),
          const SizedBox(height: 6),
        ],
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: size, height: size, alignment: Alignment.center,
            decoration: BoxDecoration(color: kbC(face), shape: BoxShape.circle, boxShadow: shadows),
            child: letter.isEmpty && icon != null
                ? KbIcon(icon!, size: cur ? 36 : 30, color: kbC(ink))
                : Padding(
                    // A multi-letter item (a joined form, a word) shrinks to fit the circle.
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(letter, textDirection: TextDirection.rtl, style: kbText(cur ? 36 : 30, kbC(ink), family: kbFontArabic, weight: FontWeight.w600, height: 1))),
                  ),
          ),
          if (!cur && state != KbNodeState.open)
            Positioned(right: -4, bottom: -2, child: KbDot(done ? 'check' : 'lock', bg: done ? ui.th.deep : ui.lockBg, ink: kWhite, size: 24, iconSize: 14, ring: ui.surface)),
        ]),
      ]),
    ));
  }
}

/// Zig-zag path: nodes alternate left/right inside 34 px side padding, gap 6, with a 5 px dashed
/// vertical line (pathLine colour) behind them from 30 px below the top to 30 px above the bottom.
class KbLessonPath extends StatelessWidget {
  final KbUi ui;
  final List<(String letter, KbNodeState state)> nodes;
  const KbLessonPath({super.key, required this.ui, required this.nodes});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Stack(children: [
          Positioned(top: 30, bottom: 30, left: 0, right: 0, child: Center(child: CustomPaint(size: const Size(5, double.infinity), painter: _DashPainter(ui.pathLine)))),
          Column(children: [
            for (var i = 0; i < nodes.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Align(alignment: i.isOdd ? Alignment.centerRight : Alignment.centerLeft, child: KbPathNode(ui: ui, letter: nodes[i].$1, state: nodes[i].$2)),
            ],
          ]),
        ]),
      );
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color..strokeWidth = 5;
    for (double y = 0; y < s.height; y += 25) {
      c.drawLine(Offset(s.width / 2, y), Offset(s.width / 2, (y + 15).clamp(0, s.height)), p);
    }
  }
  @override
  bool shouldRepaint(_DashPainter o) => o.color != color;
}

// ───────────────────────── shop "Looks" rows ─────────────────────────

/// CSS `padding:14px 16px;border-radius:22px;gap:14px`; avatar 50; name 22/800.
/// Owned: check dot (cardDeep) + outlined pill "Use original" (16/700, padding 8 16 6).
/// For sale: diamond + price (18/700 inkSoft, icon linkInk) under the name + deep pill "Get" (18/800, padding 9 30 7).
class KbLooksRow extends StatelessWidget {
  final KbUi ui;
  final KbAvatarInfo avatar;
  final bool owned;
  final VoidCallback? onAction;
  const KbLooksRow({super.key, required this.ui, required this.avatar, required this.owned, this.onAction});
  @override
  Widget build(BuildContext context) => KbSurface(
        color: ui.surface, edge: ui.edge, elev: KbElev.card, radius: 22, padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Image.asset(avatar.asset, width: 50, height: 50),
          const SizedBox(width: 14),
          Expanded(
            child: owned
                ? Text(avatar.name, style: kbText(22, kbC(ui.ink)))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(avatar.name, style: kbText(22, kbC(ui.ink), height: 1.1)),
                    Row(children: [KbIcon('diamond', size: 18, color: kbC(ui.linkInk)), const SizedBox(width: 4), Text('${avatar.price}', style: kbText(18, kbC(ui.inkSoft), weight: FontWeight.w700))]),
                  ]),
          ),
          if (owned) ...[
            KbDot('check', bg: ui.cardDeep, ink: kWhite),
            const SizedBox(width: 14),
            KbPill('Use original', ui: ui, kind: KbPillKind.outlined, fontSize: 16, padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), onTap: onAction),
          ] else
            KbPill('Get', ui: ui, kind: KbPillKind.deep, padding: const EdgeInsets.fromLTRB(30, 9, 30, 7), onTap: onAction),
        ]),
      );
}

// ───────────────────────── navigation ─────────────────────────

class KbNavItem {
  final String id, icon, label;
  const KbNavItem(this.id, this.icon, this.label);
}

const kbNavItems = [KbNavItem('home', 'home', 'Home'), KbNavItem('learn', 'menu_book', 'Learn'), KbNavItem('rank', 'emoji_events', 'Rank'), KbNavItem('rewards', 'redeem', 'Rewards'), KbNavItem('me', 'face', 'Me')];

/// Bottom bar. CSS `padding:10px 10px 24px;border-radius:28px 28px 0 0;background:surface;box-shadow:0 -8px 24px rgba(0,0,0,.18)`.
/// Item 68 wide: pill 52×32 r16 (active: tile bg + tileInk; else transparent + inkSoft), icon 24; label 14/700.
/// Bottom padding 24 replaces the home-indicator inset — use max(24, safeBottom).
class KbNavBar extends StatelessWidget {
  final KbUi ui;
  final String current;
  final ValueChanged<String> onSelect;
  final List<KbNavItem> items; // APP ADAPTATION: localized labels
  const KbNavBar({super.key, required this.ui, required this.current, required this.onSelect, this.items = kbNavItems});
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 10, 10, bottom > 24 ? bottom : 24),
      decoration: BoxDecoration(color: kbC(ui.surface), borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: kbC(kBlack, .18), offset: const Offset(0, -8), blurRadius: kbCssBlur(24))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        for (final it in items)
          // APP ADAPTATION: 68 wide as designed, narrower only when five of them do
          // not fit (a 320px phone); a long label scales down rather than wrapping.
          Flexible(child: Semantics(button: true, selected: it.id == current, child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(it.id),
            child: SizedBox(
              width: 68,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 52, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: it.id == current ? kbC(ui.tile) : null, borderRadius: BorderRadius.circular(16)),
                    child: KbIcon(it.icon, size: 24, color: kbC(it.id == current ? ui.tileInk : ui.inkSoft))),
                const SizedBox(height: 2),
                FittedBox(fit: BoxFit.scaleDown, child: Text(it.label, maxLines: 1, style: kbText(14, kbC(it.id == current ? ui.tileInk : ui.inkSoft), weight: FontWeight.w700))),
              ]),
            ),
          ))),
      ]),
    );
  }
}
