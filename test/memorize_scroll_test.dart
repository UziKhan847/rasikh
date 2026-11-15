import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/memorize.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/mushaf_atlas.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/memorize_bar.dart';
import 'package:rasikh/screens/mushaf/memorize_cards_screen.dart';
import 'package:rasikh/screens/mushaf/verse_view.dart';

import 'test_support.dart';

/// Memorizing reader-style: the cards so far, each coming as it's reached.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await MushafAtlas.load('uthmani', MushafRepo.tokensSync('uthmani'));
  });

  Future<(AppSettings, MemorizeController)> pump(
    WidgetTester tester, {
    String view = 'scroll',
    bool desktop = false,
  }) async {
    tester.view.physicalSize = desktop
        ? const Size(1400, 900)
        : const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    s.memorizeCardsView = view;
    s.desktopMode = desktop ? 'on' : 'off';
    final g = MushafRepo.globalAyahOf(2, 3);
    final c = MemorizeController.startAtToken(
      'uthmani',
      MushafRepo.tokenOf('uthmani', g, 0),
    );
    await tester.pumpWidget(
      SettingsScope(
        settings: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: MemorizeCardsScreen(controller: c, fromReader: true),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
    return (s, c);
  }

  List<int> shown(WidgetTester tester) => [
    for (final v in tester.widgetList<VerseView>(find.byType(VerseView)))
      v.globalAyah,
  ];

  testWidgets(
    'only the card it opened on; the next comes when this one is done, '
    'blank; back takes it away',
    (tester) async {
      final (_, c) = await pump(tester);
      final g = MushafRepo.globalAyahOf(2, 3);
      expect(shown(tester), [g]);
      c.nextWord();
      await tester.pumpAndSettle();
      expect(c.revealedEnd, MushafRepo.tokenOf('uthmani', g, 1));
      expect(shown(tester), [g]);

      c.nextVerse();
      await tester.pumpAndSettle();
      expect(shown(tester), [g], reason: 'all of it shows, nothing more yet');
      final done = c.revealedEnd;
      c.nextWord();
      await tester.pumpAndSettle();
      expect(shown(tester), [g, g + 1], reason: 'the next card');
      expect(c.revealedEnd, done, reason: 'blank');

      c.prevWord();
      await tester.pumpAndSettle();
      expect(shown(tester), [g]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets('a new card comes up into view', (tester) async {
    final (_, c) = await pump(tester);
    for (var i = 0; i < 6; i++) {
      c.nextVerse();
      await tester.pumpAndSettle();
      c.nextWord();
      await tester.pumpAndSettle();
    }
    final last = find.byType(VerseView).last;
    expect(tester.getTopLeft(last).dy, inInclusiveRange(0, 900 * .6));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('steps in quick succession still end with the card on screen', (
    tester,
  ) async {
    final (_, c) = await pump(tester);
    for (var i = 0; i < 8; i++) {
      c.nextVerse();
      await tester.pump(const Duration(milliseconds: 40));
      c.nextWord();
      await tester.pump(const Duration(milliseconds: 40));
      c.nextWord();
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();
    final r = tester.getRect(find.byType(VerseView).last);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.top, lessThan(tester.getTopLeft(find.byType(MemorizeBar)).dy));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('the toggle swaps to one card and back, keeping the place', (
    tester,
  ) async {
    final (s, c) = await pump(tester);
    c.nextVerse();
    await tester.pumpAndSettle();
    c.nextWord();
    await tester.pumpAndSettle();
    final g = c.viewAyah;
    await tester.tap(find.byTooltip('One card at a time'));
    await tester.pumpAndSettle();
    expect(s.memorizeCardsView, 'single');
    expect(shown(tester), [g]);
    await tester.tap(find.byTooltip('Cards in a scroll'));
    await tester.pumpAndSettle();
    expect(shown(tester), [g - 1, g]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('desktop: one card, the word just revealed large below; Space '
      'reveals, Backspace hides it again', (tester) async {
    final (_, c) = await pump(tester, desktop: true);
    final g = MushafRepo.globalAyahOf(2, 3);
    final start = c.revealedEnd;
    Finder word(int w) => find.descendant(
      of: find.byKey(const ValueKey('memo-word')),
      matching: find.text(MushafRepo.wordText('uthmani', g, w)),
    );

    expect(find.byKey(const ValueKey('memo-word')), findsOneWidget);
    expect(word(0), findsNothing, reason: 'blank yet');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(c.revealedEnd, start + 1);
    expect(word(0), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(word(1), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(c.revealedEnd, start + 1);
    expect(word(0), findsOneWidget);

    // Revealing on to the next āyah: still one card, not a list.
    c.nextVerse();
    await tester.pumpAndSettle();
    c.nextWord();
    await tester.pumpAndSettle();
    expect(shown(tester), [g + 1]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });
}
