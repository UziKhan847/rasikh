import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_widgets.dart';

/// A "look how far you've come" recap — the badge glyph and title of every
/// stage the child has already cleared to reach here — rather than the
/// reused Learn page's stale table of contents (eight rows, written before
/// waṣl and the muqaṭṭaʿāt existed as their own stages, so it does not even
/// mention them). Nothing here is new teaching, so unlike the other
/// kid-native lessons this stays a plain, complete-on-open Learn item: a
/// celebration of what came before, not a check of it.
class KidsReviewRecap extends StatelessWidget {
  const KidsReviewRecap({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = kbUi(context);
    final items = <(String, String)>[
      ('ا ب', context.l10n.kidsBlockLetters),
      ('ـبـ', context.l10n.kidsBlockForms),
      ('لا', context.l10n.kidsBlockSpecial),
      ('بَ', context.l10n.unitHarakat),
      ('بۡ', context.l10n.mkSukun),
      ('بّ', context.l10n.shaddah),
      ('بَا', context.l10n.unitMaddLin),
      ('بً', context.l10n.unitTanwin),
      ('الٓمٓ', context.l10n.unitMuqattaat),
      ('قُلۡ', context.l10n.readingWords),
      ('ٱ', context.l10n.unitWasl),
      ('ال', context.l10n.kidsBlockSolarLunar),
      ('ة', context.l10n.kidsBlockTaMarbuta),
      ('صلى', context.l10n.unitWaqfStopping),
    ];
    return KidsScreenScaffold(
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: KidsMascot(size: 96)),
            const SizedBox(height: Geo.gapMd),
            KidsLessonTitle(context.l10n.kidsReviewIntro,
                align: TextAlign.center, fontSize: 24),
            const SizedBox(height: Geo.gapLg),
            // Every stage cleared, as a tile in the design's "done" colours:
            // the reward edge and the reward check.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final (badge, title) in items)
                  KbSurface(
                    color: ui.surface,
                    edge: ui.rewardEdge,
                    elev: KbElev.tile,
                    radius: 20,
                    width: 100,
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KbGlyphTile(badge,
                            bg: ui.tile,
                            ink: ui.tileInk,
                            size: 52,
                            radius: 16,
                            fontSize: 22),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: kbText(14, kbC(ui.ink), height: 1.15),
                        ),
                        const SizedBox(height: 6),
                        KbDot('check',
                            bg: ui.reward,
                            ink: ui.rewardInk,
                            size: 22,
                            iconSize: 15),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Geo.gapLg),
          ],
        ),
      ),
    );
  }
}
