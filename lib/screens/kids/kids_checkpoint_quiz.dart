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
import 'kids_lookalike_quiz.dart'
    show kidsConfusableOptions, kidsConfusablesIn;

/// How many lessons a stage runs before it stops and checks.
const kidsCheckpointEvery = 5;

/// Questions in one checkpoint round. Ten is what every other quiz in the app
/// asks, and at the first checkpoint it is exactly two goes at each of the
/// five letters — one in each direction.
const _questions = 10;

/// How many of a joining-shapes round are "drag the shape into the word".
const _gapQuestions = 2;

final _rng = math.Random();

/// Draws up to [n] questions from [makers] — each one distinct way of asking
/// one distinct thing — WITHOUT replacement, skipping any that cannot be built
/// (a maker returns null). This is what keeps a round from asking the same
/// question twice: a round used to be `pickN(letters, 10)` with the direction
/// pinned to the question's position, so a five-letter checkpoint asked ten
/// questions of five letters and could put one letter in the same direction
/// twice.
List<QuizQuestion> _draw(List<QuizQuestion? Function()> makers, int n) {
  final order = [...makers]..shuffle(_rng);
  final out = <QuizQuestion>[];
  for (final make in order) {
    if (out.length >= n) break;
    final q = make();
    if (q != null) out.add(q);
  }
  return out;
}

/// The dots a letter is shown with — null for a dotless letter, and for ي,
/// which the muṣḥaf font draws dotless when it stands alone (see
/// `dotsDescForLetter`), so asking for it by its dots would contradict the
/// glyph on screen.
String? _dotSignature(ArabicLetter l) =>
    l.dotCount == 0 || l.char == 'ي' ? null : '${l.dotCount}.${l.dotPos}';

/// A **cumulative** check-up over the first [upTo] letters of the path: not
/// the five just learned, but everything met in this stage so far. That is
/// the point of it — letter five is fresh, letter one is three days old, and
/// only a cumulative round notices when the old one has faded.
///
/// Several ways of asking, because recognising a shape, recalling one and
/// knowing what is on it are different skills, and a round of nothing but
/// "which letter is this?" only ever drills the first:
///
///  * shape → name (the glyph is shown, the names are the options);
///  * name → shape (the name is asked for, the glyphs are the options);
///  * dots → shape ("which letter has 2 dots below?");
///  * the alphabet's own order (tap three letters in order).
///
/// Every question a round asks is a different one (see [_draw]), so a round is
/// never a letter twice in the same way, and a retake is a different set.
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

  QuizQuestion shapeToName(ArabicLetter l) {
    final o = kidsConfusableOptions(
      answer: l,
      pool: pool,
      show: (x) => letterName(context, x),
      rng: _rng,
    );
    return QuizQuestion(
      prompt: context.l10n.qpWhichLetterIsThis,
      arabic: l.char,
      reviewId: 'letter.${l.char}',
      options: o.options,
      correct: o.correct,
    );
  }

  QuizQuestion nameToShape(ArabicLetter l) {
    final o = kidsConfusableOptions(
      answer: l,
      pool: pool,
      show: (x) => x.char,
      rng: _rng,
    );
    return QuizQuestion(
      prompt: context.l10n.qpWhichOneIs(letterName(context, l)),
      reviewId: 'letter.${l.char}',
      options: o.options,
      correct: o.correct,
      optionsAreArabic: true,
      optionColumns: 4,
      optionAspect: 1.0,
    );
  }

  QuizQuestion? dotsToShape(ArabicLetter l) {
    final sig = _dotSignature(l);
    if (sig == null) return null;
    // Every option but the answer has a DIFFERENT dot signature — else two of
    // them would be right — and the answer's look-alikes come first, since
    // they differ from it by little but the dots.
    final others = [
      for (final x in pool)
        if (x.char != 'ي' && _dotSignature(x) != sig) x,
    ];
    if (others.length < 3) return null;
    final near = kidsConfusablesIn(l, others)..shuffle(_rng);
    final far = [
      for (final x in others)
        if (!near.contains(x)) x,
    ]..shuffle(_rng);
    final options = [l, ...[...near, ...far].take(3)].map((x) => x.char).toList()
      ..shuffle(_rng);
    return QuizQuestion(
      prompt: context.l10n.kidsWhichHasDots(
        dotsDesc(context, l.dotCount, l.dotPos),
      ),
      reviewId: 'letter.${l.char}',
      options: options,
      correct: options.indexOf(l.char),
      optionsAreArabic: true,
      optionColumns: 4,
      optionAspect: 1.0,
    );
  }

  QuizQuestion? alphabetOrder() {
    if (pool.length < 3) return null;
    final three = ([...pool]..shuffle(_rng)).take(3).toList()
      ..sort((a, b) => pool.indexOf(a).compareTo(pool.indexOf(b)));
    final sequence = [for (final l in three) l.char];
    final options = [...sequence];
    // Never offered already in order — that would be a question with nothing
    // to do.
    do {
      options.shuffle(_rng);
    } while (options.join() == sequence.join());
    return QuizQuestion(
      prompt: context.l10n.kidsPutInAlphabetOrder,
      options: options,
      sequence: sequence,
      optionsAreArabic: true,
      optionColumns: 3,
      optionAspect: 1.0,
    );
  }

  final qs = _draw([
    for (final l in pool) ...[
      () => shapeToName(l),
      () => nameToShape(l),
      () => dotsToShape(l),
    ],
    alphabetOrder,
  ], _questions)
    ..shuffle(_rng);
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
/// Three ways of asking, like [kidsLetterCheckpoint]: shape → name, name →
/// shape, and the character picked out in colour inside a real word. Six
/// characters in three ways is eighteen different questions, of which a round
/// asks [_specialQuestions] — it used to ask the same six, in the same
/// directions, every time.
QuizScreen kidsSpecialShapesQuiz(
  BuildContext context, {
  required String progressId,
}) {
  const chars = ['ء', 'أ', 'إ', 'ؤ', 'ئ', 'ى'];
  final pool = [for (final ch in chars) letterForAny(ch)!];
  final names = [for (final l in pool) letterName(context, l)];
  final glyphs = [for (final l in pool) l.char];

  QuizQuestion shapeToName(ArabicLetter l) {
    final o = buildOptions(letterName(context, l), names, _rng);
    return QuizQuestion(
      prompt: context.l10n.qpWhichLetterIsThis,
      arabic: l.char,
      reviewId: 'extra.${l.char}',
      options: o.options,
      correct: o.correct,
    );
  }

  QuizQuestion nameToShape(ArabicLetter l) {
    final o = buildOptions(l.char, glyphs, _rng);
    return QuizQuestion(
      prompt: context.l10n.qpWhichOneIs(letterName(context, l)),
      reviewId: 'extra.${l.char}',
      options: o.options,
      correct: o.correct,
      optionsAreArabic: true,
      optionColumns: 4,
      optionAspect: 1.0,
    );
  }

  // The character in its real word, picked out in colour — the word is the
  // letter's own example from the muṣḥaf, so nothing here is authored.
  QuizQuestion inAWord(ArabicLetter l) {
    final o = buildOptions(letterName(context, l), names, _rng);
    return QuizQuestion(
      prompt: context.l10n.kidsWhichIsColoured,
      arabic: l.exampleWord,
      highlight: l.char,
      reviewId: 'extra.${l.char}',
      options: o.options,
      correct: o.correct,
    );
  }

  final qs = _draw([
    for (final l in pool) ...[
      () => shapeToName(l),
      () => nameToShape(l),
      () => inAWord(l),
    ],
  ], _specialQuestions)
    ..shuffle(_rng);
  return QuizScreen(
    title: context.l10n.formsQuiz,
    progressId: progressId,
    questions: qs,
  );
}

/// Questions in one Special Shapes round: eight of eighteen.
const _specialQuestions = 8;

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
/// here does a child pick the right one FOR a place in a real word — and it is
/// asked by DRAGGING the shape onto the word (or tapping it).
///
/// Every (letter, direction, position) is its own question, and a round draws
/// them without replacement ([_draw]), so no round repeats itself.
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

  String formOf(ArabicLetter l, int idx) =>
      [l.initial, l.medial, l.finalForm][idx];
  String formName(int idx) => ['ini', 'med', 'fin'][idx];
  String posLabel(int idx) => [
    context.l10n.formStart,
    context.l10n.formMiddle,
    context.l10n.formEnd,
  ][idx];

  QuizQuestion shapeToLetter(ArabicLetter l, int idx) {
    final o = buildOptions(letterName(context, l), names, _rng);
    return QuizQuestion(
      prompt: context.l10n.qpShapeBelongsTo,
      arabic: formOf(l, idx),
      reviewId: 'letter.form.${l.char}.${formName(idx)}',
      options: o.options,
      correct: o.correct,
      explain: context.l10n.lookPastJoins,
    );
  }

  QuizQuestion? positionToShape(ArabicLetter l, int idx) {
    // The distractors are the SAME position of other letters, so the answer
    // turns on the letter's own skeleton rather than on which option happens
    // to have a tail on the correct side.
    final others = (idx == 2 ? pool : joiners).where((x) => x != l).toList();
    if (others.length < 3) return null;
    final o = buildOptions(formOf(l, idx), [
      formOf(l, idx),
      for (final x in others) formOf(x, idx),
    ], _rng);
    return QuizQuestion(
      prompt: context.l10n.qpFormOfAt(letterName(context, l), posLabel(idx)),
      reviewId: 'letter.form.${l.char}.${formName(idx)}',
      options: o.options,
      correct: o.correct,
      optionsAreArabic: true,
      optionColumns: 4,
      optionAspect: 1.0,
    );
  }

  QuizQuestion? gapInAWord(ArabicLetter l) {
    if (!l.joins) return null;
    final gaps = [
      for (final ex in letterExamples[l.char] ?? const <LetterExample>[])
        if (_wordGap(ex.word, l.char) case final g?) (ex.word, g),
    ];
    if (gaps.isEmpty) return null;
    final (word, g) = gaps[_rng.nextInt(gaps.length)];
    final shapes = {
      'ini': l.initial,
      'med': l.medial,
      'fin': l.finalForm,
      'iso': l.char,
    };
    final o = buildOptions(shapes[g.form]!, shapes.values.toList(), _rng);
    return QuizQuestion(
      prompt: context.l10n.kidsDragShapeOntoWord(letterName(context, l)),
      arabic: word,
      blank: g.gap,
      dragToGap: true,
      reviewId: 'letter.form.${l.char}.${g.form}',
      options: o.options,
      correct: o.correct,
      optionsAreArabic: true,
      optionColumns: 4,
      optionAspect: 1.0,
      explain: context.l10n.lookPastJoins,
    );
  }

  // Two of a round's questions are the drag-onto-the-word kind — the one that
  // asks for a shape FOR a place in a real word — whatever else the draw
  // brings; the rest come from every other way of asking.
  final gaps = _draw([for (final l in pool) () => gapInAWord(l)], _gapQuestions);
  final qs = [
    ...gaps,
    ..._draw([
      for (final l in pool)
        // A non-joiner has only its end shape (position 2).
        for (final idx in l.joins ? const [0, 1, 2] : const [2]) ...[
          () => shapeToLetter(l, idx),
          () => positionToShape(l, idx),
        ],
    ], _questions - gaps.length),
  ]..shuffle(_rng);
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
