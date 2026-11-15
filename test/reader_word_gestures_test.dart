import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/quran_screen.dart';
import 'package:rasikh/screens/reader/ayah_text.dart';
import 'package:rasikh/ui/qiraah_ornaments.dart' show AyahMarker;

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// The card reader: a tap on a word plays it (no sheet); holding it plays
/// it and opens the word's sheet. The flow layout's āyahs are one paragraph
/// each too, ending on their marker.
/// The word's sheet opens once the muṣḥaf's words are at hand (loaded the
/// first time): waited for.
Future<void> sheetOpen(WidgetTester tester) async {
  for (var i = 0; i < 40 && find.text('Play word').evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    final metas = await QuranRepo.meta();
    await QuranRepo.ayahs(metas[0].n, 'uthmani', font: 'DigitalKhattV2');
    await QuranRepo.words(metas[0].n, 'uthmani', font: 'DigitalKhattV2');
  });

  Future<void> pump(WidgetTester tester, {String layout = 'cards'}) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    useReducedMotion(tester);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    s.readerLayout = layout;
    final meta = (await QuranRepo.meta())[0];
    await tester.pumpWidget(
      SettingsScope(
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
    );
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a tap plays the word; holding opens its sheet', (tester) async {
    await pump(tester);
    // The second āyah's first word, in its paragraph (see AyahText).
    final r = tester
        .renderObjectList<RenderAyahText>(find.byType(AyahText))
        .elementAt(1);
    final word = r.localToGlobal(r.wordCenter(0)!);

    await tester.tapAt(word);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BottomSheet), findsNothing, reason: 'a tap only plays');

    await tester.longPressAt(word);
    // (The sheet opens once the muṣḥaf's words are at hand.)
    await sheetOpen(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Play word'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    // The audio plugin's 30 s prepare timeout (no audio in tests).
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('flow: one paragraph per āyah, its marker inline', (tester) async {
    await pump(tester, layout: 'mushaf');
    final ayahs = find.byType(AyahText);
    expect(ayahs, findsWidgets);
    for (final e in ayahs.evaluate()) {
      expect(find.descendant(of: find.byWidget(e.widget), matching: find.byType(AyahMarker)),
          findsOneWidget);
    }
    // No paragraph per word: any text widget in an āyah is its marker's.
    final marker = find.descendant(of: ayahs.first, matching: find.byType(AyahMarker));
    expect(find.descendant(of: ayahs.first, matching: find.byType(RichText)).evaluate().length,
        find.descendant(of: marker, matching: find.byType(RichText)).evaluate().length);

    final r = tester.renderObjectList<RenderAyahText>(ayahs).elementAt(1);
    await tester.longPressAt(r.localToGlobal(r.wordCenter(0)!));
    await sheetOpen(tester);
    expect(find.text('Play word'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  });
}
