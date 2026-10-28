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
  const PageRail({
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
    // Quiet beside the text: each colour part way to the page's (lighter on
    // a light page, darker on a dark one).
    Color soft(Color c, double t) => Color.lerp(c, paper.paper, t)!;
    // The labels and the number: the sūrah borders' gold, a shade darker
    // than the lantern drawn in it (on a dark page, the gold itself).
    final text = paper.dark
        ? soft(paper.frame, .2)
        : Color.lerp(paper.frame, paper.ink, .2)!;
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
          tap(Division.juz, down('J$juz')),
          tap(
            Division.page,
            MarginLantern(
              kind: 'lantern3',
              width: w * .8,
              text: '$page',
              // In the sūrah headers' colour; the number in the page's ink.
              ink: soft(paper.frame, .45),
              textColor: text,
              fill: paper.inner,
            ),
          ),
          tap(Division.surah, down('S$surah')),
        ],
        ),
      ),
    );
  }
}
