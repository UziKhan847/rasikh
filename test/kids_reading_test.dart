import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
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
    final arrows = find.byIcon(Icons.arrow_forward_rounded);
    await tester.tap(arrows.at(1));
    await tester.pumpAndSettle();
    expect(find.text('0 / 4'), findsOneWidget);
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
        expect(q.options, hasLength(2));
        expect(q.options.toSet(), {'ه', 'ة'});
        expect(q.arabic!.contains(q.highlight!), isTrue);
      }
    });
  });
}
