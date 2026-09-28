// The Kids lessons the step-by-step walkers run (the 320×568 smoke test and
// the lesson scene audit), and the walker itself.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart' show kidsLetterPath;
import 'package:qiraah_arabiyyah/screens/kids/kids_extra_letter_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_bingo.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_memory_match.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_three_in_a_row.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_letter_flow.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_lookalike_quiz.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_practice_screens.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_review_recap.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_madd_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_muqattaat_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_solar_lunar_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_stage_quizzes.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_special_shapes_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_tajwid_rule_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_waqf_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_wasl_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_words_lesson.dart';

import 'kids_test_support.dart';

/// Steps through whatever the screen asks for until its result screen (or the
/// end of a lesson that has none), failing on any framework exception.
Future<void> kidsWalk(
  WidgetTester tester, {
  void Function(int step)? onStep,
}) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: 'step $i');
    onStep?.call(i);
    if (find.text('Continue').evaluate().isNotEmpty) return;

    for (final label in ['I said it!', 'Next']) {
      final b = find.text(label);
      if (b.evaluate().isNotEmpty) {
        await tester.ensureVisible(b.first);
        await tester.tap(b.first, warnIfMissed: false);
        continue;
      }
    }
    if (sortCardShowing()) {
      await finishSortByTap(tester);
      continue;
    }
    final check = find.text('Check');
    if (check.evaluate().isNotEmpty) {
      final tile = kidsTappables();
      if (tile.evaluate().isNotEmpty) {
        await tester.tap(tile.first, warnIfMissed: false);
        await tester.pump();
      }
      await tester.tap(check, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
      continue;
    }
    final options = kidsTappables();
    if (options.evaluate().isNotEmpty) {
      await tester.ensureVisible(options.first);
      await tester.tap(options.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
    }
  }
}

Map<String, Widget Function()> kidsWalkLessons() => {
  'madd': () => const KidsMaddLesson(),
  'waṣl': () => const KidsWaslLesson(progressId: 'smoke.wasl'),
  'waqf': () => const KidsWaqfLesson(progressId: 'smoke.waqf'),
  'words': () => const KidsWordsLesson(progressId: 'smoke.words'),
  'muqaṭṭaʿāt': () => const KidsMuqattaatLesson(progressId: 'smoke.muqattaat'),
  'sun and moon': () => const KidsSolarLunarLesson(progressId: 'smoke.solar'),
  'tajwīd (nūn, 5 rules)': () => KidsTajwidRuleLesson(
    ruleIds: const ['izhar', 'idgham_g', 'idgham_ng', 'iqlab', 'ikhfa'],
    progressId: 'smoke.nun',
    icon: Icons.record_voice_over_rounded,
    title: (c) => 'Nūn Sākinah',
    subtitle: (c) => 'Iẓhār, idghām, iqlāb, ikhfā',
  ),
  'special shapes (stacking)': () => const KidsSpecialShapesLesson(
    group: 'stacking',
    progressId: 'smoke.stacking',
  ),
  'special shapes (heights)': () =>
      const KidsSpecialShapesLesson(group: 'tails', progressId: 'smoke.tails'),
  'ḥarakāt drill (last session)': () => KidsSyllableDrill(
    mark: tashkil.firstWhere((t) => t.id == 'dammatan'),
    progressId: 'smoke.drill',
    start: kidsDrillRanges().last.$1,
    end: kidsDrillRanges().last.$2,
  ),
  'waqf quiz': () => const KidsWaqfLesson(progressId: 'smoke.wq', quiz: true),
  'waṣl quiz': () => const KidsWaslLesson(progressId: 'smoke.wl', quiz: true),
  'words quiz': () => const KidsWordsLesson(progressId: 'smoke.wd', quiz: true),
  'muqaṭṭaʿāt quiz': () =>
      const KidsMuqattaatLesson(progressId: 'smoke.mq', quiz: true),
  'sun and moon quiz': () =>
      const KidsSolarLunarLesson(progressId: 'smoke.sl', quiz: true),
  'madd quiz': () => const KidsMaddLesson(progressId: 'smoke.md', quiz: true),
  'tajwīd (nūn) quiz': () => KidsTajwidRuleLesson(
    ruleIds: const ['izhar', 'idgham_g', 'idgham_ng', 'iqlab', 'ikhfa'],
    progressId: 'smoke.nq',
    icon: Icons.record_voice_over_rounded,
    title: (c) => 'Nūn Sākinah',
    subtitle: (c) => 'x',
    quiz: true,
  ),
  'ḥarakāt quiz': () => Builder(
    builder: (c) => kidsSyllableQuiz(
      c,
      title: 'Ḥarakāt',
      progressId: 'smoke.hq',
      markIds: const ['fatha', 'kasra', 'damma'],
    ),
  ),
  'shaddah quiz': () => Builder(
    builder: (c) => kidsMarkSpotQuiz(
      c,
      title: 'Shaddah',
      progressId: 'smoke.sq',
      markId: 'shadda',
    ),
  ),
  'review quiz': () => Builder(
    builder: (c) => kidsReviewQuiz(c, title: 'Review', progressId: 'smoke.rq'),
  ),
  'look-alikes': () => Builder(
    builder: (c) =>
        kidsLookalikeQuiz(c, known: letters, progressId: 'smoke.lookalike'),
  ),
  'extra letter': () => const KidsExtraLetterLesson(char: 'ئ'),
  'letter lesson': () => const KidsLetterFlow(letter: 'ب'),
  'flashcards': () => const KidsFlashcardsScreen(),
  'listening': () => const KidsListeningScreen(),
  'review recap': () => const KidsReviewRecap(),
  'three in a row': () => KidsThreeInARow(
      known: kidsLetterPath.take(13).toList(), progressId: 'smoke.ttt'),
  'memory match': () => KidsMemoryMatch(
      known: kidsLetterPath.take(13).toList(), progressId: 'smoke.mm'),
  'letter bingo': () => KidsGameBingo(
      known: kidsLetterPath.take(13).toList(), progressId: 'smoke.bingo'),
};
