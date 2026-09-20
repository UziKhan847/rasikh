import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_wasl_lesson.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;

import 'kids_test_support.dart';

/// What happens at the seam between two words, one idea at a time — hamzat
/// al-waṣl, the two zeros, and tanwīn meeting a waṣl alif — not the reused
/// Learn page's six-row list (two of which, solar/lunar, are taught
/// elsewhere already).
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

  testWidgets('opens on the hamzat al-waṣl rule itself', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsWaslLesson(progressId: 'test.wasl')),
    );
    await tester.pump();

    // A real `Material` ancestor — not just text on screen — or every Text
    // here silently falls back to MaterialApp's "no Material" debug style
    // (a double yellow underline) the way every lesson built after
    // `KidsLetterFlow` once did, invisible to a plain `find.text` assertion.
    expect(find.byType(Material), findsWidgets);
    expect(find.text('Hamzat al-Waṣl'), findsOneWidget);
  });

  testWidgets('walks the rectangular zero, then the round zero, then tanwīn', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsWaslLesson(progressId: 'test.wasl2')),
    );
    await tester.pump();

    await tester.tap(find.text('Next')); // past the rule
    await tester.pump();
    expect(find.text('The rectangular zero'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('The round zero'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Tanwīn meets hamzat al-waṣl'), findsOneWidget);
  });

  testWidgets('a check-up asks whether the mark ever makes a sound', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(settings, prog, const KidsWaslLesson(progressId: 'test.wasl3')),
    );
    await tester.pump();

    // Rule → rectangular zero → round zero → tanwīn, then the first check.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    expect(find.text('Does this mark ever make a sound?'), findsOneWidget);
    expect(find.byType(TapScale), findsNWidgets(2));
  });

  testWidgets('walking the whole lesson reports a real, graded result', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsWaslLesson(progressId: 'kids.wasl.learn'),
      ),
    );
    await tester.pump();

    await _finishLesson(tester);
    await tester.pump();

    expect(prog.starsFor('kids.wasl.learn'), greaterThan(0));
  });
}
