import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/fluency/fluency_store.dart';
import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/word_ref.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_line.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';
import 'package:qiraah_arabiyyah/screens/reader/reader_host.dart';

import 'test_support.dart';

/// The Reader's page: the fluency tool marks a tapped word; a mark repaints
/// its own page's lines and rebuilds no page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });
  tearDown(() => debugOnRebuildDirtyWidget = null);

  Future<FluencyStore> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s.onboarded = true;
    final f = FluencyStore();
    await f.load();
    await tester.pumpWidget(FluencyScope(
      store: f,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: MushafPageScreen(
              startPage: 50,
              script: 'uthmani',
              reader: ReaderLink(toPage: (_) {}, toVerses: (_, _) {}),
            ),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    return f;
  }

  testWidgets('a mark repaints its page, rebuilding nothing', (tester) async {
    final f = await pump(tester);
    var builds = 0;
    debugOnRebuildDirtyWidget = (e, _) {
      if (e.widget.runtimeType.toString() == '_MushafPageView') builds++;
    };
    final (first, _) = MushafRepo.pageTokens('uthmani', 50);
    final (g, w) = MushafRepo.tokenAt('uthmani', first + 3);
    RenderMushafLine.debugPaints = 0;
    f.toggleSlow(WordRef.fromGlobal(g, w), 'x');
    await tester.pump();
    expect(builds, 0, reason: 'a mark rebuilt a page');
    expect(RenderMushafLine.debugPaints, inInclusiveRange(1, 15));
    await f.flush();
  });

  testWidgets('the tool: a tap marks the word not fluent', (tester) async {
    final f = await pump(tester);
    await tester.tap(find.byTooltip('Fluency marks'));
    await tester.pump();
    expect(find.text('Not fluent'), findsOneWidget);
    final line = tester
        .renderObjectList<RenderMushafLine>(find.byType(MushafLineView))
        .firstWhere((r) => r.attached && r.spec.page == 50 && r.spec.line.words.length > 3);
    // A word, not an āyah's ۝.
    final i = line.spec.line.words.indexWhere((w) => !w.isMarker);
    final r = line.wordRect(i)!;
    await tester.tapAt(line.localToGlobal(r.center));
    await tester.pump();
    final wd = line.spec.line.words[i];
    expect(f.isSlow(WordRef.fromGlobal(wd.ayah, wd.wordIdx)), isTrue);
    await f.flush();
  });
}
