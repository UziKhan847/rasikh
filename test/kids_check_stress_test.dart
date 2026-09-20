import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_madd_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_muqattaat_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_tajwid_rule_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_waqf_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_wasl_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_words_lesson.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;

import 'kids_test_support.dart';

/// Every check is drawn at random — options shuffled, distractors sampled, the
/// example picked from a pool — and `KidsChoiceCard` asserts that the right
/// answer is one of its options. One walk of each lesson only proves the
/// draws it happened to make, so this plays each one many times, tapping the
/// FIRST option every time (a wrong pick, then a second try, then a reveal
/// as often as a right answer), through to the result screen.
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

Future<void> _walk(WidgetTester tester) async {
  for (var i = 0; i < 400; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: 'step $i');
    if (find.text('Continue').evaluate().isNotEmpty) return;
    final saidIt = find.text('I said it!');
    if (saidIt.evaluate().isNotEmpty) {
      await tester.tap(saidIt.first, warnIfMissed: false);
      continue;
    }
    final next = find.text('Next');
    if (next.evaluate().isNotEmpty) {
      await tester.ensureVisible(next.first);
      await tester.tap(next.first, warnIfMissed: false);
      continue;
    }
    final check = find.text('Check');
    final tiles = find.byType(TapScale);
    if (check.evaluate().isNotEmpty) {
      if (tiles.evaluate().isNotEmpty) {
        await tester.tap(tiles.first, warnIfMissed: false);
        await tester.pump();
      }
      await tester.tap(check, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
      continue;
    }
    if (tiles.evaluate().isNotEmpty) {
      await tester.ensureVisible(tiles.first);
      await tester.tap(tiles.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
    }
  }
  fail('never reached the result screen');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final lessons = <String, Widget Function(int)>{
    'waqf': (n) => KidsWaqfLesson(progressId: 's.waqf.$n'),
    'waqf quiz': (n) => KidsWaqfLesson(progressId: 's.waqfq.$n', quiz: true),
    'waṣl quiz': (n) => KidsWaslLesson(progressId: 's.waslq.$n', quiz: true),
    'words quiz': (n) => KidsWordsLesson(progressId: 's.wordsq.$n', quiz: true),
    'muqaṭṭaʿāt quiz': (n) =>
        KidsMuqattaatLesson(progressId: 's.muq.$n', quiz: true),
    'madd quiz': (n) => KidsMaddLesson(progressId: 's.madd.$n', quiz: true),
    'tajwīd (nūn) quiz': (n) => KidsTajwidRuleLesson(
      ruleIds: const ['izhar', 'idgham_g', 'idgham_ng', 'iqlab', 'ikhfa'],
      progressId: 's.nun.$n',
      icon: Icons.record_voice_over_rounded,
      title: (c) => 'Nūn Sākinah',
      subtitle: (c) => 'x',
      quiz: true,
    ),
    'tajwīd (qalqalah) quiz': (n) => KidsTajwidRuleLesson(
      ruleIds: const ['qalqalah'],
      progressId: 's.qal.$n',
      icon: Icons.bolt_rounded,
      title: (c) => 'Qalqalah',
      subtitle: (c) => 'x',
      quiz: true,
    ),
  };

  for (final e in lessons.entries) {
    testWidgets('${e.key}: 12 plays, first option every time', (tester) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final (settings, prog) = await _boot();
      for (var run = 0; run < 12; run++) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          SettingsScope(
            settings: settings,
            child: ProgressScope(
              progress: prog,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: e.value(run),
              ),
            ),
          ),
        );
        await tester.pump();
        await _walk(tester);
      }
    });
  }
}
