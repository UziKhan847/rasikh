import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/divisions.dart';
import '../../data/mushaf.dart';
import '../../ui/ornaments/margin.dart';

/// A page's margin, on its outer edge, when two face each other: the juzʼ
/// at the top ("J 1"), the page number in a lantern, the sūrah at the foot
/// ("S 2") — short, set down the margin, each opening its list to jump.
/// Each page of a spread has its own.
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
    final juz = MushafRepo.juzOfPage(script, page);
    final surah = MushafRepo.firstVerseOfPage(script, page).$1;
    final label = TextStyle(
      fontFamily: 'Inter',
      fontSize: (width * .36).clamp(10.0, 13.0),
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: paper.acc,
    );
    Widget tap(Division d, Widget child) => Builder(
          builder: (anchor) => InkWell(
            borderRadius: BorderRadius.circular(width / 2),
            onTap: () => onTap(d, anchor),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(width: width, child: Center(child: child)),
            ),
          ),
        );
    // Each character on its own line: read down the margin.
    Widget down(String s) => Text(s.split('').join('\n'),
        textAlign: TextAlign.center, style: label);
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          tap(Division.juz, down('J$juz')),
          tap(
            Division.page,
            MarginLantern(
              kind: 'lantern1',
              width: width * .86,
              text: '$page',
              ink: paper.ink.withValues(alpha: .75),
              fill: paper.inner,
            ),
          ),
          tap(Division.surah, down('S$surah')),
        ],
      ),
    );
  }
}
