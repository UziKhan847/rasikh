import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_solar_lunar_lesson.dart';

import 'kids_test_support.dart';

/// Sun and Moon letters, taught step by step and by contrast — not the
/// reused Tajwīd rule page's single prose block plus a 14+14 chip grid.
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

/// Drives the lesson to completion: "Next" on a letter card, tapping every tile
/// into a bin on a sort card, until Continue appears.
Future<void> _finishLesson(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Continue').evaluate().isNotEmpty) return;

    final next = find.text('Next');
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next.first);
      continue;
    }
    if (sortCardShowing()) {
      await finishSortByTap(tester);
      continue;
    }
  }
  fail('the lesson never reached its result screen');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens on the sun/moon mnemonic, not a letter', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsSolarLunarLesson(progressId: 'test.sl'),
      ),
    );
    await tester.pump();

    // A real `Material` ancestor — plain `find.text` would still pass even
    // if every Text here fell back to MaterialApp's "no Material" debug
    // style (a double yellow underline).
    expect(find.byType(Material), findsWidgets);
    expect(find.text('ٱلشَّمۡس'), findsOneWidget);
    expect(find.text('ٱلۡقَمَر'), findsOneWidget);
  });

  testWidgets('walks solar and lunar letters, interleaved, to a real result', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsSolarLunarLesson(progressId: 'kids.solar_lunar.learn'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Next')); // past the intro
    await tester.pump();
    // First letter met is solar (ت) — solar and lunar interleave from here.
    expect(find.textContaining('Sun Letter'), findsOneWidget);

    await _finishLesson(tester);
    await tester.pump();

    expect(prog.starsFor('kids.solar_lunar.learn'), greaterThan(0));
  });

  testWidgets('a check-up sorts a mixed pool into sun and moon', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsSolarLunarLesson(progressId: 'test.sl2'),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Next')); // intro
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    expect(find.text('Sun or moon? Put each word in its place.'),
        findsOneWidget);
    // Five words to sort, into two bins.
    expect(find.byType(Draggable<String>), findsNWidgets(5));
    expect(find.text('Sun letters'), findsOneWidget);
    expect(find.text('Moon letters'), findsOneWidget);
  });
}
