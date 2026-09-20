import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/letter_audio.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/letters.dart';
import 'package:qiraah_arabiyyah/data/tashkeel.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_checkpoint_quiz.dart'
    show kidsFormsCheckpoint, kidsWarmUpQuiz;
import 'package:qiraah_arabiyyah/screens/kids/kids_extra_letter_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_find_in_ayah.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_home_screen.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_lookalike_quiz.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_madd_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_muqattaat_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_parent_report.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_review_recap.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_solar_lunar_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_stage_quizzes.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_special_shapes_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_syllable_drill.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_tajwid_rule_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_waqf_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_wasl_lesson.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_words_lesson.dart';
import 'package:qiraah_arabiyyah/widgets/common.dart' show QuizScreen, TapScale;

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
  settings.arabicScale = 1.35; // the Reading Coach comfort preset
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

/// Steps through whatever the screen asks for until its result screen (or the
/// end of a lesson that has none), failing on any framework exception.
Future<void> _walk(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: 'step $i');
    if (find.text('Continue').evaluate().isNotEmpty) return;

    for (final label in ['I said it!', 'Next']) {
      final b = find.text(label);
      if (b.evaluate().isNotEmpty) {
        await tester.ensureVisible(b.first);
        await tester.tap(b.first, warnIfMissed: false);
        continue;
      }
    }
    final check = find.text('Check');
    if (check.evaluate().isNotEmpty) {
      final tile = find.byType(TapScale);
      if (tile.evaluate().isNotEmpty) {
        await tester.tap(tile.first, warnIfMissed: false);
        await tester.pump();
      }
      await tester.tap(check, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
      continue;
    }
    final options = find.byType(TapScale);
    if (options.evaluate().isNotEmpty) {
      await tester.tap(options.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 1000));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => LetterAudio.log = []);
  tearDown(() => LetterAudio.log = null);

  final lessons = <String, Widget Function()>{
    'madd': () => const KidsMaddLesson(),
    'waṣl': () => const KidsWaslLesson(progressId: 'smoke.wasl'),
    'waqf': () => const KidsWaqfLesson(progressId: 'smoke.waqf'),
    'words': () => const KidsWordsLesson(progressId: 'smoke.words'),
    'muqaṭṭaʿāt': () =>
        const KidsMuqattaatLesson(progressId: 'smoke.muqattaat'),
    'sun and moon': () => const KidsSolarLunarLesson(progressId: 'smoke.solar'),
    'tajwīd (nūn, 5 rules)': () => KidsTajwidRuleLesson(
      ruleIds: const ['izhar', 'idgham_g', 'idgham_ng', 'iqlab', 'ikhfa'],
      progressId: 'smoke.nun',
      icon: Icons.record_voice_over_rounded,
      title: (c) => 'Nūn Sākinah',
      subtitle: (c) => 'Iẓhār, idghām, iqlāb, ikhfā',
    ),
    'special shapes (stacking)': () => const KidsSpecialShapesLesson(
      group: 'stacking',
      progressId: 'smoke.stacking',
    ),
    'special shapes (heights)': () => const KidsSpecialShapesLesson(
      group: 'tails',
      progressId: 'smoke.tails',
    ),
    'ḥarakāt drill (last session)': () => KidsSyllableDrill(
      mark: tashkil.firstWhere((t) => t.id == 'dammatan'),
      progressId: 'smoke.drill',
      start: kidsDrillRanges().last.$1,
      end: kidsDrillRanges().last.$2,
    ),
    'waqf quiz': () => const KidsWaqfLesson(progressId: 'smoke.wq', quiz: true),
    'waṣl quiz': () => const KidsWaslLesson(progressId: 'smoke.wl', quiz: true),
    'words quiz': () =>
        const KidsWordsLesson(progressId: 'smoke.wd', quiz: true),
    'muqaṭṭaʿāt quiz': () =>
        const KidsMuqattaatLesson(progressId: 'smoke.mq', quiz: true),
    'sun and moon quiz': () =>
        const KidsSolarLunarLesson(progressId: 'smoke.sl', quiz: true),
    'madd quiz': () => const KidsMaddLesson(progressId: 'smoke.md', quiz: true),
    'tajwīd (nūn) quiz': () => KidsTajwidRuleLesson(
      ruleIds: const ['izhar', 'idgham_g', 'idgham_ng', 'iqlab', 'ikhfa'],
      progressId: 'smoke.nq',
      icon: Icons.record_voice_over_rounded,
      title: (c) => 'Nūn Sākinah',
      subtitle: (c) => 'x',
      quiz: true,
    ),
    'ḥarakāt quiz': () => Builder(
      builder: (c) => kidsSyllableQuiz(
        c,
        title: 'Ḥarakāt',
        progressId: 'smoke.hq',
        markIds: const ['fatha', 'kasra', 'damma'],
      ),
    ),
    'shaddah quiz': () => Builder(
      builder: (c) => kidsMarkSpotQuiz(
        c,
        title: 'Shaddah',
        progressId: 'smoke.sq',
        markId: 'shadda',
      ),
    ),
    'review quiz': () => Builder(
      builder: (c) =>
          kidsReviewQuiz(c, title: 'Review', progressId: 'smoke.rq'),
    ),
    'look-alikes': () => Builder(
      builder: (c) =>
          kidsLookalikeQuiz(c, known: letters, progressId: 'smoke.lookalike'),
    ),
  };

  for (final e in lessons.entries) {
    testWidgets('${e.key}: every step fits a 320×568 phone', (tester) async {
      useReducedMotion(tester);
      _smallPhone(tester);
      final (settings, prog) = await _boot();
      await _pump(tester, settings, prog, e.value());
      await _walk(tester);
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
      await tester.tap(find.byType(TapScale).at(i), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'word $i');
    }
    await _walk(tester);
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
    await _walk(tester);
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
      expect(tester.takeException(), isNull);
    },
  );
}
