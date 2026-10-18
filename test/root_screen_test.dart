import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qiraah_arabiyyah/core/l10n.dart';
import 'package:qiraah_arabiyyah/core/settings.dart';
import 'package:qiraah_arabiyyah/main.dart';
import 'package:qiraah_arabiyyah/screens/onboarding_screen.dart';
import 'package:qiraah_arabiyyah/screens/shell/app_shell.dart';
import 'package:qiraah_arabiyyah/screens/today_screen.dart';

import 'test_support.dart';

/// [RootScreen] shows the welcome on a fresh install, then the app shell —
/// bottom tabs on a phone, the sidebar on a desktop-sized window.
Future<(AppSettings, ProgressStore)> _boot({bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings();
  final progress = ProgressStore();
  await settings.load();
  await progress.load();
  settings.onboarded = onboarded;
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

  testWidgets('a fresh install starts on the welcome', (tester) async {
    useReducedMotion(tester);
    final (settings, progress) = await _boot(onboarded: false);
    settings.desktopMode = 'off';
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(settings.onboarded, isTrue);
    expect(find.byType(AppShell), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300)); // settings save
  });

  testWidgets('a desktop-sized window gets the sidebar', (tester) async {
    useReducedMotion(tester);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final (settings, progress) = await _boot();
    settings.desktopMode = 'on';
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('ARABIYYAH'), findsOneWidget);
  });

  testWidgets('a phone gets the bottom tabs, starting on Today',
      (tester) async {
    useReducedMotion(tester);
    final (settings, progress) = await _boot();
    settings.desktopMode = 'off';
    await tester.pumpWidget(_harness(settings, progress));
    await tester.pumpAndSettle();

    expect(find.byType(TodayScreen), findsOneWidget);
    for (final t in ['Today', 'Reader', 'Muṣḥaf', 'Learn', 'Trace']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
  });
}
