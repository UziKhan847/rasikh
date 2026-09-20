import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_madd_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_muqattaat_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_solar_lunar_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_stage_quizzes.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_tajwid_rule_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_waqf_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_wasl_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_words_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart'
    show kidsQuizLength;
import 'package:qiraah_arabiyyah/widgets/common.dart'
    show QuizQuestion, QuizScreen, TapScale;

import 'kids_test_support.dart';

/// A stage's Test is its own lesson's check-ups in the same kid words with the
/// teaching cards taken away — or, for the drills and the closing review, a
/// short quiz over the same reviewed data — never the grown-up unit's quiz
/// ("which rule lives in this verse? (2:135)").
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings s, ProgressStore p, Widget child) => SettingsScope(
  settings: s,
  child: ProgressScope(
    progress: p,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  ),
);

/// Steps through whatever the screen asks for until its result screen.
Future<void> _walk(WidgetTester tester) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: 'step $i');
    if (find.text('Continue').evaluate().isNotEmpty) return;
    final check = find.text('Check');
    if (check.evaluate().isNotEmpty) {
      final tile = find.byType(TapScale);
      if (tile.evaluate().isNotEmpty) {
        await tester.tap(tile.first, warnIfMissed: false);
        await tester.pump();
      }
      await tester.tap(check, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
      continue;
    }
    final next = find.text('Next');
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next.first, warnIfMissed: false);
      continue;
    }
    final options = find.byType(TapScale);
    if (options.evaluate().isNotEmpty) {
      await tester.tap(options.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
    }
  }
  fail('never reached the result screen');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a lesson in quiz mode is only its checks', () {
    // name → (widget, how many questions, the first thing it asks)
    final cases = <String, (Widget Function(String), int, String)>{
      'waqf': (
        (id) => KidsWaqfLesson(progressId: id, quiz: true),
        kidsQuizLength,
        'What does this mark mean?',
      ),
      'waṣl': (
        (id) => KidsWaslLesson(progressId: id, quiz: true),
        kidsQuizLength,
        'Does this mark ever make a sound?',
      ),
      'words': (
        (id) => KidsWordsLesson(progressId: id, quiz: true),
        kidsQuizLength,
        'Which word means',
      ),
      'muqaṭṭaʿāt': (
        (id) => KidsMuqattaatLesson(progressId: id, quiz: true),
        kidsQuizLength,
        'How many counts?',
      ),
      'sun and moon': (
        (id) => KidsSolarLunarLesson(progressId: id, quiz: true),
        3,
        'Tap every Sun Letter',
      ),
      'tajwīd (nūn)': (
        (id) => KidsTajwidRuleLesson(
          ruleIds: const ['izhar', 'idgham_g', 'idgham_ng', 'iqlab', 'ikhfa'],
          progressId: id,
          icon: Icons.record_voice_over_rounded,
          title: (c) => 'Nūn Sākinah',
          subtitle: (c) => 'x',
          quiz: true,
        ),
        kidsQuizLength,
        'Which rule is this?',
      ),
      'madd': (
        (id) => KidsMaddLesson(progressId: id, quiz: true),
        kidsQuizLength,
        // Either kind of madd question — see below.
        '',
      ),
    };

    for (final e in cases.entries) {
      testWidgets('${e.key}: no cards, ${e.value.$2} questions, real stars', (
        tester,
      ) async {
        useReducedMotion(tester);
        final (settings, prog) = await _boot();
        await tester.pumpWidget(_harness(settings, prog, e.value.$1('q.test')));
        await tester.pump();

        expect(find.byType(Material), findsWidgets);
        expect(find.text('Step 1 of ${e.value.$2}'), findsOneWidget);
        if (e.value.$3.isNotEmpty) {
          expect(find.textContaining(e.value.$3), findsWidgets);
        }
        expect(prog.starsFor('q.test'), 0);

        await _walk(tester);
        await tester.pump();
        expect(prog.starsFor('q.test'), greaterThan(0));
      });
    }

    testWidgets('a quiz never opens on the lesson\'s own teaching cards', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          const KidsWaqfLesson(progressId: 'q.wq', quiz: true),
        ),
      );
      await tester.pump();
      expect(find.textContaining('traffic lights'), findsNothing);
      // ...while the lesson itself still does. (A different key: the same
      // widget type in the same place would reuse the quiz's State.)
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          const KidsWaqfLesson(key: ValueKey('lesson'), progressId: 'q.wq2'),
        ),
      );
      await tester.pump();
      expect(find.textContaining('traffic lights'), findsOneWidget);
    });

    testWidgets('a wrong answer in a quiz lands in the review queue', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      // The options are shuffled, so the first tile is usually wrong; a fresh
      // quiz each time until one is.
      for (var i = 0; i < 12 && prog.dueCount == 0; i++) {
        await tester.pumpWidget(
          _harness(
            settings,
            prog,
            KidsWaqfLesson(
              key: ValueKey('run$i'),
              progressId: 'q.wq.$i',
              quiz: true,
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byType(TapScale).first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 1000));
      }
      expect(prog.dueCount, greaterThan(0));
      expect(prog.review.keys.every((k) => k.startsWith('kids.waqf.')), isTrue);
    });

    testWidgets('the madd quiz never asks a count of Madd ʿĀriḍ, and its '
        'comparisons have exactly one right answer', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      for (var run = 0; run < 15; run++) {
        await tester.pumpWidget(
          _harness(
            settings,
            prog,
            KidsMaddLesson(progressId: 'q.madd.$run', quiz: true),
          ),
        );
        await tester.pump();
        await _walk(tester);
        expect(tester.takeException(), isNull);
      }
      // Nothing about Madd ʿĀriḍ (2, 4 or 6 by choice) was ever filed.
      expect(prog.review.keys, everyElement(isNot(contains('madd246'))));
    });
  });

  group('the drill and review quizzes', () {
    test('every mark has one spoken form', () {
      String s(String letter, String mark) => kidsSyllableSound(
        letters.firstWhere((l) => l.char == letter),
        tashkil.firstWhere((t) => t.id == mark),
      );
      expect(s('ب', 'fatha'), 'ba');
      expect(s('ت', 'kasra'), 'ti');
      expect(s('ث', 'damma'), 'thu');
      expect(s('ب', 'sukun'), 'b');
      expect(s('ت', 'shadda'), 'tt');
      expect(s('ن', 'fathatan'), 'nan');
      expect(s('ج', 'dammatan'), 'jun');
    });

    test('marks are read off the code points of real words', () {
      expect(kidsWordHasMark('sukun', 'قُلۡ'), isTrue);
      expect(kidsWordHasMark('sukun', 'هُوَ'), isFalse);
      expect(kidsWordHasMark('shadda', 'ٱللَّهِ'), isTrue);
      expect(kidsWordHasMark('shadda', 'قُلۡ'), isFalse);
      expect(() => kidsWordHasMark('fatha', 'x'), throwsArgumentError);
    });

    List<QuizQuestion> questionsOf(QuizScreen q) => q.questions;

    testWidgets('syllable quizzes: eight answerable, mixed-mark questions', (
      tester,
    ) async {
      final (settings, prog) = await _boot();
      late BuildContext ctx;
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      for (var seed = 0; seed < 40; seed++) {
        final qs = questionsOf(
          kidsSyllableQuiz(
            ctx,
            title: 'T',
            progressId: 'p',
            markIds: const ['fatha', 'kasra', 'damma'],
            rng: math.Random(seed),
          ),
        );
        expect(qs, hasLength(kidsQuizLength));
        final marksAsked = <String>{};
        for (final q in qs) {
          expect(q.options, hasLength(4), reason: 'seed $seed');
          expect(q.options.toSet(), hasLength(4), reason: 'options are unique');
          expect(q.correct, inInclusiveRange(0, 3));
          // The keyed answer really is that syllable's sound.
          final l = letters.firstWhere((x) => x.char == q.arabic![0]);
          final mark = tashkil.firstWhere(
            (t) => 'kids.syllable.${t.id}.${l.char}' == q.reviewId,
          );
          expect(q.options[q.correct], kidsSyllableSound(l, mark));
          marksAsked.add(mark.id);
        }
        expect(marksAsked, {'fatha', 'kasra', 'damma'}, reason: 'seed $seed');
      }
    });

    testWidgets('mark-spot quizzes: the machine agrees with every answer', (
      tester,
    ) async {
      final (settings, prog) = await _boot();
      late BuildContext ctx;
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      for (final markId in ['sukun', 'shadda']) {
        for (var seed = 0; seed < 40; seed++) {
          final qs = questionsOf(
            kidsMarkSpotQuiz(
              ctx,
              title: 'T',
              progressId: 'p',
              markId: markId,
              rng: math.Random(seed),
            ),
          );
          expect(qs, hasLength(kidsQuizLength));
          var multi = 0;
          for (final q in qs) {
            if (q.correctSet != null) {
              multi++;
              expect(q.correctSet, isNotEmpty);
              for (final (i, o) in q.options.indexed) {
                expect(
                  q.correctSet!.contains(i),
                  kidsWordHasMark(markId, o),
                  reason: '$markId seed $seed: "$o"',
                );
              }
            } else {
              final withMark = [
                for (final (i, o) in q.options.indexed)
                  if (kidsWordHasMark(markId, o)) i,
              ];
              expect(withMark, [q.correct], reason: '$markId seed $seed');
            }
          }
          expect(multi, 3);
        }
      }
    });

    testWidgets('the review quiz is eight answerable questions, mixed', (
      tester,
    ) async {
      final (settings, prog) = await _boot();
      late BuildContext ctx;
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      for (var seed = 0; seed < 25; seed++) {
        final qs = questionsOf(
          kidsReviewQuiz(
            ctx,
            title: 'T',
            progressId: 'p',
            rng: math.Random(seed),
          ),
        );
        expect(qs, hasLength(8));
        for (final q in qs) {
          expect(q.correctSet, isNull, reason: 'review has no multi-select');
          expect(q.correct, inInclusiveRange(0, q.options.length - 1));
        }
      }
    });

    testWidgets('a syllable quiz played through reports under its own id', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          Builder(
            builder: (c) => kidsSyllableQuiz(
              c,
              title: 'Ḥarakāt',
              progressId: 'kids.harakat.test',
              markIds: const ['fatha', 'kasra', 'damma'],
              rng: math.Random(3),
            ),
          ),
        ),
      );
      await tester.pump();
      final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
      for (final q in quiz.questions) {
        await tester.tap(find.text(q.options[q.correct]).first);
        await tester.pump(const Duration(milliseconds: 800));
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(prog.starsFor('kids.harakat.test'), 3);
    });
  });
}
