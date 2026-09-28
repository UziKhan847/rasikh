import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraah_arabiyyah/kids_backdrops/kb_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/makharij.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_mouth_map.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_tajwid_rule_lesson.dart';

import 'kids_test_support.dart';

/// Mouth map: where in the mouth each letter is made — the one thing about
/// pronunciation that needs no recording. Every letter's place comes straight
/// from the grown-up Makhārij table.
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

const _names = {
  'jawf': 'Open mouth',
  'halq': 'The Throat',
  'lisan': 'The Tongue',
  'shafatan': 'The Lips',
  'khayshum': 'The Nose',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the places and their letters', () {
    test('every letter of the table is in its own zone, nowhere else', () {
      for (final e in makhrajOfLetter.entries) {
        final zone = makhrajById(e.value).zone;
        expect(kidsZoneLetters(zone), contains(e.key), reason: e.key);
      }
      expect(kidsZoneLetters('jawf'), ['ا', 'و', 'ي']);
      expect(kidsZoneLetters('khayshum'), ['ن', 'م']);
      // Six throat letters, four lip letters (ب ف م و), and a crowded tongue.
      expect(kidsZoneLetters('halq'), hasLength(6));
      expect(kidsZoneLetters('shafatan'), hasLength(4));
      expect(kidsZoneLetters('lisan').length, greaterThan(15));
    });

    test('every zone has an emoji of its own', () {
      expect({
        for (final z in kidsZoneIds) kidsZoneEmoji(z),
      }, hasLength(kidsZoneIds.length));
    });
  });

  group('the questions', () {
    test('every answer agrees with the grown-up Makhārij table', () {
      for (var seed = 0; seed < 200; seed++) {
        final qs = kidsMouthQuestions({}, math.Random(seed));
        expect(qs, hasLength(6));
        expect(qs.where((q) => q.isNose), hasLength(1));
        final letters = <String>{};
        for (final q in qs) {
          expect(q.options, hasLength(4));
          expect(q.options.toSet(), hasLength(4));
          expect(q.options, contains(q.answer));
          if (q.isNose) {
            expect(const ['ن', 'م'], contains(q.answer));
            // Exactly one of the four hums.
            expect(q.options.where(const ['ن', 'م'].contains), [q.answer]);
          } else {
            expect(
              makhrajById(makhrajOfLetter[q.letter]!).zone,
              q.answer,
              reason: 'seed $seed: ${q.letter}',
            );
            // Wāw and yāʼ are made in two places, so are never asked.
            expect(const ['و', 'ي', 'ء'], isNot(contains(q.letter)));
            expect(letters.add(q.letter!), isTrue, reason: 'no repeats');
          }
        }
      }
    });

    test('letters the child has met are asked first', () {
      for (var seed = 0; seed < 50; seed++) {
        final qs = kidsMouthQuestions({'ب', 'ح', 'ا'}, math.Random(seed));
        final asked = {
          for (final q in qs)
            if (!q.isNose) q.letter!,
        };
        expect(asked, containsAll(['ب', 'ح', 'ا']), reason: 'seed $seed');
      }
    });
  });

  group('the lesson', () {
    testWidgets('the map must be explored before the questions', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsMouthMapLesson(
            progressId: 'kids.practice.mouth',
            rng: math.Random(1),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Material), findsWidgets);
      expect(find.textContaining('Tap each place'), findsOneWidget);
      final next = find.widgetWithText(KbBigButton, 'Next');
      expect(tester.widget<KbBigButton>(next).enabled, isFalse);

      // Five dots on the map.
      final dots = kidsTappables();
      expect(dots, findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        expect(tester.widget<KbBigButton>(next).enabled, isFalse);
        await tester.tap(dots.at(i));
        await tester.pump();
      }
      expect(tester.widget<KbBigButton>(next).enabled, isTrue);
      // The last place tapped is explained: its name, its letters, its tip.
      expect(find.textContaining('nose'), findsWidgets);
    });

    testWidgets('a place shows its letters and one thing to feel', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          const KidsMouthMapLesson(progressId: 'kids.practice.mouth'),
        ),
      );
      await tester.pump();
      await tester.tap(kidsTappables().at(1)); // the throat
      await tester.pump();
      expect(find.textContaining('Touch your throat'), findsOneWidget);
      for (final l in kidsZoneLetters('halq')) {
        expect(find.text(l), findsWidgets, reason: l);
      }
    });

    Future<void> explore(WidgetTester tester) async {
      final dots = kidsTappables();
      for (var i = 0; i < 5; i++) {
        await tester.tap(dots.at(i));
        await tester.pump();
      }
      await tester.ensureVisible(find.widgetWithText(KbBigButton, 'Next'));
      await tester.tap(find.widgetWithText(KbBigButton, 'Next'));
      await tester.pump();
    }

    testWidgets('all six right earns three stars under the practice id', (
      tester,
    ) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      final known = {'ا', 'ب', 'ح', 'ق'};
      final qs = kidsMouthQuestions(known, math.Random(5));
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsMouthMapLesson(
            progressId: 'kids.practice.mouth',
            known: known,
            rng: math.Random(5),
          ),
        ),
      );
      await tester.pump();
      await explore(tester);

      for (final q in qs) {
        expect(
          find.text(
            q.isNose
                ? 'Which letter can hum through your nose?'
                : 'Where is this letter made?',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(q.isNose ? q.answer : _names[q.answer]!));
        await tester.pump();
        // Right first time: a "Yes!", the place's tip, and Next.
        expect(find.text('Yes!'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(prog.starsFor('kids.practice.mouth'), 3);
      expect(prog.dueCount, 0);
    });

    testWidgets('a wrong place files the letter for review, with the right '
        'place as its answer', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      final qs = kidsMouthQuestions({}, math.Random(8));
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsMouthMapLesson(
            progressId: 'kids.practice.mouth',
            rng: math.Random(8),
          ),
        ),
      );
      await tester.pump();
      await explore(tester);

      final first = qs.first;
      final wrong = first.isNose
          ? first.options.firstWhere((o) => o != first.answer)
          : _names[first.options.firstWhere((o) => o != first.answer)]!;
      await tester.tap(find.text(wrong));
      await tester.pump(const Duration(milliseconds: 1000));

      if (!first.isNose) {
        final card = prog.review['kids.mouth.${first.letter}']!;
        expect(card.answer, _names[first.answer]);
        expect(card.arabic, first.letter);
        expect(card.optionsArabic, isFalse);
      } else {
        expect(prog.dueCount, 0, reason: 'the nose question has no card');
      }
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
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsMouthMapLesson(
            progressId: 'kids.practice.mouth',
            rng: math.Random(2),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Every place, so the tallest explanation (the tongue's letters) shows.
      final dots = kidsTappables();
      for (var i = 0; i < 5; i++) {
        await tester.tap(dots.at(i));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'place $i');
      }
      await tester.ensureVisible(find.widgetWithText(KbBigButton, 'Next'));
      await tester.tap(find.widgetWithText(KbBigButton, 'Next'));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        // Whatever is tapped: right first time, or a second try, or the
        // reveal — the panel that follows is the tallest thing here.
        for (var t = 0; t < 2; t++) {
          final tiles = kidsTappables();
          if (tiles.evaluate().isEmpty) break;
          await tester.ensureVisible(tiles.first);
          await tester.tap(tiles.first, warnIfMissed: false);
          await tester.pump();
        }
        expect(tester.takeException(), isNull, reason: 'question $i');
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
    });
  });

  testWidgets('Home offers the Mouth map once six letters are known', (
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
    expect(find.text('Mouth map'), findsNothing);
    for (final l in letters.take(5)) {
      prog.report('kids.letter.${l.char}', 3);
    }
    await tester.pump();
    expect(find.text('Mouth map'), findsNothing, reason: 'five is not six');
    prog.report('kids.letter.${letters[5].char}', 3);
    await tester.pump();
    expect(find.text('Mouth map'), findsOneWidget);
  });

  group('tajwīd rules point at the map', () {
    test('every mapped rule names a real place, and only rules with one', () {
      const rules = [
        'ghunnah',
        'izhar',
        'idgham_g',
        'idgham_ng',
        'iqlab',
        'ikhfa',
        'qalqalah',
        'ikhfa_shafawi',
        'idgham_shafawi',
        'izhar_shafawi',
        'madd2',
        'madd4',
        'madd45',
        'madd6',
        'shamsiyya',
        'qamariyya',
        'raa_tafkhim',
        'raa_tarqiq',
        'tafkhim',
        'lam_jalalah',
      ];
      for (final r in rules) {
        final z = kidsRuleZone(r);
        if (z != null) expect(kidsZoneIds, contains(z), reason: r);
      }
      // The classical facts the card relies on.
      expect(kidsRuleZone('izhar'), 'halq');
      expect(kidsRuleZone('ikhfa'), 'khayshum');
      expect(kidsRuleZone('madd6'), 'jawf');
      // A family of places is not a place.
      expect(kidsRuleZone('qalqalah'), isNull);
      expect(kidsRuleZone('raa_tafkhim'), isNull);
      expect(kidsRuleZone('shamsiyya'), isNull);
    });

    testWidgets('a rule that happens in one place shows it — as a picture, '
        'not a control', (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await tester.pumpWidget(
        _harness(
          settings,
          prog,
          KidsTajwidRuleLesson(
            ruleIds: const ['izhar', 'qalqalah'],
            progressId: 'test.rules',
            icon: Icons.record_voice_over_rounded,
            title: (c) => 'Rules',
            subtitle: (c) => 'x',
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Next')); // past the intro
      await tester.pump();

      // Iẓhār: the throat, marked on the head — and nothing on it to tap.
      expect(find.byType(KidsMouthDiagram), findsOneWidget);
      expect(find.textContaining('The Throat'), findsOneWidget);
      expect(kidsTappables(), findsNothing);

      await tester.tap(find.text('Next'));
      await tester.pump();
      // Qalqalah belongs to a family of places: no diagram.
      expect(find.byType(KidsMouthDiagram), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
