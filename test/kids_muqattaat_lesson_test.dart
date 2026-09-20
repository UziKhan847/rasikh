import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/muqattaat.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_muqattaat_lesson.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;

import 'kids_test_support.dart';

/// Ḥurūf Muqaṭṭaʿāt, one set at a time, each letter named and counted on its
/// own — not the reused Learn page's flat list of 14 rows.
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
  for (var i = 0; i < 60; i++) {
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

  testWidgets('opens on the spelling intro, not a letter set', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsMuqattaatLesson(progressId: 'test.mq'),
      ),
    );
    await tester.pump();

    // A real `Material` ancestor — plain `find.text` would still pass even
    // if every Text here fell back to MaterialApp's "no Material" debug
    // style (a double yellow underline).
    expect(find.byType(Material), findsWidgets);
    expect(find.textContaining('Alif. Lām. Mīm.'), findsOneWidget);
  });

  testWidgets('the first set names every letter with its own madd count', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsMuqattaatLesson(progressId: 'test.mq2'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Next')); // past the intro
    await tester.pump();

    // alif_lam_mim: ا ل م — alif has no stretch, lām and mīm are six counts.
    expect(find.text(muqattaatSets.first.displayText), findsOneWidget);
    expect(find.text("No stretch — it's just Alif"), findsOneWidget);
    expect(find.text('6 counts'), findsNWidgets(2));
  });

  testWidgets('walking all 14 sets reports a real, graded result', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsMuqattaatLesson(progressId: 'kids.muqattaat.learn'),
      ),
    );
    await tester.pump();

    await _finishLesson(tester);
    await tester.pump();

    expect(prog.starsFor('kids.muqattaat.learn'), greaterThan(0));
  });
}
