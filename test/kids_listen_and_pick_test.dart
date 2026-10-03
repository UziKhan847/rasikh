import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_find_in_ayah.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_listen_and_pick.dart';

import 'kids_test_support.dart';

/// Listen & pick: a real word is played, the child picks it from three
/// written words. Audio is injected here — the real thing streams over the
/// network.
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

// al-Ikhlāṣ, word by word.
const _corpus = <int, List<List<String>>>{
  112: [
    ['قُلۡ', 'هُوَ', 'ٱللَّهُ', 'أَحَدٌ'],
    ['ٱللَّهُ', 'ٱلصَّمَدُ'],
    ['لَمۡ', 'يَلِدۡ', 'وَلَمۡ', 'يُولَدۡ'],
    ['وَلَمۡ', 'يَكُن', 'لَّهُۥ', 'كُفُوًا', 'أَحَدُۢ'],
  ],
};

Set<String> get _all => {for (final l in letters) l.char};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('building the rounds', () {
    test('every round points at the exact word it plays', () {
      for (var seed = 0; seed < 30; seed++) {
        final rounds = kidsBuildHeard(_corpus, _all, math.Random(seed));
        expect(rounds, hasLength(kidsListenRound));
        for (final r in rounds) {
          // (ayah, word) are 1-based, like the per-word recordings.
          expect(_corpus[r.surah]![r.ayah - 1][r.index - 1], r.word);
          expect(r.options, hasLength(3));
          expect(r.options.toSet(), hasLength(3));
          expect(r.options, contains(r.word));
        }
        // No word is asked twice in a round.
        expect({for (final r in rounds) r.word}, hasLength(rounds.length));
      }
    });

    test('words the child can read come first', () {
      // Only ا ل ه  م known: a handful of words are readable, the rest not.
      final known = {'ا', 'ل', 'ه', 'م'};
      final readable = {
        for (final line in _corpus[112]!)
          for (final w in line)
            if (kidsBaseLetters(w).length >= 2 &&
                kidsBaseLetters(w).length <= 6 &&
                kidsBaseLetters(w).every(known.contains))
              w,
      };
      for (var seed = 0; seed < 20; seed++) {
        final rounds = kidsBuildHeard(_corpus, known, math.Random(seed));
        final asked = {for (final r in rounds) r.word};
        expect(
          asked.where(readable.contains).length,
          readable.length,
          reason: 'every readable word is asked before an unreadable one',
        );
      }
    });

    test('on the real corpus, at every stage of the alphabet', () async {
      final corpus = {
        for (final s in kidsFindSurahs) s: await QuranRepo.words(s, 'uthmani'),
      };
      for (final n in [1, 5, 10, 20, 28]) {
        final known = {for (final l in letters.take(n)) l.char};
        for (var seed = 0; seed < 10; seed++) {
          final rounds = kidsBuildHeard(corpus, known, math.Random(seed));
          expect(rounds, hasLength(kidsListenRound), reason: 'known=$n');
          for (final r in rounds) {
            expect(corpus[r.surah]![r.ayah - 1][r.index - 1], r.word);
            expect(r.options.toSet(), hasLength(3));
          }
        }
      }
    });
  });

  group('the round', () {
    final played = <(int, int, int)>[];
    Future<void> record(int s, int a, int w) async => played.add((s, a, w));

    setUp(played.clear);

    Widget build(AppSettings s, ProgressStore p, {math.Random? rng}) =>
        _harness(
          s,
          p,
          KidsListenAndPick(
            known: _all,
            progressId: 'kids.practice.listen',
            rng: rng ?? math.Random(1),
            corpus: _corpus,
            play: record,
          ),
        );

    String heardWord() {
      final (s, a, w) = played.last;
      return _corpus[s]![a - 1][w - 1];
    }

    testWidgets('plays each word on its own, and the right pick moves on', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(build(settings, prog));
      await tester.pump();
      await tester.pump();

      expect(find.byType(Material), findsWidgets);
      expect(find.text('Which word did you hear?'), findsOneWidget);
      expect(played, hasLength(1), reason: 'the word plays as it appears');
      expect(find.text('Step 1 of 6'), findsOneWidget);

      await tester.tap(find.text(heardWord()));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Step 2 of 6'), findsOneWidget);
      expect(played, hasLength(2));
    });

    testWidgets('the speaker button plays the word again', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(build(settings, prog));
      await tester.pump();
      await tester.pump();
      await tester.tap(kidsListenIcon());
      await tester.pump();
      expect(played, hasLength(2));
      expect(played.first, played.last);
    });

    testWidgets('six right answers earn three stars under the practice id', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(build(settings, prog));
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < kidsListenRound; i++) {
        await tester.tap(find.text(heardWord()));
        await tester.pump(const Duration(milliseconds: 800));
      }
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(prog.starsFor('kids.practice.listen'), 3);
    });

    testWidgets('a wrong answer costs stars but never files a review card', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(build(settings, prog));
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < kidsListenRound; i++) {
        final right = heardWord();
        final wrong = find
            .descendant(of: kidsTappables(), matching: find.byType(Text))
            .evaluate()
            .map((e) => (e.widget as Text).data!)
            .firstWhere((t) => t != right && t != 'Next');
        await tester.tap(find.text(i == 0 ? wrong : right));
        await tester.pump(const Duration(milliseconds: 1300));
      }
      await tester.pump();
      expect(prog.starsFor('kids.practice.listen'), inInclusiveRange(1, 3));
      expect(prog.starsFor('kids.practice.listen'), lessThan(3));
      expect(prog.dueCount, 0);
    });

    testWidgets('a question can always be skipped, and skipping everything '
        'earns nothing', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(build(settings, prog));
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < kidsListenRound; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      expect(find.textContaining("couldn't play the sound"), findsOneWidget);
      expect(prog.starsFor('kids.practice.listen'), 0);
      expect(prog.xp, 0);
    });

    testWidgets('audio that fails is silent, not an error', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsListenAndPick(
            known: _all,
            progressId: 'kids.practice.listen',
            rng: math.Random(1),
            corpus: _corpus,
            play: (s, a, w) async => throw Exception('offline'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Which word did you hear?'), findsOneWidget);
    });

    testWidgets('fits a 320×568 phone at the largest Arabic size', (
      tester,
    ) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final (settings, prog) = await _boot();
      settings.kidsTextScale = 1.35;
      await tester.pumpWidget(build(settings, prog));
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < kidsListenRound; i++) {
        expect(tester.takeException(), isNull, reason: 'question $i');
        await tester.tap(find.text(heardWord()));
        await tester.pump(const Duration(milliseconds: 800));
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Home offers Listen & pick only once ten letters are known', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Test'));
    await tester.pumpWidget(
      _harness(settings, prog, KidsHomeScreen(onGoLearn: () {})),
    );
    await tester.pump();
    await tester.dragUntilVisible(
      find.text('Listening'),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    expect(find.text('Listen & pick'), findsNothing);

    for (final l in letters.take(9)) {
      prog.report('kids.letter.${l.char}', 3);
    }
    await tester.pump();
    await kidsHomeToPractice(tester);
    expect(find.text('Listen & pick'), findsNothing, reason: 'nine is not ten');

    prog.report('kids.letter.${letters[9].char}', 3);
    await tester.pump();
    await kidsHomeToPractice(tester);
    expect(find.text('Listen & pick'), findsOneWidget);
  });
}
