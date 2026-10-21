import 'package:flutter/foundation.dart';

/// The ornaments' adjustable proportions: each one's size, offset or
/// thickness, as a factor or a fraction. The defaults are what the
/// artwork is drawn at; the style screen's tuning panel overrides them
/// live (Settings), and settled values come back here as the defaults.
@immutable
class OrnamentTuning {
  /// Each value, by key: what it means, its default and its range.
  static const specs = <String, ({double def, double min, double max})>{
    // Sūrah headers: their height within the line (they're widened to
    // the line's width), vertical offset as a fraction of the line's
    // height, and the name's size within its cartouche.
    'headerScale': (def: 1.0, min: .6, max: 1.2),
    'headerDy': (def: 0.0, min: -.3, max: .3),
    'headerNameScale': (def: 1.4, min: .6, max: 2.0),
    // The basmala line's size (against the line's height).
    'basmalaScale': (def: 1.6, min: .8, max: 2.4),
    // The Indo-Pak two-tier header (it spans the header and basmala
    // rows): its size.
    'twoTierScale': (def: 1.0, min: .7, max: 1.2),
    // The traced āyah circle, against the font's own circle: size, and
    // vertical offset as a fraction of the circle's height.
    'markerIndopakScale': (def: 1.0, min: .7, max: 1.4),
    'markerIndopakDy': (def: 0.0, min: -.25, max: .25),
    // The margin's lanterns and labels: their size within the margin band,
    // and the space between them and the frame (× the font size).
    'lanternScale': (def: 1.0, min: .5, max: 1.3),
    'lanternGap': (def: .5, min: 0, max: 1.5),
    // Page borders: thickness, against each one's own default.
    'borderMadani': (def: 1.0, min: .5, max: 2.0),
    'borderIndopak': (def: 1.85, min: .5, max: 3.0),
    'borderTile': (def: 1.0, min: .5, max: 2.0),
    'borderThin': (def: 1.0, min: .5, max: 2.0),
    'borderThinnest': (def: 1.0, min: .5, max: 2.0),
  };

  final Map<String, double> _over;
  const OrnamentTuning([this._over = const {}]);

  static const defaults = OrnamentTuning();

  double operator [](String key) =>
      _over[key] ?? specs[key]?.def ?? (throw ArgumentError(key));

  /// The values that differ from the defaults.
  Map<String, double> get overrides => Map.unmodifiable(_over);

  OrnamentTuning withValue(String key, double v) {
    final m = Map<String, double>.of(_over);
    if ((v - specs[key]!.def).abs() < 1e-9) {
      m.remove(key);
    } else {
      m[key] = v;
    }
    return OrnamentTuning(m);
  }

  /// "key: value" lines for every value, to send back as new defaults.
  String describe() => [
    for (final k in specs.keys) '$k: ${this[k].toStringAsFixed(3)}',
  ].join('\n');

  @override
  bool operator ==(Object other) =>
      other is OrnamentTuning && mapEquals(other._over, _over);

  @override
  int get hashCode => Object.hashAllUnordered(
    _over.entries.map((e) => Object.hash(e.key, e.value)),
  );
}
