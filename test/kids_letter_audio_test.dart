import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_letter_flow.dart';
import 'package:qiraah_arabiyyah/screens/tracing_screen.dart'
    show TracingBoard;

import 'kids_test_support.dart';

/// Sound and shape, together. A letter lesson is the one place in the app
/// where hearing the letter and seeing it have to land at the same moment, so
/// the two things the child actually does — saying it, writing it — each say
/// the letter back.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> played;
  setUp(() => LetterAudio.log = played = []);
  tearDown(() => LetterAudio.log = null);

  test('a letter clip is addressed by codepoint, not by name', () {
    // Names are language-dependent and `glyphId` is shared (ب ت ث are all
    // 'ba'), so neither can name a file. A codepoint is unique and stable.
    expect(LetterAudio.assetName('ب'), '0628');
    expect(LetterAudio.assetPath('ب', LetterAudio.kids),
        'audio/letters/kids/0628.mp3');
    expect(LetterAudio.assetPath('ب', LetterAudio.adult),
        'audio/letters/adult/0628.mp3');
    // Every taught letter resolves to a distinct file.
    final paths = {
      for (final l in letters) LetterAudio.assetPath(l.char, LetterAudio.kids)
    };
    expect(paths, hasLength(letters.length));
  });

  testWidgets('every "I said it!" answers with the letter', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ب',
          traces: [KidsTraceStep('naskh_few', 'iso')],
        )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Five repetitions, five models to copy — not one at the start and then
    // four unchecked guesses.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('I said it!'));
      await tester.pump();
    }
    expect(played, ['ب', 'ب', 'ب', 'ب', 'ب']);
  });

  testWidgets('finishing a trace says the letter', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ج',
          introduce: false,
          traces: [KidsTraceStep('naskh_few', 'iso', repeat: 2)],
        )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(played, isEmpty, reason: 'nothing has been traced yet');

    // Grading is [TracingBoard]'s own job and is driven by real finger
    // gestures; what is under test is what the lesson does with the result,
    // so the board's callback is invoked directly.
    tester.widget<TracingBoard>(find.byType(TracingBoard)).onStars!(3);
    await tester.pump();
    expect(played, ['ج']);

    // And again on the next repetition — every completed shape, not just the
    // first of them.
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    tester.widget<TracingBoard>(find.byType(TracingBoard)).onStars!(1);
    await tester.pump();
    expect(played, ['ج', 'ج']);
  });

  testWidgets('the Listen button plays the letter, not a verse',
      (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ت',
          traces: [KidsTraceStep('naskh_few', 'iso')],
        )));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(played, ['ت']);
  });

  test('play never falls back to a verse when no clip is bundled', () async {
    // Exercise the real path, not the [LetterAudio.log] test seam — this is
    // exactly the removed behaviour: it used to reach for the letter's
    // example verse here instead of reporting nothing to play.
    LetterAudio.log = null;
    addTearDown(() => LetterAudio.log = played);
    final ok = await LetterAudio.play(letterFor('ب'));
    expect(ok, isFalse,
        reason: 'no clip ships yet, and there must be no verse fallback');
  });

  testWidgets('an explicit Listen tap says so when no clip exists yet',
      (tester) async {
    LetterAudio.log = null;
    addTearDown(() => LetterAudio.log = played);
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(_harness(
        settings,
        prog,
        const KidsLetterFlow(
          letter: 'ث',
          traces: [KidsTraceStep('naskh_few', 'iso')],
        )));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(find.textContaining('coming soon'), findsOneWidget);
  });
}
