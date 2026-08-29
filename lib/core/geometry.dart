import 'package:flutter/material.dart';

import 'theme.dart';

/// Shared corner-radius / spacing tokens. Introduced alongside Kids Mode so
/// its screens (built from scratch) draw from one small vocabulary instead of
/// hand-picked literals scattered per-widget. Existing adult screens keep
/// their own inline values for now — see the Kids Mode plan's Phase 0:
/// migrate to these opportunistically as screens are touched anyway, not in
/// one big-bang pass.
class Geo {
  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 20.0;
  static const radiusXl = 26.0;
  static const radiusPill = 999.0;

  static const gapXs = 6.0;
  static const gapSm = 10.0;
  static const gapMd = 14.0;
  static const gapLg = 20.0;
  static const gapXl = 28.0;
}

/// The fill for a "not unlocked yet" surface — a locked letter tile or trail
/// node. `surfaceHigh` alone is too close to the kids background to read as a
/// distinct shape, so this nudges it toward the dim text colour: darker on
/// the light palette, lighter on dark/OLED, contrasting on all three.
Color kidsLockedFill(Palette p) =>
    Color.alphaBlend(p.textDim.withValues(alpha: .14), p.surfaceHigh);

/// The card look every Kids Mode surface shares: rounded, palette surface,
/// soft shadow. Mirrors the desktop-only `deskCard`/`deskBorder` decorations
/// in `screens/desktop/desktop_pages.dart` — kept separate rather than
/// reused, since those two bake in the grown-up `pal(context)` and would
/// paint kids surfaces in the wrong palette (see `kidsTheme`/`kidsPal`).
BoxDecoration kidsCard(BuildContext context, {double radius = Geo.radiusLg}) {
  final p = kidsPal(context);
  return BoxDecoration(
    color: p.surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: p.shadow, blurRadius: 14, offset: const Offset(0, 6)),
    ],
  );
}

/// The desktop design's dominant card look — surface + a thin border, no
/// shadow — as opposed to [kidsCard]'s shadow-only mobile look. Both exist
/// because both designs exist; use whichever the screen you're building was
/// actually drawn with.
BoxDecoration kidsPanel(BuildContext context, {double radius = Geo.radiusLg}) {
  final p = kidsPal(context);
  return BoxDecoration(
    color: p.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: p.surfaceHigh, width: 1.5),
  );
}

/// A soft/border/text triad tinted off one accent colour — Kids Mode's
/// answer to the design's `tintGold*`/`tintTeal*`/`tintCoral*` token families
/// (9 colours across `t.tintGoldBg/Border/Text` etc.), computed from the
/// existing palette instead of adding 15 new `Palette` fields. Pass
/// `p.amber`/`p.accent2`/`p.accent` for the gold/teal/coral equivalents.
class KidsTint {
  final Color bg;
  final Color border;
  final Color text;
  const KidsTint({required this.bg, required this.border, required this.text});
}

KidsTint kidsTint(BuildContext context, Color base) {
  final p = kidsPal(context);
  final dark = p.brightness == Brightness.dark;
  return KidsTint(
    bg: base.withValues(alpha: dark ? .18 : .14),
    border: base.withValues(alpha: dark ? .32 : .30),
    text: dark ? base : Color.alphaBlend(Colors.black.withValues(alpha: .22), base),
  );
}
