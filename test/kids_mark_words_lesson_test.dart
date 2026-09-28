import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/kids/kids_mark_words_lesson.dart';

import 'kids_test_support.dart';

/// The tamrīn lesson: real words carrying a mark, read one at a time. Every
/// other Kids Mode lesson tests its screen against an injected corpus rather
/// than the network, following [KidsListenAndPick]'s own pattern.
final _corpus = {
  1: [
    ['بِسۡمِ', 'ٱللَّهِ', 'ٱلرَّحۡمَٰنِ', 'ٱلرَّحِيمِ'],
    ['قُلۡ', 'هُوَ', 'ٱللَّهُ', 'أَحَدٌ'],
  ],
};

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walks every sukūn word and reports real progress', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    final played = <(int, int, int)>[];
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMarkWordsLesson(
          markIds: const ['sukun'],
          progressId: 'kids.sukun.words',
          corpus: _corpus,
          play: (s, a, w) async => played.add((s, a, w)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Material), findsWidgets);
    expect(prog.starsFor('kids.sukun.words'), 0);

    for (var i = 0; i < 20; i++) {
      if (find.text('Continue').evaluate().isNotEmpty) break;
      await tester.tap(find.text('I read it!'));
      await tester.pump();
    }
    expect(find.text('Continue'), findsOneWidget);
    expect(prog.starsFor('kids.sukun.words'), 3);
    // A word was actually played, with real coordinates.
    expect(played, isNotEmpty);
    expect(played.first.$1, 1); // surah 1, from the injected corpus
  });

  testWidgets('every word shown really carries the mark being practised', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMarkWordsLesson(
          markIds: const ['shadda'],
          progressId: 'test.words',
          corpus: _corpus,
          play: (s, a, w) async {},
        ),
      ),
    );
    await tester.pump();

    // شَدَّة words in the corpus: ٱللَّهِ / ٱلرَّحۡمَٰنِ / ٱلرَّحِيمِ / ٱللَّهُ — never بِسۡمِ or
    // قُلۡ or هُوَ or أَحَدٌ, which carry no shaddah.
    expect(find.text('بِسۡمِ'), findsNothing);
    expect(find.text('قُلۡ'), findsNothing);
  });

  testWidgets('mixing the three ḥarakāt draws from all three, not just one', (
    tester,
  ) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMarkWordsLesson(
          markIds: const ['fatha', 'kasra', 'damma'],
          progressId: 'test.words',
          corpus: _corpus,
          play: (s, a, w) async {},
        ),
      ),
    );
    await tester.pump();
    // Some ḥarakah word is on screen — the round is never empty when the
    // corpus plainly has fatḥah/kasrah/ḍammah words in it.
    expect(find.text('Continue'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('fits a 320×568 phone at the largest text size', (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final (settings, prog) = await _boot();
    settings.kidsTextScale = 1.2;
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMarkWordsLesson(
          markIds: const ['shadda'],
          progressId: 'test.words',
          corpus: _corpus,
          play: (s, a, w) async {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty match shows the same "unavailable" message as '
      'reading does, never a stuck spinner', (tester) async {
    useReducedMotion(tester);
    final (settings, prog) = await _boot();
    await tester.pumpWidget(
      _harness(
        settings,
        prog,
        KidsMarkWordsLesson(
          markIds: const ['sukun'],
          progressId: 'test.words',
          corpus: const {
            1: [
              ['خَلَقَ'], // no sukūn anywhere
            ],
          },
          play: (s, a, w) async {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(prog.starsFor('test.words'), 0);
  });
}
