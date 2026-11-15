import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rasikh/core/l10n.dart';
import 'package:rasikh/core/settings.dart';
import 'package:rasikh/data/quran.dart';
import 'package:rasikh/main.dart';
import 'package:rasikh/screens/mushaf_screen.dart';
import 'package:rasikh/screens/onboarding_screen.dart';

import 'test_support.dart';

/// [RootScreen]: the welcome on a fresh install, then — finished or skipped
/// — the muṣḥaf, the app's one home.
Future<(AppSettings, ProgressStore)> _boot({bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore();
  await settings.load();
  await progress.load();
  settings
    ..onboarded = onboarded
    ..desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings settings, ProgressStore progress) => SettingsScope(
      settings: settings,
      child: ProgressScope(
        progress: progress,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const RootScreen(),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    mockAudioPlugins();
    await QuranRepo.meta();
    await loadMushaf('uthmani');
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('a fresh install: the welcome; skipped, the muṣḥaf', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await _boot(onboarded: false);
    await tester.pumpWidget(_harness(s, p));
    await settle(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(s.onboarded, isTrue);
    expect(find.byType(MushafPageScreen), findsOneWidget);
    expect(tester.widget<MushafPageScreen>(find.byType(MushafPageScreen)).home, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('once set up, the app opens on the muṣḥaf', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (s, p) = await _boot();
    await tester.pumpWidget(_harness(s, p));
    await settle(tester);
    expect(find.byType(MushafPageScreen), findsOneWidget);
  });
}
