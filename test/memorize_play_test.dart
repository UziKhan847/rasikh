import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rasikh/core/memorize.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/memorize_bar.dart';

/// Memorizing, Play recites only what shows: the āyah being memorized as
/// far as it's revealed; held, any āyah showing, each as far as it shows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
  });

  test('each āyah as far as it shows, never a hidden word', () {
    final c = MemorizeController.startAt('uthmani', 50);
    final (first, _) = MushafRepo.pageTokens('uthmani', 50);
    final g0 = MushafRepo.tokenAt('uthmani', first).$1;
    expect(c.shownAyahs(), isEmpty);
    expect(c.clipOf(g0), isNull);
    // The first āyah all, and three words of the next.
    c.revealAyah();
    final g1 = g0 + 1;
    for (var i = 0; i < 3; i++) {
      c.nextWord();
    }
    expect(c.clipOf(g0), (g0, -1), reason: 'all of it');
    expect(c.clipOf(g1), (g1, 2), reason: 'to its third word');
    expect(c.clipOf(g1 + 1), isNull, reason: 'none of it shows');
    expect(c.shownAyahs(), [g0, g1]);
    expect(c.currentClip, (g1, 2), reason: 'a tap on Play: the āyah being memorized');
  });

  testWidgets('Play, held: the āyāt showing, each to be heard as far as it shows',
      (tester) async {
    final c = MemorizeController.startAt('uthmani', 50);
    c.revealAyah();
    c.nextWord();
    c.nextWord();
    final played = <List<(int, int)>>[];
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: MemorizeBar(
            controller: c,
            surahNames: const {},
            bg: Colors.white,
            ink: Colors.black,
            sub: Colors.grey,
            line: Colors.grey,
            accent: Colors.teal,
            onPlay: () {},
            onPlayPage: () {},
            onEnd: () {},
            onPlayClips: played.add,
          ),
        ),
      ),
    )));
    final shown = c.shownAyahs();
    expect(shown, hasLength(2));
    await tester.longPress(find.byTooltip('Hear the āyah as far as it shows (hold: choose the āyah)').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('up to word 2'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('memo-play-${shown.last}')));
    await tester.pumpAndSettle();
    expect(played.single, [(shown.last, 1)]);

    await tester.longPress(find.byTooltip('Hear the āyah as far as it shows (hold: choose the āyah)').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('memo-play-all')));
    await tester.pumpAndSettle();
    expect(played.last, [(shown.first, -1), (shown.last, 1)]);
  });
}
