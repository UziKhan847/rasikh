import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/main.dart';
import 'package:qiraah_arabiyyah/screens/learn_screen.dart';
import 'package:qiraah_arabiyyah/screens/onboarding_screen.dart';
import 'package:qiraah_arabiyyah/screens/quran_list_screen.dart';
import 'package:qiraah_arabiyyah/screens/settings_screen.dart';
import 'package:qiraah_arabiyyah/screens/shell/app_mode.dart';
import 'package:qiraah_arabiyyah/screens/shell/app_shell.dart';
import 'package:qiraah_arabiyyah/screens/tracing_screen.dart';

import 'test_support.dart';

/// [RootScreen]: the setup on a fresh install (the mode among its steps),
/// the mode alone once for an install from before the modes, then the
/// chosen mode's home; Settings switches mode.
Future<(AppSettings, ProgressStore)> _boot(
    {bool onboarded = true, String mode = 'reader'}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore();
  await settings.load();
  await progress.load();
  settings
    ..onboarded = onboarded
    ..appMode = mode
    ..desktopMode = 'off';
  return (settings, progress);
}

Widget _harness(AppSettings settings, ProgressStore progress) {
  return SettingsScope(
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a fresh install: the setup, with the mode; then its home',
      (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (settings, progress) = await _boot(onboarded: false, mode: '');
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('Begin')); // welcome → mode
    await tester.pumpAndSettle();
    expect(find.text('How will you use Qiraah?'), findsOneWidget);
    await tester.tap(find.text('Learning'));
    await tester.pumpAndSettle();
    // Learning: appearance, then the daily goal; no script step.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).last); // finish
    await tester.pumpAndSettle();
    expect(settings.onboarded, isTrue);
    expect(settings.mode, AppMode.learn);
    expect(find.byType(LearnScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300)); // settings save
  });

  testWidgets('skipping picks the Reader', (tester) async {
    useReducedMotion(tester);
    final (settings, progress) = await _boot(onboarded: false, mode: '');
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(settings.mode, AppMode.reader);
    expect(find.byType(SurahListScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('an install from before the modes chooses one, once',
      (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (settings, progress) = await _boot(mode: '');
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();
    expect(find.text('How will you use Qiraah?'), findsOneWidget);
    expect(find.text('Begin'), findsNothing, reason: 'the mode step only');
    await tester.tap(find.text('Writing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).last);
    await tester.pumpAndSettle();
    expect(settings.mode, AppMode.write);
    expect(find.byType(TracingScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  for (final (mode, home) in [
    ('reader', SurahListScreen),
    ('learn', LearnScreen),
    ('write', TracingScreen),
  ]) {
    testWidgets('$mode opens to its home', (tester) async {
      useReducedMotion(tester);
      final (settings, progress) = await _boot(mode: mode);
      await tester.pumpWidget(_harness(settings, progress));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(home), findsOneWidget);
    });
  }

  testWidgets('settings: switch mode; long press: the switcher', (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (settings, progress) = await _boot(mode: 'learn');
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(AlsoInApp), findsOneWidget);
    await tester.tap(find.text('Writing'));
    await tester.pumpAndSettle();
    expect(settings.mode, AppMode.write);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TracingScreen), findsOneWidget);

    await tester.longPress(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Switch mode'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
