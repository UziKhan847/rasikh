import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';
import 'kit.dart';

/// The app's calligraphy (the launcher icon's) on its green tile, tinted
/// [glyph]. It's taller than wide: [inset] is its margin top and bottom.
class AppLogoTile extends StatelessWidget {
  final double size;
  final double radius;
  final Color glyph;
  final Color? background;
  final double inset;
  const AppLogoTile({
    super.key,
    this.size = 34,
    this.radius = 9,
    this.glyph = kHeroInk,
    this.background,
    this.inset = 6,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(inset),
        decoration: BoxDecoration(
          color: background ?? pal(context).hero,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: SvgPicture.asset('assets/brand/rasikh_icon.svg',
            colorFilter: ColorFilter.mode(glyph, BlendMode.srcIn)),
      );
}
