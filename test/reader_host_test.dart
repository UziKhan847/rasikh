import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_persistence.dart';
import 'package:qiraah_arabiyyah/core/marks/marks_store.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_index_sheet.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';
import 'package:qiraah_arabiyyah/screens/quran_screen.dart';
import 'package:qiraah_arabiyyah/screens/reader/reader_host.dart';

import 'test_support.dart';

/// The Reader: one place, two views a switch apart, the place kept across;
/// back from either goes to the index; the view last used comes back; the
/// index is the title (and the page line), no button of its own; no Hifẓ
/// pen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<(AppSettings, NavigatorState)> pump(WidgetTester tester,
      {String view = 'verses'}) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    useReducedMotion(tester);
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    final p = ProgressStore();
    await s.load();
    await p.load();
    s
      ..onboarded = true
      ..readerView = view;
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    m.ensureActiveBook('Me');
    final meta = (await QuranRepo.meta())[1]; // Al-Baqarah
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: MaterialApp(
            navigatorKey: nav,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: Text('the index')),
          ),
        ),
      ),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => ReaderHost(meta: meta, startAyah: 30)));
    await settle(tester);
    return (s, nav.currentState!);
  }

  testWidgets('verses → page → verses keeps the place; remembered',
      (tester) async {
    final (s, _) = await pump(tester);
    // Its words loaded and scrolled to 2:255.
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    expect(find.byType(SurahReaderScreen), findsOneWidget);
    expect(find.byTooltip('Mark recitation'), findsNothing, reason: 'no Hifẓ pen');
    await tester.tap(find.byTooltip('Page'));
    await settle(tester);
    final page = tester.widget<MushafPageScreen>(find.byType(MushafPageScreen));
    expect(page.startPage,
        MushafRepo.pageForGlobalAyah('uthmani', MushafRepo.globalAyahOf(2, 30)));
    expect(s.readerView, 'page');
    expect(find.byTooltip('Mark recitation'), findsNothing, reason: 'no Hifẓ pen');
    expect(find.byTooltip('Muṣḥaf settings'), findsOneWidget);
    await tester.tap(find.byTooltip('Verses'));
    await settle(tester);
    final v = tester.widget<SurahReaderScreen>(find.byType(SurahReaderScreen));
    expect(v.meta.n, 2);
    expect(s.readerView, 'verses');
    await tester.pump(const Duration(milliseconds: 400)); // the save
  });

  testWidgets('opens on the page view if that was last; back goes to the '
      'index; the page line opens the index', (tester) async {
    await pump(tester, view: 'page');
    expect(find.byType(MushafPageScreen), findsOneWidget);
    expect(find.byTooltip('Index'), findsOneWidget, reason: 'the title');
    await tester.tap(find.byTooltip('Go to page'));
    await tester.pumpAndSettle();
    expect(find.byType(MushafIndex), findsOneWidget);
    await tester.tapAt(const Offset(215, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.text('the index'), findsOneWidget);
  });

  testWidgets('verses: the title opens the index, no button for it',
      (tester) async {
    await pump(tester);
    expect(find.byTooltip('Index'), findsOneWidget, reason: 'only the title');
    await tester.tap(find.byTooltip('Index'));
    await tester.pumpAndSettle();
    expect(find.byType(MushafIndex), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}
