import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_lookalike_quiz.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show QuizScreen;

import 'kids_test_support.dart';

/// Look-alike practice: interleaving near-identical letters is what trains
/// telling them apart, and dot discrimination is the documented bottleneck
/// in learning to read Arabic. None of it needs audio.
ArabicLetter _l(String ch) => letterFor(ch);
const _boat = ['ب', 'ت', 'ث', 'ن', 'ي'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('confusables', () {
    test('a letter\'s look-alikes come from every family it belongs to', () {
      final near = kidsConfusablesIn(_l('ب'), letters).map((l) => l.char);
      expect(near.toSet(), {'ت', 'ث', 'ن', 'ي'});
      // د sits in both its own pair and the shape-confusion set.
      final dal = kidsConfusablesIn(_l('د'), letters).map((l) => l.char);
      expect(dal.toSet(), {'ذ', 'ر', 'و'});
    });

    test('only letters in the pool are ever offered as distractors', () {
      final pool = [_l('ا'), _l('ب'), _l('ت'), _l('ث'), _l('ج')];
      for (var i = 0; i < 40; i++) {
        final o = kidsConfusableOptions(
          answer: _l('ب'),
          pool: pool,
          show: (x) => x.char,
          rng: math.Random(i),
        );
        expect(o.options[o.correct], 'ب');
        expect(o.options.every(['ا', 'ب', 'ت', 'ث', 'ج'].contains), isTrue);
        // Its two look-alikes in the pool are ALWAYS on screen.
        expect(o.options, containsAll(['ت', 'ث']));
      }
    });

    test('with the whole alphabet, every distractor of ب is a look-alike', () {
      for (var i = 0; i < 40; i++) {
        final o = kidsConfusableOptions(
          answer: _l('ب'),
          pool: letters,
          show: (x) => x.char,
          rng: math.Random(i),
        );
        expect(o.options, hasLength(4));
        expect(o.options.toSet(), hasLength(4));
        for (final d in o.options.where((x) => x != 'ب')) {
          expect(_boat, contains(d));
        }
      }
    });

    test('the drill needs a pair of look-alikes to contrast', () {
      expect(kidsLookalikeAvailable([]), isFalse);
      expect(kidsLookalikeAvailable([_l('ا'), _l('ب')]), isFalse);
      expect(kidsLookalikeAvailable([_l('ب'), _l('ت')]), isTrue);
    });
  });

  group('the drill\'s questions are always answerable', () {
    Future<QuizScreen> build(
      WidgetTester tester,
      List<ArabicLetter> known,
      int seed,
    ) async {
      late QuizScreen quiz;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (c) {
              quiz = kidsLookalikeQuiz(
                c,
                known: known,
                progressId: 'test.lookalike',
                rng: math.Random(seed),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return quiz;
    }

    testWidgets('over the whole alphabet, 30 different rounds', (tester) async {
      var sawOdd = false, sawHunter = false, sawWhich = false;
      for (var seed = 0; seed < 30; seed++) {
        final quiz = await build(tester, letters, seed);
        expect(quiz.questions, isNotEmpty);
        for (final q in quiz.questions) {
          expect(
            q.options.toSet(),
            hasLength(q.options.length),
            reason: 'no duplicate options',
          );
          if (q.correctSet != null) {
            sawHunter = true;
            expect(q.correctSet, isNotEmpty);
            expect(
              q.correctSet!.length,
              lessThan(q.options.length),
              reason: 'a hunt with nothing to reject is not a hunt',
            );
            expect(
              q.correctSet!.every((i) => i >= 0 && i < q.options.length),
              isTrue,
            );
            // ي is drawn dotless when isolated, so it can never be a hunt
            // option — the glyph would contradict "2 dots below".
            expect(q.options, isNot(contains('ي')));
            // Every picked target really shares one dot signature.
            final sigs = {
              for (final i in q.correctSet!)
                '${letterFor(q.options[i]).dotCount}.'
                    '${letterFor(q.options[i]).dotPos}',
            };
            expect(sigs, hasLength(1));
            // ...and no rejected option shares it.
            for (var i = 0; i < q.options.length; i++) {
              if (q.correctSet!.contains(i)) continue;
              final l = letterFor(q.options[i]);
              expect('${l.dotCount}.${l.dotPos}', isNot(sigs.single));
            }
          } else if (q.reviewId == null) {
            sawOdd = true;
            expect(q.options, hasLength(4));
            // Exactly one of the four is outside the family of the rest.
            final fam = similarFamilies.entries
                .where((e) => e.key != 'cross')
                .firstWhere(
                  (e) => q.options.where(e.value.contains).length == 3,
                );
            expect(q.options[q.correct], isNot(isIn(fam.value)));
          } else {
            sawWhich = true;
            expect(q.correct, inInclusiveRange(0, q.options.length - 1));
            expect(q.optionsAreArabic, isTrue);
          }
        }
      }
      expect([sawOdd, sawHunter, sawWhich], everyElement(isTrue));
    });

    testWidgets('with only a pair of look-alikes it still builds a round', (
      tester,
    ) async {
      final quiz = await build(tester, [_l('ب'), _l('ت')], 1);
      expect(quiz.questions, isNotEmpty);
      for (final q in quiz.questions) {
        if (q.correctSet == null) {
          expect(q.correct, inInclusiveRange(0, q.options.length - 1));
        }
      }
    });
  });

  testWidgets('Home offers Look-alikes only once a pair has been learned', (
    tester,
  ) async {
    useReducedMotion(tester);
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    final prog = ProgressStore(profileId: 'p1');
    await settings.load();
    await prog.load();
    settings.kidsMode = true;
    settings.desktopMode = 'off';
    settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Test'));

    Future<void> pumpHome() async {
      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: ProgressScope(
            progress: prog,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: KidsHomeScreen(onGoLearn: () {}),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.dragUntilVisible(
        find.text('Listening'),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
    }

    await pumpHome();
    expect(find.text('Look-alikes'), findsNothing);

    prog.report('kids.letter.ب', 3);
    await tester.pump();
    expect(
      find.text('Look-alikes'),
      findsNothing,
      reason: 'one letter is not a pair',
    );

    prog.report('kids.letter.ت', 3);
    await tester.pump();
    expect(find.text('Look-alikes'), findsOneWidget);
  });
}
