import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/audio.dart' show PlaybackHandle;
import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_reading_screen.dart';
import 'package:qiraah_arabiyyah/screens/lessons/forms_quizzes.dart';

import 'kids_test_support.dart';

/// The reading stages — "read it aloud, then tap" over real text from the
/// bundled corpus, from two words at a time up to a whole short sūrah.
///
/// The text is loaded, never hand-typed: everything shown here has to be
/// byte-for-byte what `assets/quran/u/*.json` holds, the same discipline
/// `test/letters_data_test.dart` enforces on the rest of the app's Qurʼānic
/// strings.
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

/// The screen loads its text through [QuranRepo], which does real asset I/O
/// and decodes off the UI thread — neither of which advances inside a widget
/// test's fake-async zone, so the spinner would spin until `pumpAndSettle`
/// gave up. Warming the repo's cache in [WidgetTester.runAsync] first means
/// the screen's own await resolves on the next microtask.
Future<void> _warm(WidgetTester tester, int surah) async {
  await tester.runAsync(() => QuranRepo.words(surah, 'uthmani'));
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

  testWidgets('chunks a sūrah into the requested number of words',
      (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _warm(tester, 112);

    await tester.pumpWidget(_harness(
      settings,
      prog,
      const KidsReadingScreen(
          surah: 112, wordsPerChunk: 2, progressId: 'test.read'),
    ));
    await tester.pumpAndSettle();

    // al-Ikhlāṣ, in twos.
    final words = await QuranRepo.words(112, 'uthmani');
    final expected = words.fold<int>(
        0, (n, ayah) => n + (ayah.length / 2).ceil());
    expect(find.textContaining('/ $expected'), findsOneWidget);
  });

  testWidgets('whole-āyah mode gives one card per āyah', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _warm(tester, 112);

    await tester.pumpWidget(_harness(
      settings,
      prog,
      const KidsReadingScreen(
          surah: 112,
          wordsPerChunk: 0,
          wholeAyahs: true,
          progressId: 'test.capstone'),
    ));
    await tester.pumpAndSettle();

    final ayahs = await QuranRepo.ayahs(112, 'uthmani');
    expect(find.text('0 / ${ayahs.length}'), findsOneWidget);
  });

  testWidgets('reading every line in order reports the stage done',
      (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _warm(tester, 112);

    await tester.pumpWidget(_harness(
      settings,
      prog,
      const KidsReadingScreen(
          surah: 112,
          wordsPerChunk: 0,
          wholeAyahs: true,
          progressId: 'test.capstone'),
    ));
    await tester.pumpAndSettle();

    final ayahs = await QuranRepo.ayahs(112, 'uthmani');
    expect(prog.starsFor('test.capstone'), 0);

    for (var i = 0; i < ayahs.length; i++) {
      // Always the FIRST arrow: lines are read in order, so the current one
      // is the only tappable target.
      await tester.tap(kidsIcon('arrow_forward', Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();
    }

    expect(prog.starsFor('test.capstone'), 3);
    expect(prog.xp, greaterThan(0));
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('tapping out of order does nothing', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await _warm(tester, 112);

    await tester.pumpWidget(_harness(
      settings,
      prog,
      const KidsReadingScreen(
          surah: 112,
          wordsPerChunk: 0,
          wholeAyahs: true,
          progressId: 'test.order'),
    ));
    await tester.pumpAndSettle();

    // The second line's arrow — skipping the first would let a child mark a
    // whole sūrah read by tapping the last line once.
    final arrows = kidsIcon('arrow_forward', Icons.arrow_forward_rounded);
    await tester.tap(arrows.at(1));
    await tester.pumpAndSettle();
    expect(find.text('0 / 4'), findsOneWidget);
  });

  group('read along', () {
    // A stand-in for the per-word recordings: it records what was asked for
    // and lets the test say which word is "playing".
    late List<(int, int, int, int)> asked;
    late void Function(int) onWord;
    late PlaybackHandle handle;
    late List<(int, int, int)> single;

    PlaybackHandle fakeWords(int s, int a, int first, int last,
        void Function(int) cb) {
      asked.add((s, a, first, last));
      onWord = cb;
      return handle = PlaybackHandle();
    }

    Future<void> fakeWord(int s, int a, int w) async => single.add((s, a, w));

    setUp(() {
      asked = [];
      single = [];
    });

    Future<void> open(WidgetTester tester, {int perChunk = 2}) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await _warm(tester, 112);
      await tester.pumpWidget(_harness(
        settings,
        prog,
        KidsReadingScreen(
            surah: 112,
            wordsPerChunk: perChunk,
            progressId: 'test.read',
            playWords: fakeWords,
            playWord: fakeWord),
      ));
      await tester.pumpAndSettle();
    }

    /// The accent colour of every word in the first card that is lit.
    int lit(WidgetTester tester) => tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).color != Colors.transparent)
        .length;

    testWidgets('a line is heard word by word, asking for exactly its words',
        (tester) async {
      await open(tester);
      // The first card is āyah 1, words 1-2 (قُلۡ هُوَ).
      await tester.tap(kidsIcon('record_voice_over', Icons.record_voice_over_rounded).first);
      await tester.pump();
      expect(asked, [(112, 1, 1, 2)]);
      expect(lit(tester), 0, reason: 'nothing lit until a word is said');

      onWord(0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(lit(tester), 1);
      onWord(1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(lit(tester), 1, reason: 'one word at a time');
      onWord(-1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(lit(tester), 0, reason: 'and none when it is over');
    });

    testWidgets('a later line asks for ITS words, numbered by their place in '
        'the āyah', (tester) async {
      await open(tester);
      // The second card: words 3-4 of āyah 1 (ٱللَّهُ أَحَدٌ).
      await tester.tap(kidsIcon('record_voice_over', Icons.record_voice_over_rounded).at(1));
      await tester.pump();
      expect(asked, [(112, 1, 3, 4)]);
      onWord(2); // word 3 of the āyah is the first of this line
      await tester.pump(const Duration(milliseconds: 200));
      expect(lit(tester), 1);
    });

    testWidgets('tapping the speaker again while it plays stops it',
        (tester) async {
      await open(tester);
      final speaker = kidsIcon('record_voice_over', Icons.record_voice_over_rounded).first;
      await tester.tap(speaker);
      await tester.pump();
      onWord(0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(lit(tester), 1);

      // (Stopping the real player is skipped when the audio is injected.)
      await tester.tap(speaker);
      await tester.pump(const Duration(milliseconds: 200));
      expect(handle.cancelled, isTrue);
      expect(lit(tester), 0);
    });

    testWidgets('starting another line cancels the first', (tester) async {
      await open(tester);
      await tester.tap(kidsIcon('record_voice_over', Icons.record_voice_over_rounded).first);
      await tester.pump();
      final first = handle;
      await tester.tap(kidsIcon('record_voice_over', Icons.record_voice_over_rounded).at(1));
      await tester.pump();
      expect(first.cancelled, isTrue);
      expect(asked, hasLength(2));
    });

    testWidgets('tapping a word says that word, and lights it for a moment',
        (tester) async {
      await open(tester);
      // The first word of the first card: a real word of the corpus.
      final words = await QuranRepo.words(112, 'uthmani');
      await tester.tap(find.text(words[0][1]).first);
      await tester.pump(const Duration(milliseconds: 200));
      expect(single, [(112, 1, 2)]);
      expect(lit(tester), 1);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(lit(tester), 0);
    });

    testWidgets('audio that never arrives changes nothing about reading',
        (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await _warm(tester, 112);
      await tester.pumpWidget(_harness(
        settings,
        prog,
        KidsReadingScreen(
            surah: 112,
            wordsPerChunk: 2,
            progressId: 'test.silent',
            playWords: fakeWords,
            playWord: (s, a, w) async => throw Exception('offline')),
      ));
      await tester.pumpAndSettle();
      final words = await QuranRepo.words(112, 'uthmani');
      await tester.tap(find.text(words[0][0]).first);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 1300)); // the light fades
      // Reading in order still works.
      await tester.tap(kidsIcon('arrow_forward', Icons.arrow_forward_rounded).first);
      await tester.pump();
      expect(find.textContaining('1 /'), findsOneWidget);
    });

    testWidgets('the capstone keeps the flowing āyah button as well',
        (tester) async {
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      await _warm(tester, 112);
      await tester.pumpWidget(_harness(
        settings,
        prog,
        KidsReadingScreen(
            surah: 112,
            wordsPerChunk: 0,
            wholeAyahs: true,
            progressId: 'test.cap',
            playWords: fakeWords,
            playWord: fakeWord),
      ));
      await tester.pumpAndSettle();
      expect(kidsListenIcon(), findsWidgets);
      expect(kidsIcon('record_voice_over', Icons.record_voice_over_rounded), findsWidgets);
      // Word by word over a whole āyah asks for every word of it.
      await tester.tap(kidsIcon('record_voice_over', Icons.record_voice_over_rounded).first);
      await tester.pump();
      expect(asked, [(112, 1, 1, 4)]);
    });

    testWidgets('the two-word stage has no flowing button — it would say the '
        'whole āyah over a two-word card', (tester) async {
      await open(tester);
      expect(kidsListenIcon(), findsNothing);
    });

    testWidgets('a line still fits a 320×568 phone at the largest Arabic size',
        (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      useReducedMotion(tester);
      final (settings, prog) = await _boot();
      settings.kidsTextScale = 1.35;
      await _warm(tester, 112);
      await tester.pumpWidget(_harness(
        settings,
        prog,
        KidsReadingScreen(
            surah: 112,
            wordsPerChunk: 0,
            wholeAyahs: true,
            progressId: 'test.small',
            playWords: fakeWords,
            playWord: fakeWord),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The five-word last āyah, mid-recitation.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      await tester.tap(kidsIcon('record_voice_over', Icons.record_voice_over_rounded).last);
      await tester.pump();
      onWord(2);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });

  group('tāʼ marbūṭah drill', () {
    testWidgets('draws on every example, not just the two primaries',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));

      final qs = taMarbutaQuestions(ctx, count: 6);
      expect(qs, hasLength(6));
      // The shared `haaVsTaaMarbutaQuestion` only ever uses each variant's
      // PRIMARY word, so a six-question round built on it would show at most
      // two distinct words. This one pulls in `moreExamples` as well.
      expect(qs.map((q) => q.arabic).toSet().length, greaterThan(2));
      for (final q in qs) {
        // Three options — ة, ه and the open ت — so a round is not a coin flip.
        expect(q.options, hasLength(3));
        expect(q.options.toSet(), {'ه', 'ة', 'ت'});
        expect(q.arabic!.contains(q.highlight!), isTrue);
        expect(q.options[q.correct], q.highlight!.substring(0, 1),
            reason: q.arabic);
      }
    });

    testWidgets('a wide pool: many rounds ask many different words',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
      final words = <String>{};
      for (var round = 0; round < 40; round++) {
        words.addAll(taMarbutaQuestions(ctx, count: 6).map((q) => q.arabic!));
      }
      // It used to be six drawn from ten, forever.
      expect(words.length, greaterThan(20));
    });
  });
}
