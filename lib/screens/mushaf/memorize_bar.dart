import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/memorize.dart';
import '../../core/recite_back.dart';
import '../../core/theme.dart';
import '../../data/mushaf.dart';
import '../../ui/app_icons.dart';
import '../../ui/kit.dart';

/// The bar shown while memorizing: where the cursor is, then — laid out
/// right to left like the text — back an āyah, back a word, the next word,
/// the rest of the āyah, the rest of the page; show or hide the page; hear
/// what's showing (Ḥuṣarī); end. Colours come from the host.
class MemorizeBar extends StatelessWidget {
  final MemorizeController controller;
  final Map<int, String> surahNames;
  final Color bg, ink, sub, line, accent;
  final VoidCallback onPlay;
  final VoidCallback onPlayPage;
  final VoidCallback onEnd;

  /// Floating pill (desktop / landscape) vs. a full-width bar.
  final bool floating;

  /// Verse cards: the āyah is the unit (show / hide the āyah; no page).
  final bool cards;

  /// Switches between the muṣḥaf page and verse cards, keeping the place.
  final VoidCallback? onSwitchView;
  const MemorizeBar({
    super.key,
    required this.controller,
    required this.surahNames,
    required this.bg,
    required this.ink,
    required this.sub,
    required this.line,
    required this.accent,
    required this.onPlay,
    required this.onPlayPage,
    required this.onEnd,
    this.floating = false,
    this.cards = false,
    this.onSwitchView,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, ReciteBack.instance.playing]),
      builder: (context, _) {
        final c = controller;
        final playing = ReciteBack.instance.playing.value;
        // Where: the next word to recite.
        final String where;
        if (c.atEnd) {
          where = context.l10n.mzAllShown;
        } else {
          final (g, w) = MushafRepo.tokenAt(c.script, c.revealedEnd);
          final (s, a) = MushafRepo.surahAyahOf(g);
          where = context.l10n
              .mzWhere('${surahNames[s] ?? ''} $s:$a', w < 0 ? 1 : w + 1);
        }
        final hidden = cards ? c.ayahHidden : c.hideFromOn(c.viewPage) >= 0;
        IconButton icon(IconData i, String tip, VoidCallback? on) => IconButton(
              tooltip: tip,
              onPressed: on,
              icon: Icon(i, color: on == null ? sub.withValues(alpha: .5) : ink),
            );
        final caption = Row(children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '$where  ',
                    style: uiStyle(context,
                        size: 13, weight: FontWeight.w700, color: ink)),
                TextSpan(
                    text: context.l10n.mzHint,
                    style: uiStyle(context, size: 12.5, color: sub)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]);
        // Laid out left to right explicitly (the icon font mirrors arrows
        // inside right-to-left text): onward is leftward, as the text runs.
        final controls = Directionality(
          textDirection: TextDirection.ltr,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!cards)
              icon(AppIcons.pageOn, context.l10n.mzNextPage,
                  c.atEnd ? null : c.nextPage),
            icon(AppIcons.nextVerse, context.l10n.mzNextVerse,
                c.atEnd ? null : c.nextVerse),
            FilledButton.icon(
              onPressed: c.atEnd ? null : c.nextWord,
              icon: const Icon(AppIcons.chevronLeft, size: 20),
              label: Text(context.l10n.mzNextWord),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: bg,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 38),
              ),
            ),
            icon(AppIcons.chevronRight, context.l10n.mzPrevWord,
                c.atStart ? null : c.prevWord),
            icon(AppIcons.prevVerse, context.l10n.mzPrevVerse,
                c.atStart ? null : c.prevVerse),
            Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: line),
            if (cards)
              icon(hidden ? AppIcons.show : AppIcons.memorize,
                  hidden ? context.l10n.mzShowAyah : context.l10n.mzHideAyah,
                  hidden ? c.revealAyah : c.hideAyah)
            else
              icon(hidden ? AppIcons.show : AppIcons.memorize,
                  hidden ? context.l10n.mzShowPage : context.l10n.mzHidePage,
                  hidden ? c.revealPage : c.hidePage),
            if (onSwitchView != null)
              icon(cards ? AppIcons.mushaf : AppIcons.cards,
                  cards ? context.l10n.mzAsPage : context.l10n.mzAsCards,
                  onSwitchView),
            Tooltip(
              message: cards ? context.l10n.mzPlayCards : context.l10n.mzPlay,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: c.atStart ? null : onPlay,
                onLongPress: c.atStart ? null : onPlayPage,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(playing ? AppIcons.pause : AppIcons.play,
                      color: c.atStart ? sub.withValues(alpha: .5) : accent),
                ),
              ),
            ),
            TextButton(
              onPressed: onEnd,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(48, 38),
              ),
              child: Text(context.l10n.mkEnd,
                  style: uiStyle(context,
                      size: 14, weight: FontWeight.w700, color: accent)),
            ),
          ]),
        );
        final body = Column(mainAxisSize: MainAxisSize.min, children: [
          caption,
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: controls),
        ]);
        if (!floating) return body;
        return Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: line),
            boxShadow: qShadows(context, const [
              BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  spreadRadius: -10),
            ]),
          ),
          child: body,
        );
      },
    );
  }
}
