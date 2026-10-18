import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'kit.dart';

/// The app glyph (icon 1a) on its emerald tile: the PNG is used as an alpha
/// mask, tinted [glyph].
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
        child: Image.asset('assets/brand/icon-glyph.png',
            color: glyph, colorBlendMode: BlendMode.srcIn),
      );
}

/// The wordmark: "Qiraah" in Source Serif 4 with "ARABIYYAH" beneath it.
class AppWordmark extends StatelessWidget {
  final double size;
  const AppWordmark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Qiraah',
            style: TextStyle(
                fontFamily: 'SourceSerif4',
                                fontSize: size,
                height: 1,
                color: p.ink)),
        const SizedBox(height: 3),
        Text('ARABIYYAH',
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: size * .46,
                fontWeight: FontWeight.w700,
                letterSpacing: size * .055,
                color: p.ink3)),
      ],
    );
  }
}
