import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'test_support.dart';

/// The 15-line muṣḥaf on the desktop, reciting: what a recited word
/// rebuilds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
  });

  testWidgets('a recited word', (tester) async {
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
      ..toolHintSeen = true
      ..desktopMode = 'on';
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
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
            home: const MushafPageScreen(home: true, startPage: 50, script: 'uthmani'),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 80));
    }
    final state = tester.state(find.byType(MushafPageScreen)) as dynamic;
    final (first, _) = MushafRepo.pageTokens('uthmani', 50);
    final g = MushafRepo.tokenAt('uthmani', first).$1 + 1;
    MushafPageScreen.debugBuilds = 0;
    MushafPageScreen.debugPageBuilds = 0;
    for (var w = 0; w < 10; w++) {
      state.debugRecite(g, w);
      await tester.pump();
    }
    debugPrint('[mushaf] 10 recited words: screen ${MushafPageScreen.debugBuilds}, '
        'pages ${MushafPageScreen.debugPageBuilds}');
    expect(MushafPageScreen.debugBuilds, 0, reason: 'not the dock, header and bars');
    expect(MushafPageScreen.debugPageBuilds, lessThanOrEqualTo(10), reason: 'the playing page only');
    await m.flush();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 31));
  });
}
