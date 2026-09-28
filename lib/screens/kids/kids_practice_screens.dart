import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/letter_audio.dart';
import '../../core/settings.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart';
import '../../data/letters.dart';
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kWhite, kbC;
import 'kids_widgets.dart';

/// The letters a child has already met — the same set the Home screen's
/// letter path marks "done" or "current". Flashcards/Listening review this
/// set rather than the whole alphabet, so early practice isn't drowned in
/// letters not taught yet.
List<ArabicLetter> _reviewableLetters(ProgressStore prog) {
  final doneCount = (prog.kidsLettersLearned + 1).clamp(1, kidsLetterPath.length);
  return kidsLetterPath.sublist(0, doneCount);
}

/// A flip-card review of every letter learned so far: tap to reveal the name
/// and an example word, then swipe to the next.
class KidsFlashcardsScreen extends StatefulWidget {
  const KidsFlashcardsScreen({super.key});
  @override
  State<KidsFlashcardsScreen> createState() => _KidsFlashcardsScreenState();
}

class _KidsFlashcardsScreenState extends State<KidsFlashcardsScreen> {
  int _i = 0;
  bool _flipped = false;

  Widget _card(BuildContext context, ArabicLetter letter, double width) {
    final ui = kbUi(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      // The design's big lesson card; tap it to turn it over.
      child: KbSurface(
        key: ValueKey('$_i-$_flipped'),
        color: ui.surface,
        edge: ui.edge,
        elev: KbElev.big,
        radius: 30,
        width: width,
        height: width * 1.25,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        onTap: () => setState(() => _flipped = !_flipped),
        child: _flipped
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(letterName(context, letter),
                      textAlign: TextAlign.center,
                      style: kbText(28, kbC(ui.ink))),
                  const SizedBox(height: 14),
                  KidsQuranWord(letter.exampleWord, size: 30),
                ],
              )
            : Text(letter.char,
                textDirection: TextDirection.rtl,
                style: kbText(110, kbC(ui.ink),
                    family: kbFontArabic,
                    weight: FontWeight.w600,
                    height: 1.3)),
      ),
    );
  }

  Widget _body(BuildContext context, ArabicLetter letter, int poolLength) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: LayoutBuilder(builder: (context, c) {
              final width = c.maxHeight < c.maxWidth
                  ? (c.maxHeight * .75).clamp(180.0, 320.0)
                  : (c.maxWidth * .8).clamp(180.0, 320.0);
              return _card(context, letter, width);
            }),
          ),
        ),
        const SizedBox(height: 16),
        KidsLessonSubtitle(context.l10n.kidsTapToFlip,
            fontSize: 18, align: TextAlign.center),
        const SizedBox(height: 20),
        KidsNextButton(
          context.l10n.kidsNextCard,
          onTap: () => setState(() {
            _i = (_i + 1) % poolLength;
            _flipped = false;
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final pool = _reviewableLetters(prog);
    final letter = pool[_i % pool.length];
    return KidsScreenScaffold(
      caption: context.l10n.kidsFlashcards,
      child: _body(context, letter, pool.length),
    );
  }
}

/// Says each learned letter out loud, one row per letter — the drill this
/// screen exists for, so it goes through [LetterAudio] rather than reciting
/// the whole āyah the letter's example word happens to sit in.
class KidsListeningScreen extends StatelessWidget {
  const KidsListeningScreen({super.key});

  Widget _row(BuildContext context, ArabicLetter letter) {
    final ui = kbUi(context);
    return KbSurface(
      color: ui.surface,
      edge: ui.edge,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => LetterAudio.playOrComingSoon(context, letter),
      child: Row(children: [
        KbGlyphTile(letter.char, bg: ui.tile, ink: ui.tileInk, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Text(letterName(context, letter),
              style: kbText(20, kbC(ui.ink))),
        ),
        // Icon-only, so the accent face is allowed (UI_SPEC §1.5).
        KbSurface(
          color: ui.accent,
          edge: ui.accentEdge,
          elev: KbElev.edge4,
          circle: true,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: KbIcon('play_arrow', size: 26, color: kbC(kWhite)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final pool = _reviewableLetters(prog);
    return KidsScreenScaffold(
      caption: context.l10n.kidsListening,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.none,
        itemCount: pool.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) => _row(context, pool[i]),
      ),
    );
  }
}
