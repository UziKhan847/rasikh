import 'dart:ui';

import 'strokes_gen.dart';

/// Tracing data model. The actual stroke data lives in [strokes_gen.dart],
/// extracted from the KFGQPC Uthman Taha letterforms (the same naskh the
/// user's reference SVG was set in): every letter in every position, plus
/// whole words — skeletonized into ordered calligraphic strokes.
class TracedGlyph {
  final String id; // e.g. 'ب.med'  or  'w.بسم'
  final String char; // display form, e.g. 'ـبـ'
  final String name; // e.g. 'Bā’ · middle'
  final List<List<Offset>> strokes; // normalized: y ∈ 0..1, x ∈ 0..aspect
  final List<Offset> dots;
  final double aspect; // board width / height (1 for letters)

  const TracedGlyph(this.id, this.char, this.name, this.strokes,
      {this.dots = const [], this.aspect = 1});
}

/// Catmull-Rom → cubic Bézier smoothing shared by the tracing engine and
/// its painter, so detection geometry always matches what is drawn.
Path smoothPath(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 2) {
    path.lineTo(pts[1].dx, pts[1].dy);
    return path;
  }
  for (var i = 0; i < pts.length - 1; i++) {
    final p0 = pts[i == 0 ? 0 : i - 1];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = pts[i + 2 > pts.length - 1 ? pts.length - 1 : i + 2];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// Scale uniformly by the board HEIGHT (x may exceed 1 for wide words).
Path smoothPathScaled(List<Offset> pts, double u) =>
    smoothPath([for (final p in pts) p * u]);

// ── registries ──────────────────────────────────────────────────────

const String _noJoin = 'اودذرز'; // letters with no start/middle form

bool letterJoins(String ch) => !_noJoin.contains(ch);

List<String> formsOf(String ch) =>
    letterJoins(ch) ? const ['iso', 'ini', 'med', 'fin'] : const ['iso', 'fin'];

String formLabel(String form) => switch (form) {
      'ini' => 'Start',
      'med' => 'Middle',
      'fin' => 'End',
      _ => 'Alone',
    };

TracedGlyph glyphFor(String ch, String form) =>
    generatedGlyphs.firstWhere((g) => g.id == '$ch.$form',
        orElse: () => generatedGlyphs.firstWhere((g) => g.id == '$ch.iso'));

/// The 28 letters, in order, with their base names — derived from the data.
final List<({String char, String name})> tracedLetters = [
  for (final g in generatedGlyphs)
    if (g.id.endsWith('.iso'))
      (char: g.id.split('.').first, name: g.name.split(' · ').first),
];

List<TracedGlyph> get tracedWordGlyphs => tracedWords;
