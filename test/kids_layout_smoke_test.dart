import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart' show kKidsShopThemeFamilies;
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_checkpoint_quiz.dart'
    show kidsFormsCheckpoint, kidsWarmUpQuiz;
import 'package:qiraah_arabiyyah/screens/kids/kids_extra_letter_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_find_in_ayah.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_parent_report.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_review_recap.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_shell.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show QuizScreen;

import 'kids_lesson_walk_support.dart';
import 'kids_test_support.dart';

/// Children use phones. Every other widget test runs in the default 800×600
/// window, where a card that is too tall or a row that is too wide simply
/// fits, so a RenderFlex overflow can ship unnoticed — exactly how the
/// muʼānaqah check card's long āyah did. This walks every kid screen built
/// this round, STEP BY STEP, on the smallest phone we support (320×568
/// logical) with the Arabic size at the Reading Coach's largest preset, and
/// lets the framework's own overflow errors fail the test.
Future<(AppSettings, ProgressStore)> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore(profileId: 'p1');
  await settings.load();
  await progress.load();
  settings.kidsMode = true;
  settings.desktopMode = 'off';
  settings.kidsTextScale = 1.2; // Large — the biggest size Me ▸ Appearance offers
  settings.addKidsProfile(KidsProfile(id: 'p1', name: 'Amina'));
  return (settings, progress);
}

void _smallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 1136);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => LetterAudio.log = []);
  tearDown(() => LetterAudio.log = null);

  final lessons = kidsWalkLessons();

  for (final e in lessons.entries) {
    testWidgets('${e.key}: every step fits a 320×568 phone', (tester) async {
      useReducedMotion(tester);
      _smallPhone(tester);
      final (settings, prog) = await _boot();
      await _pump(tester, settings, prog, e.value());
      await kidsWalk(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final ch in ['ء', 'أ', 'ؤ', 'ى', 'ة', 'ٱ']) {
    testWidgets('extra letter $ch fits a 320×568 phone', (tester) async {
      useReducedMotion(tester);
      _smallPhone(tester);
      final (settings, prog) = await _boot();
      await _pump(tester, settings, prog, KidsExtraLetterLesson(char: ch));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('find it in the āyah fits a 320×568 phone at the largest scale', (
    tester,
  ) async {
    useReducedMotion(tester);
    _smallPhone(tester);
    final (settings, prog) = await _boot();
    // An eight-word line is the widest a hunt can be; the words must wrap.
    const line = [
      'بِسۡمِ',
      'ٱللَّهِ',
      'ٱلرَّحۡمَٰنِ',
      'ٱلرَّحِيمِ',
      'ٱلۡحَمۡدُ',
      'لِلَّهِ',
      'رَبِّ',
      'ٱلۡعَٰلَمِينَ',
    ];
    await _pump(
      tester,
      settings,
      prog,
      KidsFindInAyah(
        known: [letterFor('ب'), letterFor('ح')],
        progressId: 'smoke.find',
        rng: math.Random(3),
        lines: const [line],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Tap every word with'), findsOneWidget);
    // Tap every word once: found ones light up (spans), wrong ones flash.
    for (var i = 0; i < line.length; i++) {
      await tester.tap(kidsTappables().at(i), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'word $i');
    }
    await kidsWalk(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Warm-up over every kind of review card fits a 320×568 phone', (
    tester,
  ) async {
    useReducedMotion(tester);
    _smallPhone(tester);
    final (settings, prog) = await _boot();
    // One of each thing that files a card, the longest first.
    prog.recordMiss(
      'kids.memorise.112.3',
      'لَمۡ يَلِدۡ وَلَمۡ يُولَدۡ',
      answer: 'وَلَمۡ يَكُن لَّهُۥ كُفُوًا أَحَدُۢ',
      distractors: const ['قُلۡ هُوَ ٱللَّهُ أَحَدٌ', 'ٱللَّهُ ٱلصَّمَدُ'],
    );
    prog.recordMiss(
      'kids.mouth.ق',
      'ق',
      answer: 'The Tongue',
      distractors: const ['The Lips', 'The Throat', 'Open mouth'],
      optionsArabic: false,
    );
    prog.recordMiss(
      'kids.syllable.fatha.ب',
      'بَ',
      answer: 'ba',
      distractors: const ['bi', 'bu', 'ta'],
      optionsArabic: false,
    );
    prog.recordMiss(
      'kids.word.ب',
      'بَيۡت',
      answer: 'a house',
      distractors: const ['a book', 'a tree', 'a door'],
      optionsArabic: false,
    );
    await _pump(
      tester,
      settings,
      prog,
      Builder(builder: (c) => kidsWarmUpQuiz(c, prog)),
    );
    await kidsWalk(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every kind of forms check-up question fits a 320×568 phone, '
      'the gap-in-a-word ones included', (tester) async {
    useReducedMotion(tester);
    _smallPhone(tester);
    final (settings, prog) = await _boot();
    // Built ONCE: a Builder that drew a fresh quiz on every rebuild would swap
    // the questions under the screen.
    late BuildContext ctx;
    await _pump(
      tester,
      settings,
      prog,
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    );
    late QuizScreen quiz;
    do {
      quiz = kidsFormsCheckpoint(
        ctx,
        progressId: 'smoke.forms',
        upTo: letters.length,
      );
    } while (!quiz.questions.any((q) => q.blank != null));
    await _pump(tester, settings, prog, quiz);
    for (final q in quiz.questions) {
      expect(tester.takeException(), isNull, reason: q.prompt);
      // The right option, whatever kind of tile it is.
      final f = find.text(q.options[q.correct]);
      await tester.ensureVisible(f.first);
      await tester.tap(f.first);
      await tester.pump(const Duration(milliseconds: 1000));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the review recap and the parent report fit a 320×568 phone', (
    tester,
  ) async {
    useReducedMotion(tester);
    _smallPhone(tester);
    final (settings, prog) = await _boot();
    await _pump(tester, settings, prog, const KidsReviewRecap());
    expect(tester.takeException(), isNull);

    // A report with everything to show: real progress, a long review queue.
    for (final l in letters.take(12)) {
      prog.report('kids.letter.${l.char}', 3);
    }
    for (final l in letters.skip(12).take(8)) {
      prog.recordMiss(
        'letter.${l.char}',
        l.char,
        answer: l.name,
        distractors: const ['a', 'b', 'c'],
      );
    }
    // The longest things a card can hold: a five-word āyah and its answer.
    prog.recordMiss(
      'kids.memorise.112.3',
      'لَمۡ يَلِدۡ وَلَمۡ يُولَدۡ',
      answer: 'وَلَمۡ يَكُن لَّهُۥ كُفُوًا أَحَدُۢ',
      distractors: const ['قُلۡ هُوَ ٱللَّهُ أَحَدٌ'],
    );
    prog.recordMiss(
      'kids.mouth.ق',
      'ق',
      answer: 'The Tongue',
      distractors: const ['The Lips'],
      optionsArabic: false,
    );
    await _pump(tester, settings, prog, const KidsParentReport());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home with the Warm-up and every practice tile fits a 320×568 phone',
    (tester) async {
      useReducedMotion(tester);
      _smallPhone(tester);
      final (settings, prog) = await _boot();
      // Twenty letters met: enough for every gated practice tile to appear.
      for (final l in letters.take(20)) {
        prog.report('kids.letter.${l.char}', 3);
      }
      prog.recordMiss('letter.ث', 'ث', answer: 'Thā’', distractors: const []);
      // 320px WIDE is what can overflow; a tall window lets the lazy list
      // lay everything out without scrolling.
      tester.view.physicalSize = const Size(640, 3600);
      await _pump(tester, settings, prog, KidsHomeScreen(onGoLearn: () {}));
      expect(find.text('Warm-up'), findsOneWidget);
      expect(find.text('Look-alikes'), findsOneWidget);
      expect(find.text('Write it'), findsOneWidget);
      expect(find.text('Find it'), findsOneWidget);
      expect(find.text('Listen & pick'), findsOneWidget);
      expect(find.text('Mouth map'), findsOneWidget);
      expect(find.text('Memorise'), findsOneWidget);
      expect(find.text('Build the word'), findsOneWidget);
      expect(find.text('Three in a Row'), findsOneWidget);
      expect(find.text('Memory Match'), findsOneWidget);
      expect(find.text('Letter Bingo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Every shop theme paints its own scene with its own motes, and the vivid
  // scene puts white outlined headings on top of it. None of that may cost the
  // layout anything on the smallest phone — and a new family is exactly where a
  // scene-specific painter bug (a NaN in a ridge, an unbounded blur) would hide.
  testWidgets(
    'every shop theme lays out on a 320×568 phone, vivid, in every appearance',
    (tester) async {
      useReducedMotion(tester);
      _smallPhone(tester);
      for (final family in ['kids', ...kKidsShopThemeFamilies]) {
        for (final mode in ['light', 'dark', 'oled']) {
          final (settings, prog) = await _boot();
          settings.kidsDetail = KidsDetail.high;
          settings.kidsThemeMode = mode;
          settings.activeKidsProfile!.theme = family;
          await tester.pumpWidget(
            SettingsScope(
              settings: settings,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: const KidsShell(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$family.$mode threw while painting or laying out',
          );
          expect(find.text('Hello, Amina!'), findsOneWidget, reason: '$family.$mode');
          prog.dispose();
        }
      }
    },
  );
}
