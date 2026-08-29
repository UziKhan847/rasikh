import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../data/glyph_names.dart';
import '../../data/letters.dart';
import '../../data/variants.dart';
import '../../widgets/common.dart';

/// Extra joining-form question shapes, shared by the grown-up Qāʿidah unit
/// and Kids Mode's forms block — one set of generators, not two.
///
/// The existing forms quiz (`qaidah_screen.dart`) asks one thing: *which
/// letter is this shape?* These ask the other three questions a Qāʿidah
/// actually drills — which FORM, the letter and form together in a real word,
/// and the word built from its forms in order.

final _rng = math.Random();

// ── contextual shaping ────────────────────────────────────────────────────

/// Letters that never join to the letter AFTER them, so the next letter can
/// only ever take an isolated or initial shape. Superset of
/// [ArabicLetter.joins]'s six, adding the hamza carriers, tāʼ marbūṭah and
/// alif maqṣūrah that appear in real muṣḥaf words but aren't in the 28.
const _noForwardJoin = 'اأإآٱوؤدذرزءةى';

bool _isMark(int c) =>
    (c >= 0x064B && c <= 0x065F) ||
    c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06ED) ||
    (c >= 0x08F0 && c <= 0x08FF) ||
    c == 0x0640; // tatweel: a joiner, not a letter

/// The base letters of [word] with the index each one starts at, ḥarakāt and
/// tatweel dropped.
List<({String char, int at})> _baseLetters(String word) => [
      for (var i = 0; i < word.length; i++)
        if (!_isMark(word.codeUnitAt(i)) && word[i].trim().isNotEmpty)
          (char: word[i], at: i),
    ];

/// Which of the four shapes the letter at base-index [k] really takes in
/// [bases] — derived from its neighbours, the way Arabic shaping actually
/// works, rather than trusted from a 'beginning/middle/end' tag. A letter
/// tagged "middle" that follows a non-joiner (the kāf in `ٱلۡكِتَٰبُ`) takes the
/// INITIAL shape, so the tag alone would mark a right answer wrong.
String _formAt(List<({String char, int at})> bases, int k) {
  final joinsRight = k > 0 && !_noForwardJoin.contains(bases[k - 1].char);
  final joinsLeft =
      k < bases.length - 1 && !_noForwardJoin.contains(bases[k].char);
  if (joinsRight && joinsLeft) return 'med';
  if (joinsRight) return 'fin';
  if (joinsLeft) return 'ini';
  return 'iso';
}

/// Every base letter of [word] with the shape it actually takes there —
/// `'iso' | 'ini' | 'med' | 'fin'`, in writing order, ḥarakāt ignored.
///
/// Public because it is the one piece of these quizzes that can be *wrong*
/// rather than merely awkward: a mis-derived form marks a correct answer
/// incorrect and teaches the child the opposite of the lesson. Covered
/// directly by `test/forms_quizzes_test.dart`.
List<({String char, String form})> contextualForms(String word) {
  final bases = _baseLetters(word);
  return [
    for (var k = 0; k < bases.length; k++)
      (char: bases[k].char, form: _formAt(bases, k))
  ];
}

/// The letter [l] drawn in [form], using the tatweel joiner — the same
/// rendering `ArabicLetter.initial`/`medial`/`finalForm` already use, so
/// these options look identical to the ones the existing forms quiz shows.
String _glyphFor(ArabicLetter l, String form) => switch (form) {
      'ini' => l.initial,
      'med' => l.medial,
      'fin' => l.finalForm,
      _ => l.char,
    };

String _formLabel(BuildContext context, String form) => switch (form) {
      'ini' => context.l10n.formStart,
      'med' => context.l10n.formMiddle,
      'fin' => context.l10n.formEnd,
      _ => context.l10n.formAlone,
    };

/// [count] letters to offer against [answer]: its look-alike family first
/// (the ones a learner actually confuses — ف/ق, ب/ت/ث), topped up at random.
List<ArabicLetter> _confusables(ArabicLetter answer, int count) {
  final family = [
    for (final c in similarFamilies[answer.similarGroup] ?? const <String>[])
      if (c != answer.char) letterFor(c)
  ]..shuffle(_rng);
  final rest = [
    for (final l in letters)
      if (l.char != answer.char &&
          l.joins &&
          !family.any((f) => f.char == l.char))
        l
  ]..shuffle(_rng);
  return [answer, ...family, ...rest].take(count).toList();
}

/// The letter plus the ḥarakāt riding on it, so removing it from a word
/// leaves a clean gap rather than an orphaned vowel mark.
String _gapAt(String word, int at) {
  var j = at + 1;
  while (j < word.length && _isMark(word.codeUnitAt(j))) {
    j++;
  }
  return word.substring(at, j);
}

// ── 1. the letter AND its form, in a real word ────────────────────────────

/// "Pick Kāf in the right shape" — a real word with one letter lifted out,
/// and a grid of candidate forms across three confusable letters. Harder
/// than naming a shape in isolation, because both the letter and its
/// position have to be right.
List<QuizQuestion> formGridQuestions(BuildContext context, {int count = 6}) {
  final pool = [
    for (final l in letters)
      if (l.joins && (letterExamples[l.char]?.isNotEmpty ?? false)) l
  ];
  final qs = <QuizQuestion>[];
  for (final l in pickN(pool, count, _rng)) {
    final example = letterExamples[l.char]![
        _rng.nextInt(letterExamples[l.char]!.length)];
    final bases = _baseLetters(example.word);
    final k = bases.indexWhere((b) => b.char == l.char);
    if (k < 0) continue;
    final form = _formAt(bases, k);

    // 3 letters x 4 forms — the same grid the design's mockup shows.
    final rows = _confusables(l, 3)..shuffle(_rng);
    const forms = ['fin', 'med', 'ini', 'iso'];
    final options = [
      for (final row in rows)
        for (final f in forms) _glyphFor(row, f)
    ];
    final answer = _glyphFor(l, form);
    qs.add(QuizQuestion(
      prompt: context.l10n.qpPickLetterAndForm(letterName(context, l)),
      arabic: example.word,
      blank: _gapAt(example.word, bases[k].at),
      options: options,
      correct: options.indexOf(answer),
      optionsAreArabic: true,
      optionColumns: 4,
      optionAspect: 1.0,
      reviewId: 'letter.form.${l.char}.$form',
      explain: context.l10n.lookPastJoins,
    ));
  }
  return qs;
}

// ── 2. which position is this shape? ──────────────────────────────────────

/// The mirror of the existing forms quiz: it shows a shape and asks which
/// LETTER it is; this shows a shape and asks WHERE in a word it sits.
List<QuizQuestion> formPositionQuestions(BuildContext context,
    {int count = 5}) {
  // Non-joiners have no real initial or medial shape, so a four-way
  // position question about one would be unanswerable.
  final pool = [for (final l in letters) if (l.joins) l];
  final qs = <QuizQuestion>[];
  for (final l in pickN(pool, count, _rng)) {
    const forms = ['ini', 'med', 'fin', 'iso'];
    final form = forms[_rng.nextInt(forms.length)];
    final labels = [for (final f in forms) _formLabel(context, f)];
    qs.add(QuizQuestion(
      prompt: context.l10n.qpWhichPosition,
      arabic: _glyphFor(l, form),
      options: labels,
      correct: forms.indexOf(form),
      reviewId: 'letter.position.${l.char}.$form',
      explain: context.l10n.lookPastJoins,
    ));
  }
  return qs;
}

// ── 3. build the word from its forms ──────────────────────────────────────

/// Tap the joining forms in order to spell a real word — reading direction
/// and shaping together. Uses the engine's existing ordering support.
List<QuizQuestion> buildTheWordQuestions(BuildContext context,
    {int count = 4}) {
  final words = <(String, String)>[
    for (final entry in letterExamples.entries)
      for (final e in entry.value) (e.word, e.translit)
  ];
  final qs = <QuizQuestion>[];
  for (final (word, translit) in pickN(words, count * 3, _rng)) {
    if (qs.length >= count) break;
    final bases = _baseLetters(word);
    if (bases.length < 3 || bases.length > 5) continue;
    // Every base letter has to be one of the 28 for a form to be drawable.
    if (bases.any((b) => !letters.any((l) => l.char == b.char))) continue;

    final sequence = [
      for (var k = 0; k < bases.length; k++)
        _glyphFor(letterFor(bases[k].char), _formAt(bases, k))
    ];
    // Duplicate shapes within one word would make "which tile did you mean"
    // ambiguous to grade, so skip those words rather than mis-mark a tap.
    if (sequence.toSet().length != sequence.length) continue;

    qs.add(QuizQuestion(
      prompt: context.l10n.qpTapLettersInOrder(translit),
      options: [...sequence]..shuffle(_rng),
      sequence: sequence,
      optionsAreArabic: true,
      optionColumns: sequence.length <= 4 ? 4 : 5,
      optionAspect: 1.0,
      reviewId: 'word.build.$word',
    ));
  }
  return qs;
}

// ── 4. listen, then pick ──────────────────────────────────────────────────

/// Play a letter's real Qur'anic example verse, then pick the letter.
///
/// Always [QuizQuestion.skippable]: the only recitation this app has is
/// whole-āyah audio that needs the network, so the letter is never isolated
/// and the sound may not arrive at all. A learner must be able to move on.
List<QuizQuestion> listenAndPickQuestions(BuildContext context,
    {int count = 4}) {
  final qs = <QuizQuestion>[];
  for (final l in pickN(letters, count, _rng)) {
    final options = (_confusables(l, 4)..shuffle(_rng))
        .map((o) => o.char)
        .toList();
    qs.add(QuizQuestion(
      prompt: context.l10n.qpListenThenPick(letterName(context, l)),
      audioRef: l.exampleRef,
      options: options,
      correct: options.indexOf(l.char),
      optionsAreArabic: true,
      optionColumns: 4,
      optionAspect: 1.0,
      skippable: true,
      reviewId: 'letter.listen.${l.char}',
    ));
  }
  return qs;
}

// ── tāʼ marbūṭah vs. final hāʼ ────────────────────────────────────────────

/// "Which letter ends this word?" — ة or ه, over every real example the
/// variants data carries for the pair.
///
/// The Qāʿidah practice round already asks this once via
/// `haaVsTaaMarbutaQuestion`, but that only ever uses each variant's PRIMARY
/// word, so it can produce exactly two distinct questions. A whole stage
/// built on it would repeat itself; this draws on the `moreExamples` too.
List<QuizQuestion> taMarbutaQuestions(BuildContext context, {int count = 6}) {
  final pool = <(String, String, String)>[]; // word, highlight, answer
  for (final v in letterVariants) {
    if (v.id != 'haa.word_final' && v.id != 'taa_marbuta.word_final') continue;
    final answer = v.id.startsWith('haa') ? 'ه' : 'ة';
    pool.add((v.word, v.highlight, answer));
    for (final (word, _, highlight) in v.moreExamples) {
      pool.add((word, highlight, answer));
    }
  }
  return [
    for (final (word, highlight, answer) in pickN(pool, count, _rng))
      () {
        final o = buildOptions(answer, const ['ه', 'ة'], _rng);
        return QuizQuestion(
          prompt: context.l10n.qpWhichLetterEndsWord,
          arabic: word,
          highlight: highlight,
          options: o.options,
          correct: o.correct,
          optionsAreArabic: true,
          reviewId: 'variant.taMarbuta.$word',
          explain: context.l10n.lsnTaMarbutaHint,
        );
      }()
  ];
}

/// All four shapes in one round — what both the Qāʿidah unit's Test phase and
/// the Kids Mode forms block run.
QuizScreen formsVarietyQuiz(BuildContext context,
    {bool graded = true, String progressId = 'qaidah.forms'}) {
  final qs = <QuizQuestion>[
    ...formGridQuestions(context),
    ...formPositionQuestions(context),
    ...buildTheWordQuestions(context),
    ...listenAndPickQuestions(context, count: 2),
  ]..shuffle(_rng);
  return QuizScreen(
      title: context.l10n.formsQuiz,
      progressId: progressId,
      questions: qs,
      graded: graded);
}
