import 'package:flutter/material.dart';

import '../../data/extra_letters.dart';
import '../../data/glyph_names.dart' show letterName;
import '../../data/kids_glosses.dart' show kidsExtraLetterNote;
import '../../widgets/common.dart' show MediaRow, highlightSpans;
import '../../kids_backdrops/kb_app.dart';
import '../../kids_backdrops/kb_components.dart';
import '../../kids_backdrops/kb_scene.dart' show kbC;
import 'kids_widgets.dart';

/// One "meet this character" card for a letter the 28-letter alphabet
/// doesn't cover but the muṣḥaf uses constantly — the hamza's four seated
/// forms, alif maqṣūrah, alif al-waṣl, and tāʼ marbūṭah. Complete on open,
/// same as the page it replaces: a single character with a single real
/// example is not something a multiple-choice question improves on, and the
/// stage's own quiz (Special Shapes' `kidsSpecialShapesQuiz`, or Tāʼ
/// Marbūṭah's own Test) already checks recognition right after.
///
/// Replaces `LetterDetail` — the full grown-up letter-detail screen, found
/// still opening here on a real device (Kids Mode is supposed to never
/// leave its own presentation). That screen's tracing/watch machinery and
/// its own quiz-variety picker are built for an adult reference page, not a
/// single card in a child's lesson.
class KidsExtraLetterLesson extends StatelessWidget {
  final String char;
  const KidsExtraLetterLesson({super.key, required this.char});

  @override
  Widget build(BuildContext context) {
    final letter = letterForAny(char)!;
    final note = kidsExtraLetterNote(context, char);
    final more = extraLetterMoreExamples[char] ?? const [];
    final words = [
      (letter.exampleWord, letter.exampleRef, char),
      for (final (word, ref, hl) in more.take(2)) (word, ref, hl),
    ];
    return KidsLessonScaffold(
      index: 0,
      total: 1,
      done: true,
      child: KidsCentered(
        // The design's Hamzah card (kb_screens.dart `KbHamzahScreen`): the
        // character on its tile, its name and note, then each real example on
        // a word block with its Listen / Watch pills.
        child: Builder(builder: (context) {
          final ui = kbUi(context);
          final base = kbText(38, kbC(ui.ink),
              family: kbFontQuran, weight: FontWeight.w400, height: 1.9);
          return KbSurface(
            color: ui.surface,
            edge: ui.edge,
            elev: KbElev.hero,
            radius: 32,
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: KbGlyphTile(char,
                      bg: ui.tile,
                      ink: ui.tileInk,
                      size: 110,
                      radius: 30,
                      fontSize: 66),
                ),
                const SizedBox(height: 18),
                Text(
                  letterName(context, letter),
                  textAlign: TextAlign.center,
                  style: kbText(30, kbC(ui.ink)),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    textAlign: TextAlign.center,
                    style: kbText(19, kbC(ui.inkSoft),
                        weight: FontWeight.w600, height: 1.35),
                  ),
                ],
                const SizedBox(height: 14),
                for (final (i, (word, ref, hl)) in words.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    decoration: BoxDecoration(
                        color: kbC(ui.wordBg),
                        borderRadius: BorderRadius.circular(22)),
                    child: Column(children: [
                      RichText(
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        textScaler: MediaQuery.textScalerOf(context),
                        text: TextSpan(
                          children: highlightSpans(word, hl, base,
                              base.copyWith(color: kbC(ui.linkInk))),
                        ),
                      ),
                      MediaRow(ref: ref),
                    ]),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}
