import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../data/glyph_names.dart' show tashkilName;
import '../../data/letters.dart';
import '../../data/tanwin_allographs.dart';
import '../../data/tashkeel.dart';
import '../../data/word_pool.dart';
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

/// One question per tanwīn mark, asking which of the muṣḥaf's three shapes
/// carries the meaning [prompt] describes — "say it clearly", "blend into a
/// hum", "turns into an m" — over the three real allographs of that mark, so
/// the answer turns on the SHAPE, not the letter it happens to sit on.
/// Filed under `kids.tanwin.<allographId>`, so a miss here reaches the
/// Warm-up under the same id [KidsTanwinShapesLesson] would use if it ever
/// graded (it does not — it is Learn content).
List<QuizQuestion> _tanwinShapeQuestions(BuildContext context, math.Random r) {
  final byMark = <String, List<TanwinAllograph>>{};
  for (final a in tanwinAllographs) {
    byMark.putIfAbsent(a.tanwinId, () => []).add(a);
  }
  String promptFor(String form) => switch (form) {
        'parallel' => context.l10n.kidsTanwinAskClear,
        'alternate' => context.l10n.kidsTanwinAskHum,
        _ => context.l10n.kidsTanwinAskMim,
      };
  return [
    for (final entry in byMark.entries)
      for (final answer in entry.value)
        () {
          final order = [...entry.value]..shuffle(r);
          return QuizQuestion(
            prompt: promptFor(answer.form),
            reviewId: 'kids.tanwin.${answer.id}',
            options: [for (final a in order) a.highlight],
            correct: order.indexOf(answer),
            optionsAreArabic: true,
            optionColumns: 3,
            optionAspect: 1.4,
          );
        }(),
  ];
}

/// The tanwīn stage's Test: the syllable checks every drill stage gets, plus
/// [_tanwinShapeQuestions] over the shapes [KidsTanwinShapesLesson] teaches —
/// the one drill Test that also checks a WRITTEN distinction, not only sound.
QuizScreen kidsTanwinTest(
  BuildContext context, {
  required String progressId,
  math.Random? rng,
}) {
  final r = rng ?? _rng;
  final sound = kidsSyllableQuiz(
    context,
    title: context.l10n.unitTanwin,
    progressId: progressId,
    markIds: const ['fathatan', 'kasratan', 'dammatan'],
    rng: r,
  ).questions;
  final shapes = _tanwinShapeQuestions(context, r)..shuffle(r);
  final qs = [...pickN(sound, kidsQuizLength - 3, r), ...shapes.take(3)]
    ..shuffle(r);
  return QuizScreen(
    title: context.l10n.unitTanwin,
    progressId: progressId,
    questions: qs,
  );
}

/// The marks a word-level check can honestly be asked about: each is written
/// with a single code point, so "does this word have it?" is a plain lookup.
/// (The tanwīn are not: the muṣḥaf writes each of them in more than one form.)
const _spottable = {'fatha', 'kasra', 'damma', 'sukun', 'shadda'};

/// [l] carrying [m] — 'بَ'.
String _syllable(ArabicLetter l, TashkilItem m) =>
    '${l.char}${m.mark.substring(1)}';

/// A round of syllable checks over [markIds]: a letter with a mark, and how it
/// SOUNDS; a sound, and which letter-with-a-mark says it; and — for the marks a
/// word can be searched for — which real word has the mark. Three formats,
/// where it was one prompt asked eight times over.
///
/// The wrong options are the honest mistakes: the same letter with a different
/// mark, or a neighbouring letter with the same one. Marks are dealt out from a
/// shuffled deck, so every mark is asked about whatever the draw.
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
  ]..shuffle(r);
  final pool = letters.where((l) => l.char != 'ا').toList()..shuffle(r);
  final spotMarks = [
    for (final id in markIds)
      if (_spottable.contains(id)) id,
  ]..shuffle(r);

  final qs = <QuizQuestion>[];
  // Two word-search questions where the marks allow them; the rest split
  // between "how does it sound?" and "which one sounds like this?".
  final spots = spotMarks.isEmpty ? 0 : 2;
  for (var i = 0; i < spots; i++) {
    final q = _whichWordHas(context, spotMarks[i % spotMarks.length], r);
    if (q != null) qs.add(q);
  }
  var k = 0;
  while (qs.length < kidsQuizLength && k < pool.length) {
    final l = pool[k];
    final m = marks[k % marks.length];
    final next = pool[(k + 1) % pool.length];
    final answer = kidsSyllableSound(l, m);
    if (k.isEven) {
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
          arabic: _syllable(l, m),
          reviewId: 'kids.syllable.${m.id}.${l.char}',
          options: o.options,
          correct: o.correct,
        ),
      );
    } else {
      // The syllables that could be mistaken for it — but never one that
      // SOUNDS the same, or two options would be right.
      final wrong = <String>{
        for (final other in marks)
          if (other != m && kidsSyllableSound(l, other) != answer)
            _syllable(l, other),
        if (kidsSyllableSound(next, m) != answer) _syllable(next, m),
        for (final other in marks)
          if (kidsSyllableSound(next, other) != answer) _syllable(next, other),
      }.toList();
      final o = buildOptions(_syllable(l, m), wrong, r);
      qs.add(
        QuizQuestion(
          prompt: context.l10n.kidsWhichSays(answer),
          reviewId: 'kids.syllable.${m.id}.${l.char}',
          options: o.options,
          correct: o.correct,
          optionsAreArabic: true,
          optionColumns: 4,
          optionAspect: 1.0,
        ),
      );
    }
    k++;
  }
  qs.shuffle(r);
  return QuizScreen(title: title, progressId: progressId, questions: qs);
}

/// Whether [word] carries the mark [markId] — read off its code points, so
/// the answer to every question is checked by the machine, never authored.
bool kidsWordHasMark(String markId, String word) => switch (markId) {
  'fatha' => word.contains('\u064E'),
  'kasra' => word.contains('\u0650'),
  'damma' => word.contains('\u064F'),
  'sukun' => word.contains('\u06E1') || word.contains('\u0652'),
  'shadda' => word.contains('\u0651'),
  _ => throw ArgumentError('no word-level test for mark $markId'),
};

/// "Which word has [markId]?" — one real word that carries it among three that
/// do not, or null when the words to hand are too few to ask it fairly.
/// [answer] fixes the word that carries the mark; otherwise one is drawn.
QuizQuestion? _whichWordHas(
  BuildContext context,
  String markId,
  math.Random r, {
  String? answer,
}) {
  final mark = tashkil.firstWhere((t) => t.id == markId);
  final name = '${tashkilName(context, mark)} (${mark.mark})';
  final all = quranicExampleWords();
  final with_ = [
    for (final w in all)
      if (kidsWordHasMark(markId, w)) w,
  ];
  final without = [
    for (final w in all)
      if (!kidsWordHasMark(markId, w)) w,
  ];
  if (with_.isEmpty || without.length < 3) return null;
  final o = buildOptions(
    answer ?? with_[r.nextInt(with_.length)],
    pickN(without, 3, r),
    r,
  );
  return QuizQuestion(
    prompt: context.l10n.kidsWhichWordHas(name),
    options: o.options,
    correct: o.correct,
    optionsAreArabic: true,
  );
}

/// Spotting a mark inside real words: five "which word has it?" (one word of
/// four) and three "tap every word with it" (several of six). A mark is
/// something a child SEES before it is anything else, so what a Test can
/// honestly ask is whether they can find it in a word — ḥarakāt, sukūn and
/// shaddah alike ([kidsWordHasMark] says which are supported).
///
/// The words are drawn without replacement, so a round never asks about one
/// word twice.
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
  final all = quranicExampleWords();
  final with_ = [
    for (final w in all)
      if (kidsWordHasMark(markId, w)) w,
  ];
  final without = [
    for (final w in all)
      if (!kidsWordHasMark(markId, w)) w,
  ];
  final singles = kidsQuizLength - 3;
  final answers = pickN(with_, singles, r);
  final qs = <QuizQuestion>[
    for (final w in answers) _whichWordHas(context, markId, r, answer: w)!,
  ];
  for (var i = singles; i < kidsQuizLength; i++) {
    final yes = pickN(with_, 2 + r.nextInt(2), r);
    final options = [...yes, ...pickN(without, 6 - yes.length, r)]..shuffle(r);
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
    for (final id in const ['fatha', 'kasra', 'damma', 'sukun', 'shadda'])
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
