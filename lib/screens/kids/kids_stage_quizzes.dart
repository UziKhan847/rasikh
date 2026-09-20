import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../data/glyph_names.dart' show tashkilName;
import '../../data/letters.dart';
import '../../data/tashkeel.dart';
import '../../data/wasl.dart';
import '../../widgets/common.dart'
    show QuizQuestion, QuizScreen, buildOptions, pickN;
import 'kids_checkpoint_quiz.dart'
    show kidsFormsCheckpoint, kidsLetterCheckpoint;
import 'kids_syllable_drill.dart' show kidsSyllableSound;
import 'kids_widgets.dart' show kidsQuizLength;

/// Tests for the stages whose lessons are not check-driven themselves — the
/// ḥarakāt, tanwīn, sukūn and shaddah drills, and the closing review — built
/// from the same reviewed data the lessons teach, in the same short words.
/// (The lesson-shaped stages — waqf, waṣl, words, muqaṭṭaʿāt, tajwīd, sun and
/// moon — run their own checks as a `quiz:` mode instead; see each lesson.)
///
/// They run on [QuizScreen], the shared quiz shell: it is the engine, not a
/// grown-up page — its prompts, option tiles and result card all take the
/// kids palette, and what makes a Test feel grown-up is the QUESTIONS, which
/// is what these replace: no prose about what a mark "does", no "which rule
/// lives in this verse", no surah numbers to recall.

final _rng = math.Random();

/// "How does this sound?" over syllables that carry one of [markIds]:
/// a letter with a mark, and its sound to pick from four. Mixes marks and
/// letters so the wrong options are the honest mistakes — the same letter
/// with a different mark, or a neighbouring letter with the same one.
///
/// Review ids and answers match the drill's own checks
/// (`kids.syllable.<mark>.<letter>` → the sound), so a miss here and a miss
/// there are the same card in the Warm-up.
QuizScreen kidsSyllableQuiz(
  BuildContext context, {
  required String title,
  required String progressId,
  required List<String> markIds,
  math.Random? rng,
}) {
  final r = rng ?? _rng;
  final marks = [
    for (final id in markIds) tashkil.firstWhere((t) => t.id == id),
  ];
  final pool = letters.where((l) => l.char != 'ا').toList()..shuffle(r);
  final qs = <QuizQuestion>[];
  for (final (i, l) in pool.take(kidsQuizLength).indexed) {
    // Cycle the marks rather than draw at random: every mark is asked about,
    // whatever the draw.
    final m = marks[i % marks.length];
    final next = pool[(i + 1) % pool.length];
    final answer = kidsSyllableSound(l, m);
    final wrong = <String>{
      for (final other in marks)
        if (other != m) kidsSyllableSound(l, other),
      kidsSyllableSound(next, m),
      for (final other in marks) kidsSyllableSound(next, other),
    }.toList();
    final o = buildOptions(answer, wrong, r);
    qs.add(
      QuizQuestion(
        prompt: context.l10n.qpHowDoesThisSound,
        arabic: '${l.char}${m.mark.substring(1)}',
        reviewId: 'kids.syllable.${m.id}.${l.char}',
        options: o.options,
        correct: o.correct,
      ),
    );
  }
  qs.shuffle(r);
  return QuizScreen(title: title, progressId: progressId, questions: qs);
}

/// Real Qurʼānic words drawn from the marks' and waṣl's own examples — every
/// one already checked verbatim against the muṣḥaf text by the data tests.
List<String> _quranicWords() => {
  for (final t in tashkil) ...[
    ...t.example.split(' '),
    for (final e in t.moreExamples) ...e.$1.split(' '),
  ],
  for (final w in waslItems) ...[
    ...w.example.split(' '),
    for (final e in w.moreExamples) ...e.$1.split(' '),
  ],
}.where((w) => w.trim().isNotEmpty && !w.contains('\u0640')).toList();

/// Whether [word] carries the mark [markId] — read off its code points, so
/// the answer to every question is checked by the machine, never authored.
bool kidsWordHasMark(String markId, String word) => switch (markId) {
  'sukun' => word.contains('\u06E1') || word.contains('\u0652'),
  'shadda' => word.contains('\u0651'),
  _ => throw ArgumentError('no word-level test for mark $markId'),
};

/// Spotting a mark inside real words: five "which word has it?" (one word of
/// four) and three "tap every word with it" (several of six). Sukūn and
/// shaddah are marks a child SEES before they are anything else, so what a
/// Test can honestly ask is whether they can find them in a word.
QuizScreen kidsMarkSpotQuiz(
  BuildContext context, {
  required String title,
  required String progressId,
  required String markId,
  math.Random? rng,
}) {
  final r = rng ?? _rng;
  final mark = tashkil.firstWhere((t) => t.id == markId);
  final name = '${tashkilName(context, mark)} (${mark.mark})';
  final all = _quranicWords();
  final with_ = [
    for (final w in all)
      if (kidsWordHasMark(markId, w)) w,
  ];
  final without = [
    for (final w in all)
      if (!kidsWordHasMark(markId, w)) w,
  ];
  final qs = <QuizQuestion>[];
  for (var i = 0; i < kidsQuizLength; i++) {
    if (i < kidsQuizLength - 3) {
      final answer = with_[r.nextInt(with_.length)];
      final o = buildOptions(answer, pickN(without, 3, r), r);
      qs.add(
        QuizQuestion(
          prompt: context.l10n.kidsWhichWordHas(name),
          options: o.options,
          correct: o.correct,
          optionsAreArabic: true,
        ),
      );
    } else {
      final yes = pickN(with_, 2 + r.nextInt(2), r);
      final options = [...yes, ...pickN(without, 6 - yes.length, r)]
        ..shuffle(r);
      qs.add(
        QuizQuestion(
          prompt: context.l10n.kidsFindEvery(name),
          options: options,
          correctSet: {
            for (final (k, w) in options.indexed)
              if (yes.contains(w)) k,
          },
          optionsAreArabic: true,
        ),
      );
    }
  }
  qs.shuffle(r);
  return QuizScreen(title: title, progressId: progressId, questions: qs);
}

/// The Review stage's Test: a little of everything the path has taught —
/// letters, joining shapes, syllables, and marks in words — mixed, so it
/// checks the whole rather than the last stage.
QuizScreen kidsReviewQuiz(
  BuildContext context, {
  required String title,
  required String progressId,
  math.Random? rng,
}) {
  final r = rng ?? _rng;
  final letterQs = kidsLetterCheckpoint(
    context,
    progressId: progressId,
    upTo: letters.length,
  ).questions;
  final formQs = kidsFormsCheckpoint(
    context,
    progressId: progressId,
    upTo: letters.length,
  ).questions;
  final syllableQs = kidsSyllableQuiz(
    context,
    title: title,
    progressId: progressId,
    markIds: const [
      'fatha',
      'kasra',
      'damma',
      'fathatan',
      'kasratan',
      'dammatan',
    ],
    rng: r,
  ).questions;
  final markQs = [
    for (final id in const ['sukun', 'shadda'])
      ...kidsMarkSpotQuiz(
        context,
        title: title,
        progressId: progressId,
        markId: id,
        rng: r,
      ).questions.where((q) => q.correctSet == null),
  ];
  final qs = [
    ...pickN(letterQs, 3, r),
    ...pickN(formQs, 2, r),
    ...pickN(syllableQs, 2, r),
    ...pickN(markQs, 1, r),
  ]..shuffle(r);
  return QuizScreen(title: title, progressId: progressId, questions: qs);
}
