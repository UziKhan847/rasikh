// Drop-in widgets. Sizes/radii/shadows copied from the HTML template.

import 'package:flutter/material.dart';
import 'kb_components.dart' show KbIcon, kbFontQuran, kbFontUi, kbText;
import 'kb_hifi.dart' show kbPaintSceneStill;
import 'kb_raster.dart';
import 'kb_scene.dart';
import 'kb_themes.dart';
import 'kb_ui.dart';

// APP ADAPTATION: the app's own faces catch letters the design's do not (Urdu's
// ٹ ڈ ڑ ں ے) — the same chain as kbText.
const _fallback = ['Baloo2', 'Outfit', 'ScheherazadeNew'];

/// Full-screen backdrop: static scene + animated motes. Put page content in [child].
/// The top ~30% of the sky is kept clear for headings by design; don't overlay cards there.
class KbBackdrop extends StatefulWidget {
  final KbTheme theme;
  final KbMode mode;
  final KbStyle style;
  final bool motion;
  final Widget? child;
  // APP ADAPTATION: the tab backdrop's bloom and saturation, so a lesson looks like
  // its tab. Baked into the scene image (no per-frame cost); vivid only.
  final double bloom, saturation;
  // APP ADAPTATION: on Ultra a lesson's scene also gets Ultra's still touches
  // (rim light, standing mist, vignette — see kbPaintSceneStill), baked into the
  // same image; nothing that moves.
  final bool ultraStill;
  const KbBackdrop({super.key, required this.theme, required this.mode, this.style = KbStyle.vivid, this.motion = true, this.bloom = 0, this.saturation = 1, this.ultraStill = false, this.child});
  @override
  State<KbBackdrop> createState() => _KbBackdropState();
}

class _KbBackdropState extends State<KbBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(KbBackdrop old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (!widget.motion) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // APP ADAPTATION: the scene keeps the height it has without the keyboard (see
    // KbParallaxBackdrop) — otherwise it is re-drawn every frame the keyboard slides.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final vivid = widget.style == KbStyle.vivid;
    final bloom = vivid ? widget.bloom : 0.0, sat = vivid ? widget.saturation : 1.0;
    return Stack(fit: StackFit.expand, children: [
      // APP ADAPTATION: the static scene as an image drawn once (kb_raster.dart) — its
      // blurs are then never re-run per frame while the motes move over it.
      LayoutBuilder(builder: (context, c) {
        final h = inset > 0 && c.maxHeight + inset <= screenH + .5 ? c.maxHeight + inset : c.maxHeight;
        return OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: h,
          minHeight: h,
          child: RepaintBoundary(
            child: KbRaster(
              size: Size(c.maxWidth, h),
              cacheKey: (widget.theme.id, widget.mode, widget.style, bloom, widget.ultraStill),
              colorFilter: sat == 1 ? null : ColorFilter.matrix(kbSaturation(sat)),
              paint: (c, size) {
                final p = widget.ultraStill
                    ? kbPaintSceneStill(c, size, widget.theme, widget.mode, widget.style)
                    : kbPaintScene(c, size, widget.theme, widget.mode, widget.style);
                // Bloom screens over the finished scene, as on the tabs.
                if (bloom > 0 && kbHasBloom(widget.theme, p)) {
                  kbPaintBloom(c, size, widget.theme, size.width, size.height, bloom);
                }
              },
            ),
          ),
        );
      }),
      if (!reduce) RepaintBoundary(child: CustomPaint(painter: KbMotesPainter(widget.theme, widget.mode, widget.style, _t, saturation: sat))),
      if (widget.child != null) widget.child!,
    ]);
  }
}

/// Square theme preview (shop tile, theme picker). Same painter at 1:1, no motes.
class KbThemeIcon extends StatelessWidget {
  final KbTheme theme;
  final KbMode mode;
  final KbStyle style;
  final double? size;
  final double radius; // 14 inside shop tiles; use size*.22 standalone
  const KbThemeIcon({super.key, required this.theme, required this.mode, this.style = KbStyle.vivid, this.size, this.radius = 14});
  @override
  Widget build(BuildContext context) {
    final icon = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      // APP ADAPTATION: drawn once into an image (kb_raster.dart), like the backdrop.
      child: AspectRatio(
        aspectRatio: 1,
        child: RepaintBoundary(child: KbRaster(cacheKey: (theme.id, mode, style), paint: (c, size) => kbPaintScene(c, size, theme, mode, style))),
      ),
    );
    return size == null ? icon : SizedBox.square(dimension: size, child: icon);
  }
}

const _fontUi = kbFontUi;

// APP ADAPTATION: icons go through KbIcon (codepoints in the bundled subset font).
Widget _symbol(String name, double size, Color color) => KbIcon(name, size: size, color: color);

/// Rewards → Shop → Themes tile. States: locked (price), owned ("Use"), inUse ("In use").
class KbThemeShopTile extends StatelessWidget {
  final KbTheme theme;
  final KbUi ui; // tokens of the CURRENT app theme (not the tile's theme)
  final bool owned, inUse;
  final VoidCallback onTap;
  // APP ADAPTATION: the app's own (localized) name and labels and its own price.
  // Null keeps the prototype's English and `theme.price`.
  final String? name, useLabel, inUseLabel;
  final int? price;
  const KbThemeShopTile({super.key, required this.theme, required this.ui, required this.owned, required this.inUse, required this.onTap, this.name, this.useLabel, this.inUseLabel, this.price});
  @override
  Widget build(BuildContext context) {
    final cost = price ?? theme.price;
    final locked = cost > 0 && !owned;
    final icon = locked ? 'diamond' : inUse ? 'check_circle' : 'palette';
    final iconInk = kbC(locked ? ui.linkInk : inUse ? ui.accent : ui.inkSoft);
    final tag = locked ? '$cost' : inUse ? (inUseLabel ?? 'In use') : (useLabel ?? 'Use');
    return Semantics(button: true, selected: inUse, child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: kbC(ui.surface),
          borderRadius: BorderRadius.circular(20),
          border: inUse ? Border.all(color: kbC(ui.accent), width: 4, strokeAlign: BorderSide.strokeAlignOutside) : null,
          boxShadow: kbCardShadow(kbC(inUse ? ui.accentEdge : ui.edge)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            KbThemeIcon(theme: theme, mode: ui.mode, style: ui.style),
            if (locked)
              Positioned(
                right: 5, top: 5,
                child: Container(
                  width: 24, height: 24, alignment: Alignment.center,
                  decoration: BoxDecoration(color: kbC(kBlack, .55), shape: BoxShape.circle),
                  child: _symbol('lock', 15, kbC(kWhite)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(name ?? theme.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontUi, fontFamilyFallback: _fallback, fontSize: 17, fontWeight: FontWeight.w800, height: 1.1, color: kbC(ui.ink))),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _symbol(icon, 15, iconInk),
            const SizedBox(width: 3),
            Flexible(child: Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: _fontUi, fontFamilyFallback: _fallback, fontSize: 15, fontWeight: FontWeight.w700, height: 1, color: kbC(ui.inkSoft)))),
          ]),
        ]),
      ),
    ));
  }
}

/// Circular avatar. Uses the app's existing avatar SVGs. If the app already has an avatar widget,
/// swap it in here; only the circle, background and 82% inset belong to the redesign.
class KbAvatar extends StatelessWidget {
  final KbAvatarInfo? avatar;
  final double size;
  final Color? background;
  // APP ADAPTATION: the app's own avatar widget, built at the given face size
  // (82% of the circle). Used instead of loading `avatar.asset`.
  final Widget Function(double faceSize)? face;
  const KbAvatar({super.key, this.avatar, this.size = 56, this.background, this.face}) : assert(avatar != null || face != null);
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: face != null ? face!(size * .82) : Image.asset(avatar!.asset, width: size * .82, height: size * .82, semanticLabel: avatar!.name),
      );
}

/// New Profile picker cell (6-column grid, gap 10 x 8).
class KbAvatarPickerTile extends StatelessWidget {
  final KbAvatarInfo? avatar;
  final KbUi ui;
  final bool selected, locked;
  final VoidCallback onTap;
  final Widget Function(double faceSize)? face; // APP ADAPTATION: see KbAvatar.face
  const KbAvatarPickerTile({super.key, this.avatar, required this.ui, required this.selected, required this.locked, required this.onTap, this.face});
  @override
  Widget build(BuildContext context) => Semantics(button: true, selected: selected, child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (context, c) {
            final d = c.maxWidth;
            return Stack(clipBehavior: Clip.none, children: [
              Container(
                decoration: BoxDecoration(
                  color: kbC(selected ? ui.tile : ui.surface),
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: kbC(ui.accent), width: 4, strokeAlign: BorderSide.strokeAlignOutside) : null,
                  boxShadow: kbCardShadow(kbC(selected ? ui.accentEdge : ui.edge), edgeY: 4, blur: 14),
                ),
                child: KbAvatar(avatar: avatar, face: face, size: d),
              ),
              if (locked)
                Positioned(
                  right: -3, bottom: -3,
                  child: Container(
                    width: 20, height: 20, alignment: Alignment.center,
                    decoration: BoxDecoration(color: kbC(ui.lockBg), shape: BoxShape.circle, border: Border.all(color: kbC(ui.surface), width: 2.5)),
                    child: _symbol('lock', 12, kbC(kWhite)),
                  ),
                ),
            ]);
          }),
        ),
      ));
}

/// Page title over the sky. White fill + deep outline (vivid), or banner variant.
class KbHeading extends StatelessWidget {
  final String text;
  final KbUi ui;
  final double fontSize;
  final double height; // Step-6 fix: CSS gives every heading line-height 1.1 (the kit had 1.05); the Write title is 1.2
  final TextAlign? align; // APP ADAPTATION: centred game titles and lesson prompts that wrap
  const KbHeading(this.text, {super.key, required this.ui, this.fontSize = 30, this.height = 1.1, this.align}); // 30 page titles, 25 home sections, 23 rewards, 21 settings, 32 games
  @override
  Widget build(BuildContext context) {
    final t = Text(text, textAlign: align, style: TextStyle(fontFamily: _fontUi, fontFamilyFallback: _fallback, fontSize: fontSize, fontWeight: FontWeight.w800, height: height, color: kbC(ui.headInk), shadows: ui.headShadows));
    if (!ui.banner) return t;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 0),
      decoration: BoxDecoration(color: kbC(ui.outlineC), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: kbC(kbMix(ui.outlineC, kBlack, .45)), offset: const Offset(0, 4))]),
      child: t,
    );
  }
}

/// The Arabic name beside a page title ("Your Path · مَسارُك"). CSS `font:400 26px
/// Amiri Quran;line-height:1.6;color:headInk;text-shadow:subShadow`.
/// APP ADAPTATION: the design draws it inline on the Learn screen; named here so
/// the app can reuse it and a test can tell it is a heading.
class KbArabicTitle extends StatelessWidget {
  final String text;
  final KbUi ui;
  final double fontSize;
  const KbArabicTitle(this.text, {super.key, required this.ui, this.fontSize = 26});
  @override
  Widget build(BuildContext context) => Text(text, textDirection: TextDirection.rtl, style: kbText(fontSize, kbC(ui.headInk), family: kbFontQuran, weight: FontWeight.w400, height: 1.6, shadows: ui.subShadows));
}
