import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/fluency/fluency_store.dart';
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/core/theme.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/reader/ayah_text.dart';
import 'package:rasikh/screens/mushaf_screen.dart';

import 'shots/shots_test.dart' show loadFonts;
import 'test_support.dart';

/// The Reader follows dark and light at once: its āyāt in the new ink, both
/// ways, as the app's own theme changes under it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    await loadFonts();
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets('the Reader from the home page, Dark from its ⋯ and back: the āyāt '
      'readable each time', (tester) async {
    tester.view.physicalSize = const Size(590, 1280);
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
      ..desktopMode = 'off';
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    m.ensureActiveBook('Me');
    final page = MushafRepo.pageForGlobalAyah('uthmani', MushafRepo.globalAyahOf(68, 16));
    final shotKey = GlobalKey();
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: FluencyScope(
            store: FluencyStore(),
            // As the app: its theme from the settings, rebuilt as they change.
            child: RepaintBoundary(
              key: shotKey,
              child: ListenableBuilder(
              listenable: s,
              builder: (_, _) => MaterialApp(
                theme: buildTheme(s),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: MushafPageScreen(home: true, startPage: page, script: 'uthmani'),
              ),
            ),
            ),
          ),
        ),
      ),
    ));
    await settle(tester);
    await tester.tap(find.byTooltip('Verses').hitTestable().first);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AyahText), findsWidgets);

    // Anything over an āyah that would dim it, from it up to the screen.
    double dimming() {
      var o = 1.0;
      RenderObject? r = tester.renderObject(find.byType(AyahText).first);
      while (r != null) {
        if (r is RenderOpacity) o *= r.opacity;
        if (r is RenderAnimatedOpacity) o *= r.opacity.value;
        r = r.parent;
      }
      return o;
    }

    RenderObject? lastText = tester.renderObject(find.byType(AyahText).first);
    for (final _ in [1, 2, 3, 4]) {
      await tester.tap(find.byTooltip('More').hitTestable().first);
      await tester.pumpAndSettle();
      final before = s.theme;
      final dark = find.byTooltip(s.isDarkTheme ? 'Light' : 'Dark').hitTestable();
      await tester.tap(dark.first);
      await tester.pumpAndSettle();
      expect(s.theme, isNot(before), reason: 'switched');
      await settle(tester);
      final ctx = find.byType(AyahText).evaluate().first;
      final r = tester.renderObject<RenderAyahText>(find.byType(AyahText).first);
      expect(r.debugInk, readingInk(ctx), reason: 'the ink now (${s.theme})');
      expect(dimming(), 1.0, reason: 'nothing dims it (${s.theme})');
      // Built afresh in the new theme (not the old text re-inked).
      expect(identical(r, tester.renderObject(find.byType(AyahText).first)), isTrue);
      expect(identical(r, lastText), isFalse, reason: 'a new text, not the old');
      lastText = r;
      // The fan closed again.
      await tester.tapAt(const Offset(300, 400));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
