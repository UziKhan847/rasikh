import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_build_word.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_find_in_ayah.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';

import 'kids_test_support.dart';

/// Build the word: a real, joined word is shown and the child builds it from
/// separate letters, in reading order, with look-alikes among the tiles.
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

Finder _tile(String text) =>
    find.descendant(of: kidsTappables(), matching: find.text(text));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<List<String>> lines;
  setUpAll(() async {
    lines = [
      for (final s in kidsFindSurahs) ...await QuranRepo.words(s, 'uthmani'),
    ];
  });

  group('choosing words', () {
    test('every word is buildable, and its decoys are not in it', () {
      for (var seed = 0; seed < 40; seed++) {
        final words = kidsBuildWords(letters, lines, math.Random(seed));
        expect(words, hasLength(kidsBuildRound), reason: 'seed $seed');
        expect({for (final w in words) w.word}, hasLength(words.length));
        for (final w in words) {
          expect(w.letters, kidsBaseLetters(w.word));
          expect(w.letters.length, inInclusiveRange(3, 5));
          expect(w.decoys, hasLength(2));
          expect(w.decoys.toSet(), hasLength(2));
          for (final d in w.decoys) {
            expect(w.letters, isNot(contains(d)), reason: '${w.word}: $d');
            expect(letters.any((l) => l.char == d), isTrue);
          }
        }
      }
    });

    test('a child who knows twenty letters is offered only words in them', () {
      final known = letters.take(20).toList();
      final chars = {for (final l in known) l.char};
      for (var seed = 0; seed < 30; seed++) {
        final words = kidsBuildWords(known, lines, math.Random(seed));
        expect(words, isNotEmpty);
        for (final w in words) {
          expect(w.letters.every(chars.contains), isTrue, reason: w.word);
          expect(w.decoys.every(chars.contains), isTrue, reason: w.word);
        }
      }
    });

    test('with too few letters there is nothing to build', () {
      expect(
        kidsBuildWords(letters.take(2).toList(), lines, math.Random(1)),
        isEmpty,
      );
    });

    test('decoys are look-alikes of the word\'s own letters when there are '
        'any', () {
      // ب ت ث share a skeleton, so a word of ب and ت offers ث.
      final known = [for (final c in 'بتثاسر'.split('')) letterFor(c)];
      final words = kidsBuildWords(known, const [
        ['ستر'],
      ], math.Random(1));
      // (سترت is not a corpus word — only the shape of the choice matters.)
      for (final w in words) {
        expect(w.decoys, isNotEmpty);
      }
    });
  });

  group('a round', () {
    Future<List<KidsWordBuild>> open(
      WidgetTester tester,
      AppSettings s,
      ProgressStore p, {
      int seed = 3,
      List<ArabicLetter>? known,
    }) async {
      final k = known ?? letters;
      await tester.pumpWidget(
        _harness(
          s,
          p,
          KidsBuildWord(
            known: k,
            progressId: 'kids.practice.build',
            rng: math.Random(seed),
            lines: lines,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // The same draw the screen made (first use of that generator).
      return kidsBuildWords(k, lines, math.Random(seed));
    }

    Future<void> build(WidgetTester tester, KidsWordBuild w) async {
      for (final l in w.letters) {
        await tester.ensureVisible(_tile(l).first);
        await tester.tap(_tile(l).first);
        await tester.pump();
      }
    }

    testWidgets('shows the joined word, and builds it letter by letter', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      final words = await open(tester, settings, prog);

      expect(find.byType(Material), findsWidgets);
      expect(find.text('Build this word, letter by letter.'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      final w = words.first;
      expect(find.text(w.word), findsOneWidget, reason: 'the model to copy');
      // The letters and its decoys are on offer, separately.
      for (final l in {...w.letters, ...w.decoys}) {
        expect(_tile(l), findsWidgets, reason: l);
      }

      await build(tester, w);
      // Snapped together: the word now shows twice (model and result), and
      // the letters are no longer tiles.
      expect(find.text(w.word), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Step 2 of 4'), findsOneWidget);
    });

    testWidgets('four words built right earn three stars', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      final words = await open(tester, settings, prog);
      for (final w in words) {
        await build(tester, w);
        await tester.pump(const Duration(milliseconds: 800));
      }
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(prog.starsFor('kids.practice.build'), 3);
      expect(prog.dueCount, 0);
    });

    testWidgets('a wrong letter files the wanted letter for review, and '
        'the word still gets built', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      final words = await open(tester, settings, prog);
      final w = words.first;

      await tester.tap(_tile(w.decoys.first).first);
      await tester.pump();
      final wanted = w.letters.first;
      final card = prog.review['letter.$wanted']!;
      expect(card.arabic, wanted);
      expect(card.answer, letterFor(wanted).name);
      expect(find.text('Step 1 of 4'), findsOneWidget, reason: 'not undone');

      await tester.pump(const Duration(milliseconds: 600));
      await build(tester, w);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Step 2 of 4'), findsOneWidget);
    });

    testWidgets('letters must come in reading order', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      final w = (await open(tester, settings, prog)).first;
      // The last letter first is wrong (a word of distinct letters).
      if (w.letters.last != w.letters.first) {
        await tester.tap(_tile(w.letters.last).first);
        await tester.pump();
        expect(prog.review.containsKey('letter.${w.letters.first}'), isTrue);
      }
      await tester.pump(const Duration(milliseconds: 600)); // the flash fades
    });

    testWidgets('nothing to build says so instead of showing nothing', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsBuildWord(
            known: letters.take(2).toList(),
            progressId: 'kids.practice.build',
            lines: lines,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining("couldn't be loaded"), findsOneWidget);
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
      final words = await open(tester, settings, prog, seed: 7);
      for (final w in words) {
        expect(tester.takeException(), isNull);
        await build(tester, w);
        await tester.pump(const Duration(milliseconds: 800));
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Home offers Build the word once twenty letters are known', (
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
    for (final l in letters.take(19)) {
      prog.report('kids.letter.${l.char}', 3);
    }
    await tester.pump();
    await kidsHomeToPractice(tester);
    expect(find.text('Build the word'), findsNothing, reason: '19 is not 20');
    prog.report('kids.letter.${letters[19].char}', 3);
    await tester.pump();
    await kidsHomeToPractice(tester);
    expect(find.text('Build the word'), findsOneWidget);
  });
}
