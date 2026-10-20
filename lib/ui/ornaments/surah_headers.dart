import 'package:flutter/material.dart';

import '../qiraah_ornaments.dart' show SurahHeader;
import 'art.dart';
import 'tuning.dart';

/// Where each artwork header's parts are, as fractions of the artwork's
/// own box: the title (its cartouche's inside), and what a white-filled
/// paper fills behind it.
const _madaniTitle = Rect.fromLTRB(.29, .2, .71, .8);
const _madaniFill = Rect.fromLTWH(.07, .19, .86, .62);
const _indopakTitle = Rect.fromLTRB(.3, .25, .7, .86);
const _indopakFill = Rect.fromLTRB(.26, .18, .74, .94);
const _tileTitle = Rect.fromLTRB(.28, .2, .72, .8);
const _twoTierTitle = Rect.fromLTRB(.3, .14, .7, .5);
const _twoTierBasmala = Rect.fromLTRB(.22, .63, .78, .95);
const _twoTierFill = [
  Rect.fromLTRB(.26, .1, .74, .53),
  Rect.fromLTRB(.12, .57, .88, .98),
];

/// The share of the two-tier Indo-Pak artwork its top tier takes.
const _topTier = .564;

/// A sūrah header line in the muṣḥaf, as [kind] draws it:
/// - 'plain' and 'rosette': the drawn band (with rosettes and a pill
///   cartouche for 'rosette');
/// - 'madani', 'indopak' (its one-tier form) and 'tile1'…'tile3': the
///   artwork, kept to its proportions and centred in the line, the name in
///   its cartouche.
///
/// [title] is the name (sized to fit); [frame] tints single-colour artwork
/// (the tiles are full colour); [fill], on white-filled papers, fills the
/// cartouche.
class MushafSurahHeader extends StatelessWidget {
  final String kind;
  final double lineHeight;
  final Widget title;
  final TextStyle? plainStyle;
  final String plainTitle;
  final Color frame, paper, soft, ink;
  final Color? fill;
  final OrnamentTuning tune;
  const MushafSurahHeader({
    super.key,
    required this.kind,
    required this.lineHeight,
    required this.title,
    required this.plainTitle,
    this.plainStyle,
    required this.frame,
    required this.paper,
    required this.soft,
    required this.ink,
    this.fill,
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
        textStyle: plainStyle ?? const TextStyle(fontSize: 22),
      );
    }
    final tile = kind.startsWith('tile') ? int.tryParse(kind.substring(4)) : null;
    final art = switch (kind) {
      'indopak' => ClassicArt.indopakSurahHeader,
      _ => ClassicArt.surahBorder,
    };
    return SizedBox(
      height: lineHeight,
      child: OrnamentArtBox(
        ratio: tile != null ? 2288 / 279 : art.ratio,
        place: (box) => containRect(
          Rect.fromLTWH(0, box.height * .02, box.width, box.height * .96),
          tile != null ? 2288 / 279 : art.ratio,
          scale: tune['headerScale'],
          dy: tune['headerDy'],
        ),
        look: (kind, frame, fill),
        paintArt: (canvas, r) {
          if (tile != null) {
            paintOrnamentImage(canvas, OrnamentImages.header(tile), r);
            return;
          }
          if (fill != null) {
            fillBoxes(canvas, r, [
              kind == 'indopak' ? _indopakFill : _madaniFill,
            ], fill!);
          }
          art.paint(canvas, r, frame);
        },
        slots: [
          (
            tile != null
                ? _tileTitle
                : (kind == 'indopak' ? _indopakTitle : _madaniTitle),
            title,
          ),
        ],
      ),
    );
  }
}

/// The Indo-Pak two-tier header over a sūrah heading and the basmala under
/// it, spanning both rows (each [rowHeight]): the artwork 1.773 rows tall —
/// its top tier filling the heading's row, its lower one the top of the
/// basmala's — and its width following.
class IndopakTwoTierHeader extends StatelessWidget {
  final double rowHeight;
  final Widget title, basmala;
  final Color frame;
  final Color? fill;
  final OrnamentTuning tune;
  const IndopakTwoTierHeader({
    super.key,
    required this.rowHeight,
    required this.title,
    required this.basmala,
    required this.frame,
    this.fill,
    this.tune = OrnamentTuning.defaults,
  });

  @override
  Widget build(BuildContext context) {
    final art = ClassicArt.indopakSurahBorder;
    return OrnamentArtBox(
      ratio: art.ratio,
      place: (box) {
        var h = rowHeight / _topTier * tune['twoTierScale'];
        var w = h * art.ratio;
        if (w > box.width) {
          w = box.width;
          h = w / art.ratio;
        }
        // The top tier centred on the heading's row.
        final top = (rowHeight - h * _topTier) / 2 +
            tune['headerDy'] * rowHeight;
        return Rect.fromLTWH((box.width - w) / 2, top, w, h);
      },
      look: ('twoTier', frame, fill),
      paintArt: (canvas, r) {
        if (fill != null) fillBoxes(canvas, r, _twoTierFill, fill!);
        art.paint(canvas, r, frame);
      },
      slots: [(_twoTierTitle, title), (_twoTierBasmala, basmala)],
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

/// Draws the full-colour image [name] into [r] (nothing until it's loaded).
void paintOrnamentImage(Canvas canvas, String name, Rect r) {
  final img = OrnamentImages.image(name);
  if (img == null) return;
  canvas.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    r,
    Paint()..filterQuality = FilterQuality.medium,
  );
}

/// An ornament drawn in a rectangle of its box ([place]), with widgets set
/// in parts of that rectangle ([slots], fractions of it, each scaled down
/// to fit). [look] identifies what's drawn, for repainting.
class OrnamentArtBox extends StatelessWidget {
  final double ratio;
  final Rect Function(Size box) place;
  final void Function(Canvas canvas, Rect art) paintArt;
  final List<(Rect, Widget)> slots;
  final Object look;
  const OrnamentArtBox({
    super.key,
    required this.ratio,
    required this.place,
    required this.paintArt,
    required this.slots,
    required this.look,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final r = place(c.biggest);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _ArtPainter(r, paintArt, look)),
            ),
          ),
          for (final (b, child) in slots)
            Positioned.fromRect(
              rect: Rect.fromLTWH(
                r.left + b.left * r.width,
                r.top + b.top * r.height,
                b.width * r.width,
                b.height * r.height,
              ),
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
  final Rect art;
  final void Function(Canvas canvas, Rect art) paintArt;
  final Object look;
  _ArtPainter(this.art, this.paintArt, this.look)
    : super(repaint: OrnamentImages.loaded);

  @override
  void paint(Canvas canvas, Size size) => paintArt(canvas, art);

  @override
  bool shouldRepaint(_ArtPainter o) => o.art != art || o.look != look;
}
