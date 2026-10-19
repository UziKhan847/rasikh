import 'package:flutter/material.dart';

import '../../core/marks/marks_model.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../ui/mark_style.dart';
import 'mushaf_line.dart';

/// One āyah drawn the way the muṣḥaf draws it — from the glyph atlas, with
/// `drawRawAtlas` — but wrapped to the given width: its words (and ۝) are
/// broken into rows, and each row is an ordinary muṣḥaf line (marks, the
/// focus outline, the recited word, word taps and all). Rows are justified
/// like the page's, except the last.
///
/// Needs [script]'s atlas loaded (see [MushafAtlas.load]); until it is,
/// shows nothing but its space.
class VerseView extends StatelessWidget {
  final String script;
  final int globalAyah;
  final double fontSize;
  final Color ink, accent, strongBg, verseBg;
  final Map<int, MarkVisual> marks;
  final MarkPalette? markPal;

  /// The word in focus ([WordRef.key]); -1 for none.
  final int focus;

  /// Memorize: tokens from here on are hidden (see [MushafLineSpec.hideFrom]).
  final int hideFrom;
  final int playAyah, playWord;
  final bool reciting;
  final MushafTapHandlers handlers;

  const VerseView({
    super.key,
    required this.script,
    required this.globalAyah,
    required this.fontSize,
    required this.ink,
    required this.accent,
    required this.strongBg,
    required this.verseBg,
    required this.handlers,
    this.marks = const {},
    this.markPal,
    this.focus = -1,
    this.hideFrom = -1,
    this.playAyah = -1,
    this.playWord = -1,
    this.reciting = false,
  });

  /// Row height for [fontSize]: the muṣḥaf's line pitch.
  static double rowHeight(double fontSize) => fontSize * 1.9;

  /// [words] (starting at token [first]) broken into rows that fit [width]
  /// at [fontSize], each as (first token, words).
  static List<(int, List<MushafWord>)> wrap(MushafAtlas atlas, int first,
      List<MushafWord> words, double width, double fontSize) {
    final k = fontSize / atlas.upem;
    final rows = <(int, List<MushafWord>)>[];
    var start = 0;
    var x = 0.0;
    for (var i = 0; i < words.length; i++) {
      final tok = first + i;
      final w = atlas.wordAdvance[atlas.tokenWord[tok]] * k;
      final gap = i == start ? 0.0 : _gap(atlas, tok - 1) * k;
      if (i > start && x + gap + w > width) {
        rows.add((first + start, words.sublist(start, i)));
        start = i;
        x = w;
      } else {
        x += gap + w;
      }
    }
    if (start < words.length) rows.add((first + start, words.sublist(start)));
    return rows;
  }

  static int _gap(MushafAtlas atlas, int tok) {
    final g = atlas.tokenGap[tok];
    return g == 0 ? atlas.space : g;
  }

  /// The natural width of [words] from token [first] at [fontSize].
  static double naturalWidth(
      MushafAtlas atlas, int first, int count, double fontSize) {
    final k = fontSize / atlas.upem;
    var x = 0.0;
    for (var i = 0; i < count; i++) {
      x += atlas.wordAdvance[atlas.tokenWord[first + i]] * k;
      if (i < count - 1) x += _gap(atlas, first + i) * k;
    }
    return x;
  }

  @override
  Widget build(BuildContext context) {
    final atlas = MushafAtlas.of(script);
    final (first, words) = MushafRepo.ayahTokens(script, globalAyah);
    final slotH = rowHeight(fontSize);
    if (atlas == null || first < 0) return SizedBox(height: slotH);
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final rows = wrap(atlas, first, words, width, fontSize);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (var r = 0; r < rows.length; r++)
          SizedBox(
            width: width,
            height: slotH,
            child: MushafLineView(
              handlers: handlers,
              spec: MushafLineSpec(
                script: script,
                // A key of its own, apart from every page's lines.
                page: -1 - globalAyah,
                index: r,
                line: MushafLine.text(rows[r].$2, firstTok: rows[r].$1),
                fontSize: fontSize,
                slotH: slotH,
                // The last row keeps its natural spacing (it only justifies
                // past 45% of the measure, so a measure past it holds off).
                targetW: r == rows.length - 1
                    ? width.clamp(
                        naturalWidth(atlas, rows[r].$1, rows[r].$2.length,
                                fontSize) /
                            .44,
                        double.infinity)
                    : width,
                ink: ink,
                accent: accent,
                strongBg: strongBg,
                verseBg: verseBg,
                playAyah: playAyah,
                playWord: playWord,
                reciting: reciting,
                marks: marks,
                markPal: markPal,
                focus: focus,
                hideFrom: hideFrom,
                rewrap: true,
              ),
            ),
          ),
      ]);
    });
  }
}
