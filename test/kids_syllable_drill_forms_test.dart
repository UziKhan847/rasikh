import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';

import 'kids_test_support.dart';

/// The sukūn and shaddah drills now show a whole row of forms per letter,
/// not one unsayable bare glyph — this walks both end to end.
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

/// Drives the drill to completion the same way as the plain-mark tests: "I
/// said it!" on a letter step, the first option on a check-up.
Future<void> _finishDrill(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Continue').evaluate().isNotEmpty) return;
    final saidIt = find.text('I said it!');
    if (saidIt.evaluate().isNotEmpty) {
      await tester.tap(saidIt);
      continue;
    }
    final options = kidsTappables();
    if (options.evaluate().isNotEmpty) {
      await tester.tap(options.first);
      await tester.pump(const Duration(milliseconds: 800));
      continue;
    }
  }
  fail('the drill never reached its result screen');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> played;
  setUp(() => LetterAudio.log = played = []);
  tearDown(() => LetterAudio.log = null);

  testWidgets('sukūn opens on three tappable forms, none of them bare', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    final sukun = tashkil.firstWhere((t) => t.id == 'sukun');
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsSyllableDrill(mark: sukun, progressId: 'test.sukun'),
      ),
    );
    await tester.pump();

    // Three carrier forms for the first letter — بۡ must never appear bare,
    // the exact bug this fixes.
    expect(kidsTappables(), findsNWidgets(3));
    expect(find.text('بۡ'), findsNothing);
    expect(find.text('I said it!'), findsOneWidget);
    expect(find.text('Tap each one to hear it'), findsOneWidget);
  });

  testWidgets(
    'tapping a sukūn form plays that whole form, not just the letter',
    (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      final sukun = tashkil.firstWhere((t) => t.id == 'sukun');
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsSyllableDrill(mark: sukun, progressId: 'test.sukun'),
        ),
      );
      await tester.pump();

      await tester.tap(kidsTappables().first);
      await tester.pump();
      expect(played, hasLength(1));
      expect(played.single, contains('ۡ')); // the sukūn glyph itself
      expect(played.single.length, greaterThan(2)); // never a bare letter+mark
    },
  );

  testWidgets('shaddah opens on six tappable forms — the six combinations', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    final shadda = tashkil.firstWhere((t) => t.id == 'shadda');
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsSyllableDrill(mark: shadda, progressId: 'test.shadda'),
      ),
    );
    await tester.pump();

    expect(kidsTappables(), findsNWidgets(6));
    expect(find.text('بّ'), findsNothing);
  });

  testWidgets('every shaddah form carries a vowel — none is silent', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    final shadda = tashkil.firstWhere((t) => t.id == 'shadda');
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsSyllableDrill(mark: shadda, progressId: 'test.shadda'),
      ),
    );
    await tester.pump();

    for (final tile in kidsTappables().evaluate().toList()) {
      await tester.tap(find.byWidget(tile.widget));
      await tester.pump();
    }
    expect(played, hasLength(6));
    expect(played.toSet(), hasLength(6)); // six DIFFERENT forms, not repeats
  });

  testWidgets('walking a whole sukūn drill reports real progress', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    final sukun = tashkil.firstWhere((t) => t.id == 'sukun');
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsSyllableDrill(mark: sukun, progressId: 'kids.sukun.sukun'),
      ),
    );
    await tester.pump();
    await _finishDrill(tester);
    await tester.pump();

    expect(prog.starsFor('kids.sukun.sukun'), greaterThan(0));
  });

  testWidgets('walking a whole shaddah drill reports real progress', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    final shadda = tashkil.firstWhere((t) => t.id == 'shadda');
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsSyllableDrill(mark: shadda, progressId: 'kids.shadda.shadda'),
      ),
    );
    await tester.pump();
    await _finishDrill(tester);
    await tester.pump();

    expect(prog.starsFor('kids.shadda.shadda'), greaterThan(0));
  });

  testWidgets(
    'the check-up after a sukūn/shaddah run still asks about ONE glyph, '
    'the canonical form',
    (tester) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final (settings, prog) = await _boot();
      final shadda = tashkil.firstWhere((t) => t.id == 'shadda');
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsSyllableDrill(mark: shadda, progressId: 'test.shadda'),
        ),
      );
      await tester.pump();

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('I said it!'));
        await tester.pump();
      }
      expect(find.text('Which one did you just say?'), findsOneWidget);
      // Four glyph options, each one FULL form (fatḥah carrier + doubled
      // letter + fatḥah) — not the old bare `بّ`.
      expect(kidsTappables(), findsNWidgets(4));
      expect(find.text('بّ'), findsNothing);
    },
  );
}
