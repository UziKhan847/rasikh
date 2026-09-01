import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../data/glyph_names.dart';
import '../../data/kids_content.dart';
import '../../data/letters.dart';
import '../../widgets/common.dart';

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
/// noise.
QuizScreen kidsLetterCheckpoint(BuildContext context,
    {required String progressId, required int upTo}) {
  final pool = kidsLetterPath.take(upTo).toList();
  final names = [for (final l in pool) letterName(context, l)];
  final glyphs = [for (final l in pool) l.char];
  final qs = <QuizQuestion>[];

  for (final (i, l) in pickN(pool, _questions, _rng).indexed) {
    final name = letterName(context, l);
    if (i.isEven) {
      final o = buildOptions(name, names, _rng);
      qs.add(QuizQuestion(
          prompt: context.l10n.qpWhichLetterIsThis,
          arabic: l.char,
          reviewId: 'letter.${l.char}',
          options: o.options,
          correct: o.correct));
    } else {
      final o = buildOptions(l.char, glyphs, _rng);
      qs.add(QuizQuestion(
          prompt: context.l10n.qpWhichOneIs(name),
          reviewId: 'letter.${l.char}',
          options: o.options,
          correct: o.correct,
          optionsAreArabic: true,
          optionColumns: 4,
          optionAspect: 1.0));
    }
  }
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.kidsCheckpoint,
      progressId: progressId,
      questions: qs);
}

/// The joining-forms stage's cumulative check-up, over the first [upTo]
/// letters' real shapes. Same two directions as [kidsLetterCheckpoint]:
///
///  * a shape in context → which letter is it?
///  * a letter and a position → which shape is that?
///
/// Initial and medial questions are asked only about letters that join on
/// both sides: a dāl has no start or middle shape, and showing a tatweel run
/// where one would be teaches a form the muṣḥaf does not contain.
QuizScreen kidsFormsCheckpoint(BuildContext context,
    {required String progressId, required int upTo}) {
  final pool = kidsLetterPath.take(upTo).toList();
  final names = [for (final l in pool) letterName(context, l)];
  final joiners = [for (final l in pool) if (l.joins) l];
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
    if (i.isEven) {
      final o = buildOptions(name, names, _rng);
      qs.add(QuizQuestion(
          prompt: context.l10n.qpShapeBelongsTo,
          arabic: formOf(l, idx),
          reviewId: 'letter.form.${l.char}.${formName(idx)}',
          options: o.options,
          correct: o.correct,
          explain: context.l10n.lookPastJoins));
    } else {
      // The distractors are the SAME position of other letters, so the answer
      // turns on the letter's own skeleton rather than on which option happens
      // to have a tail on the correct side.
      final others = (idx == 2 ? pool : joiners).where((x) => x != l).toList();
      if (others.length < 3) continue;
      final o = buildOptions(formOf(l, idx),
          [formOf(l, idx), for (final x in others) formOf(x, idx)], _rng);
      qs.add(QuizQuestion(
          prompt: context.l10n.qpFormOfAt(name, posLabel(idx)),
          reviewId: 'letter.form.${l.char}.${formName(idx)}',
          options: o.options,
          correct: o.correct,
          optionsAreArabic: true,
          optionColumns: 4,
          optionAspect: 1.0));
    }
  }
  qs.shuffle(_rng);
  return QuizScreen(
      title: context.l10n.kidsCheckpoint,
      progressId: progressId,
      questions: qs);
}
