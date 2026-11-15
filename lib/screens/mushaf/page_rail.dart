import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/divisions.dart';
import '../../data/mushaf.dart';
import '../../ui/ornaments/margin.dart';

/// A page's margin, on its outer edge, when two face each other: the page
/// number in a lantern, the juzʼ just above it ("J 1") and the sūrah just
/// below ("S 2"), together in the middle of the margin — each opening its
/// list to jump. Each page of a spread has its own.
class PageRail extends StatelessWidget {
  final String script;
  final int page;
  final double width;
  final MushafPaper paper;
  final void Function(Division d, BuildContext anchor) onTap;

  /// Small toggles at the rail's top and foot.
  final Widget? above, below;
  const PageRail({
    this.above,
    this.below,
    super.key,
    required this.script,
    required this.page,
    required this.width,
    required this.paper,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Room between the labels and the page: they sit on the rail's outer
    // part (right of an odd page, left of an even one).
    final toPage = width * .3;
    final w = width - toPage;
    // The lantern in the sūrah headers' own colour; the labels and the
    // number in the ornaments' stronger shade, to read.
    final text = paper.frameInk ?? Color.lerp(paper.frame, paper.ink, .25)!;
    final juz = MushafRepo.juzOfPage(script, page);
    final surah = MushafRepo.firstVerseOfPage(script, page).$1;
    final label = TextStyle(
      fontFamily: 'Inter',
      fontSize: (w * .42).clamp(10.0, 13.5),
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: text,
    );
    Widget tap(Division d, Widget child) => Builder(
          builder: (anchor) => InkWell(
            borderRadius: BorderRadius.circular(w / 2),
            onTap: () => onTap(d, anchor),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(width: w, child: Center(child: child)),
            ),
          ),
        );
    // Each character on its own line: read down the margin.
    Widget down(String s) => Text(s.split('').join('\n'),
        textAlign: TextAlign.center, style: label);
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: page.isOdd ? EdgeInsets.only(left: toPage) : EdgeInsets.only(right: toPage),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (above case final a?)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: a),
          tap(Division.juz, down('J$juz')),
          tap(
            Division.page,
            MarginLantern(
              kind: 'lantern3',
              width: w * .8,
              text: '$page',
              ink: paper.frame,
              textColor: text,
              // As the labels, a little smaller: the window is narrow.
              textStyle: label.copyWith(
                  fontSize: label.fontSize! * .9,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()]),
              fill: paper.inner,
            ),
          ),
          tap(Division.surah, down('S$surah')),
          if (below case final b?)
            Padding(padding: const EdgeInsets.only(top: 6), child: b),
        ],
        ),
      ),
    );
  }
}
