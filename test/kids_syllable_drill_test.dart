import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';

import 'kids_test_support.dart';

/// Qāʿidah Nūrāniyyah's own drill: one mark, walked letter by letter through
/// the whole alphabet — بَ تَ ثَ … — rather than a single prose page about the
/// mark. Alif takes none of these marks, so it must never appear; a
/// recognition check-up should land every five letters; and finishing must
/// report real progress under the drill's own id.
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

/// Drives the drill to completion: taps "I said it!" on a letter step, or the
/// first option on a check-up step, until the result screen's Continue
/// button appears. Bounded, so a stuck flow fails the test instead of hanging.
Future<void> _finishDrill(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
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
      // The check-up holds its answer on screen briefly before advancing.
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

  testWidgets('opens on the first non-alif letter, never on alif itself', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    final fatha = tashkil.firstWhere((t) => t.id == 'fatha');
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsSyllableDrill(mark: fatha, progressId: 'test.fatha'),
      ),
    );
    await tester.pump();

    // A real `Material` ancestor — plain `find.text` would still pass even
    // if every Text here fell back to MaterialApp's "no Material" debug
    // style (a double yellow underline).
    expect(find.byType(Material), findsWidgets);
    // Alif takes no ḥarakah — the first letter shown must be Bāʼ, not Alif.
    expect(find.text('بَ'), findsOneWidget);
    expect(find.text('اَ'), findsNothing);
  });

  testWidgets(
    'the Listen button plays the composed syllable, not just the letter',
    (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      final kasra = tashkil.firstWhere((t) => t.id == 'kasra');
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsSyllableDrill(mark: kasra, progressId: 'test.kasra'),
        ),
      );
      await tester.pump();

      await tester.tap(kidsListenIcon());
      await tester.pump();
      expect(played, ['بِ']);
    },
  );

  testWidgets(
    'walking every letter reports real progress and never touches ا',
    (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      final damma = tashkil.firstWhere((t) => t.id == 'damma');
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsSyllableDrill(mark: damma, progressId: 'kids.harakat.damma'),
        ),
      );
      await tester.pump();

      // The alif card never appears at any point in the whole walk.
      for (var i = 0; i < letters.length; i++) {
        if (find.text('Continue').evaluate().isNotEmpty) break;
        expect(find.text('اُ'), findsNothing);
        final saidIt = find.text('I said it!');
        if (saidIt.evaluate().isNotEmpty) {
          await tester.tap(saidIt);
          await tester.pump();
        } else {
          final options = kidsTappables();
          if (options.evaluate().isNotEmpty) {
            await tester.tap(options.first);
            await tester.pump(const Duration(milliseconds: 800));
          }
        }
      }
      await _finishDrill(tester);
      await tester.pump();

      expect(prog.starsFor('kids.harakat.damma'), greaterThan(0));
    },
  );

  testWidgets('a check-up lands every five letters, drawn from the pool', (
    tester,
  ) async {
    useReducedMotion(tester);
    // A phone: in the wide default window the grid lays out lazily and the
    // second row of options is not built yet.
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

    // Five "I said it!" taps should surface the check-up's own prompt.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('I said it!'));
      await tester.pump();
    }
    expect(find.text('Which one did you just say?'), findsOneWidget);
    expect(kidsTappables(), findsNWidgets(4));
  });
}
