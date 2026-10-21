import 'package:flutter/material.dart';

import '../qiraah_ornaments.dart' show SurahHeader;
import 'art.dart';
import 'tuning.dart';

/// Where each header's parts are, as fractions of its artwork: the name
/// (its cartouche's inside), the side cartouches (the Indo-Pak headers'
/// āyah and rukūʿ counts), and what a white-filled paper fills behind.
const _madaniTitle = Rect.fromLTRB(.29, .2, .71, .8);
const _madaniFill = Rect.fromLTWH(.07, .19, .86, .62);
const _indopakTitle = Rect.fromLTRB(.3, .24, .7, .86);
const _indopakSides = (
  Rect.fromLTRB(.06, .3, .19, .8),
  Rect.fromLTRB(.81, .3, .94, .8),
);
const _indopakFill = Rect.fromLTRB(.26, .18, .74, .94);
const _twoTierTitle = Rect.fromLTRB(.3, .12, .7, .48);
const _twoTierSides = (
  Rect.fromLTRB(.055, .15, .19, .45),
  Rect.fromLTRB(.81, .15, .945, .45),
);
const _twoTierFill = [
  Rect.fromLTRB(.26, .1, .74, .53),
  Rect.fromLTRB(.12, .57, .88, .98),
];

/// The two-tier artwork's top tier (its share of the height), and the lower
/// band's two lines, which the basmala's letters overlapped in the drawing
/// and are drawn whole again ([_bandLines], fractions of the art).
const _topTier = .552;
const _bandLines = [
  Rect.fromLTRB(.21, .5608, .79, .5725),
  Rect.fromLTRB(.21, .9808, .79, .9933),
];

/// The Madani headers' middle — only the cartouche's straight lines —
/// stretches; the Indo-Pak ones repeat two of their beads (each 1.16% of
/// the width) from the centre.
const _madaniStretch = (.30, .70);
const _bead = .011595;
const _indopakRepeat = (.5 - _bead, 2 * _bead);

/// The coloured header's own colours, and each tiled palette's for them
/// (its greens, its dark green, its brown).
const _green = Color(0xFF587831),
    _darkGreen = Color(0xFF2E612C),
    _brown = Color(0xFFAE6635);
final _tilePalettes = <Map<Color, Color>>[
  {_green: Color(0xFF1BA6C4), _darkGreen: Color(0xFF13788F), _brown: Color(0xFFC0281E)},
  {_green: Color(0xFF4FA56C), _darkGreen: Color(0xFF2F7A49), _brown: Color(0xFFB5533F)},
  {_green: Color(0xFF5AAFC2), _darkGreen: Color(0xFF3A8597), _brown: Color(0xFFA04A44)},
];

/// A sūrah header line in the muṣḥaf, as [kind] draws it, widened to the
/// line's width without distorting it:
/// - 'madani' (line art in [frame]), 'madaniColoured' (its own colours)
///   and 'tile1'…'tile3' (the coloured one in each tiled palette): the
///   straight middle of the cartouche stretches;
/// - 'indopak' (its one-tier form): the beaded middle repeats, the name in
///   the middle cartouche and [sides] (the āyah and rukūʿ counts) in the
///   side ones;
/// - 'plain' and 'rosette' (focus mode, Lite): the drawn band.
///
/// [title] is the name (sized to fit); [fill], on white-filled papers,
/// fills the cartouche. [mono] draws coloured artwork in black and white
/// (inverted when [dark]).
class MushafSurahHeader extends StatelessWidget {
  final String kind;
  final double lineHeight;
  final Widget title;
  final (Widget, Widget)? sides;
  final TextStyle? plainStyle;
  final String plainTitle;
  final Color frame, paper, soft, ink;
  final Color? fill;
  final bool mono, dark;
  final OrnamentTuning tune;
  const MushafSurahHeader({
    super.key,
    required this.kind,
    required this.lineHeight,
    required this.title,
    this.sides,
    required this.plainTitle,
    this.plainStyle,
    required this.frame,
    required this.paper,
    required this.soft,
    required this.ink,
    this.fill,
    this.mono = false,
    this.dark = false,
    this.tune = OrnamentTuning.defaults,
  });

  @override
  Widget build(BuildContext context) {
    if (kind == 'plain' || kind == 'rosette') {
      return SurahHeader(
        title: plainTitle,
        ornate: kind == 'rosette',
        lineHeight: lineHeight,
        frame: frame,
        paper: paper,
        soft: soft,
        accent: ink,
        textStyle: plainStyle ?? const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 22),
      );
    }
    final indopak = kind == 'indopak';
    final tile = kind.startsWith('tile')
        ? (int.tryParse(kind.substring(4)) ?? 1).clamp(1, 3)
        : 0;
    final coloured = tile > 0 || kind == 'madaniColoured';
    final art = indopak
        ? ClassicArt.indopakSurahHeader
        : coloured
        ? ClassicArt.surahBorderColoured
        : ClassicArt.surahBorder;
    final palette = tile > 0 ? _tilePalettes[tile - 1] : const <Color, Color>{};
    final filter = coloured && mono ? monoFilter(dark: dark) : null;
    final nameScale = tune['headerNameScale'];
    return SizedBox(
      height: lineHeight,
      child: OrnamentArtBox(
        look: (kind, frame, fill, mono, dark, tune),
        layout: (box) => WideArt.layout(
          art,
          box: (Offset.zero & box).translate(0, tune['headerDy'] * box.height),
          height: box.height * .96 * tune['headerScale'],
          stretch: indopak ? null : _madaniStretch,
          repeat: indopak ? _indopakRepeat : null,
        ),
        paintArt: (canvas, wide) {
          if (fill != null) {
            final p = Paint()..color = fill!;
            canvas.drawRect(
              wide.map(indopak ? _indopakFill : _madaniFill),
              p,
            );
          }
          if (filter != null) {
            canvas.saveLayer(null, Paint()..colorFilter = filter);
          }
          wide.paint(
            canvas,
            art,
            (c, whole) => art.paint(
              c,
              whole,
              coloured ? null : frame,
              palette,
            ),
          );
          if (filter != null) canvas.restore();
        },
        slots: [
          (_scaled(indopak ? _indopakTitle : _madaniTitle, nameScale), title),
          if (indopak && sides != null) ...[
            (_indopakSides.$2, sides!.$1),
            (_indopakSides.$1, sides!.$2),
          ],
        ],
      ),
    );
  }
}

/// [b] grown or shrunk about its centre by [k] (the name's size).
Rect _scaled(Rect b, double k) => Rect.fromCenter(
  center: b.center,
  width: b.width,
  height: b.height * k,
);

/// The Indo-Pak two-tier header over a sūrah heading and the basmala under
/// it, spanning both rows (each [rowHeight]): its top tier fills the
/// heading's row and holds the name and [sides] (āyah and rukūʿ counts);
/// its lower band, the top of the basmala's row, holds the basmala drawn
/// at its own proportions. Widened to the line by repeating its beads.
class IndopakTwoTierHeader extends StatelessWidget {
  final double rowHeight;
  final Widget title;
  final (Widget, Widget)? sides;
  final Color frame, ink;
  final Color? fill;
  final OrnamentTuning tune;
  const IndopakTwoTierHeader({
    super.key,
    required this.rowHeight,
    required this.title,
    this.sides,
    required this.frame,
    required this.ink,
    this.fill,
    this.tune = OrnamentTuning.defaults,
  });

  @override
  Widget build(BuildContext context) {
    final art = ClassicArt.indopakSurahBorder;
    final basmala = ClassicArt.indopakBasmala;
    return OrnamentArtBox(
      look: ('twoTier', frame, ink, fill, tune),
      layout: (box) {
        final h = rowHeight / _topTier * tune['twoTierScale'];
        // The top tier centred on the heading's row.
        final top = (rowHeight - h * _topTier) / 2 +
            tune['headerDy'] * rowHeight;
        return WideArt.layout(
          art,
          box: Rect.fromLTWH(0, top, box.width, h),
          height: h,
          repeat: _indopakRepeat,
        );
      },
      paintArt: (canvas, wide) {
        if (fill != null) {
          final p = Paint()..color = fill!;
          for (final b in _twoTierFill) {
            canvas.drawRect(wide.map(b), p);
          }
        }
        wide.paint(canvas, art, (c, whole) => art.paint(c, whole, frame));
        final line = Paint()..color = frame;
        for (final b in _bandLines) {
          canvas.drawRect(wide.map(b), line);
        }
        // The basmala at its own proportions, centred.
        final r = wide.bounds;
        final w = r.height * basmala.ratio;
        basmala.paint(
          canvas,
          Rect.fromLTWH(r.center.dx - w / 2, r.top, w, r.height),
          ink,
        );
      },
      slots: [
        (_scaled(_twoTierTitle, tune['headerNameScale']), title),
        if (sides != null) ...[
          (_twoTierSides.$2, sides!.$1),
          (_twoTierSides.$1, sides!.$2),
        ],
      ],
    );
  }
}

/// Fills [boxes] (fractions of [r]) with [color].
void fillBoxes(Canvas canvas, Rect r, List<Rect> boxes, Color color) {
  final paint = Paint()..color = color;
  for (final b in boxes) {
    canvas.drawRect(
      Rect.fromLTWH(
        r.left + b.left * r.width,
        r.top + b.top * r.height,
        b.width * r.width,
        b.height * r.height,
      ),
      paint,
    );
  }
}

/// An ornament laid out in its box ([layout]: widened artwork), drawn by
/// [paintArt], with widgets set in parts of the artwork ([slots],
/// fractions of it, each scaled down to fit). [look] identifies what's
/// drawn, for repainting.
class OrnamentArtBox extends StatelessWidget {
  final WideArt Function(Size box) layout;
  final void Function(Canvas canvas, WideArt art) paintArt;
  final List<(Rect, Widget)> slots;
  final Object look;
  const OrnamentArtBox({
    super.key,
    required this.layout,
    required this.paintArt,
    required this.slots,
    required this.look,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final wide = layout(c.biggest);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _ArtPainter(wide, paintArt, look)),
            ),
          ),
          for (final (b, child) in slots)
            Positioned.fromRect(
              rect: wide.map(b),
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: child),
              ),
            ),
        ],
      );
    },
  );
}

class _ArtPainter extends CustomPainter {
  final WideArt art;
  final void Function(Canvas canvas, WideArt art) paintArt;
  final Object look;
  _ArtPainter(this.art, this.paintArt, this.look);

  @override
  void paint(Canvas canvas, Size size) => paintArt(canvas, art);

  @override
  bool shouldRepaint(_ArtPainter o) =>
      o.art.bounds != art.bounds || o.look != look;
}
