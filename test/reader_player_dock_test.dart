import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/quran_screen.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// The docked player's tab (Unpin · Collapse · Hide) sits on the player's top
/// edge. Its upper half used to hang outside the player, where taps went to
/// the words behind it instead — the button didn't act and a word played.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await loadFonts();
    final metas = await QuranRepo.meta();
    await QuranRepo.ayahs(metas[1].n, 'uthmani', font: 'DigitalKhattV2');
    await QuranRepo.words(metas[1].n, 'uthmani', font: 'DigitalKhattV2');
  });

  for (final (tip, check) in [
    ('Unpin', (AppSettings s) => s.playerDock == 'floating'),
    ('Collapse', (AppSettings s) => s.playerMinimised),
    ('Hide player', (AppSettings s) => s.playerDock == 'hidden'),
  ]) {
    testWidgets('the top edge of the dock tab\'s "$tip" acts on the player', (
      tester,
    ) async {
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
      s.playerDock = 'pinned';
      s.playerMinimised = false;
      final meta = (await QuranRepo.meta())[1];
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
      final button = find.byTooltip(tip);
      expect(button, findsOneWidget);
      // 3 px below the button's top: the half that used to stick out.
      final r = tester.getRect(button);
      await tester.tapAt(Offset(r.center.dx, r.top + 3));
      await tester.pump(const Duration(milliseconds: 300));
      expect(check(s), isTrue, reason: '"$tip" didn\'t act');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
