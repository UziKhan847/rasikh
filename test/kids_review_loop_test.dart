import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_checkpoint_quiz.dart' show kidsWarmUpQuiz;
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_widgets.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show QuizScreen;

import 'kids_test_support.dart';

/// The retrieval loop: a kid lesson's check-up files a miss into the shared
/// spaced-repetition queue, and the Warm-up on Home is the way back to it.
/// Before this, every miss made inside a kid lesson vanished — nothing
/// recorded WHICH item was missed, and Kids Mode had no way to open the
/// queue even for the misses its checkpoint quizzes did record.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Test'));
  return (settings, progress);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> played;
  setUp(() => LetterAudio.log = played = []);
  tearDown(() => LetterAudio.log = null);

  testWidgets('a wrong answer is filed for review; a right one promotes it', (
    tester,
  ) async {
    final (settings, prog) = await _boot();
    late BuildContext ctx;
    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: ProgressScope(
          progress: prog,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(prog.dueCount, 0);
    kidsRecordCheck(
      ctx,
      correct: false,
      reviewId: 'kids.test.x',
      arabic: 'بَ',
      answer: 'بَ',
      distractors: const ['تَ', 'ثَ'],
    );
    expect(prog.dueCount, 1);
    expect(prog.review['kids.test.x']!.box, 0);

    kidsRecordCheck(
      ctx,
      correct: true,
      reviewId: 'kids.test.x',
      arabic: 'بَ',
      answer: 'بَ',
    );
    // Promoted a Leitner box and pushed out: no longer due today.
    expect(prog.review['kids.test.x']!.box, 1);
    expect(prog.dueCount, 0);
  });

  testWidgets('a missed syllable check-up in the drill lands in the queue', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    final fatha = tashkil.firstWhere((t) => t.id == 'fatha');
    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: ProgressScope(
          progress: prog,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: KidsSyllableDrill(mark: fatha, progressId: 'test.fatha'),
          ),
        ),
      ),
    );
    await tester.pump();

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('I said it!'));
      await tester.pump();
    }
    // The check-up auto-plays the syllable it asks about.
    final answer = played.last;
    expect(find.text('Which one did you just say?'), findsOneWidget);

    final wrong = find
        .descendant(of: kidsTappables(), matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .firstWhere((t) => t != answer);
    await tester.tap(find.text(wrong!));
    await tester.pump(const Duration(milliseconds: 800));

    expect(prog.dueCount, 1);
    expect(prog.review.keys.single, startsWith('kids.syllable.fatha.'));
    // The card asks "how does this sound?": it stores the SOUND, not the
    // syllable it is already showing.
    final letter = letters.firstWhere(
      (l) => l.char == String.fromCharCode(answer.runes.first),
    );
    expect(prog.review.values.single.answer, kidsSyllableSound(letter, fatha));
    expect(prog.review.values.single.arabic, answer);
    expect(prog.review.values.single.optionsArabic, isFalse);
  });

  testWidgets('Home offers the Warm-up only while something is due', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
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

    expect(find.text('Warm-up'), findsNothing);

    prog.recordMiss(
      'kids.test.y',
      'بَ',
      answer: 'بَ',
      distractors: const ['تَ', 'ثَ', 'جَ'],
    );
    await tester.pump();

    // Home is a lazy ListView and the practice row sits at the bottom.
    await tester.scrollUntilVisible(
      find.text('Warm-up'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Warm-up'), findsOneWidget);
    expect(find.text('1 to practise again'), findsOneWidget);
  });

  testWidgets('tapping the Warm-up opens a review round over what was missed', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    prog.recordMiss(
      'kids.test.z',
      'بَ',
      answer: 'بَ',
      distractors: const ['تَ', 'ثَ', 'جَ'],
    );
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
    await kidsHomeToPractice(tester);
    await tester.ensureVisible(find.text('Warm-up'));
    await tester.pump();
    await tester.tap(find.text('Warm-up'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets('every third Warm-up card is the mascot\'s mistake to fix', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    const answers = ['بَ', 'تَ', 'ثَ', 'جَ', 'حَ', 'خَ'];
    for (final a in answers) {
      prog.recordMiss(
        'kids.test.$a',
        a,
        answer: a,
        distractors: const ['دَ', 'ذَ', 'رَ'],
      );
    }
    late QuizScreen quiz;
    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: ProgressScope(
          progress: prog,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Builder(
              builder: (c) {
                quiz = kidsWarmUpQuiz(c, prog);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(quiz.questions, hasLength(6));
    for (final (i, q) in quiz.questions.indexed) {
      final slip = q.prompt.startsWith('Oops');
      expect(slip, i % 3 == 2, reason: 'card $i');
      // Framing only: still one right answer, and it is never the one the
      // mascot "said".
      expect(answers, contains(q.options[q.correct]));
      if (slip) {
        final said = RegExp('“(.+)”').firstMatch(q.prompt)!.group(1)!;
        expect(q.options, contains(said));
        expect(said, isNot(q.options[q.correct]));
      }
    }
  });
}
