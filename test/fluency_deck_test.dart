import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/fluency/fluency_store.dart';
import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/screens/fluency/deck_screen.dart';

import 'test_support.dart';

/// The flashcards: read, rate; slow comes back until it's instant; only the
/// first rating counts; the warm-up holds the plan week's tier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    mockAudioPlugins();
    await loadMushaf('uthmani');
  });

  Future<FluencyStore> pump(WidgetTester tester, Deck deck) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final f = FluencyStore();
    await f.load();
    f
      ..toggleSlow(const WordRef(2, 30, 1), 'وَإِذْ')
      ..toggleSlow(const WordRef(2, 30, 2), 'قَالَ');
    await tester.pumpWidget(FluencyScope(
      store: f,
      child: SettingsScope(
        settings: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: DeckScreen(deck: deck, title: 'Deck', block: 'warmup'),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    return f;
  }

  testWidgets('slow comes back until instant; the first rating counts', (tester) async {
    final f = await pump(tester, Deck.words);
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tap(find.text('Slow'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Instant'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    // The slow one, again.
    await tester.tap(find.text('Instant'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Done for now'), findsOneWidget);
    expect(find.text('1 instant · 1 slow · 0 wrong'), findsOneWidget);
    expect(f.progressOf('f:وَإِذْ')!.last, Recall.slow, reason: 'only the first rating');
    expect(f.progressOf('f:قَالَ')!.instantDays, hasLength(1));
    expect(f.blocksDoneToday, contains('warmup'));
    await f.flush();
  });

  testWidgets('the warm-up: your words and the tier', (tester) async {
    final f = await pump(tester, Deck.warmup);
    // 2 marked + tier 1 (the first weeks), capped at 25.
    expect(find.text('1 of 25'), findsOneWidget);
    await f.flush();
  });
}
