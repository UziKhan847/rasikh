import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart' show ProgressStore;
import '../../data/extra_letters.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart';
import '../../data/letters.dart';
import '../../widgets/common.dart';
import '../dyslexia_screen.dart' show mistakeReviewQuiz;
import '../lessons/forms_quizzes.dart' show contextualForms;
import 'kids_lookalike_quiz.dart' show kidsConfusableOptions;

/// How many lessons a stage runs before it stops and checks.
const kidsCheckpointEvery = 5;

/// Questions in one checkpoint round. Ten is what every other quiz in the app
/// asks, and at the first checkpoint it is exactly two goes at each of the
/// five letters — one in each direction.
const _questions = 10;

final _rng = math.Random();

/// A **cumulative** check-up over the first [upTo] letters of the path: not
/// the five just learned, but everything met in this stage so far. That is
/// the point of it — letter five is fresh, letter one is three days old, and
/// only a cumulative round notices when the old one has faded.
///
/// Two directions, alternating, because recognising a shape and recalling one
/// are different skills and a round of nothing but "which letter is this?"
/// only ever drills the first:
///
///  * shape → name (the glyph is shown, the names are the options);
///  * name → shape (the name is asked for, the glyphs are the options).
///
/// Distractors are drawn from the same first [upTo] letters, never the whole
/// alphabet: an option the child has not met yet is not a distractor, it is
/// noise — and within that pool a letter's own look-alikes (ب ↔ ت ↔ ث) are
/// chosen first, since telling those apart is the actual skill
/// (`kidsConfusableOptions`).
QuizScreen kidsLetterCheckpoint(
  BuildContext context, {
  required String progressId,
  required int upTo,
}) {
  final pool = kidsLetterPath.take(upTo).toList();
  final qs = <QuizQuestion>[];

  for (final (i, l) in pickN(pool, _questions, _rng).indexed) {
    final name = letterName(context, l);
    if (i.isEven) {
      final o = kidsConfusableOptions(
        answer: l,
        pool: pool,
        show: (x) => letterName(context, x),
        rng: _rng,
      );
      qs.add(
        QuizQuestion(
          prompt: context.l10n.qpWhichLetterIsThis,
          arabic: l.char,
          reviewId: 'letter.${l.char}',
          options: o.options,
          correct: o.correct,
        ),
      );
    } else {
      final o = kidsConfusableOptions(
        answer: l,
        pool: pool,
        show: (x) => x.char,
        rng: _rng,
      );
      qs.add(
        QuizQuestion(
          prompt: context.l10n.qpWhichOneIs(name),
          reviewId: 'letter.${l.char}',
          options: o.options,
          correct: o.correct,
          optionsAreArabic: true,
          optionColumns: 4,
          optionAspect: 1.0,
        ),
      );
    }
  }
  qs.shuffle(_rng);
  return QuizScreen(
    title: context.l10n.kidsCheckpoint,
    progressId: progressId,
    questions: qs,
  );
}

/// The Special Shapes stage's own quiz — over what that stage actually
/// taught a child: the six extra characters (ء أ إ ؤ ئ ى) the 28-letter
/// alphabet leaves out. It used to reuse the grown-up Joining Forms unit's
/// Practice round, which also asked about hamza carriers, but that question
/// picks one of five hamza-seat glyphs at random and, for the seatless ء,
/// asks "Which is Hamzah?" over five options that are all, in a real sense,
/// hamzah — unanswerable without already knowing this app's own naming.
/// Ligatures, kāf wraps, stacks and heights are hand-drawn shapes with no
/// text form a quiz option can show, so they stay lesson-only.
///
/// Same two directions as [kidsLetterCheckpoint]: shape → name, and
/// name → shape — recognising and recalling are different skills.
QuizScreen kidsSpecialShapesQuiz(
  BuildContext context, {
  required String progressId,
}) {
  const chars = ['ء', 'أ', 'إ', 'ؤ', 'ئ', 'ى'];
  final pool = [for (final ch in chars) letterForAny(ch)!];
  final names = [for (final l in pool) letterName(context, l)];
  final glyphs = [for (final l in pool) l.char];
  final qs = <QuizQuestion>[];

  for (final (i, l) in pool.indexed) {
    final name = letterName(context, l);
    if (i.isEven) {
      final o = buildOptions(name, names, _rng);
      qs.add(
        QuizQuestion(
          prompt: context.l10n.qpWhichLetterIsThis,
          arabic: l.char,
          reviewId: 'extra.${l.char}',
          options: o.options,
          correct: o.correct,
        ),
      );
    } else {
      final o = buildOptions(l.char, glyphs, _rng);
      qs.add(
        QuizQuestion(
          prompt: context.l10n.qpWhichOneIs(name),
          reviewId: 'extra.${l.char}',
          options: o.options,
          correct: o.correct,
          optionsAreArabic: true,
          optionColumns: 4,
          optionAspect: 1.0,
        ),
      );
    }
  }
  qs.shuffle(_rng);
  return QuizScreen(
    title: context.l10n.formsQuiz,
    progressId: progressId,
    questions: qs,
  );
}

/// Diacritics, dagger alif and the small high signs of the muṣḥaf, plus the
/// tatweel joiner — everything that rides on a letter rather than being one.
/// The same set `contextualForms` skips.
final _riders = RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u08F0-\u08FF\u0640]');

/// [char]'s first appearance in [word] as the shape it really takes there, and
/// the gap it leaves — the letter with the marks riding on it — or null when
/// it is absent or would stand alone (an isolated shape needs no context).
///
/// The shape comes from `contextualForms`, the one place these are derived
/// from a letter's neighbours (a kāf after a non-joiner is INITIAL, whatever
/// its position in the word) and the one that has its own test.
({String form, String gap})? _wordGap(String word, String char) {
  final forms = contextualForms(word);
  final k = forms.indexWhere((f) => f.char == char);
  if (k < 0 || forms[k].form == 'iso') return null;
  // Where the k-th base letter starts, counting the way contextualForms does.
  var seen = -1;
  var start = -1;
  for (var i = 0; i < word.length; i++) {
    if (_riders.hasMatch(word[i]) || word[i].trim().isEmpty) continue;
    if (++seen == k) {
      start = i;
      break;
    }
  }
  if (start < 0) return null;
  var end = start + 1;
  while (end < word.length && _riders.hasMatch(word[end])) {
    end++;
  }
  return (form: forms[k].form, gap: word.substring(start, end));
}

/// The joining-forms stage's cumulative check-up, over the first [upTo]
/// letters' real shapes. Three directions, like [kidsLetterCheckpoint]:
///
///  * a shape in context → which letter is it?
///  * a letter and a position → which shape is that?
///  * a real word with one letter lifted out → which shape fills the gap?
///
/// The last is the one that matters for reading: the shapes are met one at a
/// time in the lessons, but a word is read with all of them at once, and only
/// here does a child pick the right one FOR a place in a real word.
///
/// Initial and medial questions are asked only about letters that join on
/// both sides: a dāl has no start or middle shape, and showing a tatweel run
/// where one would be teaches a form the muṣḥaf does not contain.
QuizScreen kidsFormsCheckpoint(
  BuildContext context, {
  required String progressId,
  required int upTo,
}) {
  final pool = kidsLetterPath.take(upTo).toList();
  final names = [for (final l in pool) letterName(context, l)];
  final joiners = [
    for (final l in pool)
      if (l.joins) l,
  ];
  final qs = <QuizQuestion>[];

  String formOf(ArabicLetter l, int idx) =>
      [l.initial, l.medial, l.finalForm][idx];
  String formName(int idx) => ['ini', 'med', 'fin'][idx];
  String posLabel(int idx) => [
    context.l10n.formStart,
    context.l10n.formMiddle,
    context.l10n.formEnd,
  ][idx];

  for (final (i, l) in pickN(pool, _questions, _rng).indexed) {
    // Position 2 (final) is the only one a non-joiner really has.
    final idx = l.joins ? _rng.nextInt(3) : 2;
    final name = letterName(context, l);

    // Every third question is a gap in a real word — when this letter has an
    // example in which it takes a joined shape, else it falls through to the
    // "which shape" question below.
    if (i % 3 == 2 && l.joins) {
      final gaps = [
        for (final ex in letterExamples[l.char] ?? const <LetterExample>[])
          if (_wordGap(ex.word, l.char) case final g?) (ex.word, g),
      ];
      if (gaps.isNotEmpty) {
        final (word, g) = gaps[_rng.nextInt(gaps.length)];
        final shapes = {
          'ini': l.initial,
          'med': l.medial,
          'fin': l.finalForm,
          'iso': l.char,
        };
        final o = buildOptions(shapes[g.form]!, shapes.values.toList(), _rng);
        qs.add(
          QuizQuestion(
            prompt: context.l10n.qpPickLetterAndForm(name),
            arabic: word,
            blank: g.gap,
            reviewId: 'letter.form.${l.char}.${g.form}',
            options: o.options,
            correct: o.correct,
            optionsAreArabic: true,
            optionColumns: 4,
            optionAspect: 1.0,
            explain: context.l10n.lookPastJoins,
          ),
        );
        continue;
      }
    }

    if (i.isEven) {
      final o = buildOptions(name, names, _rng);
      qs.add(
        QuizQuestion(
          prompt: context.l10n.qpShapeBelongsTo,
          arabic: formOf(l, idx),
          reviewId: 'letter.form.${l.char}.${formName(idx)}',
          options: o.options,
          correct: o.correct,
          explain: context.l10n.lookPastJoins,
        ),
      );
    } else {
      // The distractors are the SAME position of other letters, so the answer
      // turns on the letter's own skeleton rather than on which option happens
      // to have a tail on the correct side.
      final others = (idx == 2 ? pool : joiners).where((x) => x != l).toList();
      if (others.length < 3) continue;
      final o = buildOptions(formOf(l, idx), [
        formOf(l, idx),
        for (final x in others) formOf(x, idx),
      ], _rng);
      qs.add(
        QuizQuestion(
          prompt: context.l10n.qpFormOfAt(name, posLabel(idx)),
          reviewId: 'letter.form.${l.char}.${formName(idx)}',
          options: o.options,
          correct: o.correct,
          optionsAreArabic: true,
          optionColumns: 4,
          optionAspect: 1.0,
        ),
      );
    }
  }
  qs.shuffle(_rng);
  return QuizScreen(
    title: context.l10n.kidsCheckpoint,
    progressId: progressId,
    questions: qs,
  );
}

/// The Warm-up: a short round over whatever this child has missed and is due
/// to see again — the same spaced-repetition queue every quiz in the app
/// already files misses into (`ProgressStore.recordMiss`), which Kids Mode
/// had no way to open until now. Reuses [mistakeReviewQuiz] (a pure builder
/// over that queue, not a grown-up screen) under its own progress id, so a
/// finished Warm-up counts as the day's activity but never as a path stage.
///
/// **Every third card is the mascot's mistake** ([_mascotSlip]): it "answers"
/// the card wrongly and the child is asked to fix it. Children work harder for
/// a character they are helping than for themselves, most of all the ones who
/// find this hardest, and it takes the sting out of being wrong — the mistake
/// on screen is the mascot's. Same options, same answer, same review-queue
/// entry as the plain card: only the framing changes.
QuizScreen kidsWarmUpQuiz(
  BuildContext context,
  ProgressStore prog, {
  math.Random? rng,
}) {
  final r = rng ?? _rng;
  final base = mistakeReviewQuiz(
    context,
    prog,
    title: context.l10n.kidsWarmUp,
    progressId: 'kids.warmup',
  );
  return QuizScreen(
    title: base.title,
    progressId: base.progressId,
    questions: [
      for (final (i, q) in base.questions.indexed)
        i % 3 == 2 ? _mascotSlip(context, q, r) : q,
    ],
  );
}

/// [q], asked as "Oops — I think this is X. Can you fix my mistake?" where X
/// is one of its WRONG options. A question with nothing wrong to say (a
/// single option, or a multi-select) is returned unchanged.
QuizQuestion _mascotSlip(BuildContext context, QuizQuestion q, math.Random r) {
  if (q.correctSet != null || q.sequence != null || q.correct < 0) return q;
  final wrong = [
    for (var i = 0; i < q.options.length; i++)
      if (i != q.correct) q.options[i],
  ];
  if (wrong.isEmpty) return q;
  return QuizQuestion(
    prompt: context.l10n.kidsMascotSlip(wrong[r.nextInt(wrong.length)]),
    arabic: q.arabic,
    highlight: q.highlight,
    options: q.options,
    correct: q.correct,
    optionsAreArabic: q.optionsAreArabic,
    explain: q.explain,
    reviewId: q.reviewId,
    optionColumns: q.optionColumns,
    optionAspect: q.optionAspect,
    audioRef: q.audioRef,
    skippable: q.skippable,
  );
}
