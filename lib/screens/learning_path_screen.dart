import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/responsive.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../data/glyph_names.dart';
import '../data/learning_path.dart';
import '../data/letters.dart';
import '../ui/app_icons.dart';
import '../ui/kit.dart';
import '../widgets/common.dart';
import 'qaidah_screen.dart';

/// The step-by-step path (lib/data/learning_path.dart): every step in
/// order, the next one marked, a quiz every few. Nothing is locked. A step
/// is done once opened and come back from; a quiz, once it earns a star.
class LearningPathScreen extends StatelessWidget {
  const LearningPathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prog = ProgressScope.of(context);
    final path = learningPath();
    final units = _unitsById(context);
    final next = nextPathStep(prog, path);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.pathTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            QColumn(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(context.l10n.pathLead,
                    style: displayStyle(context, size: 22, height: 1.25)),
              ),
            ),
            QColumn(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: next < 0
                    ? QCard(
                        padding: const EdgeInsets.all(14),
                        child: Text(context.l10n.pathDone,
                            style: uiStyle(context, size: 15, weight: FontWeight.w700)),
                      )
                    : QPrimaryButton(
                        '${context.l10n.pathContinue} · ${pathStepTitle(context, path[next], units)}',
                        icon: AppIcons.play,
                        height: 48,
                        onTap: () => openPathStep(context, path[next])),
              ),
            ),
            for (var i = 0; i < path.length; i++)
              QColumn(
                child: _StepRow(
                  step: path[i],
                  title: pathStepTitle(context, path[i], units),
                  glyph: _glyph(path[i], units),
                  done: prog.starsFor(path[i].progressId) > 0,
                  current: i == next,
                  last: i == path.length - 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The first step not done yet, or -1 when the path is finished.
int nextPathStep(ProgressStore p, List<PathStep> path) =>
    path.indexWhere((s) => p.starsFor(s.progressId) == 0);

Map<String, QaidahUnit> _unitsById(BuildContext context) =>
    {for (final u in qaidahUnits(context)) u.progressId: u};

ArabicLetter _letter(String char) => letters.firstWhere((l) => l.char == char);

String pathStepTitle(BuildContext context, PathStep s, [Map<String, QaidahUnit>? units]) =>
    switch (s.kind) {
      PathKind.letter => letterName(context, _letter(s.id)),
      PathKind.unit => (units ?? _unitsById(context))[s.id]!.title,
      PathKind.quiz => context.l10n.pathQuiz(int.parse(s.id)),
    };

String _glyph(PathStep s, Map<String, QaidahUnit> units) => switch (s.kind) {
      PathKind.letter => s.id,
      PathKind.unit => units[s.id]!.arabicBadge,
      PathKind.quiz => '',
    };

/// Opens [s]: a letter's page, a unit's lesson, or the quiz on the steps
/// before it. A letter or lesson counts as done on the way back.
Future<void> openPathStep(BuildContext context, PathStep s) async {
  final prog = ProgressScope.read(context);
  final units = _unitsById(context);
  final Widget screen = switch (s.kind) {
    PathKind.letter => LetterDetail(letter: _letter(s.id)),
    PathKind.unit => Builder(builder: units[s.id]!.phases.first.builder!),
    PathKind.quiz => _quiz(context, s, units),
  };
  await pushAdaptive(context, screen);
  if (s.kind != PathKind.quiz) prog.report(s.progressId, 1);
}

/// The quiz on [quiz]'s steps: each letter once, and a couple of questions
/// from each unit's own test.
QuizScreen _quiz(BuildContext context, PathStep quiz, Map<String, QaidahUnit> units) {
  final rng = math.Random();
  List<QuizQuestion> fromUnit(QaidahUnit u) {
    final test = u.phases.firstWhere((p) => p.isTest, orElse: () => u.phases[1]);
    final w = test.builder?.call(context);
    if (w is! QuizScreen) return const [];
    return ([...w.questions]..shuffle(rng)).take(2).toList();
  }

  final qs = <QuizQuestion>[
    ...letterQuestions(context, [
      for (final s in quiz.covers)
        if (s.kind == PathKind.letter) _letter(s.id),
    ]),
    for (final s in quiz.covers)
      if (s.kind == PathKind.unit) ...fromUnit(units[s.id]!),
  ]..shuffle(rng);
  return QuizScreen(
      title: context.l10n.pathQuiz(int.parse(quiz.id)),
      progressId: quiz.progressId,
      questions: qs);
}

/// One step: a node on the line (✓ done, ring for the next, a dot
/// otherwise) and its card. Quizzes are tinted.
class _StepRow extends StatelessWidget {
  final PathStep step;
  final String title, glyph;
  final bool done, current, last;
  const _StepRow({
    required this.step,
    required this.title,
    required this.glyph,
    required this.done,
    required this.current,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final quiz = step.kind == PathKind.quiz;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 24,
          child: Column(children: [
            const SizedBox(height: 16),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? p.accBg : (current ? p.card : p.bg),
                border: Border.all(color: done || current ? p.acc : p.line3, width: 2),
              ),
              child: done ? const Icon(AppIcons.check, size: 13, color: Colors.white) : null,
            ),
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.only(top: 3),
                color: last ? Colors.transparent : (done ? p.acc : p.line3),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: QCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: quiz ? p.accSoft : null,
              borderColor: current ? p.acc : null,
              onTap: () => openPathStep(context, step),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: uiStyle(context, size: 15, weight: FontWeight.w700)),
                    if (quiz)
                      Text(context.l10n.pathQuizSub(step.covers.length),
                          style: uiStyle(context, size: 12.5, color: p.ink3)),
                  ]),
                ),
                const SizedBox(width: 10),
                if (quiz)
                  Icon(AppIcons.quiz, color: p.acc)
                else
                  Text(glyph,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      style: quranicStyle(context, size: 22, height: 1.3, color: p.acc)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
