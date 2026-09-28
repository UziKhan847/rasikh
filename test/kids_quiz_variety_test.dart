import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_checkpoint_quiz.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_lookalike_quiz.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_stage_quizzes.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show QuizQuestion;

/// The quizzes used to repeat: fixed question lists, a direction pinned to the
/// question's position, families that could never qualify, five dot signatures
/// forever. These play many rounds of each generator and hold it to two
/// standards — no round asks the same question twice, and many rounds between
/// them ask many different questions.
late BuildContext _ctx;

Future<void> _boot(WidgetTester tester) => tester.pumpWidget(
  SettingsScope(
    settings: AppSettings(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (c) {
          _ctx = c;
          return const SizedBox();
        },
      ),
    ),
  ),
);

/// What a question asks and what its answer is, in one string.
String _sig(QuizQuestion q) {
  final String answer;
  if (q.sequence != null) {
    answer = q.sequence!.join();
  } else if (q.correctSet != null) {
    answer = ([for (final i in q.correctSet!) q.options[i]]..sort()).join();
  } else {
    answer = q.options[q.correct];
  }
  // "Which one is different?" shows nothing but its four options, so they are
  // part of what it asks.
  final shown = q.prompt == 'Which one is different?'
      ? ([...q.options]..sort()).join()
      : '';
  return '${q.prompt}|${q.arabic ?? ''}|${q.blank ?? ''}|$answer|$shown';
}

void _expectNoRepeatsInARound(List<QuizQuestion> qs, String reason) {
  final sigs = qs.map(_sig).toList();
  expect(sigs.toSet().length, sigs.length, reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('letter check-up', () {
    testWidgets('five letters: a full round, nothing asked twice', (
      tester,
    ) async {
      await _boot(tester);
      final all = <String>{};
      for (var i = 0; i < 50; i++) {
        final qs = kidsLetterCheckpoint(
          _ctx,
          progressId: 'p',
          upTo: 5,
        ).questions;
        // It used to ask ten of five letters with the direction pinned to the
        // question's position, so a letter could come up twice the same way.
        expect(qs, hasLength(10));
        _expectNoRepeatsInARound(qs, 'round $i');
        all.addAll(qs.map(_sig));
      }
      expect(all.length, greaterThan(12));
    });

    testWidgets('the whole alphabet: many rounds, many different questions', (
      tester,
    ) async {
      await _boot(tester);
      final all = <String>{};
      var order = 0, dots = 0, toName = 0, toShape = 0;
      for (var i = 0; i < 50; i++) {
        final qs = kidsLetterCheckpoint(
          _ctx,
          progressId: 'p',
          upTo: 28,
        ).questions;
        _expectNoRepeatsInARound(qs, 'round $i');
        all.addAll(qs.map(_sig));
        for (final q in qs) {
          if (q.sequence != null) order++;
          if (q.prompt.startsWith('Which letter has')) dots++;
          if (q.prompt == 'Which letter is this?') toName++;
          if (q.prompt.startsWith('Which one is')) toShape++;
        }
      }
      expect(all.length, greaterThan(60));
      expect([order, dots, toName, toShape], everyElement(greaterThan(0)));
    });

    testWidgets('a dots question has exactly one right answer', (tester) async {
      await _boot(tester);
      for (var i = 0; i < 60; i++) {
        for (final q in kidsLetterCheckpoint(
          _ctx,
          progressId: 'p',
          upTo: 28,
        ).questions) {
          if (!q.prompt.startsWith('Which letter has')) continue;
          final l = letterFor(q.options[q.correct]);
          expect(l.dotCount, greaterThan(0));
          for (final (k, o) in q.options.indexed) {
            if (k == q.correct) continue;
            final x = letterFor(o);
            expect(
              x.dotCount == l.dotCount && x.dotPos == l.dotPos,
              isFalse,
              reason: '${q.prompt}: $o also has them',
            );
          }
        }
      }
    });

    testWidgets('the alphabet-order question is in the alphabet\'s order', (
      tester,
    ) async {
      await _boot(tester);
      var seen = 0;
      for (var i = 0; i < 40; i++) {
        for (final q in kidsLetterCheckpoint(
          _ctx,
          progressId: 'p',
          upTo: 28,
        ).questions) {
          final s = q.sequence;
          if (s == null) continue;
          seen++;
          final idx = [
            for (final c in s) kidsLetterPath.indexWhere((l) => l.char == c),
          ];
          expect(idx, [...idx]..sort());
          expect(
            q.options.join(),
            isNot(s.join()),
            reason: 'never offered already in order',
          );
        }
      }
      expect(seen, greaterThan(0));
    });
  });

  group('joining-shapes check-up', () {
    testWidgets('nothing asked twice, and a retake is a different round', (
      tester,
    ) async {
      await _boot(tester);
      for (final upTo in [5, 28]) {
        final all = <String>{};
        for (var i = 0; i < 50; i++) {
          final qs = kidsFormsCheckpoint(
            _ctx,
            progressId: 'p',
            upTo: upTo,
          ).questions;
          expect(qs, hasLength(10), reason: 'upTo $upTo');
          _expectNoRepeatsInARound(qs, 'upTo $upTo round $i');
          all.addAll(qs.map(_sig));
        }
        expect(
          all.length,
          greaterThan(upTo == 5 ? 20 : 150),
          reason: 'upTo $upTo',
        );
      }
    });

    testWidgets('every gap question takes a drag', (tester) async {
      await _boot(tester);
      var gaps = 0;
      for (var i = 0; i < 40; i++) {
        for (final q in kidsFormsCheckpoint(
          _ctx,
          progressId: 'p',
          upTo: 28,
        ).questions) {
          if (q.blank == null) continue;
          gaps++;
          expect(q.dragToGap, isTrue);
        }
      }
      expect(gaps, greaterThan(0));
    });
  });

  group('special shapes quiz', () {
    testWidgets('eight different questions, and a retake asks others', (
      tester,
    ) async {
      await _boot(tester);
      final all = <String>{};
      final firstRoundSigs = <String>[];
      var inAWord = 0;
      for (var i = 0; i < 30; i++) {
        final qs = kidsSpecialShapesQuiz(_ctx, progressId: 'p').questions;
        expect(qs, hasLength(8));
        _expectNoRepeatsInARound(qs, 'round $i');
        all.addAll(qs.map(_sig));
        if (i == 0) firstRoundSigs.addAll(qs.map(_sig));
        inAWord += qs.where((q) => q.highlight != null).length;
      }
      // It was six questions, the same six, in the same directions, every time.
      expect(all.length, greaterThan(12));
      expect(all.length, greaterThan(firstRoundSigs.length));
      expect(inAWord, greaterThan(0));
    });

    testWidgets('a coloured letter really is in its word', (tester) async {
      await _boot(tester);
      for (var i = 0; i < 30; i++) {
        for (final q in kidsSpecialShapesQuiz(
          _ctx,
          progressId: 'p',
        ).questions) {
          if (q.highlight == null) continue;
          expect(q.arabic!.contains(q.highlight!), isTrue, reason: q.arabic);
        }
      }
    });
  });

  group('look-alikes', () {
    testWidgets('every pair of look-alikes can now be asked', (tester) async {
      await _boot(tester);
      final seen = <String>{};
      final prompts = <String>{};
      for (var seed = 0; seed < 150; seed++) {
        final qs = kidsLookalikeQuiz(
          _ctx,
          known: letters,
          progressId: 'p',
          rng: math.Random(seed),
        ).questions;
        _expectNoRepeatsInARound(qs, 'seed $seed');
        for (final q in qs) {
          if (q.correctSet != null) prompts.add(q.prompt);
          if (q.prompt != 'Which letter looks like this one?') continue;
          final a = q.arabic!;
          final b = q.options[q.correct];
          for (final e in similarFamilies.entries) {
            if (e.value.contains(a) && e.value.contains(b)) seen.add(e.key);
          }
        }
      }
      // Seven of the nine families are pairs, which "which one is different?"
      // needs three of; these are the only way they are ever asked.
      expect(seen, containsAll(['sin', 'sad', 'ta', 'ayn', 'fa']));
      // Five dot signatures used to be all a hunt could be.
      expect(prompts.length, greaterThanOrEqualTo(8));
    });

    testWidgets('a round is a spread of formats, not one format nine times', (
      tester,
    ) async {
      await _boot(tester);
      for (var seed = 0; seed < 30; seed++) {
        final qs = kidsLookalikeQuiz(
          _ctx,
          known: letters,
          progressId: 'p',
          rng: math.Random(seed),
        ).questions;
        expect(qs, hasLength(9));
        final formats = {
          for (final q in qs)
            q.correctSet != null
                ? 'hunt'
                : q.prompt == 'Which one is different?'
                ? 'odd'
                : q.prompt == 'Which letter looks like this one?'
                ? 'twin'
                : 'which',
        };
        expect(formats, hasLength(4), reason: 'seed $seed');
      }
    });
  });

  group('marks in words', () {
    testWidgets('no round asks about one word twice', (tester) async {
      await _boot(tester);
      for (final id in ['sukun', 'shadda', 'fatha', 'kasra', 'damma']) {
        for (var seed = 0; seed < 30; seed++) {
          final qs = kidsMarkSpotQuiz(
            _ctx,
            title: 'T',
            progressId: 'p',
            markId: id,
            rng: math.Random(seed),
          ).questions;
          final singles = qs.where((q) => q.correctSet == null).toList();
          final answers = [for (final q in singles) q.options[q.correct]];
          expect(answers.toSet().length, answers.length, reason: '$id $seed');
        }
      }
    });

    testWidgets('a syllable round differs from the next', (tester) async {
      await _boot(tester);
      final all = <String>{};
      for (var seed = 0; seed < 40; seed++) {
        final qs = kidsSyllableQuiz(
          _ctx,
          title: 'T',
          progressId: 'p',
          markIds: const ['fatha', 'kasra', 'damma'],
          rng: math.Random(seed),
        ).questions;
        _expectNoRepeatsInARound(qs, 'seed $seed');
        all.addAll(qs.map(_sig));
      }
      expect(all.length, greaterThan(150));
    });
  });
}
