import 'package:flutter/material.dart';

import '../../core/geometry.dart';
import '../../core/theme.dart';
import '../../data/extra_letters.dart';
import '../../data/glyph_names.dart' show letterName;
import '../../widgets/common.dart' show MediaRow, highlightSpans;
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
    final p = kidsPal(context);
    final letter = letterForAny(char)!;
    final note = extraLetterNotes[char] ?? '';
    final more = extraLetterMoreExamples[char] ?? const [];
    return KidsLessonScaffold(
      index: 0,
      total: 1,
      done: true,
      child: Padding(
        padding: const EdgeInsets.only(top: Geo.gapLg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(Geo.gapLg),
                decoration: kidsCard(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        char,
                        textDirection: TextDirection.rtl,
                        style: quranicStyle(context, size: 56, color: p.accent),
                      ),
                    ),
                    const SizedBox(height: Geo.gapSm),
                    Text(
                      letterName(context, letter),
                      textAlign: TextAlign.center,
                      style: kidsStyle(
                        context,
                        size: 19,
                        weight: FontWeight.w800,
                      ),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: Geo.gapMd),
                      Text(
                        note,
                        textAlign: TextAlign.center,
                        style: kidsStyle(context, size: 13, color: p.textDim),
                      ),
                    ],
                    const SizedBox(height: Geo.gapMd),
                    Center(
                      child: RichText(
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: highlightSpans(
                            letter.exampleWord,
                            char,
                            quranicStyle(context, size: 30),
                            quranicStyle(context, size: 30, color: p.accent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Geo.gapSm),
                    Center(child: MediaRow(ref: letter.exampleRef)),
                    if (more.isNotEmpty) ...[
                      const SizedBox(height: Geo.gapMd),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Geo.gapMd,
                        runSpacing: Geo.gapSm,
                        children: [
                          for (final (word, ref, hl) in more.take(2))
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RichText(
                                  textDirection: TextDirection.rtl,
                                  text: TextSpan(
                                    children: highlightSpans(
                                      word,
                                      hl,
                                      quranicStyle(context, size: 20),
                                      quranicStyle(
                                        context,
                                        size: 20,
                                        color: p.accent,
                                      ),
                                    ),
                                  ),
                                ),
                                MediaRow(ref: ref),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
