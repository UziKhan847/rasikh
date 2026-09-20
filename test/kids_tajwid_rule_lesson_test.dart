import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_tajwid_rule_lesson.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;

import 'kids_test_support.dart';

/// A Tajwīd rule family taught rule by rule — from qalqalah's single rule to
/// nūn sākinah's five — rather than the reused hub's flat Learn page.
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
      home:
          child, // no Scaffold here: the widget itself must supply its own Material
      // ancestor (KidsLessonScaffold), exactly like pushKidsOverlay hosts it.
    ),
  ),
);

/// Drives the lesson to completion: "Next" on a rule card, the first option
/// on a check card, until the result screen's Continue button appears.
Future<void> _finishLesson(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Continue').evaluate().isNotEmpty) return;
    final next = find.text('Next');
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next.first);
      continue;
    }
    final options = find.byType(TapScale);
    if (options.evaluate().isNotEmpty) {
      await tester.tap(options.first);
      await tester.pump(const Duration(milliseconds: 1000));
      continue;
    }
  }
  fail('the lesson never reached its result screen');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens on the family intro, showing its own title and subtitle', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsTajwidRuleLesson(
          ruleIds: const ['qalqalah'],
          progressId: 'test.qalqalah',
          icon: Icons.bolt_rounded,
          title: (c) => 'Qalqalah',
          subtitle: (c) => 'The echoing bounce',
        ),
      ),
    );
    await tester.pump();

    // A real `Material` ancestor — plain `find.text` would still pass even
    // if every Text here fell back to MaterialApp's "no Material" debug
    // style (a double yellow underline).
    expect(find.byType(Material), findsWidgets);
    expect(find.text('Qalqalah'), findsOneWidget);
    expect(find.text('The echoing bounce'), findsOneWidget);
    // The rule itself hasn't been shown yet — only its own card carries the
    // Arabic name.
    expect(find.text('قَلْقَلَة'), findsNothing);
  });

  testWidgets('a single-rule family still walks to a real, graded result', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsTajwidRuleLesson(
          ruleIds: const ['qalqalah'],
          progressId: 'kids.tajwid.qalqalah.learn',
          icon: Icons.bolt_rounded,
          title: (c) => 'Qalqalah',
          subtitle: (c) => 'The echoing bounce',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Next')); // past the intro
    await tester.pump();
    expect(find.text('Qalqalah'), findsWidgets);
    expect(find.text('قَلْقَلَة'), findsOneWidget);

    await _finishLesson(tester);
    await tester.pump();

    expect(prog.starsFor('kids.tajwid.qalqalah.learn'), greaterThan(0));
  });

  testWidgets(
    'a five-rule family walks every rule, then checks with 4 options',
    (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsTajwidRuleLesson(
            ruleIds: const ['izhar', 'idgham_g', 'idgham_ng', 'iqlab', 'ikhfa'],
            progressId: 'test.nun',
            icon: Icons.record_voice_over_rounded,
            title: (c) => 'Nūn Sākinah',
            subtitle: (c) => 'Iẓhār, idghām, iqlāb, ikhfā',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Next')); // intro
      await tester.pump();
      for (final name in [
        'Iẓhār',
        'Idghām with Ghunnah',
        'Idghām without Ghunnah',
        'Iqlāb',
        'Ikhfā’',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      // Now on a check card: the question and four glyph-free option tiles.
      expect(find.text('Which rule is this?'), findsOneWidget);
      expect(find.byType(TapScale), findsNWidgets(4));
    },
  );
}
