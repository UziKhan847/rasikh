// Drop-in widgets. Sizes/radii/shadows copied from the HTML template.

import 'package:flutter/material.dart';
import 'kb_scene.dart';
import 'kb_themes.dart';
import 'kb_ui.dart';

/// Full-screen backdrop: static scene + animated motes. Put page content in [child].
/// The top ~30% of the sky is kept clear for headings by design; don't overlay cards there.
class KbBackdrop extends StatefulWidget {
  final KbTheme theme;
  final KbMode mode;
  final KbStyle style;
  final bool motion;
  final Widget? child;
  const KbBackdrop({super.key, required this.theme, required this.mode, this.style = KbStyle.vivid, this.motion = true, this.child});
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
    return Stack(fit: StackFit.expand, children: [
      RepaintBoundary(child: CustomPaint(painter: KbScenePainter(widget.theme, widget.mode, widget.style))),
      if (!reduce) RepaintBoundary(child: CustomPaint(painter: KbMotesPainter(widget.theme, widget.mode, widget.style, _t))),
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
      child: AspectRatio(aspectRatio: 1, child: RepaintBoundary(child: CustomPaint(painter: KbScenePainter(theme, mode, style)))),
    );
    return size == null ? icon : SizedBox.square(dimension: size, child: icon);
  }
}

const _fontUi = 'Baloo Bhaijaan 2';
const _fontIcon = 'Material Symbols Rounded';

Widget _symbol(String name, double size, Color color) =>
    Text(name, style: TextStyle(fontFamily: _fontIcon, fontSize: size, color: color, height: 1, fontVariations: const [FontVariation('FILL', 1), FontVariation('wght', 600)]));

/// Rewards → Shop → Themes tile. States: locked (price), owned ("Use"), inUse ("In use").
class KbThemeShopTile extends StatelessWidget {
  final KbTheme theme;
  final KbUi ui; // tokens of the CURRENT app theme (not the tile's theme)
  final bool owned, inUse;
  final VoidCallback onTap;
  const KbThemeShopTile({super.key, required this.theme, required this.ui, required this.owned, required this.inUse, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final locked = theme.price > 0 && !owned;
    final icon = locked ? 'diamond' : inUse ? 'check_circle' : 'palette';
    final iconInk = kbC(locked ? ui.linkInk : inUse ? ui.accent : ui.inkSoft);
    final tag = locked ? '${theme.price}' : inUse ? 'In use' : 'Use';
    return GestureDetector(
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
          Text(theme.name, style: TextStyle(fontFamily: _fontUi, fontSize: 17, fontWeight: FontWeight.w800, height: 1.1, color: kbC(ui.ink))),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _symbol(icon, 15, iconInk),
            const SizedBox(width: 3),
            Text(tag, style: TextStyle(fontFamily: _fontUi, fontSize: 15, fontWeight: FontWeight.w700, height: 1, color: kbC(ui.inkSoft))),
          ]),
        ]),
      ),
    );
  }
}

/// Circular avatar (PNG 1x/2x/3x from assets/avatars). Do not load the SVGs with flutter_svg: it drops the blur-filter shadows.
class KbAvatar extends StatelessWidget {
  final KbAvatarInfo avatar;
  final double size;
  final Color? background;
  const KbAvatar({super.key, required this.avatar, this.size = 56, this.background});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Image.asset(avatar.asset, width: size * .82, height: size * .82, semanticLabel: avatar.name),
      );
}

/// New Profile picker cell (6-column grid, gap 10 x 8).
class KbAvatarPickerTile extends StatelessWidget {
  final KbAvatarInfo avatar;
  final KbUi ui;
  final bool selected, locked;
  final VoidCallback onTap;
  const KbAvatarPickerTile({super.key, required this.avatar, required this.ui, required this.selected, required this.locked, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
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
                child: KbAvatar(avatar: avatar, size: d),
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
      );
}

/// Page title over the sky. White fill + deep outline (vivid), or banner variant.
class KbHeading extends StatelessWidget {
  final String text;
  final KbUi ui;
  final double fontSize;
  const KbHeading(this.text, {super.key, required this.ui, this.fontSize = 30}); // 30 page titles, 25 home sections, 23 rewards, 21 settings, 32 games
  @override
  Widget build(BuildContext context) {
    final t = Text(text, style: TextStyle(fontFamily: _fontUi, fontSize: fontSize, fontWeight: FontWeight.w800, height: 1.05, color: kbC(ui.headInk), shadows: ui.headShadows));
    if (!ui.banner) return t;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 0),
      decoration: BoxDecoration(color: kbC(ui.outlineC), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: kbC(kbMix(ui.outlineC, kBlack, .45)), offset: const Offset(0, 4))]),
      child: t,
    );
  }
}
