import 'package:flutter/material.dart';

import '../../core/marks/marks_model.dart';
import '../../data/mushaf.dart';
import '../../data/mushaf_atlas.dart';
import '../../ui/mark_style.dart';
import 'mushaf_line.dart';
import 'verse_view.dart';

/// A few words of an āyah on one line, drawn from the glyph atlas (nothing
/// shaped): words [from]..[to] (0-based; the ۝ past the last) with up to
/// [around] on either side, as many as fit — a search's match on its
/// ground ([match]), a mark's word outlined ([focus]), the āyah's marks as
/// on the page. For search results: dozens of these cost little.
class WordsLine extends StatelessWidget {
  final String script;
  final int ayah;
  final int from, to;
  final bool match;
  final int focus;
  final Map<int, MarkVisual> marks;
  final MarkPalette? markPal;
  final Color ink, accent, strongBg, verseBg;
  final double fontSize;
  final int around;
  const WordsLine({
    super.key,
    required this.script,
    required this.ayah,
    required this.from,
    required this.to,
    required this.ink,
    required this.accent,
    required this.strongBg,
    required this.verseBg,
    this.match = false,
    this.focus = -1,
    this.marks = const {},
    this.markPal,
    this.fontSize = 20,
    this.around = 4,
  });

  @override
  Widget build(BuildContext context) {
    final atlas = MushafAtlas.of(script);
    final (first, words) = MushafRepo.ayahTokens(script, ayah);
    if (words.isEmpty) return const SizedBox.shrink();
    final lo = from.clamp(0, words.length - 1);
    final hi = to.clamp(lo + 1, words.length);
    if (atlas == null || first < 0) {
      return Text(
        words.sublist((lo - around).clamp(0, lo), (hi + around).clamp(hi, words.length))
            .map((w) => w.text)
            .join(' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.rtl,
        style: TextStyle(
            fontFamily: MushafRepo.fontFamily(script), fontSize: fontSize, color: ink),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      var a = (lo - around).clamp(0, lo), b = (hi + around).clamp(hi, words.length);
      double natural() =>
          VerseView.naturalWidth(atlas, first + a, b - a, fontSize);
      // Too wide: drop words from the side with more of them to spare.
      while (natural() > width && (a < lo || b > hi)) {
        if (lo - a >= b - hi && a < lo) {
          a++;
        } else if (b > hi) {
          b--;
        } else {
          a++;
        }
      }
      final n = natural();
      final fs = n > width ? fontSize * width / n * .98 : fontSize;
      final slotH = VerseView.rowHeight(fs);
      return IgnorePointer(
        child: SizedBox(
          width: width,
          height: slotH,
          child: MushafLineView(
            handlers: MushafTapHandlers(),
            spec: MushafLineSpec(
              script: script,
              // Keys of their own, apart from every page's lines.
              page: -200000 - ayah,
              index: a * 1000 + b,
              line: MushafLine.text(words.sublist(a, b), firstTok: first + a),
              fontSize: fs,
              slotH: slotH,
              targetW: width,
              ink: ink,
              accent: accent,
              strongBg: strongBg,
              verseBg: verseBg,
              marks: marks,
              markPal: markPal,
              focus: focus,
              justify: false,
              rewrap: true,
              matchFrom: match ? first + lo : -1,
              matchTo: match ? first + hi : -1,
            ),
          ),
        ),
      );
    });
  }
}
