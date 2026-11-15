import '../ui/ornaments/tuning.dart';

/// One script's muṣḥaf look as chosen (Settings → Muṣḥaf style): each
/// script keeps its own, as their printed muṣḥafs differ. "auto" takes the
/// script's own artwork (see MushafLook.resolve).
/// - [header]: 'auto' | 'madani' | 'madaniColoured' | 'indopak' |
///   'tile1'…'tile3';
/// - [marker]: 'auto' | 'font' | 'indopak';
/// - [border]: 'none' | 'line' | 'double' | 'auto' | 'madani' | 'indopak'
///   | 'tile1'…'tile3' | 'thin1'…'thin3' | 'thinnest1'…'thinnest3';
/// - [margin]: 'none' | 'auto' | 'lantern1' | 'lantern2' | 'text';
/// - [paper]: the light theme's page colours ('white', 'cream', 'madani',
///   'mono', 'tile1'…'tile3');
/// - [head]: the running head — 'auto' | 'inside' | 'frame' | 'edges', and
///   for 'edges' which of its parts show ([edgeTop], [edgeRuku],
///   [edgeBottom]; the para along the side is the 'text' [margin]);
/// - [edge]: edge to edge — the page fills the screen, no frame, margins
///   or running head, only a hair of margin (sūrah headers stay);
/// - [tune]: the tuning panel's overrides.
class MushafStyle {
  String header, marker, border, margin, paper, head;

  /// The ornaments' colour (sūrah headers, āyah markers, the margin's
  /// lantern), chosen apart from the paper: a [kOrnamentSeeds] id.
  String ornament;
  bool edgeTop, edgeRuku, edgeBottom, edge;
  Map<String, double> tune;

  MushafStyle({
    this.header = 'auto',
    this.marker = 'auto',
    this.border = 'auto',
    this.margin = 'auto',
    required this.paper,
    this.head = 'auto',
    this.ornament = 'gold',
    this.edgeTop = true,
    this.edgeRuku = true,
    this.edgeBottom = true,
    this.edge = false,
    Map<String, double>? tune,
  }) : tune = tune ?? {};

  /// The script's default look: Madani — white, a thin double gold frame
  /// with the running head inside, the line-art header (its printed look
  /// is a preset); Indo-Pak — its own frame and two-tier header, in black
  /// and white, the page's details along the frame.
  factory MushafStyle.defaultsFor(String script) =>
      MushafStyle(paper: script == 'indopak' ? 'mono' : 'white');

  OrnamentTuning get tuning => OrnamentTuning(tune);

  Map<String, Object> toJson() => {
    'header': header,
    'marker': marker,
    'border': border,
    'margin': margin,
    'paper': paper,
    'head': head,
    'ornament': ornament,
    'edgeTop': edgeTop,
    'edgeRuku': edgeRuku,
    'edgeBottom': edgeBottom,
    'edge': edge,
    'tune': tune,
  };

  factory MushafStyle.fromJson(String script, Map<String, dynamic> m) {
    final d = MushafStyle.defaultsFor(script);
    return MushafStyle(
      header: m['header'] as String? ?? d.header,
      marker: m['marker'] as String? ?? d.marker,
      border: m['border'] as String? ?? d.border,
      margin: m['margin'] as String? ?? d.margin,
      paper: m['paper'] as String? ?? d.paper,
      head: m['head'] as String? ?? d.head,
      ornament: m['ornament'] as String? ?? d.ornament,
      edgeTop: m['edgeTop'] as bool? ?? true,
      edgeRuku: m['edgeRuku'] as bool? ?? true,
      edgeBottom: m['edgeBottom'] as bool? ?? true,
      edge: m['edge'] as bool? ?? false,
      tune: {
        for (final e in ((m['tune'] as Map?) ?? const {}).entries)
          if (e.value is num && OrnamentTuning.specs.containsKey(e.key))
            e.key as String: (e.value as num).toDouble(),
      },
    );
  }
}
