import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/l10n.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
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
    final p = kidsPal(context);
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
    final content = Padding(
      padding: const EdgeInsets.all(Geo.gapLg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: KidsMascot(size: 96)),
            const SizedBox(height: Geo.gapMd),
            Text(
              context.l10n.kidsReviewIntro,
              textAlign: TextAlign.center,
              style: kidsStyle(context, size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: Geo.gapLg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Geo.gapSm,
              runSpacing: Geo.gapSm,
              children: [
                for (final (badge, title) in items)
                  Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: kidsCard(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.ok,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          badge,
                          textDirection: TextDirection.rtl,
                          style: quranicStyle(
                            context,
                            size: 20,
                            color: p.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: kidsStyle(
                            context,
                            size: 11,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (useDesktop(context)) return content;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(child: content),
    );
  }
}
