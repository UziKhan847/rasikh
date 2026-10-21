import 'package:flutter/material.dart';

import 'art.dart';

/// The muṣḥaf page's border around [child], as [kind] draws it:
/// - 'none': just [padding];
/// - 'line' / 'double': one or two thin rules in [frame] at 60%;
/// - 'madani': the nine-slice of Madani tiles (corners kept, the edge tile
///   repeated in whole tiles), [band] thick;
/// - 'indopak': the Indo-Pak frame as a nine-slice — its corners kept to
///   their drawn proportions, its edges (bar and centre motif) repeated;
/// - 'tile1'…'tile3', 'thin1'…'thin3': a full-colour frame (Update 10's
///   tiled frames, and thinner ones), nine-slice with its edge tiles
///   repeated, never stretched or tinted.
///
/// [inner], on white-filled papers, fills inside an artwork border. With
/// [mono] (the Mono papers) a full-colour frame is drawn in black and white
/// — inverted on a dark one ([dark]).
class MushafPageBorder extends StatelessWidget {
  final String kind;
  final double band;
  final Color frame, cut, hairline;
  final Color? inner;
  final EdgeInsets padding;
  final bool mono, dark;
  final Widget child;
  const MushafPageBorder({
    super.key,
    required this.kind,
    required this.band,
    required this.frame,
    required this.cut,
    required this.hairline,
    this.inner,
    required this.padding,
    this.mono = false,
    this.dark = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final rule = frame.withValues(alpha: .6);
    switch (kind) {
      case 'none':
        return Padding(padding: padding, child: child);
      case 'line':
      case 'double':
        final single = Container(
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(color: rule),
            borderRadius: BorderRadius.circular(kind == 'double' ? 4 : 6),
          ),
          child: child,
        );
        if (kind == 'line') return single;
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: rule),
            borderRadius: BorderRadius.circular(6),
          ),
          child: single,
        );
    }
    final CustomPainter painter = switch (kind) {
      'madani' => _MadaniBorderPainter(band, frame, cut, hairline, inner),
      'indopak' => _IndopakBorderPainter(band, frame, inner),
      _ => _ImageBorderPainter(
        band,
        FrameArt.of(kind),
        inner,
        mono ? monoFilter(dark: dark) : null,
      ),
    };
    return CustomPaint(
      painter: painter,
      child: Padding(padding: EdgeInsets.all(band) + padding, child: child),
    );
  }
}

/// The Madani page border's two 30-unit tiles (from madani_page_border.svg):
/// each part's colour key — 0 the band, 1 the motifs, 2 the hairlines — and
/// its outline.
final List<(int, Path)> _edgeTile = _tile([
  (0, 'M0 0h30v28.6H0z'),
  (2, 'M0 2.9h30v.5H0zM0 25.4h30v.5H0z'),
  (
    1,
    'M4.6 15C7.4 10.6 10 7.9 15 6.4 20 7.9 22.6 10.6 25.4 15 22.6 19.4 20 22.1 '
        '15 23.6 10 22.1 7.4 19.4 4.6 15Z',
  ),
  (
    0,
    'M15 9.8C16.6 11.2 16.8 12.6 15 14.1 13.2 12.6 13.4 11.2 15 9.8ZM15 20.2C'
        '16.6 18.8 16.8 17.4 15 15.9 13.2 17.4 13.4 18.8 15 20.2ZM9.6 15C11.4 '
        '13.6 12.8 13.5 14 15 12.8 16.5 11.4 16.4 9.6 15ZM20.4 15C18.6 13.6 17.2 '
        '13.5 16 15 17.2 16.5 18.6 16.4 20.4 15Z',
  ),
  (1, _circle(15, 15, .8)),
  (1, 'M0 11.2 3 15 0 18.8-3 15ZM30 11.2 33 15 30 18.8 27 15Z'),
  (1, 'M2.4 14.6h2.4v.8H2.4zM25.2 14.6h2.4v.8h-2.4z'),
  (1, _circle(0, 7.4, 1.1)),
  (1, _circle(30, 7.4, 1.1)),
  (1, _circle(0, 22.6, 1.1)),
  (1, _circle(30, 22.6, 1.1)),
]);

final List<(int, Path)> _cornerTile = _tile([
  (0, 'M0 0h30v28.6H28.6V30H0z'),
  (2, 'M2.9 2.9h27.1v.5H3.4V30h-.5zM25.4 25.4h4.6v.5h-4.1V30h-.5z'),
  (1, 'M15 5.8 17.8 11.2 24.2 15 17.8 18.8 15 24.2 12.2 18.8 5.8 15 12.2 11.2Z'),
  (
    1,
    'M8.6 8.6 13.4 10.4 15 11.8 16.6 10.4 21.4 8.6 19.6 13.4 18.2 15 19.6 16.6 '
        '21.4 21.4 16.6 19.6 15 18.2 13.4 19.6 8.6 21.4 10.4 16.6 11.8 15 10.4 '
        '13.4Z',
  ),
  (0, 'M15 10.4 16.2 13.8 19.6 15 16.2 16.2 15 19.6 13.8 16.2 10.4 15 13.8 13.8Z'),
  (1, _circle(15, 15, 1.4)),
  (1, _circle(7, 7, 1.1)),
  (1, _circle(23.2, 23.2, 1.1)),
]);

String _circle(double cx, double cy, double r) =>
    'M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0Z';

List<(int, Path)> _tile(List<(int, String)> parts) => [
  for (final (k, d) in parts) (k, parseSvgPath(d)),
];

/// How many whole tiles of length [tile] fill a run of [len] (at least
/// one), as CSS's `round` repeats a border image.
int wholeTiles(double len, double tile) =>
    tile <= 0 ? 1 : (len / tile).round().clamp(1, 1000);

class _MadaniBorderPainter extends CustomPainter {
  final double t;
  final Color band, cut, hairline;
  final Color? inner;
  _MadaniBorderPainter(this.t, this.band, this.cut, this.hairline, this.inner);

  @override
  void paint(Canvas canvas, Size size) {
    if (inner != null) {
      canvas.drawRect(
        Rect.fromLTWH(t, t, size.width - 2 * t, size.height - 2 * t),
        Paint()..color = inner!,
      );
    }
    final paints = [
      Paint()..color = band,
      Paint()..color = cut,
      Paint()..color = hairline,
    ];
    final k = t / 30;
    final w = size.width, h = size.height;
    // The band as one ring (each tile's first part), so no seams show where
    // tiles meet; the tiles' motifs and hairlines go over it.
    final b = 28.6 * k;
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(Rect.fromLTWH(b, b, w - 2 * b, h - 2 * b)),
      paints[0],
    );
    // Draws [tile] through the SVG transform (a b c d e f) in tile units,
    // [along] stretching it lengthwise, clipped to its 30-unit square.
    void draw(List<(int, Path)> tile, Matrix4 m, {double along = 1}) {
      canvas.save();
      canvas.transform(m.storage);
      canvas.scale(along, 1);
      canvas.clipRect(const Rect.fromLTWH(0, 0, 30, 30), doAntiAlias: false);
      for (final (key, p) in tile.skip(1)) {
        canvas.drawPath(p, paints[key]);
      }
      canvas.restore();
    }

    Matrix4 at(double a, double b, double c, double d, double e, double f) =>
        Matrix4(a * k, b * k, 0, 0, c * k, d * k, 0, 0, 0, 0, 1, 0, e, f, 0, 1);

    // Corners, mirrored into place.
    draw(_cornerTile, at(1, 0, 0, 1, 0, 0));
    draw(_cornerTile, at(-1, 0, 0, 1, w, 0));
    draw(_cornerTile, at(1, 0, 0, -1, 0, h));
    draw(_cornerTile, at(-1, 0, 0, -1, w, h));
    // Edges: whole tiles, each stretched a little to fill the run.
    void edge(double len, Matrix4 Function(double offset) place) {
      if (len <= 0) return;
      final n = wholeTiles(len, t);
      final step = len / n;
      for (var i = 0; i < n; i++) {
        draw(_edgeTile, place(t + i * step), along: step / t);
      }
    }

    edge(w - 2 * t, (o) => at(1, 0, 0, 1, o, 0));
    edge(w - 2 * t, (o) => at(1, 0, 0, -1, o, h));
    edge(h - 2 * t, (o) => at(0, 1, 1, 0, 0, o));
    edge(h - 2 * t, (o) => at(0, 1, -1, 0, w, o));
  }

  @override
  bool shouldRepaint(_MadaniBorderPainter o) =>
      o.t != t ||
      o.band != band ||
      o.cut != cut ||
      o.hairline != hairline ||
      o.inner != inner;
}

/// Draws parts of a drawing (in its own units) into place: [src] of it
/// into [dst] of the canvas, clipped there.
typedef _DrawPart = void Function(Rect src, Rect dst);

/// Lays a nine-slice out over [size]: four corners of [corner] (source
/// units, kept to their proportions at [s] px per unit) and edges of
/// [srcSize] − 2 corners repeated in whole tiles — calling [part] for each
/// piece.
void _nineSlice(
  Size size,
  Size srcSize,
  EdgeInsets corner,
  double s,
  _DrawPart part,
) {
  final w = size.width, h = size.height;
  final sw = srcSize.width, sh = srcSize.height;
  final l = corner.left, t = corner.top, r = corner.right, b = corner.bottom;
  // Corners.
  part(Rect.fromLTWH(0, 0, l, t), Rect.fromLTWH(0, 0, l * s, t * s));
  part(
    Rect.fromLTWH(sw - r, 0, r, t),
    Rect.fromLTWH(w - r * s, 0, r * s, t * s),
  );
  part(
    Rect.fromLTWH(0, sh - b, l, b),
    Rect.fromLTWH(0, h - b * s, l * s, b * s),
  );
  part(
    Rect.fromLTWH(sw - r, sh - b, r, b),
    Rect.fromLTWH(w - r * s, h - b * s, r * s, b * s),
  );
  // Edges: whole tiles, scaled a little to fill the run.
  final hTile = sw - l - r, vTile = sh - t - b;
  final hRun = w - (l + r) * s, vRun = h - (t + b) * s;
  if (hRun > 0) {
    final n = wholeTiles(hRun, hTile * s);
    final step = hRun / n;
    for (var i = 0; i < n; i++) {
      final x = l * s + i * step;
      part(Rect.fromLTWH(l, 0, hTile, t), Rect.fromLTWH(x, 0, step, t * s));
      part(
        Rect.fromLTWH(l, sh - b, hTile, b),
        Rect.fromLTWH(x, h - b * s, step, b * s),
      );
    }
  }
  if (vRun > 0) {
    final n = wholeTiles(vRun, vTile * s);
    final step = vRun / n;
    for (var i = 0; i < n; i++) {
      final y = t * s + i * step;
      part(Rect.fromLTWH(0, t, l, vTile), Rect.fromLTWH(0, y, l * s, step));
      part(
        Rect.fromLTWH(sw - r, t, r, vTile),
        Rect.fromLTWH(w - r * s, y, r * s, step),
      );
    }
  }
}

/// The scale (px per source unit) for a nine-slice whose [bandUnits] thick
/// band is drawn [band] px thick — no larger than lets the corners fit.
double _sliceScale(Size size, EdgeInsets corner, double bandUnits, double band) {
  var s = band / bandUnits;
  final fitW = size.width / (corner.left + corner.right);
  final fitH = size.height / (corner.top + corner.bottom);
  if (s > fitW) s = fitW;
  if (s > fitH) s = fitH;
  return s;
}

class _IndopakBorderPainter extends CustomPainter {
  final double band;
  final Color color;
  final Color? inner;
  _IndopakBorderPainter(this.band, this.color, this.inner);

  /// The frame's band, and its corners (20% × 14.4% of the artwork), in
  /// its own units.
  static const _bandUnits = 40.0;
  static final _art = ClassicArt.indopakPageBorder;
  static final _corner = EdgeInsets.symmetric(
    horizontal: _art.width * .2,
    vertical: _art.height * .144,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (inner != null) {
      canvas.drawRect(
        Rect.fromLTWH(band, band, size.width - 2 * band, size.height - 2 * band),
        Paint()..color = inner!,
      );
    }
    final s = _sliceScale(size, _corner, _bandUnits, band);
    final paint = Paint()..color = color;
    _nineSlice(size, Size(_art.width, _art.height), _corner, s, (src, dst) {
      canvas.save();
      canvas.clipRect(dst);
      canvas.translate(dst.left, dst.top);
      canvas.scale(dst.width / src.width, dst.height / src.height);
      canvas.translate(-src.left, -src.top);
      for (final p in _art.paths) {
        canvas.drawPath(p, paint);
      }
      canvas.restore();
    });
  }

  @override
  bool shouldRepaint(_IndopakBorderPainter o) =>
      o.band != band || o.color != color || o.inner != inner;
}

/// A full-colour page frame as a compact nine-slice image in
/// `assets/ornaments/`: its corner slices (px of the image) and its band's
/// thickness there. (The thin frames' are cut by tool/gen_frame_slices.py.)
class FrameArt {
  final String asset;
  final EdgeInsets corner;
  final double band;
  const FrameArt(this.asset, this.corner, this.band);

  static const _tiles = [
    FrameArt('tile_frame_1', EdgeInsets.fromLTRB(96, 120, 94, 91), 51),
    FrameArt('tile_frame_2', EdgeInsets.fromLTRB(96, 120, 94, 91), 51),
    FrameArt('tile_frame_3', EdgeInsets.fromLTRB(96, 120, 94, 91), 51),
  ];
  static const _thinnest = [
    FrameArt('thinnest_frame_1', EdgeInsets.fromLTRB(113, 51, 85, 75), 22),
    FrameArt('thinnest_frame_2', EdgeInsets.fromLTRB(113, 51, 85, 75), 22),
    FrameArt('thinnest_frame_3', EdgeInsets.fromLTRB(113, 51, 85, 75), 22),
  ];
  static const _thin = [
    FrameArt('thin_frame_1', EdgeInsets.fromLTRB(94, 148, 68, 98), 36),
    FrameArt('thin_frame_2', EdgeInsets.fromLTRB(94, 148, 68, 98), 36),
    FrameArt('thin_frame_3', EdgeInsets.fromLTRB(94, 148, 68, 98), 36),
  ];

  /// The frame for [kind] ('tile1'…'tile3', 'thin1'…'thin3',
  /// 'thinnest1'…'thinnest3').
  static FrameArt of(String kind) {
    final n = (int.tryParse(kind.substring(kind.length - 1)) ?? 1).clamp(1, 3) - 1;
    if (kind.startsWith('thinnest')) return _thinnest[n];
    return kind.startsWith('thin') ? _thin[n] : _tiles[n];
  }
}

class _ImageBorderPainter extends CustomPainter {
  final double band;
  final FrameArt art;
  final Color? inner;
  final ColorFilter? filter;
  _ImageBorderPainter(this.band, this.art, this.inner, this.filter)
    : super(repaint: OrnamentImages.loaded);

  @override
  void paint(Canvas canvas, Size size) {
    if (inner != null) {
      canvas.drawRect(
        Rect.fromLTWH(band, band, size.width - 2 * band, size.height - 2 * band),
        Paint()..color = inner!,
      );
    }
    final img = OrnamentImages.image(art.asset);
    if (img == null) return;
    final s = _sliceScale(size, art.corner, art.band, band);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = filter;
    _nineSlice(
      size,
      Size(img.width.toDouble(), img.height.toDouble()),
      art.corner,
      s,
      (src, dst) => canvas.drawImageRect(img, src, dst, paint),
    );
  }

  @override
  bool shouldRepaint(_ImageBorderPainter o) =>
      o.band != band ||
      o.art != art ||
      o.inner != inner ||
      o.filter != filter;
}
