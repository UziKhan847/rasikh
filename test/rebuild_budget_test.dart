import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/core/theme.dart';
import 'package:qiraah_arabiyyah/data/mushaf.dart';
import 'package:qiraah_arabiyyah/data/quran.dart';
import 'package:qiraah_arabiyyah/screens/mushaf_screen.dart';
import 'package:qiraah_arabiyyah/screens/shell/app_shell.dart';
import 'package:qiraah_arabiyyah/screens/tracing_screen.dart';

import 'test_support.dart';

/// Guards against the rebuild/redraw costs that made the app sluggish on
/// slower devices creeping back.
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

Widget _app(AppSettings s, ProgressStore p, Widget home) => SettingsScope(
      settings: s,
      child: ProgressScope(
        progress: p,
        child: MaterialApp(
          theme: buildTheme(s),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: home,
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await MushafRepo.ensure('uthmani');
  });

  tearDown(() => debugOnRebuildDirtyWidget = null);

  testWidgets('showing/hiding the muṣḥaf bars does not rebuild the pages',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await _boot(desktop: true);
    await tester.pumpWidget(
        _app(s, p, const MushafPageScreen(startPage: 50, script: 'uthmani')));
    await _settle(tester);

    var pageBuilds = 0;
    debugOnRebuildDirtyWidget = (e, _) {
      if (e.widget.runtimeType.toString() == '_MushafPageView') pageBuilds++;
    };
    // Focus (hide bars) via the keyboard-free route: the bar's focus button.
    await tester.tap(find.byTooltip('Focus — hide all menus').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(pageBuilds, 0, reason: 'pages rebuilt on a chrome toggle');
  });

  testWidgets('after the Writing home, the app goes idle (no endless frames)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await _boot(desktop: false);
    s.appMode = 'write';
    await tester.pumpWidget(_app(s, p, const AppShell()));
    await _settle(tester);
    expect(find.byType(TracingScreen), findsOneWidget);
    s.update(() => s.appMode = 'reader');
    // The new home's entrances run their course (a few seconds), then stop.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(TracingScreen), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'something keeps animating after the mode changed');
  });
}
