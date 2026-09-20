import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/settings.dart' show ProgressStore;
import '../../data/glyph_names.dart';
import '../../data/letters.dart';
import '../../widgets/common.dart';

/// Arabic letter recognition is bottlenecked on look-alikes: many letters
/// differ from a neighbour only by the number or position of dots. The
/// research on children's category learning is consistent that interleaving
/// similar items (rather than drilling each in its own block) is what trains
/// discrimination, and that dot-focused visual search specifically improves
/// Arabic reading accuracy. The classical alif→yāʾ TEACHING order stays as it
/// is (blocked practice is right for learning to write a shape); this file is
/// where PRACTICE interleaves.

/// The families in [similarFamilies] that name letters which genuinely look
/// alike. `'cross'` (د ر و) is a shape-confusion set across families, not a
/// look-alike one, so it is not a "which is different?" family.
final _lookalikeFamilies = [
  for (final e in similarFamilies.entries)
    if (e.key != 'cross') e.value,
];

/// Every letter in [pool] that looks like [l] — sharing ANY family with it,
/// counting the shape-confusion set too, since a child who mixes up د and ر
/// is mixing up look-alikes in the only sense that matters to them.
List<ArabicLetter> kidsConfusablesIn(ArabicLetter l, List<ArabicLetter> pool) {
  final near = <String>{};
  for (final fam in similarFamilies.values) {
    if (fam.contains(l.char)) near.addAll(fam);
  }
  near.remove(l.char);
  return [
    for (final x in pool)
      if (near.contains(x.char)) x,
  ];
}

/// Multiple-choice options for [answer] whose distractors are its own
/// look-alikes FIRST (from [pool] only — a letter the child has not met is
/// noise, not a distractor), topped up from the rest of the pool. This is
/// the one place the interleaving evidence applies to what a child is
/// already asked: which shapes it puts side by side.
({List<String> options, int correct}) kidsConfusableOptions({
  required ArabicLetter answer,
  required List<ArabicLetter> pool,
  required String Function(ArabicLetter) show,
  required math.Random rng,
  int count = 4,
}) {
  final near = kidsConfusablesIn(answer, pool)..shuffle(rng);
  final far = [
    for (final l in pool)
      if (l != answer && !near.contains(l)) l,
  ]..shuffle(rng);
  final picks = [...near, ...far].take(count - 1);
  final correct = show(answer);
  final options = <String>[
    correct,
    for (final l in picks)
      if (show(l) != correct) show(l),
  ]..shuffle(rng);
  return (options: options, correct: options.indexOf(correct));
}

/// The letters this child has actually met — the only ones the look-alike
/// drill may show (same rule the checkpoints follow).
List<ArabicLetter> kidsLearnedLetters(ProgressStore prog) => [
  for (final l in letters)
    if (prog.starsFor('kids.letter.${l.char}') > 0) l,
];

/// Whether [known] holds at least one pair of look-alikes — the drill has
/// nothing to contrast otherwise, so its Home tile stays hidden until then.
bool kidsLookalikeAvailable(List<ArabicLetter> known) =>
    known.any((l) => kidsConfusablesIn(l, known).isNotEmpty);

/// The "Look-alikes" drill: a mixed round of three formats, over letters the
/// child has met, that all train telling near-identical shapes apart.
///
///  * **Which one is X?** — the answer's own look-alikes are the options.
///  * **Which one is different?** — three from one family, one intruder.
///  * **Dot Hunter** — "tap every letter with 2 dots below" (multi-select).
///
/// None of it needs audio. Each question that has a real single answer files
/// its own miss into the shared review queue (`reviewId`), so a confusion
/// found here resurfaces in the Warm-up.
QuizScreen kidsLookalikeQuiz(
  BuildContext context, {
  required List<ArabicLetter> known,
  required String progressId,
  math.Random? rng,
}) {
  final r = rng ?? math.Random();
  final qs = <QuizQuestion>[
    ..._whichOneQuestions(context, known, r),
    ..._oddOneOutQuestions(context, known, r),
    ..._dotHunterQuestions(context, known, r),
  ]..shuffle(r);
  return QuizScreen(
    title: context.l10n.kidsLookalikes,
    progressId: progressId,
    questions: qs,
  );
}

List<QuizQuestion> _whichOneQuestions(
  BuildContext context,
  List<ArabicLetter> known,
  math.Random r,
) {
  final withNear = [
    for (final l in known)
      if (kidsConfusablesIn(l, known).isNotEmpty) l,
  ]..shuffle(r);
  return [
    for (final l in withNear.take(3))
      () {
        final o = kidsConfusableOptions(
          answer: l,
          pool: known,
          show: (x) => x.char,
          rng: r,
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
      }(),
  ];
}

List<QuizQuestion> _oddOneOutQuestions(
  BuildContext context,
  List<ArabicLetter> known,
  math.Random r,
) {
  final out = <QuizQuestion>[];
  final families = [..._lookalikeFamilies]..shuffle(r);
  for (final fam in families) {
    if (out.length >= 3) break;
    final inFam = [
      for (final l in known)
        if (fam.contains(l.char)) l,
    ]..shuffle(r);
    if (inFam.length < 3) continue;
    final outsiders = [
      for (final l in known)
        if (!fam.contains(l.char)) l,
    ];
    if (outsiders.isEmpty) continue;
    final odd = outsiders[r.nextInt(outsiders.length)];
    final options = [...inFam.take(3), odd].map((l) => l.char).toList()
      ..shuffle(r);
    out.add(
      QuizQuestion(
        prompt: context.l10n.kidsOddOneOut,
        options: options,
        correct: options.indexOf(odd.char),
        optionsAreArabic: true,
        optionColumns: 4,
        optionAspect: 1.0,
      ),
    );
  }
  return out;
}

List<QuizQuestion> _dotHunterQuestions(
  BuildContext context,
  List<ArabicLetter> known,
  math.Random r,
) {
  // ي is drawn dotless when isolated in the muṣḥaf font (see
  // `dotsDescForLetter`), so asking a child to find it by its dots would
  // contradict the glyph on screen.
  final candidates = [
    for (final l in known)
      if (l.dotCount > 0 && l.char != 'ي') l,
  ];
  final bySignature = <String, List<ArabicLetter>>{};
  for (final l in candidates) {
    bySignature.putIfAbsent('${l.dotCount}.${l.dotPos}', () => []).add(l);
  }
  final signatures = bySignature.keys.toList()..shuffle(r);
  final out = <QuizQuestion>[];
  for (final sig in signatures) {
    if (out.length >= 3) break;
    final targets = bySignature[sig]!..shuffle(r);
    final t = targets.first;
    // Distractors: every known letter with a DIFFERENT dot signature,
    // look-alikes of a target first — the hard ones are the ones that share
    // a body and differ only in the dots.
    final others = [
      for (final l in known)
        if (l.char != 'ي' && '${l.dotCount}.${l.dotPos}' != sig) l,
    ]..shuffle(r);
    final near = [
      for (final l in others)
        if (targets.any((x) => kidsConfusablesIn(x, [l]).isNotEmpty)) l,
    ];
    final far = [
      for (final l in others)
        if (!near.contains(l)) l,
    ];
    final picked = targets.take(3).toList();
    final want = math.min(6, picked.length + 3);
    final distractors = [...near, ...far].take(want - picked.length).toList();
    if (distractors.isEmpty) continue;
    final all = [...picked, ...distractors]..shuffle(r);
    out.add(
      QuizQuestion(
        prompt: context.l10n.kidsDotHunterPrompt(
          dotsDesc(context, t.dotCount, t.dotPos),
        ),
        options: [for (final l in all) l.char],
        correctSet: {
          for (var i = 0; i < all.length; i++)
            if (picked.contains(all[i])) i,
        },
        optionsAreArabic: true,
        optionColumns: 3,
        optionAspect: 1.2,
      ),
    );
  }
  return out;
}
