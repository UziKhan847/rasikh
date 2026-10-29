import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/fluency/fluency_audio.dart';
import 'package:qiraah_arabiyyah/core/fluency/fluency_store.dart';
import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/fluency/deck_screen.dart';
import 'package:qiraah_arabiyyah/screens/fluency/fluency_tools.dart';
import 'package:qiraah_arabiyyah/screens/fluency/verse_review_screen.dart';
import 'package:qiraah_arabiyyah/screens/reader/ayah_text.dart';

import 'test_support.dart';

/// The fluency review verse by verse; Ḥuṣarī's timing rows for words run
/// together; everything marked in the warm-up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  test('a word run into the one before plays from that one\'s row', () {
    const segs = [
      [0, 0, 500],
      [1, 500, 900], // words 1 and 2 recited as one
      [3, 900, 1500],
    ];
    expect(FluencyAudio.rowOf(segs, 2), [1, 500, 900]);
    expect(FluencyAudio.rowOf(segs, 3), [3, 900, 1500]);
  });

  Future<FluencyStore> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final f = FluencyStore();
    await f.load();
    await tester.pumpWidget(FluencyScope(
      store: f,
      child: SettingsScope(
        settings: s,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: home,
        ),
      ),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
    return f;
  }

  testWidgets('verse by verse: mark a word, it\'s under the card, rate it, on',
      (tester) async {
    final g = MushafRepo.globalAyahOf(2, 30);
    final f = await pump(tester, VerseReviewScreen(ayahs: [g, g + 1], title: 'Review'));
    expect(find.text('Al-Baqarah 2:30'), findsOneWidget);
    expect(find.text('Nothing marked here yet. Tap a word above to mark it.'), findsOneWidget);
    final r = tester.renderObject<RenderAyahText>(find.byType(AyahText));
    await tester.tapAt(r.localToGlobal(r.wordCenter(2)!));
    await tester.pump();
    expect(f.isSlow(WordRef.fromGlobal(g, 2)), isTrue);
    expect(find.text('Not fluent'), findsWidgets);
    await tester.ensureVisible(find.text('Instant'));
    await tester.pump();
    await tester.tap(find.text('Instant'));
    await tester.pump();
    expect(f.marks.single.cardId, isNotEmpty);
    expect(f.progressOf(f.marks.single.cardId)!.last, Recall.instant);
    await tester.tap(find.text('Next āyah'));
    await tester.pump();
    expect(find.text('Al-Baqarah 2:31'), findsOneWidget);
    await f.flush();
  });

  testWidgets('the warm-up holds pairs and chunks too', (tester) async {
    late BuildContext ctx;
    final f = await pump(tester, Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    togglePairAt(f, 'uthmani', const WordRef(2, 30, 6));
    f.setChunk(const WordRef(2, 31, 1), 'وَعَلَّمَ', 1, 0);
    final ids = deckCards(ctx, f, 'uthmani', Deck.warmup).map((c) => c.id).toList();
    expect(ids.where((i) => i.startsWith('pair:') || i.startsWith('chunk:')), hasLength(2));
    await f.flush();
  });
}
