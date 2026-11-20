import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/quran_screen.dart';
import 'package:rasikh/screens/reader/ayah_text.dart';

import 'test_support.dart';

/// The desktop Reader on a long sūrah, tajwīd on: what a recited word and
/// a mark rebuild. Only what shows them should.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    final metas = await QuranRepo.meta();
    await QuranRepo.ayahs(metas[1].n, 'uthmani', font: 'DigitalKhattV2');
    await QuranRepo.words(metas[1].n, 'uthmani', font: 'DigitalKhattV2');
  });

  Future<(MarksStore, String)> reader(WidgetTester tester, {String layout = 'cards'}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..desktopMode = 'on'
      ..tajwidColors = true
      ..readerLayout = layout;
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    final b = m.ensureActiveBook('Me').id;
    final meta = (await QuranRepo.meta())[1];
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: SurahReaderScreen(meta: meta),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    return (m, b);
  }

  void reset() {
    SurahReaderScreen.debugBuilds = 0;
    SurahReaderScreen.debugAyahBuilds = 0;
    SurahReaderScreen.debugSpanBuilds = 0;
  }

  String counts() => 'reader ${SurahReaderScreen.debugBuilds}, '
      'āyāt ${SurahReaderScreen.debugAyahBuilds}, '
      'spans ${SurahReaderScreen.debugSpanBuilds}';

  for (final layout in ['cards', 'mushaf']) {
    testWidgets('$layout: a recited word, and a mark', (tester) async {
      final (m, b) = await reader(tester, layout: layout);
      final state = tester.state(find.byType(SurahReaderScreen)) as dynamic;

      reset();
      for (var w = 0; w < 10; w++) {
        state.debugRecite(2, w);
        await tester.pump();
      }
      debugPrint('[$layout] 10 recited words: ${counts()}');
      final perWord = (
        SurahReaderScreen.debugBuilds / 10,
        SurahReaderScreen.debugAyahBuilds / 10,
        SurahReaderScreen.debugSpanBuilds / 10,
      );

      reset();
      m.addMark(b, const WordRef(2, 4, 2), MarkType.mistake);
      await tester.pump();
      debugPrint('[$layout] one mark: ${counts()}');
      final mark = (
        SurahReaderScreen.debugBuilds,
        SurahReaderScreen.debugAyahBuilds,
        SurahReaderScreen.debugSpanBuilds,
      );
      debugPrint('[$layout] per word $perWord; mark $mark');
      // Only the text of the āyah reciting, and only the āyah marked.
      expect(perWord.$1, 0, reason: 'the Reader isn\'t rebuilt for a word');
      expect(perWord.$3, 0, reason: 'its word spans are kept');
      if (layout == 'cards') expect(perWord.$2, 0, reason: 'the card around it is left');
      expect(mark, (0, 1, 0), reason: 'a mark rebuilds its own āyah, nothing else');
      // And they still show: the word lit, the mark drawn.
      // (Built just past the screen's edge, in the list's look-ahead.)
      expect(
          find.byWidgetPredicate((w) => w is AyahText && w.playWord == 9, skipOffstage: false),
          findsOneWidget);
      expect(
          find.byWidgetPredicate(
              (w) => w is AyahText && w.marks.any((v) => v?.open == MarkType.mistake),
              skipOffstage: false),
          findsOneWidget);

      await m.flush();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    });
  }
}
