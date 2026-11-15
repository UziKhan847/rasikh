import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/fluency/fluency_store.dart';
import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/marks/marks_model.dart';
import 'package:rasikh/core/marks/marks_persistence.dart';
import 'package:rasikh/core/marks/marks_store.dart';
import 'package:rasikh/core/marks/word_ref.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/screens/marks/marking_bar.dart';
import 'package:rasikh/screens/marks/review_bar.dart';
import 'package:rasikh/screens/marks/review_cards_screen.dart';
import 'package:rasikh/screens/mushaf/memorize_bar.dart';
import 'package:rasikh/screens/mushaf/memorize_cards_screen.dart';
import 'package:rasikh/screens/mushaf_screen.dart';
import 'package:rasikh/screens/quran_screen.dart';

import 'test_support.dart';

/// One app, two views: whatever's on carries across the switch between the
/// page and the verses, both ways, and both have the same tools.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  Finder tip(String t) => find.byWidgetPredicate(
      (w) => w is Tooltip && (w.message == t || (w.message ?? '').startsWith('$t (')));

  Future<(AppSettings, MarksStore)> pump(WidgetTester tester,
      {Size size = const Size(430, 930), String mode = 'off'}) async {
    tester.view.physicalSize = size;
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
      ..desktopMode = mode;
    final m = MarksStore(persistence: MemoryMarksPersistence(), saveDelay: Duration.zero);
    await m.load();
    m.ensureActiveBook('Me');
    await tester.pumpWidget(MarksScope(
      store: m,
      child: SettingsScope(
        settings: s,
        child: ProgressScope(
          progress: p,
          child: FluencyScope(
            store: FluencyStore(),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: const MushafPageScreen(home: true, startPage: 50, script: 'uthmani'),
            ),
          ),
        ),
      ),
    ));
    await settle(tester);
    return (s, m);
  }

  Future<void> toVerses(WidgetTester t) async {
    await t.tap(find.byTooltip('Verses').hitTestable().first);
    await settle(t);
  }

  Future<void> toPage(WidgetTester t) async {
    await t.tap(find.byTooltip('Page').hitTestable().first);
    await settle(t);
  }

  List<String> openSessions(MarksStore m) => [
        for (final s in m.sessionsOf(m.activeBookId!))
          if (s.isOpen) s.id
      ];

  testWidgets('marking: on in the Reader too, the same session, and back', (tester) async {
    final (_, m) = await pump(tester);
    await tester.tap(tip('Mark'));
    await settle(tester);
    final session = openSessions(m).single;
    await toVerses(tester);
    expect(find.byType(SurahReaderScreen), findsOneWidget);
    expect(find.byType(MarkingBar), findsOneWidget, reason: 'marking in the Reader');
    expect(openSessions(m), [session], reason: 'the same session');
    await toPage(tester);
    expect(find.byType(SurahReaderScreen), findsNothing);
    expect(find.byType(MarkingBar), findsOneWidget, reason: 'and on the page again');
    expect(openSessions(m), [session]);
    await tester.pump(const Duration(seconds: 5));
    await m.flush();
  });

  testWidgets('the recitation tool carries across', (tester) async {
    final (_, m) = await pump(tester);
    await tester.tap(tip('Recitation'));
    await settle(tester);
    await toVerses(tester);
    expect(find.byType(SurahReaderScreen), findsOneWidget);
    expect(tip('Recitation'), findsNothing, reason: 'the player has the row');
    await toPage(tester);
    expect(find.text('Done'), findsWidgets, reason: 'the recitation tool\'s bar again');
    await m.flush();
  });

  testWidgets('reviewing: as cards, and back to the page\'s review at the same mark',
      (tester) async {
    final (_, m) = await pump(tester);
    final b = m.activeBookId!;
    m.addMark(b, const WordRef(3, 1, 1), MarkType.mistake);
    m.addMark(b, const WordRef(3, 2, 1), MarkType.doubt);
    await tester.tap(tip('Review'));
    await settle(tester);
    expect(find.byType(ReviewBar), findsOneWidget);
    await toVerses(tester);
    expect(find.byType(ReviewCardsScreen), findsOneWidget);
    await toPage(tester);
    expect(find.byType(ReviewCardsScreen), findsNothing);
    expect(find.byType(ReviewBar), findsOneWidget, reason: 'the review goes on on the page');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    await m.flush();
  });

  testWidgets('memorizing from the Reader: its cards hand over to the page', (tester) async {
    final (_, m) = await pump(tester);
    await toVerses(tester);
    await tester.tap(tip('Memorize'));
    await settle(tester);
    expect(find.byType(MemorizeCardsScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Muṣḥaf page').first);
    await settle(tester);
    expect(find.byType(MemorizeCardsScreen), findsNothing);
    expect(find.byType(SurahReaderScreen), findsNothing);
    expect(find.byType(MemorizeBar), findsOneWidget, reason: 'memorizing on the page');
    await m.flush();
  });

  testWidgets('the Reader: its options in the row, the same menu as the page\'s',
      (tester) async {
    final (_, m) = await pump(tester);
    await toVerses(tester);
    expect(tip('Reader options'), findsOneWidget, reason: 'outside the ⋯');
    expect(find.byTooltip('Back'), findsNothing, reason: 'the switch is the way back');
    await tester.tap(find.byTooltip('More').last);
    await settle(tester);
    for (final t in ['Theme', 'Dark', 'History', 'Settings']) {
      expect(tip(t), findsWidgets, reason: t);
    }
    expect(find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').startsWith('Arabic script')),
        findsWidgets);
    await m.flush();
  });

  testWidgets('desktop: the gear\'s menu has what the row doesn\'t', (tester) async {
    final (_, m) = await pump(tester, size: const Size(1400, 900), mode: 'on');
    expect(find.byTooltip('More'), findsNothing);
    expect(tip('History'), findsNothing, reason: 'in the menu, not the row');
    await tester.tap(find.byTooltip('Settings').last);
    await tester.pumpAndSettle();
    for (final t in ['History', 'Keyboard shortcuts', 'Button guide', 'Settings']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    await tester.tap(find.text('Keyboard shortcuts'));
    await tester.pumpAndSettle();
    expect(find.text('Reset all'), findsNothing);
    expect(find.textContaining('Keyboard'), findsWidgets);
    await m.flush();
  });
}
