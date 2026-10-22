import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../../core/memorize.dart';
import '../../core/recite_back.dart';
import '../../core/settings.dart';
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

  /// The pages on screen, (first, last): what "show / hide the page" acts
  /// on. Unset: the page in view.
  final (int, int)? screen;

  /// Switches between the muṣḥaf page and verse cards, keeping the place.
  final VoidCallback? onSwitchView;

  /// Focus mode: a small floating pill with only back a word, the next
  /// word, play, leave focus and close.
  final bool minimal;
  final VoidCallback? onExitFocus;

  /// The controls without the caption above them (a phone on its side,
  /// short of height).
  final bool compact;

  /// The controls in a column, onward at the top (a phone on its side
  /// showing two pages: the bar stands in the margin beside them).
  final bool vertical;
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
    this.screen,
    this.onSwitchView,
    this.minimal = false,
    this.onExitFocus,
    this.compact = false,
    this.vertical = false,
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
        final (first, last) = screen ?? (c.viewPage, c.viewPage);
        final hidden = cards ? c.ayahHidden : c.hideFromOn(last) >= 0;
        // The controls are laid out left to right with onward on the left
        // (as the text runs). The verse and page glyphs (» « →|) are drawn
        // for left-to-right reading and mirror in right-to-left, so they're
        // set right to left here to point the way the text runs. (The
        // chevrons are already picked by their literal direction.)
        IconButton icon(IconData i, String tip, VoidCallback? on) => IconButton(
              tooltip: tip,
              onPressed: on,
              visualDensity: vertical ? VisualDensity.compact : null,
              icon: Directionality(
                textDirection: i == AppIcons.nextVerse ||
                        i == AppIcons.prevVerse ||
                        i == AppIcons.pageOn
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: Icon(i,
                    color: on == null ? sub.withValues(alpha: .5) : ink),
              ),
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
                    text: switch (SettingsScope.of(context).memorizeTap) {
                      'word' => context.l10n.mzHint,
                      'verse' => context.l10n.mzHintVerse,
                      'split' => context.l10n.mzHintSplit,
                      'pad' => context.l10n.mzHintPad,
                      _ => context.l10n.mzHintPlay,
                    },
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
          child: Flex(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              mainAxisSize: MainAxisSize.min,
              children: [
            if (!cards)
              icon(AppIcons.pageOn, context.l10n.mzNextPage,
                  c.atEnd ? null : c.nextPage),
            icon(AppIcons.nextVerse, context.l10n.mzNextVerse,
                c.atEnd ? null : c.nextVerse),
            if (vertical)
              IconButton.filled(
                tooltip: context.l10n.mzNextWord,
                onPressed: c.atEnd ? null : c.nextWord,
                icon: const Icon(AppIcons.chevronLeft, size: 22),
                style: IconButton.styleFrom(
                    backgroundColor: accent, foregroundColor: bg),
              )
            else
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
                width: vertical ? 24 : 1,
                height: vertical ? 1 : 28,
                margin: vertical
                    ? const EdgeInsets.symmetric(vertical: 4)
                    : const EdgeInsets.symmetric(horizontal: 4),
                color: line),
            if (cards)
              icon(hidden ? AppIcons.show : AppIcons.memorize,
                  hidden ? context.l10n.mzShowAyah : context.l10n.mzHideAyah,
                  hidden ? c.revealAyah : c.hideAyah)
            else
              icon(hidden ? AppIcons.show : AppIcons.memorize,
                  hidden ? context.l10n.mzShowPage : context.l10n.mzHidePage,
                  hidden
                      ? () => c.revealPage(last)
                      : () => c.hidePage(first)),
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
                  padding: EdgeInsets.all(vertical ? 7 : 10),
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
        if (vertical) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: line),
            ),
            child: controls,
          );
        }
        final body = minimal
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
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
                  Tooltip(
                    message: cards ? context.l10n.mzPlayCards : context.l10n.mzPlay,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: c.atStart ? null : onPlay,
                      onLongPress: c.atStart ? null : onPlayPage,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(playing ? AppIcons.pause : AppIcons.play,
                            color: c.atStart
                                ? sub.withValues(alpha: .5)
                                : accent),
                      ),
                    ),
                  ),
                  if (onExitFocus != null)
                    icon(AppIcons.focusExit, context.l10n.fcExit, onExitFocus),
                  icon(AppIcons.close, context.l10n.mkEnd, onEnd),
                ]),
              ))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                if (!compact) ...[
                  caption,
                  const SizedBox(height: 4),
                ],
                FittedBox(fit: BoxFit.scaleDown, child: controls),
              ]);
        // Docked: centred, at most 720 wide on a wide window.
        if (!floating && !minimal) {
          return Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: body));
        }
        return Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: minimal
              ? const EdgeInsets.fromLTRB(8, 4, 4, 4)
              : const EdgeInsets.fromLTRB(12, 8, 8, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(minimal ? 999 : 22),
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

/// One-hand memorizing: a small pad in a bottom corner, where the thumb
/// rests — four zones, laid out as the screen's halves are: the left column
/// goes on, the right one goes back; the top row by words, the bottom row
/// by āyāt (as the screen's halves split them). Its guide — faint
/// outlines and arrows — is there to learn it by; hidden, the zones still
/// work.
class MemorizePad extends StatelessWidget {
  final MemorizeController controller;
  final Color ink, accent;
  final bool guide;
  final bool haptics;
  const MemorizePad({
    super.key,
    required this.controller,
    required this.ink,
    required this.accent,
    this.guide = true,
    this.haptics = true,
  });

  /// Each zone's size (two by two), and the gap between the word row and
  /// the āyah row, so a thumb aiming for one doesn't land on the other.
  static const zone = Size(84, 70);
  static const rowGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget cell(IconData icon, String tip, VoidCallback action) {
      final glyph = Icon(icon, size: 26, color: ink.withValues(alpha: .45));
      return Semantics(
        button: true,
        label: tip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (haptics) HapticFeedback.selectionClick();
            action();
          },
          child: Container(
            width: zone.width,
            height: zone.height,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: guide
                ? BoxDecoration(
                    color: accent.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: .28)),
                  )
                : null,
            alignment: Alignment.center,
            // The verse and page glyphs mirror in right-to-left text; set
            // them right to left so they point the way the text runs.
            child: guide
                ? Directionality(
                    textDirection: icon == AppIcons.nextVerse ||
                            icon == AppIcons.prevVerse
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: glyph)
                : null,
          ),
        ),
      );
    }

    // Fixed left to right: onward is leftward, as the text runs.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          cell(AppIcons.chevronLeft, context.l10n.mzNextWord, c.nextWord),
          cell(AppIcons.chevronRight, context.l10n.mzPrevWord, c.prevWord),
        ]),
        const SizedBox(height: rowGap),
        Row(mainAxisSize: MainAxisSize.min, children: [
          cell(AppIcons.nextVerse, context.l10n.mzNextVerse, c.nextVerse),
          cell(AppIcons.prevVerse, context.l10n.mzPrevVerse, c.prevVerse),
        ]),
      ]),
    );
  }
}

/// Memorize's tap settings, as rows for a [QGroup] (the muṣḥaf's settings
/// and the Hifz screen): what a tap does and, for one hand, the pad's
/// corner and guide.
List<Widget> memorizeTapRows(BuildContext context, AppSettings s) => [
      QRow(
        title: context.l10n.mzTap,
        subtitle: context.l10n.mzTapSub,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (v, label) in [
            ('play', context.l10n.mzTapPlay),
            ('word', context.l10n.mzTapWord),
            ('verse', context.l10n.mzTapVerse),
            ('split', context.l10n.mzTapSplit),
            ('pad', context.l10n.mzTapPad),
          ])
            ChoiceChip(
              label: Text(label),
              selected: s.memorizeTap == v,
              onSelected: (_) => s.update(() => s.memorizeTap = v),
            ),
        ]),
      ),
      if (s.memorizePad) ...[
        QRow(
          title: context.l10n.mzPadSide,
          control: QSegmented<String>(
            expand: false,
            options: [
              ('left', context.l10n.mzPadLeft, null),
              ('right', context.l10n.mzPadRight, null),
            ],
            value: s.memorizePadSide,
            onChanged: (v) => s.update(() => s.memorizePadSide = v),
          ),
        ),
        QRow(
          title: context.l10n.mzPadGuide,
          subtitle: context.l10n.mzPadGuideSub,
          control: QSwitch(
              value: s.memorizePadGuide,
              onChanged: (v) => s.update(() => s.memorizePadGuide = v)),
        ),
      ],
    ];
