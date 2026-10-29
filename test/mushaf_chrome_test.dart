import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/memorize_bar.dart';
import 'package:qiraah_arabiyyah/screens/mushaf/mushaf_index_sheet.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';

import 'test_support.dart';

/// The muṣḥaf's chrome: the bars hide and show with a tap on the page, the
/// page colour button walks the papers (setting the app theme), page turns
/// are remembered, and on desktop the view modes and arrow keys work.
Future<(AppSettings, ProgressStore)> _boot({required bool desktop}) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppSettings();
  final p = ProgressStore();
  await s.load();
  await p.load();
  s.onboarded = true;
  s.desktopMode = desktop ? 'on' : 'off';
  return (s, p);
}

Future<void> _pump(
  WidgetTester tester,
  AppSettings s,
  ProgressStore p, {
  int page = 1,
}) async {
  await tester.pumpWidget(
    SettingsScope(
      settings: s,
      child: ProgressScope(
        progress: p,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: MushafPageScreen(startPage: page),
        ),
      ),
    ),
  );
  // The page data loads asynchronously.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

double _barOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byTooltip('Close Muṣḥaf'),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    )
    .opacity;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  testWidgets('phone: tap toggles the bars; the page line opens the index', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await _boot(desktop: false);
    await _pump(tester, s, p, page: 2);

    expect(_barOpacity(tester), 1);
    // A tap in the page margin (not on a word) hides both bars …
    await tester.tapAt(const Offset(12, 420));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_barOpacity(tester), 0);
    // … and another brings them back.
    await tester.tapAt(const Offset(12, 420));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_barOpacity(tester), 1);

    // The page colour is in the settings now; the bar keeps to the page.
    expect(find.byTooltip('Page colour'), findsNothing);
    await tester.tap(find.byTooltip('Muṣḥaf settings'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
        find.text('Dark'), find.byType(ListView).last, const Offset(0, -200));
    await tester.ensureVisible(find.text('Dark').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pump();
    expect(s.appTheme, 'night');
    await tester.tapAt(const Offset(195, 20)); // out of the sheet
    await tester.pumpAndSettle();
    // The page line opens the index; there's no separate button for it.
    expect(find.byTooltip('Go to page'), findsOneWidget);
    await tester.tap(find.byTooltip('Go to page'));
    await tester.pumpAndSettle();
    expect(find.byType(MushafIndex), findsOneWidget);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();

    // Turning the page is remembered for next time.
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(p.lastMushafPage, 3);
    expect(find.text('Page 3 · Juzʼ 1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300)); // settings save
  });

  testWidgets('desktop: view modes, arrow keys and Focus', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await _boot(desktop: true);
    await _pump(tester, s, p, page: 1);

    expect(s.mushafView, 'spread');
    expect(
      find.text('Pages 1 – 2 · Juzʼ 1 · ← → to turn · Space to recite'),
      findsOneWidget,
    );

    // ← turns forward a whole spread.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(p.lastMushafPage, 3);

    // Single page: one page at a time.
    await tester.tap(find.byTooltip('Single page, zoomed'));
    await tester.pumpAndSettle();
    expect(s.mushafView, 'single');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(p.lastMushafPage, 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(p.lastMushafPage, 3);

    await tester.tap(find.byTooltip('Fill width — scroll down'));
    await tester.pumpAndSettle();
    expect(s.mushafView, 'fill');

    // Focus hides the bar; Esc brings it back.
    await tester.tap(find.byTooltip('Focus — hide all menus'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close Muṣḥaf').hitTestable(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close Muṣḥaf').hitTestable(), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300)); // settings save
  });

  testWidgets('focus mode: the page opens bare; memorize keeps a small pill',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await _boot(desktop: false);
    s.focusMode = true;
    await _pump(tester, s, p, page: 50);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_barOpacity(tester), 0, reason: 'the bars start hidden');
    expect(s.mushafHeaderShown, isFalse);
    final look = s.mushafLook('uthmani');
    expect((look.header, look.marker, look.border, look.margin),
        ('plain', 'font', 'none', 'none'));

    // A tap in the margin brings the bars back; memorize from the sheet.
    await tester.tapAt(const Offset(12, 420));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_barOpacity(tester), 1);
    await tester.tap(find.byTooltip('Muṣḥaf settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Memorize from this page'));
    await tester.pumpAndSettle();
    final bar = tester.widget<MemorizeBar>(find.byType(MemorizeBar));
    expect(bar.minimal, isTrue, reason: 'only the essentials');
    expect(find.text('Next word'), findsOneWidget);
    expect(find.text('Rest of the āyah'), findsNothing);

    // Leaving focus mode brings the full bar back.
    await tester.tap(find.byTooltip('Leave focus mode'));
    await tester.pumpAndSettle();
    expect(s.focusMode, isFalse);
    expect(tester.widget<MemorizeBar>(find.byType(MemorizeBar)).minimal,
        isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
