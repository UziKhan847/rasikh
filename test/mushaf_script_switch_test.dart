import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';

import 'test_support.dart';

/// Switching the muṣḥaf between Madani and Indo-Pak keeps the reader where
/// they were: the two scripts break their pages at different words, so the
/// page is matched by the words on it, not by its number or its sūrah.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadMushaf('indopak');
  });

  /// Global (āyah, word) keys of the words printed on [page].
  Set<(int, int)> wordsOn(String script, int page) => {
        for (final ln in MushafRepo.pageSync(script, page)!)
          if (ln.isText)
            for (final w in ln.words) (w.ayah, w.wordIdx),
      };

  test('every page maps to a page that shares its words, in order', () {
    for (final (from, to) in [('uthmani', 'indopak'), ('indopak', 'uthmani')]) {
      var last = 0;
      for (var p = 1; p <= MushafRepo.pageCountSync(from); p++) {
        final q = MushafRepo.matchingPage(from, p, to);
        expect(q, greaterThanOrEqualTo(last), reason: '$from p.$p');
        last = q;
        final mine = wordsOn(from, p);
        if (mine.isEmpty) continue;
        expect(wordsOn(to, q).intersection(mine), isNotEmpty,
            reason: '$from p.$p → $to p.$q shares no word');
        // Never further than the neighbouring page from where it maps back.
        expect((MushafRepo.matchingPage(to, q, from) - p).abs(),
            lessThanOrEqualTo(1),
            reason: '$from p.$p → $to p.$q → back');
      }
    }
  });

  testWidgets('switching script keeps the place; switching back is exact',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    s.desktopMode = 'off';
    s.mushafScript = 'uthmani';

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: ProgressScope(
        progress: p,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          // Deep in al-Baqarah, where going by sūrah lands 40 pages back.
          home: const MushafPageScreen(startPage: 40),
        ),
      ),
    ));
    await settle();
    expect(p.lastMushafPage, 40);

    s.update(() => s.mushafScript = 'indopak');
    await settle();
    final ip = MushafRepo.matchingPage('uthmani', 40, 'indopak');
    expect(ip, greaterThan(30));
    expect(p.lastMushafPage, ip);
    expect(p.lastMushafScript, 'indopak');

    s.update(() => s.mushafScript = 'uthmani');
    await settle();
    expect(p.lastMushafPage, 40);
    expect(p.lastMushafScript, 'uthmani');
  });

  testWidgets('the last page read opens mapped into the shown script',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    s.desktopMode = 'off';
    s.mushafScript = 'indopak';
    await tester.pumpWidget(SettingsScope(
      settings: s,
      child: ProgressScope(
        progress: p,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const MushafPageScreen(startPage: 300, pageScript: 'uthmani'),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(p.lastMushafPage, MushafRepo.matchingPage('uthmani', 300, 'indopak'));
    expect(p.lastMushafScript, 'indopak');
  });
}
