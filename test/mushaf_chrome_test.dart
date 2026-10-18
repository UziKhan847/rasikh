import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
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
    await MushafRepo.ensure('uthmani');
  });

  testWidgets('phone: tap toggles the bars, page colour cycles the theme', (
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

    // Cream → white → mono → night → oled → cream.
    expect(s.appTheme, 'light');
    expect(s.mushafPaper, 'cream');
    final colour = find.byTooltip('Page colour');
    await tester.tap(colour);
    await tester.pump();
    expect((s.appTheme, s.mushafPaper), ('light', 'white'));
    for (final t in ['mono', 'night', 'oled']) {
      await tester.tap(colour);
      await tester.pump();
      expect(s.appTheme, t);
    }
    await tester.tap(colour);
    await tester.pump();
    expect((s.appTheme, s.mushafPaper), ('light', 'cream'));

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
}
