import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_memorise.dart';

import 'kids_test_support.dart';

/// Memorise: al-Ikhlāṣ in three short sittings — listen in phrases, say it
/// three times, say it as its words vanish, put the words back in order, then
/// "what comes next?". Everything gradable works with no audio.
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

/// A tap that first scrolls its target into view — on a small phone the
/// options of a long question sit below the fold, as they should.
Future<void> _tapTile(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

/// Plays a session through, answering everything correctly.
Future<void> _solve(
  WidgetTester tester,
  List<List<String>> ayahs,
  int session,
) async {
  final mine = kidsMemoriseAyahsOf(session);
  final nexts = mine.isEmpty ? [1, 2, 3] : [mine.first];
  var order = 0;
  var next = 0;
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: 'step $i');
    if (find.text('Continue').evaluate().isNotEmpty) return;
    if (find.text('Put the words in order.').evaluate().isNotEmpty) {
      for (final w in ayahs[mine[order] - 1]) {
        await _tapTile(tester, _tile(w).first);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 800));
      order++;
      continue;
    }
    if (find.text('Put the āyāt in order.').evaluate().isNotEmpty) {
      for (final a in ayahs) {
        await _tapTile(tester, _tile(a.join(' ')).first);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 800));
      continue;
    }
    if (find.text('What comes next?').evaluate().isNotEmpty) {
      final from = nexts[next++];
      await _tapTile(tester, _tile(ayahs[from].join(' ')).first);
      await tester.pump(const Duration(milliseconds: 1000));
      continue;
    }
    final hide = find.text('Hide more');
    if (hide.evaluate().isNotEmpty) {
      await tester.tap(hide);
      continue;
    }
    for (final label in ['I said it!', 'Next']) {
      final b = find.text(label);
      if (b.evaluate().isNotEmpty) {
        await tester.ensureVisible(b.first);
        await tester.tap(b.first, warnIfMissed: false);
        break;
      }
    }
  }
  fail('never reached the result screen');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chunks and fading', () {
    test('phrases are even, at most three words, and lose nothing', () {
      List<String> w(int n) => [for (var i = 0; i < n; i++) 'w$i'];
      expect(kidsChunks(w(1)).map((c) => c.length), [1]);
      expect(kidsChunks(w(2)).map((c) => c.length), [2]);
      expect(kidsChunks(w(3)).map((c) => c.length), [3]);
      expect(kidsChunks(w(4)).map((c) => c.length), [2, 2]);
      expect(kidsChunks(w(5)).map((c) => c.length), [3, 2]);
      expect(kidsChunks(w(6)).map((c) => c.length), [3, 3]);
      expect(kidsChunks(w(7)).map((c) => c.length), [3, 2, 2]);
      for (var n = 1; n < 20; n++) {
        final chunks = kidsChunks(w(n));
        expect(chunks.expand((c) => c).toList(), w(n), reason: '$n words');
        expect(chunks.every((c) => c.length <= 3), isTrue);
      }
      expect(kidsChunks(const []), isEmpty);
    });

    test('the fading cue steps down to nothing without repeating itself', () {
      expect(kidsFadeLevels(2), [2, 1, 0]);
      expect(kidsFadeLevels(3), [3, 1, 0]);
      expect(kidsFadeLevels(4), [4, 2, 1, 0]);
      expect(kidsFadeLevels(5), [5, 3, 1, 0]);
      expect(kidsFadeLevels(1), [1, 0]);
      for (var n = 1; n < 30; n++) {
        final l = kidsFadeLevels(n);
        expect(l.first, n);
        expect(l.last, 0);
        for (var i = 1; i < l.length; i++) {
          expect(l[i], lessThan(l[i - 1]), reason: '$n words');
        }
      }
    });

    test('al-Ikhlāṣ is four āyāt in the corpus', () async {
      final ayahs = await QuranRepo.words(kidsMemoriseSurah, 'uthmani');
      expect(ayahs.map((a) => a.length), [4, 2, 4, 5]);
    });

    test(
      'the next sitting is the first one not yet done, then revision',
      () async {
        final (_, prog) = await _boot();
        expect(kidsMemoriseNextSession(prog), 1);
        prog.report('kids.memorise.1', 2);
        expect(kidsMemoriseNextSession(prog), 2);
        prog.report('kids.memorise.2', 3);
        expect(kidsMemoriseNextSession(prog), 3);
        prog.report('kids.memorise.3', 3);
        expect(kidsMemoriseNextSession(prog), 3, reason: 'revision repeats');
      },
    );
  });

  group('a sitting', () {
    late List<List<String>> ayahs;
    setUpAll(() async {
      ayahs = await QuranRepo.words(kidsMemoriseSurah, 'uthmani');
    });

    Future<void> open(
      WidgetTester tester,
      AppSettings s,
      ProgressStore p,
      int session, {
      int seed = 1,
    }) async {
      await tester.pumpWidget(
        _harness(
          s,
          p,
          KidsMemoriseLesson(
            session: session,
            progressId: 'kids.memorise.$session',
            ayahs: ayahs,
            rng: math.Random(seed),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('opens on the listening card, phrase by phrase', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await open(tester, settings, prog, 1);

      expect(find.byType(Material), findsWidgets);
      expect(find.text('Step 1 of 9'), findsOneWidget);
      expect(
        find.text('Listen to the āyah and follow the words.'),
        findsOneWidget,
      );
      // Four words, two phrases of two — one phrase to a line.
      final first = ayahs[0];
      expect(find.text(first.sublist(0, 2).join(' ')), findsOneWidget);
      expect(find.text(first.sublist(2).join(' ')), findsOneWidget);
      expect(
        find.text('Listen'),
        findsWidgets,
        reason: 'the recitation is one tap away',
      );
    });

    testWidgets('saying it counts three, then moves on by itself', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await open(tester, settings, prog, 1);
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Say it out loud — three times!'), findsOneWidget);
      await tester.tap(find.text('I said it!'));
      await tester.pump();
      await tester.tap(find.text('I said it!'));
      await tester.pump();
      expect(find.text('Say it out loud — three times!'), findsOneWidget);
      await tester.tap(find.text('I said it!'));
      await tester.pump();
      expect(find.textContaining('fade away'), findsOneWidget);
    });

    testWidgets('the words vanish a step at a time, and Peek brings them '
        'back', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await open(tester, settings, prog, 1);
      await tester.tap(find.text('Next'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('I said it!'));
        await tester.pump();
      }

      int hidden() => tester
          .widgetList<Opacity>(find.byType(Opacity))
          .where((o) => o.opacity == 0)
          .length;
      // Four words: 4, 2, 1, 0 visible.
      expect(hidden(), 0);
      await tester.tap(find.text('Hide more'));
      await tester.pump();
      expect(hidden(), 2);
      await tester.tap(find.text('Hide more'));
      await tester.pump();
      expect(hidden(), 3);
      expect(
        find.text('Peek'),
        findsNothing,
        reason: 'not until nothing is left',
      );
      await tester.tap(find.text('Hide more'));
      await tester.pump();
      expect(hidden(), 4);

      await tester.tap(find.text('Peek'));
      await tester.pump();
      expect(hidden(), 0, reason: 'a peek shows everything');
      await tester.pump(const Duration(milliseconds: 2000));
      expect(hidden(), 4, reason: 'and hides it again');

      await tester.tap(find.text('I said it!'));
      await tester.pump();
      expect(find.text('Put the words in order.'), findsOneWidget);
    });

    testWidgets('the words are never offered already in order', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      for (var seed = 0; seed < 25; seed++) {
        await tester.pumpWidget(const SizedBox());
        await open(tester, settings, prog, 1, seed: seed);
        await tester.tap(find.text('Next'));
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('I said it!'));
          await tester.pump();
        }
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Hide more'));
          await tester.pump();
        }
        await tester.tap(find.text('I said it!'));
        await tester.pump();

        // Bank tiles, left to right on screen = the order offered (the wrap
        // is right-to-left, so reading order is descending x).
        final tiles = [
          for (final w in ayahs[0]) (w, tester.getCenter(_tile(w).first).dx),
        ]..sort((a, b) => b.$2.compareTo(a.$2));
        expect(
          tiles.map((t) => t.$1).toList(),
          isNot(ayahs[0]),
          reason: 'seed $seed: nothing left to do',
        );
      }
    });

    testWidgets('a full first sitting, all right, earns three stars', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await open(tester, settings, prog, 1);
      await _solve(tester, ayahs, 1);
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
      expect(prog.starsFor('kids.memorise.1'), 3);
      // Right answers put no card in the queue.
      expect(prog.dueCount, 0);
    });

    testWidgets('the second sitting teaches the other two āyāt', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await open(tester, settings, prog, 2);
      expect(find.text('Step 1 of 9'), findsOneWidget);
      expect(find.text(ayahs[2].sublist(0, 2).join(' ')), findsOneWidget);
      await _solve(tester, ayahs, 2);
      await tester.pump();
      expect(prog.starsFor('kids.memorise.2'), 3);
    });

    testWidgets('a wrong "what comes next" files that āyah for revision', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await open(tester, settings, prog, 3);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('What comes next?'), findsOneWidget);

      // Pick something that is not āyah 2.
      final wrong = ayahs[2].join(' ');
      await tester.tap(_tile(wrong).first);
      await tester.pump(const Duration(milliseconds: 1000));

      final card = prog.review['kids.memorise.$kidsMemoriseSurah.1']!;
      expect(card.arabic, ayahs[0].join(' '));
      expect(card.answer, ayahs[1].join(' '));
      expect(card.optionsArabic, isTrue);
      // The card never has its answer on its face.
      expect(card.arabic, isNot(card.answer));
      expect(card.distractors, isNot(contains(card.answer)));
    });

    testWidgets('the revision runs through every āyah and puts the sūrah '
        'in order', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await open(tester, settings, prog, 3);
      await _solve(tester, ayahs, 3);
      await tester.pump();
      expect(prog.starsFor('kids.memorise.3'), 3);
    });

    testWidgets('a right answer to an earlier miss promotes the card', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      prog.recordMiss(
        'kids.memorise.$kidsMemoriseSurah.1',
        ayahs[0].join(' '),
        answer: ayahs[1].join(' '),
        distractors: [ayahs[2].join(' '), ayahs[3].join(' ')],
      );
      await open(tester, settings, prog, 3);
      await tester.tap(_tile(ayahs[1].join(' ')).first);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(prog.review['kids.memorise.$kidsMemoriseSurah.1']!.box, 1);
    });

    testWidgets('wrong words in the ordering cost the first try, not the '
        'progress', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await open(tester, settings, prog, 1);
      await tester.tap(find.text('Next'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('I said it!'));
        await tester.pump();
      }
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Hide more'));
        await tester.pump();
      }
      await tester.tap(find.text('I said it!'));
      await tester.pump();

      // The last word first: wrong, flashes, and nothing is placed.
      await tester.tap(_tile(ayahs[0].last).first);
      await tester.pump();
      expect(find.text('Step 4 of 9'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      // Then all of them right, in order.
      for (final w in ayahs[0]) {
        await tester.tap(_tile(w).first);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Step 5 of 9'), findsOneWidget, reason: 'it moved on');
    });

    testWidgets('both sittings and the revision fit a 320×568 phone at the '
        'largest Arabic size', (tester) async {
      useReducedMotion(tester);
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final (settings, prog) = await _boot();
      settings.kidsTextScale = 1.35;
      for (final session in [1, 2, 3]) {
        await tester.pumpWidget(const SizedBox());
        await open(tester, settings, prog, session);
        await _solve(tester, ayahs, session);
        expect(tester.takeException(), isNull, reason: 'session $session');
      }
    });
  });

  testWidgets('without the corpus it says so instead of showing nothing', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        const KidsMemoriseLesson(
          session: 1,
          progressId: 'kids.memorise.1',
          ayahs: [],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining("couldn't be loaded"), findsOneWidget);
  });

  testWidgets('Home offers Memorise as soon as a letter is learnt', (
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
    expect(find.text('Memorise'), findsNothing);
    prog.report('kids.letter.${letters.first.char}', 3);
    await tester.pump();
    expect(find.text('Memorise'), findsOneWidget);
  });
}
