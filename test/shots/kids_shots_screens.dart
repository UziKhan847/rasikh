import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_components.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_desktop_nav.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/data/kids_content.dart' show kidsLetterPath;
import 'package:qiraah_arabiyyah/screens/kids/kids_extra_letter_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_letter_flow.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_lookalike_quiz.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_bingo.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_memory_match.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_game_three_in_a_row.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_madd_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_muqattaat_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_tajwid_rule_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_waqf_lesson.dart';

import '../kids_test_support.dart';

/// Puts the app into the state the prototype's demo screens show, then opens
/// [screen]. The prototype's data (13/28 letters, 1110 XP, level 12…) is matched
/// where the app's own progress model can express it.
Future<void> seedAndOpen(WidgetTester tester, String screen) async {
  // The profile screens come before any child's progress exists.
  if (screen == 'profile' || screen == 'who') return;
  if (screen == 'desk') {
    await tester.pump(const Duration(milliseconds: 300));
    return;
  }
  final prog = ProgressScope.of(tester.element(find.byType(Scaffold).first));
  // A child partway through: letters done, into Joining Shapes.
  const done = ['ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش'];
  for (final c in done) {
    prog.report('kids.letter.$c', 3);
  }
  prog.awardXp(1110 - prog.xp);
  prog.awardGems(105 - prog.gems);
  // The equipped theme is one the child bought.
  final theme = SettingsScope.of(tester.element(find.byType(Scaffold).first)).activeKidsProfile!.theme;
  if (theme != 'kids') prog.shopOwned.add(theme);
  await tester.pumpAndSettle();

  Future<void> tab(String label) async {
    await tester.tap(kidsTab(label));
    await tester.pumpAndSettle();
  }

  // A lesson, pushed the way the app pushes it.
  final lesson = kidsShotLessons[screen];
  if (lesson != null) {
    pushKidsOverlay(tester.element(find.byType(KbNavBar)),
        title: screen, builder: lesson);
    // Bounded: some lessons animate forever (the tracing board's pulse).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return;
  }

  switch (screen) {
    case 'home':
      break;
    case 'learn':
      await tab('Learn');
    case 'rank':
      await tab('Rank');
    case 'rewards':
      await tab('Rewards');
    case 'rewardsscrolled':
      // Both sideways shelves part-scrolled, so both of each one's fades show.
      await tab('Rewards');
      for (final g in [find.byType(GridView).first, find.byType(GridView).last]) {
        await tester.drag(g, const Offset(-160, 0));
        await tester.pumpAndSettle();
      }
    case 'me':
      await tab('Me');
    case 'stage':
      await tab('Learn');
      await tester.tap(find.byKey(const ValueKey('kids.block.letters')));
      await tester.pumpAndSettle();
  }
}

/// Lessons the harness can open by name.
final kidsShotLessons = <String, WidgetBuilder>{
  'hamzah': (_) => const KidsExtraLetterLesson(char: 'ئ'),
  'drill': (_) => KidsSyllableDrill(
      mark: tashkil.firstWhere((t) => t.id == 'fatha'), progressId: 'shot.drill'),
  'madd': (_) => const KidsMaddLesson(),
  'waqf': (_) => const KidsWaqfLesson(progressId: 'shot.waqf'),
  'tajwid': (_) => KidsTajwidRuleLesson(
      ruleIds: const ['izhar', 'idgham_g'],
      progressId: 'shot.nun',
      icon: Icons.record_voice_over_rounded,
      title: (c) => 'Nūn Sākinah',
      subtitle: (c) => 'Iẓhār, idghām, iqlāb, ikhfā'),
  'muqattaat': (_) => const KidsMuqattaatLesson(progressId: 'shot.mq'),
  'waqfquiz': (_) => const KidsWaqfLesson(progressId: 'shot.wq', quiz: true),
  'quiz': (c) => kidsLookalikeQuiz(c,
      known: kidsLetterPath.take(13).toList(), progressId: 'shot.q'),
  'letter': (_) => const KidsLetterFlow(letter: 'و'),
  'trace': (_) => const KidsLetterFlow(letter: 'ت', introduce: false),
  'bingo': (_) => KidsGameBingo(known: kidsLetterPath.take(13).toList(), progressId: 'shot.b'),
  'ttt': (_) => KidsThreeInARow(known: kidsLetterPath.take(13).toList(), progressId: 'shot.t'),
  'memory': (_) => KidsMemoryMatch(known: kidsLetterPath.take(13).toList(), progressId: 'shot.m'),
};
