import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/l10n.dart';
import '../../data/glyph_names.dart';
import '../../data/letters.dart';
import '../../widgets/common.dart';
import '../../screens/qaidah_screen.dart' show connectorQuestion;
import 'families.dart';

/// One step of a lesson: something to look at, to write, or to answer.
sealed class QStep {
  const QStep();
}

/// A page to read: a title, a line or two, and glyphs to look at.
class ExplainStep extends QStep {
  final String title, body;
  final List<String> glyphs;
  const ExplainStep({required this.title, required this.body, this.glyphs = const []});
}

/// A letter: its shape, name, sound and dots (and its recording, if any).
class MeetStep extends QStep {
  final ArabicLetter letter;
  const MeetStep(this.letter);
}

/// A letter's shapes in a word — alone, start, middle, end — and words
/// from the Qurʾān that carry it.
class FormsStep extends QStep {
  final ArabicLetter letter;
  const FormsStep(this.letter);
}

/// Writing a letter by following its strokes.
class TraceStep extends QStep {
  final ArabicLetter letter;
  const TraceStep(this.letter);
}

/// A question; [graded] ones count toward the lesson's stars.
class PickStep extends QStep {
  final QuizQuestion question;
  final bool graded;
  const PickStep(this.question, {this.graded = false});
}

/// A lesson: its steps, and where its stars go.
class QLesson {
  final String id, title;
  final List<QStep> steps;
  final String progressId;
  const QLesson({required this.id, required this.title, required this.steps, required this.progressId});

  int get graded => steps.whereType<PickStep>().where((s) => s.graded).length;
}

/// [f]'s lesson: the shape the family shares, then each letter — meet it,
/// see its shapes in words, find it in a word — writing the family's
/// shape once, telling the letters apart, and a short check that counts.
QLesson familyLesson(BuildContext context, LetterFamily f, {math.Random? rng}) {
  final r = rng ?? math.Random();
  final l = context.l10n;
  final ls = f.letters;
  final steps = <QStep>[
    if (f.id == 'alif')
      ExplainStep(title: l.qcAlifTitle, body: l.qcAlifBody, glyphs: const ['ا', 'د', 'ذ', 'ر', 'ز', 'و'])
    else
      ExplainStep(title: l.qcShapeTitle(ls.length), body: l.qcShapeBody, glyphs: f.chars),
    for (final x in ls) ...[
      MeetStep(x),
      FormsStep(x),
      PickStep(_spotQuestion(context, x, f, r)),
    ],
    TraceStep(ls.first),
    // Alif: which letters join the next, and which don't.
    if (f.id == 'alif')
      for (final c in (['ا', 'د', 'ر', 'و', 'ب', 'م']..shuffle(r)))
        PickStep(connectorQuestion(context, letterFor(c))),
    if (ls.length > 1)
      for (final x in [...ls]..shuffle(r)) PickStep(_whichIsThis(context, x, f, r)),
    ExplainStep(title: l.qcCheckYourself, body: l.qcCheckBody(_checkCount(ls.length))),
    ...[
      for (final x in ls) ...[
        PickStep(_whichIsName(context, x, f, r), graded: true),
        PickStep(_formQuestion(context, x, f, r), graded: true),
        if (ls.length < 4) PickStep(_spotQuestion(context, x, f, r), graded: true),
      ],
    ],
  ];
  return QLesson(
    id: f.id,
    title: familyTitle(context, f),
    steps: steps,
    progressId: f.progressId,
  );
}

int _checkCount(int letters) => letters * (letters < 4 ? 3 : 2);

/// "Bāʾ and its family", or Alif's own title.
String familyTitle(BuildContext context, LetterFamily f) => f.id == 'alif'
    ? context.l10n.qcAlifLesson
    : context.l10n.qcFamily(letterName(context, f.letters.first));

/// Letters to offer beside [x]: its family first, then look-alikes and
/// others, so there are always four.
List<ArabicLetter> _pool(ArabicLetter x, LetterFamily f, math.Random r) {
  final out = <ArabicLetter>[...f.letters];
  final rest = [...letters]..shuffle(r);
  for (final o in rest) {
    if (out.length >= 4) break;
    if (!out.contains(o)) out.add(o);
  }
  return out;
}

/// The letter shown: which is it? (names)
QuizQuestion _whichIsThis(BuildContext context, ArabicLetter x, LetterFamily f, math.Random r) {
  final o = buildOptions(letterName(context, x),
      [for (final y in _pool(x, f, r)) letterName(context, y)], r);
  return QuizQuestion(
    prompt: context.l10n.qpWhichLetterIsThis,
    arabic: x.char,
    reviewId: 'letter.${x.char}',
    options: o.options,
    correct: o.correct,
    explain: dotsDescForLetter(context, x),
  );
}

/// The name given: which shape is it? (glyphs)
QuizQuestion _whichIsName(BuildContext context, ArabicLetter x, LetterFamily f, math.Random r) {
  final o = buildOptions(x.char, [for (final y in _pool(x, f, r)) y.char], r);
  return QuizQuestion(
    prompt: context.l10n.qcWhichIsName(letterName(context, x)),
    reviewId: 'letter.${x.char}',
    options: o.options,
    correct: o.correct,
    optionsAreArabic: true,
  );
}

/// One of the letter's joined shapes: whose is it?
QuizQuestion _formQuestion(BuildContext context, ArabicLetter x, LetterFamily f, math.Random r) {
  final forms = x.joins ? [x.initial, x.medial, x.finalForm] : [x.finalForm];
  final form = forms[r.nextInt(forms.length)];
  final o = buildOptions(letterName(context, x),
      [for (final y in _pool(x, f, r)) letterName(context, y)], r);
  return QuizQuestion(
    prompt: context.l10n.qpShapeBelongsTo,
    arabic: form,
    reviewId: 'letter.form.${x.char}',
    options: o.options,
    correct: o.correct,
  );
}

/// A word from the Qurʾān with the letter marked: which is it?
QuizQuestion _spotQuestion(BuildContext context, ArabicLetter x, LetterFamily f, math.Random r) {
  // Words that carry the letter as written (not, say, alif under a hamzah).
  final words = [
    for (final e in letterExamples[x.char] ?? const <LetterExample>[])
      if (e.word.contains(x.char)) e.word,
  ];
  final w = words.isEmpty ? x.exampleWord : words[r.nextInt(words.length)];
  final o = buildOptions(x.char, [for (final y in _pool(x, f, r)) y.char], r);
  return QuizQuestion(
    prompt: context.l10n.qcWhichMarked,
    arabic: w,
    highlight: x.char,
    reviewId: 'letter.${x.char}',
    options: o.options,
    correct: o.correct,
    optionsAreArabic: true,
  );
}

/// A few questions on [f]'s letters, for the learning path's quizzes.
List<QuizQuestion> familyQuestions(BuildContext context, LetterFamily f, int n, {math.Random? rng}) {
  final r = rng ?? math.Random();
  final qs = [
    for (final x in f.letters) ...[
      _whichIsName(context, x, f, r),
      _formQuestion(context, x, f, r),
    ],
  ]..shuffle(r);
  return qs.take(n).toList();
}
