import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/quran_screen.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// The card reader: a tap on a word plays it (no sheet); holding it plays
/// it and opens the word's sheet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    final metas = await QuranRepo.meta();
    await QuranRepo.ayahs(metas[0].n, 'uthmani', font: 'DigitalKhattV2');
    await QuranRepo.words(metas[0].n, 'uthmani', font: 'DigitalKhattV2');
  });

  testWidgets('a tap plays the word; holding opens its sheet', (tester) async {
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
    final words = await QuranRepo.words(1, 'uthmani', font: 'DigitalKhattV2');
    final word = find.text(words[1][0], findRichText: true).first;

    await tester.tap(word);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BottomSheet), findsNothing, reason: 'a tap only plays');

    await tester.longPress(word);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Play word'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    // The audio plugin's 30 s prepare timeout (no audio in tests).
    await tester.pump(const Duration(seconds: 31));
  });
}
