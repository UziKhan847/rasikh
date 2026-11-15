import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/fluency/fluency_store.dart';
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/mushaf.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/mushaf/mushaf_index_sheet.dart';
import 'package:rasikh/screens/quran_screen.dart';
import 'package:rasikh/screens/reader/ayah_text.dart';
import 'package:rasikh/screens/reader/reader_host.dart';

import 'package:rasikh/screens/settings_screen.dart' show SettingsBody;
import 'test_support.dart';

/// The muṣḥaf's Verses view: opened at the page's first āyah; its switch
/// goes back to the page it's reading; back returns nothing; the title is
/// the way to the index; fluency marks show on its cards at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late int page;

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
    page = MushafRepo.pageForGlobalAyah('uthmani', MushafRepo.globalAyahOf(2, 30));
  });

  late FluencyStore fluency;
  late int? result;
  late bool closed;

  Future<void> pump(WidgetTester tester) async {
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
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    fluency = FluencyStore();
    await fluency.load();
    result = null;
    closed = false;
    await tester.pumpWidget(FluencyScope(
      store: fluency,
      child: MarksScope(
        store: m,
        child: SettingsScope(
          settings: s,
          child: ProgressScope(
            progress: p,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Builder(
                builder: (c) => TextButton(
                  onPressed: () async {
                    result = (await openVerses(c, 'uthmani', page))?.page;
                    closed = true;
                  },
                  child: const Text('the muṣḥaf'),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('the muṣḥaf'));
    await settle(tester);
    await settle(tester);
  }

  testWidgets('opens at the page\'s first āyah; Page goes back to it', (tester) async {
    await pump(tester);
    final v = tester.widget<SurahReaderScreen>(find.byType(SurahReaderScreen));
    expect(v.meta.n, 2);
    expect(MushafRepo.pageForGlobalAyah('uthmani', MushafRepo.globalAyahOf(2, v.startAyah!)), page);
    // Its words loaded and scrolled to the āyah.
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    await tester.tap(find.byTooltip('Page'));
    await settle(tester);
    expect(closed, isTrue);
    expect(result, page);
  });

  testWidgets('back: the page as it was (nothing to show)', (tester) async {
    await pump(tester);
    // No back button of its own: the switch, or the system's back.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('the title opens the index, and the row\'s button', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Index'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Index').first);
    await tester.pumpAndSettle();
    expect(find.byType(MushafIndex), findsOneWidget);
  });

  testWidgets('the same row as the page: Index, Review, Memorize, Mark, '
      'Recitation, and the rest in ⋯', (tester) async {
    await pump(tester);
    for (final t in ['Review', 'Memorize', 'Mark', 'Recitation', 'More']) {
      expect(find.byTooltip(t), findsOneWidget, reason: t);
    }
    expect(find.byTooltip('Fluency marks'), findsNothing, reason: 'in Mark now');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsBody), findsOneWidget);
    expect(find.byType(VersesView, skipOffstage: false), findsOneWidget);
  });

  testWidgets('Recitation: the player in the row\'s place; its close brings the '
      'row back', (tester) async {
    await pump(tester);
    expect(find.byTooltip('Previous āyah'), findsNothing);
    await tester.tap(find.byTooltip('Recitation'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mark'), findsNothing);
    expect(find.byTooltip('Hide player'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide player'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mark'), findsOneWidget);
  });

  testWidgets('on its side: the row down the side, nothing overflowing', (tester) async {
    await pump(tester);
    tester.view.physicalSize = const Size(900, 412);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getCenter(find.byTooltip('Mark')).dx, greaterThan(800));
    tester.view.physicalSize = const Size(360, 700);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a larger size keeps the page where it is: the banner at the top; '
      'the top āyah mid-sūrah', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Quick adjust'));
    await tester.pumpAndSettle();
    ScrollPosition pos() => tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((st) => st.position.maxScrollExtent > 1000)
        .position;

    // At the sūrah's top.
    pos().jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Larger text'));
    await tester.pumpAndSettle();
    expect(pos().pixels, 0, reason: 'no jump to the first āyah');

    // Further down: the āyah at the top stays at its height on the screen.
    pos().jumpTo(1500);
    await tester.pumpAndSettle();
    final top = find.byType(AyahText).hitTestable().first;
    final key = tester.renderObject<RenderAyahText>(top);
    final y = key.localToGlobal(Offset.zero).dy;
    await tester.tap(find.byTooltip('Larger text'));
    await tester.pumpAndSettle();
    expect(key.localToGlobal(Offset.zero).dy, closeTo(y, 1));
  });

  testWidgets('Mark: on with the kind last used; a word tap marks it, shown on '
      'its card', (tester) async {
    await pump(tester);
    final m = tester.element(find.byType(VersesView));
    final store = MarksScope.of(m);
    await tester.tap(find.byTooltip('Mark'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mark'), findsNothing, reason: 'the marking bar');
    final r = tester.renderObjectList<RenderAyahText>(find.byType(AyahText).hitTestable()).first;
    await tester.tapAt(r.localToGlobal(r.wordCenter(0)!));
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.marksOf(store.activeBookId!), isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await store.flush();
  });

  testWidgets('a fluency mark shows on its card at once', (tester) async {
    await pump(tester);
    fluency.toggleSlow(const WordRef(2, 30, 3), 'x');
    await tester.pump();
    final marked = tester
        .widgetList<AyahText>(find.byType(AyahText))
        .any((a) => a.fluency.any((v) => v?.slow ?? false));
    expect(marked, isTrue);
    await fluency.flush();
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}
