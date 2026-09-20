import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_waqf_lesson.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;

import 'kids_test_support.dart';

/// Waqf & Stopping, read through the traffic light a child already knows —
/// stop, go, or either — not the reused Learn page's flat six-row list.
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

  testWidgets('opens on the traffic-light intro, not a mark', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsWaqfLesson(progressId: 'test.wq')),
    );
    await tester.pump();

    // A real `Material` ancestor — plain `find.text` would still pass even
    // if every Text here fell back to MaterialApp's "no Material" debug
    // style (a double yellow underline).
    expect(find.byType(Material), findsWidgets);
    expect(find.textContaining('traffic lights'), findsOneWidget);
    expect(find.text('Lāzim'), findsNothing);
  });

  testWidgets('the first mark shows its own action as a colored pill', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsWaqfLesson(progressId: 'test.wq2')),
    );
    await tester.pump();

    await tester.tap(find.text('Next')); // past the intro
    await tester.pump();

    expect(find.text('Lāzim'), findsOneWidget);
    expect(find.text('Must stop'), findsOneWidget);
  });

  testWidgets('walking all six marks reports a real, graded result', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsWaqfLesson(progressId: 'kids.waqf.learn'),
      ),
    );
    await tester.pump();

    await _finishLesson(tester);
    await tester.pump();

    expect(prog.starsFor('kids.waqf.learn'), greaterThan(0));
  });

  testWidgets(
    "a check-up over mu'ānaqah's own full āyah — the one long example, "
    'unlike every other mark\'s single word — never overflows',
    (tester) async {
      useReducedMotion(tester);
      // The check pool is drawn at random, so run it enough times that a
      // mu'ānaqah instance (3 of roughly 24 real examples across all six
      // marks) is overwhelmingly likely to come up at least once.
      for (var run = 0; run < 20; run++) {
        final (settings, prog) = await _boot();
        await tester.pumpWidget(
          _harness(
            settings,
            prog,
            KidsWaqfLesson(progressId: 'test.wq.stress.$run'),
          ),
        );
        await tester.pump();
        await _finishLesson(tester);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'run $run');
      }
    },
  );

  testWidgets('every sign is explained in a sentence a child can act on, not '
      'the scholarly note', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsWaqfLesson(progressId: 'test.why')),
    );
    await tester.pump();
    await tester.tap(find.text('Next')); // past the intro

    const expected = [
      'Stop here — carrying on would change the meaning.',
      "Don't stop here — the sentence isn't finished yet.",
      'You can stop or keep going — both are fine.',
      'Two of these signs go together — stop at one of them, never both.',
      'Stopping is better here, but you may keep going.',
      'Keeping going is better here, but you may stop.',
    ];
    final seen = <String>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump();
      final line = expected.where((t) => find.text(t).evaluate().isNotEmpty);
      expect(line, hasLength(1), reason: 'sign $i');
      seen.add(line.single);
      // The details a scholar wants (which muṣḥaf prints it) are not here.
      expect(find.textContaining('Indo-Pak'), findsNothing);
      await tester.tap(find.text('Next'));
    }
    expect(seen.toSet(), hasLength(6), reason: 'six signs, six meanings');
  });
}
