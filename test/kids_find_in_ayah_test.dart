import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_find_in_ayah.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show TapScale;

import 'kids_test_support.dart';

/// Find it in the āyah: tap every WORD that contains a letter, over a real
/// line of the muṣḥaf — carrying the letter from the big isolated shape it
/// is taught in to the connected, differently-shaped one it is read in.
ArabicLetter _l(String ch) => letterFor(ch);

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

Future<void> _pump(
  WidgetTester tester,
  AppSettings settings,
  ProgressStore prog,
  Widget child,
) async {
  await tester.pumpWidget(
    SettingsScope(
      settings: settings,
      child: ProgressScope(
        progress: prog,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

// al-Ikhlāṣ 112:1 — قُلۡ هُوَ ٱللَّهُ أَحَدٌ
const _line = ['قُلۡ', 'هُوَ', 'ٱللَّهُ', 'أَحَدٌ'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('finding a letter inside real words', () {
    test('marks are stripped and alif waṣla counts as the alif you see', () {
      expect(kidsBaseLetters('قُلۡ'), ['ق', 'ل']);
      expect(kidsBaseLetters('ٱللَّهُ'), ['ا', 'ل', 'ل', 'ه']);
      expect(kidsWordHas('ٱللَّهُ', 'ا'), isTrue);
      expect(kidsWordHas('قُلۡ', 'ب'), isFalse);
      // A shaddah or a tanwīn is a mark, never a letter.
      expect(kidsBaseLetters('أَحَدٌ').length, 3);
    });

    test('a hunt needs words with the letter AND words without it', () {
      final hunts = kidsBuildHunts([_l('ل'), _l('ب')], [_line], math.Random(1));
      // Nothing in the line has ب, so only ل can be hunted.
      expect(hunts.map((h) => h.letter.char), ['ل']);
      final h = hunts.single;
      expect(h.targets, {0, 2}); // قُلۡ and ٱللَّهُ
      expect(h.targets.length, lessThan(h.words.length));
    });

    test('every real hunt over the reading sūrahs is answerable', () async {
      // The whole point of the format: with real corpus lines and every
      // letter known, no hunt may be unwinnable or trivial.
      final lines = <List<String>>[
        for (final s in kidsFindSurahs) ...await QuranRepo.words(s, 'uthmani'),
      ];
      for (var seed = 0; seed < 25; seed++) {
        final hunts = kidsBuildHunts(letters, lines, math.Random(seed));
        expect(hunts, hasLength(kidsFindRound));
        for (final h in hunts) {
          expect(h.targets, isNotEmpty);
          expect(h.targets.length, lessThan(h.words.length));
          expect(h.words.length, inInclusiveRange(3, 8));
        }
      }
    });
  });

  testWidgets('finding every word with the letter completes the hunt', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _pump(
      tester,
      settings,
      prog,
      KidsFindInAyah(
        known: [_l('ل')],
        progressId: 'kids.practice.find',
        rng: math.Random(1),
        lines: const [_line],
      ),
    );

    expect(find.byType(Material), findsWidgets);
    expect(find.textContaining('Tap every word with Lām'), findsOneWidget);
    // The letter is not given away before its word is found.
    expect(find.text('Next'), findsNothing);

    // Tap the words that contain ل: قُلۡ and ٱللَّهُ.
    await tester.tap(find.text('قُلۡ'));
    await tester.pump();
    expect(find.text('Next'), findsNothing, reason: 'one word still to find');
    await tester.tap(find.text('ٱللَّهُ'));
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Continue'), findsOneWidget);
    expect(prog.starsFor('kids.practice.find'), 3, reason: 'no wrong taps');
  });

  testWidgets('a wrong tap files a miss and costs stars', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _pump(
      tester,
      settings,
      prog,
      KidsFindInAyah(
        known: [_l('ل')],
        progressId: 'kids.practice.find',
        rng: math.Random(1),
        lines: const [_line],
      ),
    );

    await tester.tap(find.text('هُوَ')); // no ل in it
    await tester.pump();
    expect(prog.review.containsKey('letter.ل'), isTrue);
    expect(prog.review['letter.ل']!.answer, 'Lām');

    await tester.tap(find.text('قُلۡ'));
    await tester.tap(find.text('ٱللَّهُ'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump();

    // 2 right, 1 wrong: 67% is 2 stars on the gentle kids curve.
    expect(prog.starsFor('kids.practice.find'), 2);
  });

  testWidgets('a clean hunt promotes an earlier miss of that letter', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    prog.recordMiss('letter.ل', 'ل', answer: 'Lām', distractors: const ['Kāf']);
    await _pump(
      tester,
      settings,
      prog,
      KidsFindInAyah(
        known: [_l('ل')],
        progressId: 'kids.practice.find',
        rng: math.Random(1),
        lines: const [_line],
      ),
    );
    await tester.tap(find.text('قُلۡ'));
    await tester.tap(find.text('ٱللَّهُ'));
    await tester.pump();
    expect(prog.review['letter.ل']!.box, 1);
  });

  testWidgets('it loads real corpus lines when none are supplied', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    // Warm the cache the way the reading tests do: the loader uses an
    // isolate, which needs real async.
    await tester.runAsync(() async {
      for (final s in kidsFindSurahs) {
        await QuranRepo.words(s, 'uthmani');
      }
    });
    await _pump(
      tester,
      settings,
      prog,
      KidsFindInAyah(
        known: letters,
        progressId: 'kids.practice.find',
        rng: math.Random(2),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Tap every word with'), findsOneWidget);
    expect(find.byType(TapScale), findsWidgets);
  });
}
