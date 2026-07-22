import 'strokes.dart';
import 'tracing_all.dart';

/// One selectable tracing level. Levels bundle their own glyph set, so the
/// letter strip, forms, and quiz all draw from the chosen script/difficulty.
class TracingLevel {
  final String id;
  final String name; // short label
  final String tier; // Beginner / Intermediate / Advanced
  final bool words; // true → whole-word glyphs (no joining forms)
  final List<TracedGlyph> glyphs;
  const TracingLevel(this.id, this.name, this.tier, this.words, this.glyphs);

  /// Distinct base letters (one entry per letter), in data order. Display
  /// names are composed per language — see `glyph_names.dart`.
  List<({String char})> get letters => [
        for (final g in glyphs)
          if (g.id.endsWith('.iso')) (char: g.id.split('.').first),
      ];

  /// Joining forms actually present for [ch] in this level, in writing order.
  List<String> formsPresentFor(String ch) {
    const order = ['iso', 'ini', 'med', 'fin'];
    final have = <String>{
      for (final g in glyphs)
        if (g.id.startsWith('$ch.')) g.id.split('.').last,
    };
    final list = [for (final f in order) if (have.contains(f)) f];
    return list.isEmpty ? const ['iso'] : list;
  }

  TracedGlyph glyphForIn(String ch, String form) => glyphs.firstWhere(
        (g) => g.id == '$ch.$form',
        orElse: () => glyphs.firstWhere((g) => g.id == '$ch.iso',
            orElse: () => glyphs.first),
      );

  /// One glyph per unit for the quiz: the isolated letter of each letter, or
  /// every word for word levels.
  List<TracedGlyph> get quizPool => words
      ? glyphs
      : [
          for (final l in letters) glyphForIn(l.char, 'iso'),
        ];
}

final List<TracingLevel> tracingLevels = [
  TracingLevel('naskh_more', 'Naskh · more strokes', 'Beginner', false,
      glyphsNaskhMore),
  TracingLevel('naskh_few', 'Naskh · fewer strokes', 'Intermediate', false,
      glyphsNaskhFew),
  TracingLevel('naskh_words', 'Naskh words', 'Intermediate', true, wordsNaskh),
  TracingLevel('ruqaa_letters', 'Ruqʿah letters', 'Advanced', false,
      glyphsRuqaa),
  TracingLevel('ruqaa_words', 'Ruqʿah words', 'Advanced', true, wordsRuqaa),
];
